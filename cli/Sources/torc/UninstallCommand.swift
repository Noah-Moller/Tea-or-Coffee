import Foundation

struct UninstallCommand {
    let os = detectOS()
    
    var binaryPath: String {
        os == .macOS ? "/usr/local/bin/torc-server" : "/usr/local/bin/torc-server"
    }
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    func run() {
        print("Uninstall Tea or Coffee Server")
        print("=" + String(repeating: "=", count: 30))
        print()
        
        // Check if installed
        let isInstalled = checkInstalled()
        
        if !isInstalled {
            print("Server does not appear to be installed.")
            return
        }
        
        // Confirm
        print("This will:")
        print("  - Stop and remove the service")
        print("  - Remove the server binary")
        print("  - Remove installation files")
        print()
        print("⚠️  WARNING: This will NOT delete:")
        print("  - Session data (Sessions/ directory)")
        print("  - Popular items stats (popular.json)")
        print()
        print("Do you want to continue? (yes/no): ", terminator: "")
        
        guard let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
              response == "yes" || response == "y" else {
            print("Uninstall cancelled.")
            return
        }
        
        print()
        
        // Stop service
        print("Stopping service...")
        stopService()
        
        // Remove service
        print("Removing service...")
        removeService()
        
        // Remove binary
        print("Removing binary...")
        if FileManager.default.fileExists(atPath: binaryPath) {
            do {
                try FileManager.default.removeItem(atPath: binaryPath)
                print("✓ Binary removed")
            } catch {
                print("Warning: Failed to remove binary: \(error.localizedDescription)")
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
        print("Note: Session data and popular.json were preserved.")
        print("To remove them manually, delete:")
        print("  \(appRoot)/Sessions/")
        print("  \(appRoot)/popular.json")
    }
    
    func checkInstalled() -> Bool {
        let serviceExists = os == .macOS ?
            FileManager.default.fileExists(atPath: (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")) :
            FileManager.default.fileExists(atPath: "/etc/systemd/system/torc-server.service")
        
        return serviceExists || FileManager.default.fileExists(atPath: binaryPath) || FileManager.default.fileExists(atPath: appRoot)
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
