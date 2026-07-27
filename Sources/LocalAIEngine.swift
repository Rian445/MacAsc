import Foundation
import Metal

class LocalAIEngine {
    static let shared = LocalAIEngine()
    
    private var activeProcess: Process?
    
    private var isMetalSupported: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    /// Returns path to bundled llama-cli binary
    func getLlamaCliPath() -> String? {
        // 1. App Bundle Resources
        if let path = Bundle.main.path(forResource: "llama-cli", ofType: nil, inDirectory: "bin"),
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let resourcePath = Bundle.main.resourcePath {
            let path = (resourcePath as NSString).appendingPathComponent("bin/llama-cli")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 2. Local relative working directory
        let localPath = "Resources/bin/llama-cli"
        if FileManager.default.fileExists(atPath: localPath) {
            return (localPath as NSString).expandingTildeInPath
        }
        let currentDir = FileManager.default.currentDirectoryPath
        let absLocalPath = (currentDir as NSString).appendingPathComponent("Resources/bin/llama-cli")
        if FileManager.default.fileExists(atPath: absLocalPath) {
            return absLocalPath
        }
        // 3. Built llama.cpp output path
        let builtPath = ".build/llama.cpp/build/bin/llama-cli"
        if FileManager.default.fileExists(atPath: builtPath) {
            return (builtPath as NSString).expandingTildeInPath
        }
        // 4. System fallbacks
        let fallbacks = ["/usr/local/bin/llama-cli", "/opt/homebrew/bin/llama-cli"]
        for p in fallbacks {
            if FileManager.default.fileExists(atPath: p) {
                return p
            }
        }
        return nil
    }
    
    /// Returns path to embedded Gemma 1B Instruct GGUF model
    func getGemmaModelPath() -> String? {
        let name = "gemma-1b.gguf"
        let baseName = "gemma-1b"
        // 1. App Bundle Resources
        if let path = Bundle.main.path(forResource: baseName, ofType: "gguf", inDirectory: "models"),
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let resourcePath = Bundle.main.resourcePath {
            let path = (resourcePath as NSString).appendingPathComponent("models/\(name)")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 2. Relative working directory
        let localPath = "Resources/models/\(name)"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        let currentDir = FileManager.default.currentDirectoryPath
        let absLocalPath = (currentDir as NSString).appendingPathComponent("Resources/models/\(name)")
        if FileManager.default.fileExists(atPath: absLocalPath) {
            return absLocalPath
        }
        return nil
    }
    
    /// Cancels any currently active generation process
    func cancelGeneration() {
        if let process = activeProcess, process.isRunning {
            process.terminate()
            activeProcess = nil
        }
    }
    
    /// Generates a local response using the embedded Gemma 1B Instruct model via llama-cli
    func generateResponse(prompt: String, history: [ChatMessage] = [], contextPath: String? = nil, onToken: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        cancelGeneration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let cliPath = self.getLlamaCliPath() else {
                DispatchQueue.main.async {
                    onToken("Error: Bundled 'llama-cli' binary not found.")
                    onComplete()
                }
                return
            }
            
            guard let modelPath = self.getGemmaModelPath() else {
                DispatchQueue.main.async {
                    onToken("Error: 'gemma-1b.gguf' model file not found in Resources/models/.")
                    onComplete()
                }
                return
            }
            
            // System Persona & Context Metadata
            var systemContext = "You are MacASC AI, an expert macOS utility & terminal assistant. Provide helpful, accurate, and concise answers."
            if let path = contextPath, !path.isEmpty {
                systemContext += "\nAttached Context Directory: \(path)"
            }
            
            let formattedPrompt = """
            <start_of_turn>user
            System Persona: \(systemContext)

            User Question: \(prompt)<end_of_turn>
            <start_of_turn>model

            """
            
            #if DEBUG
            print("===== MACASC PROMPT =====")
            print(formattedPrompt)
            print("=========================")
            #endif
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            
            // llama-cli options for Gemma 1B Instruct GGUF single-turn inference
            var args = [
                "-m", modelPath,
                "-c", "4096",
                "-p", formattedPrompt,
                "-n", "512",
                "--temp", "0.7",
                "--no-display-prompt",
                "-st",
                "--simple-io",
                "-r", "<end_of_turn>",
                "-r", "<start_of_turn>"
            ]
            
            // Metal GPU offloading flag on macOS
            if self.isMetalSupported {
                args.append(contentsOf: ["-ngl", "99"])
            }
            
            process.arguments = args
            process.standardInput = FileHandle.nullDevice
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            self.activeProcess = process
            
            let handle = pipe.fileHandleForReading
            var isFirstStreamChunk = true
            
            handle.readabilityHandler = { fileHandle in
                let availableData = fileHandle.availableData
                if availableData.isEmpty {
                    return
                }
                if let rawChunk = String(data: availableData, encoding: .utf8) {
                    var cleaned = LocalAIEngine.cleanTokenText(rawChunk)
                    
                    if isFirstStreamChunk {
                        // Strip leading blank space, newlines, and leading orphan commas at the start of response
                        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                        while cleaned.hasPrefix(",") {
                            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if cleaned.isEmpty {
                            return
                        }
                        isFirstStreamChunk = false
                    }
                    
                    if !cleaned.isEmpty {
                        DispatchQueue.main.async {
                            onToken(cleaned)
                        }
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    onToken("\n[Inference Error: \(error.localizedDescription)]")
                }
            }
            
            handle.readabilityHandler = nil
            self.activeProcess = nil
            
            DispatchQueue.main.async {
                onComplete()
            }
        }
    }
    
    /// Strips speaker label prefixes the model sometimes echoes from the transcript format
    private static func stripSpeakerPrefix(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["MacASC AI: MacASC AI:", "MacASC AI: ASC AI:", "ASC AI: ASC AI:", "MacASC AI:", "ASC AI:", "Mac ASC AI:", "Mac ASC:"] {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return result
    }
    
    /// Filters out control tags, prompt echo fragments, and timing statistics
    private static func cleanTokenText(_ text: String) -> String {
        var result = text
        
        // Strip trailing partial tag artifacts like <start_of_tu or <end_of_tu before outputting to UI
        for pattern in ["<start_of_turn>", "<start_of_turn", "<start_of_tu", "<start_of", "<start_", "<end_of_turn>", "<end_of_turn", "<end_of_tu", "<end_of", "<end_"] {
            if let tagRange = result.range(of: pattern) {
                result = String(result[..<tagRange.lowerBound])
            }
        }
        
        // If prompt header or memory context fragment leaked into text, strip up to <start_of_turn>model or model\n
        if result.contains("System Persona:") || result.contains("[Recent Conversation Memory Context]:") || result.contains("User Question:") {
            if let range = result.range(of: "<start_of_turn>model") {
                result = String(result[range.upperBound...])
            } else if let range = result.range(of: "model\n") {
                result = String(result[range.upperBound...])
            }
        }
        
        result = result
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<start_of_turn>", with: "")
            .replacingOccurrences(of: "<end_of_turn>", with: "")
        
        let lines = result.components(separatedBy: "\n")
        var filteredLines: [String] = []
        for line in lines {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.contains("Loading model...") ||
               l.contains("build      :") ||
               l.contains("model      :") ||
               l.contains("ftype      :") ||
               l.contains("modalities :") ||
               l.contains("available commands:") ||
               l.contains("/exit or Ctrl+C") ||
               l.contains("/clear") ||
               l.contains("/read") ||
               l.contains("/glob") ||
               l.contains("/regen") ||
               l.contains("Exiting...") ||
               l.contains("[ Prompt:") ||
               l.contains("█") ||
               l.contains("▄") ||
               l.contains("▀") ||
               l.hasPrefix("System Persona:") ||
               l.hasPrefix("[Recent Conversation Memory Context]:") ||
               l.hasPrefix("User Question:") ||
               l.hasPrefix(">") {
                continue
            }
            filteredLines.append(line)
        }
        
        return filteredLines.joined(separator: "\n")
    }
}

