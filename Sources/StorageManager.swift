import Foundation

// MARK: - Models

struct DriveInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let totalSpace: Int64
    let freeSpace: Int64
    let isInternal: Bool
    
    var usedSpace: Int64 {
        return totalSpace - freeSpace
    }
    
    var usedFraction: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }
    
    var formattedTotal: String {
        return totalSpace.formattedStorageSize()
    }
    
    var formattedFree: String {
        return freeSpace.formattedStorageSize()
    }
    
    var formattedUsed: String {
        return usedSpace.formattedStorageSize()
    }
}

struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    
    var formattedSize: String {
        return size.formattedStorageSize()
    }
}

struct FileItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let name: String
    let path: String
    let size: Int64
    let fileExtension: String
    
    var formattedSize: String {
        return size.formattedStorageSize()
    }
    
    var truncatedPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }
}

struct StorageBreakdown: Codable, Equatable {
    var appsSize: Int64 = 0
    var developerSize: Int64 = 0
    var mediaSize: Int64 = 0
    var documentsSize: Int64 = 0
    var otherSize: Int64 = 0
    var topFiles: [FileItem] = []
    
    var totalCategorizedSize: Int64 {
        return appsSize + developerSize + mediaSize + documentsSize + otherSize
    }
}

struct PinnedFolder: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let path: String
    var size: Int64 = 0
    
    var formattedSize: String {
        return size.formattedStorageSize()
    }
    
    var truncatedPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }
}

// MARK: - ByteCountFormatter Extension

extension Int64 {
    func formattedStorageSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - Storage Manager Engine

class StorageManager {
    
    /// Fetches all mounted volumes (internal & external drives)
    func fetchDrives() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsInternalKey]
        
        // Always attempt root /
        let rootURL = URL(fileURLWithPath: "/")
        if let rootDrive = getDriveInfo(for: rootURL, isInternalDefault: true) {
            drives.append(rootDrive)
        }
        
        // Query mounted volumes
        let volumeURLs = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        for url in volumeURLs {
            if url.path == "/" { continue } // Already added root
            if let drive = getDriveInfo(for: url, isInternalDefault: false) {
                drives.append(drive)
            }
        }
        return drives
    }
    
    private func getDriveInfo(for url: URL, isInternalDefault: Bool) -> DriveInfo? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsInternalKey])
            let name = values.volumeLocalizedName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            let isInternal = values.volumeIsInternal ?? isInternalDefault
            
            // Exclude read-only installers (dmg) and small virtual volumes
            guard total > 100 * 1024 * 1024 else { return nil } // Min 100 MB
            
            return DriveInfo(name: name, path: url.path, totalSpace: total, freeSpace: free, isInternal: isInternal)
        } catch {
            return nil
        }
    }
    
    /// Scans /Applications and ~/Applications for app bundle sizes
    func scanApplications() async -> [AppItem] {
        return await Task.detached(priority: .userInitiated) {
            var items: [AppItem] = []
            let appDirs = ["/Applications", "\(NSHomeDirectory())/Applications"]
            
            for dirPath in appDirs {
                let dirURL = URL(fileURLWithPath: dirPath)
                guard let contents = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isPackageKey], options: [.skipsHiddenFiles]) else {
                    continue
                }
                
                for itemURL in contents {
                    if itemURL.pathExtension == "app" {
                        let appSize = self.getDirectorySize(at: itemURL)
                        let appName = itemURL.deletingPathExtension().lastPathComponent
                        items.append(AppItem(name: appName, path: itemURL.path, size: appSize))
                    }
                }
            }
            
            // Sort by size descending
            items.sort { $0.size > $1.size }
            return items
        }.value
    }
    
    /// Recursively scans Downloads, Documents, Desktop, and Developer data
    func scanFilesAndCategories() async -> StorageBreakdown {
        return await Task.detached(priority: .userInitiated) {
            var breakdown = StorageBreakdown()
            var allFiles: [FileItem] = []
            
            let homeDir = NSHomeDirectory()
            let scanTargets = [
                "\(homeDir)/Downloads",
                "\(homeDir)/Documents",
                "\(homeDir)/Desktop"
            ]
            
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            
            // Folders to skip for speed and security
            let skipFolders = ["node_modules", ".git", "Pods", "Carthage", ".build", "Library", "Applications"]
            
            for targetPath in scanTargets {
                let targetURL = URL(fileURLWithPath: targetPath)
                
                guard let enumerator = fileManager.enumerator(
                    at: targetURL,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continue
                }
                
                while let fileURL = enumerator.nextObject() as? URL {
                    // Performance optimization: skip heavy folders
                    if skipFolders.contains(fileURL.lastPathComponent) {
                        enumerator.skipDescendants()
                        continue
                    }
                    
                    do {
                        let values = try fileURL.resourceValues(forKeys: Set(keys))
                        
                        guard values.isRegularFile == true else { continue }
                        let size = Int64(values.fileSize ?? 0)
                        guard size > 0 else { continue }
                        
                        let ext = fileURL.pathExtension.lowercased()
                        let item = FileItem(name: fileURL.lastPathComponent, path: fileURL.path, size: size, fileExtension: ext)
                        
                        allFiles.append(item)
                        
                        // Classify sizes
                        if self.isMedia(ext) {
                            breakdown.mediaSize += size
                        } else if self.isDocument(ext) {
                            breakdown.documentsSize += size
                        } else {
                            breakdown.otherSize += size
                        }
                    } catch {
                        // Skip unreadable files
                    }
                }
            }
            
            // Add Developer Data (Xcode DerivedData and Archives)
            let developerPath = "\(homeDir)/Library/Developer"
            if fileManager.fileExists(atPath: developerPath) {
                let devURL = URL(fileURLWithPath: developerPath)
                breakdown.developerSize = self.getDirectorySize(at: devURL)
            }
            
            // Sort to get top 5 largest files
            allFiles.sort { $0.size > $1.size }
            breakdown.topFiles = Array(allFiles.prefix(5))
            
            return breakdown
        }.value
    }
    
    /// Public async API to calculate a directory size on a detached utility thread
    func getDirectorySizeAsync(at url: URL) async -> Int64 {
        return await Task.detached(priority: .utility) {
            return self.getDirectorySize(at: url)
        }.value
    }
    
    // Calculates size of a folder (e.g. app bundle or developer cache)
    private func getDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        
        let skipFolders = ["node_modules", ".git", "Pods", "Carthage", ".build"]
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            if skipFolders.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            
            do {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                if values.isRegularFile == true {
                    size += Int64(values.fileSize ?? 0)
                }
            } catch {
                // Ignore files we can't read
            }
        }
        return size
    }
    
    private func isMedia(_ ext: String) -> Bool {
        let mediaExtensions = [
            "mp4", "mov", "avi", "mkv", "webm", "flv", "m4v",
            "mp3", "wav", "aac", "flac", "m4a", "ogg",
            "png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "svg",
            "dmg", "iso", "zip", "tar", "gz", "rar", "7z" // Grouping archives under media/other
        ]
        return mediaExtensions.contains(ext)
    }
    
    private func isDocument(_ ext: String) -> Bool {
        let docExtensions = [
            "pdf", "txt", "pages", "key", "numbers", "doc", "docx",
            "xls", "xlsx", "ppt", "pptx", "md", "rtf", "json", "csv",
            "yaml", "xml", "html", "css", "js", "ts", "swift"
        ]
        return docExtensions.contains(ext)
    }
    
    /// Traverses the folder structure of a custom volume URL (e.g. external SSD)
    /// to categorize Application bundles, Documents, Media, and other files.
    func scanDriveBreakdown(at url: URL) async -> StorageBreakdown {
        return await Task.detached(priority: .userInitiated) {
            var breakdown = StorageBreakdown()
            var allFiles: [FileItem] = []
            var appsSize: Int64 = 0
            
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            
            // Standard directory exclusion filter to prevent deep scanning system or heavy files
            let skipFolders = ["node_modules", ".git", "Pods", "Carthage", ".build", "Library", "System", "Volumes", ".DocumentRevisions-V100", ".Spotlight-V100", ".Trashes"]
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return breakdown
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Performance skip
                if skipFolders.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                
                // If it is a package ending in .app, it's an application bundle
                if fileURL.pathExtension == "app" {
                    let appSize = self.getDirectorySize(at: fileURL)
                    appsSize += appSize
                    enumerator.skipDescendants() // Skip scanning files inside this package
                    continue
                }
                
                do {
                    let values = try fileURL.resourceValues(forKeys: Set(keys))
                    if values.isRegularFile == true {
                        let size = Int64(values.fileSize ?? 0)
                        guard size > 0 else { continue }
                        
                        let ext = fileURL.pathExtension.lowercased()
                        let item = FileItem(name: fileURL.lastPathComponent, path: fileURL.path, size: size, fileExtension: ext)
                        allFiles.append(item)
                        
                        // Classify sizes
                        if self.isMedia(ext) {
                            breakdown.mediaSize += size
                        } else if self.isDocument(ext) {
                            breakdown.documentsSize += size
                        } else {
                            breakdown.otherSize += size
                        }
                    }
                } catch {
                    // Skip unreadable files
                }
            }
            
            breakdown.appsSize = appsSize
            
            // Sort to get top 5 largest files on the external drive
            allFiles.sort { $0.size > $1.size }
            breakdown.topFiles = Array(allFiles.prefix(5))
            
            return breakdown
        }.value
    }
}
