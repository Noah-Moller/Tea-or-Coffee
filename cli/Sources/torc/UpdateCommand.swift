import Foundation

struct UpdateCommand {
    let os = detectOS()
    
    var cliBinaryPath: String {
        os == .macOS ? "/usr/local/bin/torc" : "/usr/local/bin/torc"
    }
    
    var serverBinaryPath: String {
        os == .macOS ? "/usr/local/bin/torc-server" : "/usr/local/bin/torc-server"
    }
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    func run() {
        print("Updating Tea or Coffee...")
        print()
        
        // Update CLI
        print("Updating CLI...")
        if updateCLI() {
            print("✓ CLI updated successfully")
        } else {
            print("⚠️  CLI update failed or skipped")
        }
        
        print()
        
        // Update server if installed
        if checkServerInstalled() {
            print("Updating server...")
            if updateServer() {
                print("✓ Server updated successfully")
            } else {
                print("⚠️  Server update failed")
            }
        } else {
            print("Server not installed. Run 'torc install' to install it.")
        }
        
        print()
        print("✓ Update complete!")
    }
    
    func updateCLI() -> Bool {
        // Get current platform
        let platform = getPlatform()
        let binaryName = "torc-\(platform)"
        
        // Get latest version
        guard let latestVersion = getLatestVersion() else {
            print("Warning: Could not determine latest version")
            return false
        }
        
        let downloadURL = "https://github.com/Noah-Moller/tea-or-coffee/releases/download/\(latestVersion)/\(binaryName)"
        
        print("  Latest version: \(latestVersion)")
        print("  Downloading from: \(downloadURL)")
        
        // Download to temp file
        let tempFile = "/tmp/torc-update-\(UUID().uuidString)"
        let (_, exitCode) = runShellCommand("curl -fsSL '\(downloadURL)' -o '\(tempFile)'")
        
        if exitCode != 0 {
            print("  Error: Failed to download latest CLI")
            return false
        }
        
        // Make executable
        let (_, chmodExitCode) = runShellCommand("chmod +x '\(tempFile)'")
        if chmodExitCode != 0 {
            print("  Error: Failed to make binary executable")
            return false
        }
        
        // Verify it's actually a binary (basic check)
        let (verifyOutput, verifyExitCode) = runShellCommand("file '\(tempFile)'")
        if verifyExitCode != 0 || (!verifyOutput.contains("Mach-O") && !verifyOutput.contains("ELF")) {
            print("  Error: Downloaded file doesn't appear to be a valid binary")
            try? FileManager.default.removeItem(atPath: tempFile)
            return false
        }
        
        // Backup current binary if it exists
        if FileManager.default.fileExists(atPath: cliBinaryPath) {
            let backupPath = "\(cliBinaryPath).backup"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.moveItem(atPath: cliBinaryPath, toPath: backupPath)
        }
        
        // Install new binary
        if os == .macOS {
            // macOS: try without sudo first
            let (_, moveExitCode) = runShellCommand("mv '\(tempFile)' '\(cliBinaryPath)'")
            if moveExitCode != 0 {
                // Try with sudo
                let (_, sudoExitCode) = runShellCommand("sudo mv '\(tempFile)' '\(cliBinaryPath)'")
                if sudoExitCode != 0 {
                    print("  Error: Failed to install new CLI (may need sudo)")
                    // Restore backup
                    if FileManager.default.fileExists(atPath: "\(cliBinaryPath).backup") {
                        try? FileManager.default.moveItem(atPath: "\(cliBinaryPath).backup", toPath: cliBinaryPath)
                    }
                    return false
                }
            }
        } else {
            // Linux: need sudo
            let (_, sudoExitCode) = runShellCommand("sudo mv '\(tempFile)' '\(cliBinaryPath)'")
            if sudoExitCode != 0 {
                print("  Error: Failed to install new CLI (may need sudo)")
                // Restore backup
                if FileManager.default.fileExists(atPath: "\(cliBinaryPath).backup") {
                    try? FileManager.default.moveItem(atPath: "\(cliBinaryPath).backup", toPath: cliBinaryPath)
                }
                return false
            }
        }
        
        // Remove backup
        try? FileManager.default.removeItem(atPath: "\(cliBinaryPath).backup")
        
        return true
    }
    
    func updateServer() -> Bool {
        // Get project root (check if repo exists in appRoot or clone it)
        var projectRoot: String?
        
        // First check if repo exists in appRoot
        let repoPath = (appRoot as NSString).appendingPathComponent("tea-or-coffee")
        let mainGoPath = (repoPath as NSString).appendingPathComponent("main.go")
        
        if FileManager.default.fileExists(atPath: mainGoPath) {
            projectRoot = repoPath
        } else {
            // Try to find project root from current directory
            projectRoot = getProjectRoot()
        }
        
        // If still not found, clone it
        if projectRoot == nil {
            print("  Cloning repository...")
            let cloneDir = "/tmp/tea-or-coffee-update"
            try? FileManager.default.removeItem(atPath: cloneDir)
            
            let (output, exitCode) = runShellCommand("git clone https://github.com/Noah-Moller/tea-or-coffee.git \(cloneDir)")
            if exitCode != 0 {
                print("  Error: Failed to clone repository")
                print("  \(output)")
                return false
            }
            projectRoot = cloneDir
        } else {
            // Pull latest changes
            print("  Updating repository...")
            let (output, exitCode) = runShellCommand("git pull", workingDirectory: projectRoot)
            if exitCode != 0 {
                print("  Warning: Failed to pull latest changes: \(output)")
            }
        }
        
        guard let root = projectRoot else {
            return false
        }
        
        // Build server
        print("  Building server...")
        let (output, exitCode) = runCommand("go", arguments: ["build", "-o", serverBinaryPath, "main.go"], workingDirectory: root)
        
        if exitCode != 0 {
            print("  Error: Failed to build server")
            print("  \(output)")
            return false
        }
        
        // Restart service
        print("  Restarting service...")
        if os == .macOS {
            let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")
            if FileManager.default.fileExists(atPath: plistPath) {
                let (_, _) = runShellCommand("launchctl unload \(plistPath) 2>/dev/null")
                let (_, _) = runShellCommand("launchctl load \(plistPath) 2>/dev/null")
            }
        } else {
            let (_, _) = runShellCommand("sudo systemctl restart torc-server")
        }
        
        return true
    }
    
    func getLatestVersion() -> String? {
        let (output, exitCode) = runShellCommand("curl -s 'https://api.github.com/repos/Noah-Moller/tea-or-coffee/releases/latest' | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\\1/'")
        
        if exitCode == 0 && !output.isEmpty {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    func getPlatform() -> String {
        #if os(macOS)
        let arch = runShellCommand("uname -m").output.trimmingCharacters(in: .whitespacesAndNewlines)
        if arch == "arm64" {
            return "macos-arm64"
        } else {
            return "macos-x86_64"
        }
        #else
        return "linux-amd64"
        #endif
    }
    
    func checkServerInstalled() -> Bool {
        let serviceExists = os == .macOS ?
            FileManager.default.fileExists(atPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")) :
            FileManager.default.fileExists(atPath: "/etc/systemd/system/torc-server.service")
        
        return serviceExists || FileManager.default.fileExists(atPath: serverBinaryPath)
    }
}
