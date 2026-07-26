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
    
    /// Returns path to embedded Gemma 270M GGUF model
    func getGemmaModelPath() -> String? {
        // 1. App Bundle Resources
        if let path = Bundle.main.path(forResource: "gemma-270m", ofType: "gguf", inDirectory: "models"),
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let resourcePath = Bundle.main.resourcePath {
            let path = (resourcePath as NSString).appendingPathComponent("models/gemma-270m.gguf")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 2. Relative working directory
        let localPath = "Resources/models/gemma-270m.gguf"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        let currentDir = FileManager.default.currentDirectoryPath
        let absLocalPath = (currentDir as NSString).appendingPathComponent("Resources/models/gemma-270m.gguf")
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
    
    /// Generates a local response using the embedded Gemma 270M GGUF model via llama-cli
    func generateResponse(prompt: String, contextPath: String? = nil, onToken: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        cancelGeneration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let cliPath = self.getLlamaCliPath() else {
                DispatchQueue.main.async {
                    onToken("Error: Bundled 'llama-cli' binary not found. Please ensure the app bundle includes Resources/bin/llama-cli.")
                    onComplete()
                }
                return
            }
            
            guard let modelPath = self.getGemmaModelPath() else {
                DispatchQueue.main.async {
                    onToken("Error: 'gemma-270m.gguf' model file not found in Resources/models/.")
                    onComplete()
                }
                return
            }
            
            // Construct context-aware prompt
            var fullPrompt = prompt
            if let path = contextPath, !path.isEmpty {
                fullPrompt = "Context Directory: \(path)\n\nUser Question: \(prompt)"
            }
            
            // Format Gemma Official Instruct Template
            let formattedPrompt = "<start_of_turn>user\n\(fullPrompt)<end_of_turn>\n<start_of_turn>model\n"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            
            // llama-cli options for Gemma 270M Instruct GGUF inference
            var args = [
                "-m", modelPath,
                "-p", formattedPrompt,
                "-n", "256",
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
            var isStreamStarted = false
            var pendingBuffer = ""
            
            handle.readabilityHandler = { fileHandle in
                let availableData = fileHandle.availableData
                if availableData.isEmpty {
                    return
                }
                if let rawChunk = String(data: availableData, encoding: .utf8) {
                    if !isStreamStarted {
                        pendingBuffer += rawChunk
                        // Check if prompt echo finished at <start_of_turn>model
                        if let range = pendingBuffer.range(of: "<start_of_turn>model") {
                            isStreamStarted = true
                            let remaining = String(pendingBuffer[range.upperBound...])
                            let cleaned = LocalAIEngine.cleanTokenText(remaining)
                            if !cleaned.isEmpty {
                                DispatchQueue.main.async {
                                    onToken(cleaned)
                                }
                            }
                        } else if let range = pendingBuffer.range(of: "model\n") {
                            isStreamStarted = true
                            let remaining = String(pendingBuffer[range.upperBound...])
                            let cleaned = LocalAIEngine.cleanTokenText(remaining)
                            if !cleaned.isEmpty {
                                DispatchQueue.main.async {
                                    onToken(cleaned)
                                }
                            }
                        }
                    } else {
                        let cleaned = LocalAIEngine.cleanTokenText(rawChunk)
                        if !cleaned.isEmpty {
                            DispatchQueue.main.async {
                                onToken(cleaned)
                            }
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
    
    /// Filters out control tags, prompt echo fragments, and timing statistics
    private static func cleanTokenText(_ text: String) -> String {
        let result = text
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<start_of_turn>", with: "")
            .replacingOccurrences(of: "<end_of_turn>", with: "")
            .replacingOccurrences(of: "assistantuser", with: "")
            .replacingOccurrences(of: "userassistant", with: "")
            .replacingOccurrences(of: "Assistantuser", with: "")
        
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
               l.contains("Exiting...") ||
               l.contains("[ Prompt:") ||
               l.contains("▄▄ ▄▄") ||
               l.contains("██ ██") ||
               l.hasPrefix(">") {
                continue
            }
            filteredLines.append(line)
        }
        
        return filteredLines.joined(separator: "\n")
    }
}

