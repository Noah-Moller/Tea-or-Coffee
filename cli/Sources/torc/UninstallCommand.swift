import Foundation

struct UninstallCommand {
    let os = detectOS()
    
    var serverBinaryPath: String {
        os == .macOS ? "/usr/local/bin/torc-server" : "/usr/local/bin/torc-server"
    }
    
    var cliBinaryPath: String {
        os == .macOS ? "/usr/local/bin/torc" : "/usr/local/bin/torc"
    }
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    func run() {
        print("Uninstall Tea or Coffee")
        print("=" + String(repeating: "=", count: 30))
        print()
        
        // Check what's installed
        let serverInstalled = checkServerInstalled()
        let cliInstalled = checkCLIInstalled()
        
        if !serverInstalled && !cliInstalled {
            print("Nothing appears to be installed.")
            return
        }
        
        // Show what will be removed
        var itemsToRemove: [String] = []
        if serverInstalled {
            itemsToRemove.append("  - Stop and remove the server service")
            itemsToRemove.append("  - Remove the server binary")
            itemsToRemove.append("  - Remove server installation files")
        }
        if cliInstalled {
            itemsToRemove.append("  - Remove the CLI binary (torc)")
        }
        
        print("This will:")
        for item in itemsToRemove {
            print(item)
        }
        print()
        
        if serverInstalled {
            print("⚠️  WARNING: This will NOT delete:")
            print("  - Session data (Sessions/ directory)")
            print("  - Popular items stats (popular.json)")
            print()
        }
        
        print("Do you want to continue? (yes/no): ", terminator: "")
        
        guard let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
              response == "yes" || response == "y" else {
            print("Uninstall cancelled.")
            return
        }
        
        print()
        
        // Uninstall server if installed
        if serverInstalled {
            // Stop service
            print("Stopping service...")
            stopService()
            
            // Remove service
            print("Removing service...")
            removeService()
            
            // Remove server binary
            print("Removing server binary...")
            if FileManager.default.fileExists(atPath: serverBinaryPath) {
                do {
                    try FileManager.default.removeItem(atPath: serverBinaryPath)
                    print("✓ Server binary removed")
                } catch {
                    print("Warning: Failed to remove server binary: \(error.localizedDescription)")
                    // Try with sudo on Linux
                    if os == .linux {
                        let (_, exitCode) = runShellCommand("sudo rm \(serverBinaryPath)")
                        if exitCode == 0 {
                            print("✓ Server binary removed (with sudo)")
                        }
                    }
                }
            }
            
            // Remove app root (but keep Sessions and popular.json if they exist)
            print("Removing installation files...")
            if FileManager.default.fileExists(atPath: appRoot) {
                let fileManager = FileManager.default
                let appRootURL = URL(fileURLWithPath: appRoot)
                
                do {
                    let contents = try fileManager.contentsOfDirectory(at: appRootURL, includingPropertiesForKeys: nil)
                    
                    for item in contents {
                        let itemName = item.lastPathComponent
                        // Keep Sessions and popular.json
                        if itemName != "Sessions" && itemName != "popular.json" {
                            try? fileManager.removeItem(at: item)
                        }
                    }
                    
                    // If only Sessions and popular.json remain, keep the directory
                    let remaining = try fileManager.contentsOfDirectory(at: appRootURL, includingPropertiesForKeys: nil)
                    if remaining.count <= 2 {
                        print("✓ Kept Sessions/ and popular.json")
                    } else {
                        // Remove everything else
                        for item in remaining {
                            if item.lastPathComponent != "Sessions" && item.lastPathComponent != "popular.json" {
                                try? fileManager.removeItem(at: item)
                            }
                        }
                    }
                    
                    print("✓ Installation files removed")
                } catch {
                    print("Warning: Failed to remove some files: \(error.localizedDescription)")
                }
            }
        }
        
        // Remove CLI if installed
        if cliInstalled {
            print("Removing CLI binary...")
            if FileManager.default.fileExists(atPath: cliBinaryPath) {
                do {
                    try FileManager.default.removeItem(atPath: cliBinaryPath)
                    print("✓ CLI binary removed")
                } catch {
                    print("Warning: Failed to remove CLI binary: \(error.localizedDescription)")
                    // Try with sudo on Linux
                    if os == .linux {
                        let (_, exitCode) = runShellCommand("sudo rm \(cliBinaryPath)")
                        if exitCode == 0 {
                            print("✓ CLI binary removed (with sudo)")
                        } else {
                            print("Error: Could not remove CLI binary. You may need to run: sudo rm \(cliBinaryPath)")
                        }
                    } else {
                        print("Error: Could not remove CLI binary. You may need to run: rm \(cliBinaryPath)")
                    }
                }
            }
        }
        
        // Remove app root (but keep Sessions and popular.json if they exist)
        print("Removing installation files...")
        if FileManager.default.fileExists(atPath: appRoot) {
            let fileManager = FileManager.default
            let appRootURL = URL(fileURLWithPath: appRoot)
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: appRootURL, includingPropertiesForKeys: nil)
                
                for item in contents {
                    let itemName = item.lastPathComponent
                    // Keep Sessions and popular.json
                    if itemName != "Sessions" && itemName != "popular.json" {
                        try? fileManager.removeItem(at: item)
                    }
                }
                
                // If only Sessions and popular.json remain, keep the directory
                let remaining = try fileManager.contentsOfDirectory(at: appRootURL, includingPropertiesForKeys: nil)
                if remaining.count <= 2 {
                    print("✓ Kept Sessions/ and popular.json")
                } else {
                    // Remove everything else
                    for item in remaining {
                        if item.lastPathComponent != "Sessions" && item.lastPathComponent != "popular.json" {
                            try? fileManager.removeItem(at: item)
                        }
                    }
                }
                
                print("✓ Installation files removed")
            } catch {
                print("Warning: Failed to remove some files: \(error.localizedDescription)")
            }
        }
        
        print()
        print("✓ Uninstall complete!")
        print()
        
        if serverInstalled {
            print("Note: Session data and popular.json were preserved.")
            print("To remove them manually, delete:")
            print("  \(appRoot)/Sessions/")
            print("  \(appRoot)/popular.json")
        }
        
        if cliInstalled {
            print()
            print("CLI has been removed. To reinstall, run:")
            print("  curl -fsSL https://raw.githubusercontent.com/Noah-Moller/tea-or-coffee/main/cli/install.sh | bash")
        }
    }
    
    func checkServerInstalled() -> Bool {
        let serviceExists = os == .macOS ?
            FileManager.default.fileExists(atPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")) :
            FileManager.default.fileExists(atPath: "/etc/systemd/system/torc-server.service")
        
        return serviceExists || FileManager.default.fileExists(atPath: serverBinaryPath) || FileManager.default.fileExists(atPath: appRoot)
    }
    
    func checkCLIInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: cliBinaryPath)
    }
    
    func stopService() {
        if os == .macOS {
            let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")
            if FileManager.default.fileExists(atPath: plistPath) {
                let (_, _) = runShellCommand("launchctl unload \(plistPath) 2>/dev/null")
            }
        } else {
            let (_, _) = runShellCommand("sudo systemctl stop torc-server 2>/dev/null")
            let (_, _) = runShellCommand("sudo systemctl disable torc-server 2>/dev/null")
        }
    }
    
    func removeService() {
        if os == .macOS {
            let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")
            if FileManager.default.fileExists(atPath: plistPath) {
                do {
                    try FileManager.default.removeItem(atPath: plistPath)
                    print("✓ Launchd service removed")
                } catch {
                    print("Warning: Failed to remove launchd plist: \(error.localizedDescription)")
                }
            }
        } else {
            let servicePath = "/etc/systemd/system/torc-server.service"
            if FileManager.default.fileExists(atPath: servicePath) {
                let (_, exitCode) = runShellCommand("sudo rm \(servicePath)")
                if exitCode == 0 {
                    let (_, _) = runShellCommand("sudo systemctl daemon-reload")
                    print("✓ Systemd service removed")
                } else {
                    print("Warning: Failed to remove systemd service (may need sudo)")
                }
            }
        }
    }
}
