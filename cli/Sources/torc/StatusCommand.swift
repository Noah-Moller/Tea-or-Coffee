import Foundation

struct StatusCommand {
    let os = detectOS()
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    func run() {
        print("Tea or Coffee Server Status")
        print("=" + String(repeating: "=", count: 30))
        print()
        
        // Check if service is running
        let isRunning = checkServiceStatus()
        
        if isRunning {
            print("Status: ✓ Running")
        } else {
            print("Status: ✗ Not running")
        }
        print()
        
        // Print URLs
        printURLs()
        
        // Show logs on Linux
        if os == .linux && isRunning {
            print()
            print("Recent logs:")
            print("-" + String(repeating: "-", count: 30))
            let (output, _) = runShellCommand("sudo journalctl -u torc-server --no-pager -n 10")
            print(output)
        }
    }
    
    func checkServiceStatus() -> Bool {
        if os == .macOS {
            let (output, _) = runShellCommand("launchctl list | grep -q com.teacoffee.torc && echo 'running' || echo 'not running'")
            return output.contains("running")
        } else {
            let (output, _) = runShellCommand("systemctl is-active torc-server 2>/dev/null || echo inactive")
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
        }
    }
    
    func printURLs() {
        let addresses = getIPAddresses()
        
        print("Access URLs:")
        print("  Orders UI:  http://localhost:8080/")
        print("  Admin UI:   http://localhost:9090/")
        print()
        
        if !addresses.isEmpty {
            print("Network URLs:")
            for address in addresses {
                print("  Orders UI:  http://\(address):8080/")
                print("  Admin UI:   http://\(address):9090/")
            }
            print()
        }
        
        if os == .macOS {
            print("Service location:")
            print("  ~/Library/LaunchAgents/com.teacoffee.torc.plist")
        } else {
            print("Service location:")
            print("  /etc/systemd/system/torc-server.service")
        }
    }
}
