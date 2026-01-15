import Foundation

enum OperatingSystem {
    case macOS
    case linux
}

func detectOS() -> OperatingSystem {
    #if os(macOS)
    return .macOS
    #else
    return .linux
    #endif
}

func runCommand(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments
    
    if let workingDirectory = workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
    }
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return (output.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
    } catch {
        return ("Error: \(error.localizedDescription)", 1)
    }
}

func runShellCommand(_ command: String, workingDirectory: String? = nil) -> (output: String, exitCode: Int32) {
    let os = detectOS()
    let shell = os == .macOS ? "/bin/zsh" : "/bin/bash"
    return runCommand(shell, arguments: ["-c", command], workingDirectory: workingDirectory)
}

func checkCommandExists(_ command: String) -> Bool {
    let (output, exitCode) = runShellCommand("which \(command)")
    return exitCode == 0 && !output.isEmpty
}

func getIPAddresses() -> [String] {
    var addresses: [String] = []
    
    #if os(macOS)
    let (output, _) = runShellCommand("ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}'")
    addresses = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    #else
    let (output, _) = runShellCommand("ip -4 addr show | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1")
    addresses = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    #endif
    
    return addresses
}

func getProjectRoot() -> String? {
    let currentPath = FileManager.default.currentDirectoryPath
    var path = currentPath
    
    // Look for main.go in current or parent directories
    while !path.isEmpty && path != "/" {
        let mainGoPath = (path as NSString).appendingPathComponent("main.go")
        if FileManager.default.fileExists(atPath: mainGoPath) {
            return path
        }
        path = (path as NSString).deletingLastPathComponent
    }
    
    return nil
}

func ensureDirectoryExists(_ path: String) throws {
    if !FileManager.default.fileExists(atPath: path) {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
}

func copyItem(at source: String, to destination: String) throws {
    let sourceURL = URL(fileURLWithPath: source)
    let destURL = URL(fileURLWithPath: destination)
    
    // Remove destination if it exists
    if FileManager.default.fileExists(atPath: destination) {
        try FileManager.default.removeItem(at: destURL)
    }
    
    // Ensure destination directory exists
    let destDir = destURL.deletingLastPathComponent().path
    try ensureDirectoryExists(destDir)
    
    try FileManager.default.copyItem(at: sourceURL, to: destURL)
}
