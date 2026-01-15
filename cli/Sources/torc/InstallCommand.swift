import Foundation

struct InstallCommand {
    let os = detectOS()
    
    var binaryPath: String {
        os == .macOS ? "/usr/local/bin/torc-server" : "/usr/local/bin/torc-server"
    }
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    func run() {
        print("Installing Tea or Coffee server...")
        print()
        
        // Check prerequisites
        guard checkPrerequisites() else {
            exit(1)
        }
        
        // Get project root
        var projectRoot: String
        if let foundRoot = getProjectRoot() {
            projectRoot = foundRoot
        } else {
            // Try to clone the repository
            print("Project not found. Cloning repository...")
            let cloneDir = os == .macOS ? "/tmp/tea-or-coffee" : "/tmp/tea-or-coffee"
            
            // Remove if exists
            if FileManager.default.fileExists(atPath: cloneDir) {
                try? FileManager.default.removeItem(atPath: cloneDir)
            }
            
            let (output, exitCode) = runShellCommand("git clone https://github.com/Noah-Moller/tea-or-coffee.git \(cloneDir)")
            if exitCode != 0 {
                print("Error: Failed to clone repository")
                print(output)
                print()
                print("Please either:")
                print("  1. Clone the repository manually: git clone https://github.com/Noah-Moller/tea-or-coffee.git")
                print("  2. Run 'torc install' from within the project directory")
                exit(1)
            }
            
            projectRoot = cloneDir
            print("✓ Repository cloned")
        }
        
        // Build Go server
        print("Building Go server...")
        guard buildServer(projectRoot: projectRoot) else {
            exit(1)
        }
        
        // Create app root directory
        print("Creating installation directory...")
        do {
            try ensureDirectoryExists(appRoot)
        } catch {
            print("Error: Failed to create directory \(appRoot): \(error.localizedDescription)")
            exit(1)
        }
        
        // Copy files
        print("Copying files...")
        guard copyFiles(projectRoot: projectRoot) else {
            exit(1)
        }
        
        // Create service
        print("Setting up service...")
        guard createService() else {
            exit(1)
        }
        
        // Start service
        print("Starting service...")
        guard startService() else {
            exit(1)
        }
        
        print()
        print("✓ Installation complete!")
        print()
        printURLs()
    }
    
    func checkPrerequisites() -> Bool {
        print("Checking prerequisites...")
        
        if !checkCommandExists("go") {
            print("Error: Go is not installed or not in PATH")
            print("Please install Go from https://go.dev/dl/")
            return false
        }
        
        print("✓ Go found")
        return true
    }
    
    func buildServer(projectRoot: String) -> Bool {
        let mainGoPath = (projectRoot as NSString).appendingPathComponent("main.go")
        
        if !FileManager.default.fileExists(atPath: mainGoPath) {
            print("Error: main.go not found in project root")
            print("  Looked for: \(mainGoPath)")
            return false
        }
        
        // Find go binary path
        let (goPath, goPathExitCode) = runShellCommand("which go")
        guard goPathExitCode == 0, !goPath.isEmpty else {
            print("Error: Go binary not found in PATH")
            return false
        }
        
        let goBinary = goPath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Build using shell command to ensure proper PATH and working directory
        let buildCommand = "cd '\(projectRoot)' && '\(goBinary)' build -o '\(binaryPath)' main.go"
        let (output, exitCode) = runShellCommand(buildCommand)
        
        if exitCode != 0 {
            print("Error: Failed to build server")
            print(output)
            return false
        }
        
        print("✓ Server built successfully")
        return true
    }
    
    func copyFiles(projectRoot: String) -> Bool {
        let filesToCopy = [
            ("web", "web"),
            ("admin", "admin"),
            ("menu.txt", "menu.txt")
        ]
        
        for (source, dest) in filesToCopy {
            let sourcePath = (projectRoot as NSString).appendingPathComponent(source)
            let destPath = (appRoot as NSString).appendingPathComponent(dest)
            
            if !FileManager.default.fileExists(atPath: sourcePath) {
                print("Warning: \(source) not found, skipping...")
                continue
            }
            
            do {
                if FileManager.default.fileExists(atPath: sourcePath) {
                    let isDirectory = (try? FileManager.default.attributesOfItem(atPath: sourcePath)[.type] as? FileAttributeType) == .typeDirectory
                    
                    if isDirectory {
                        // Copy directory recursively
                        let destURL = URL(fileURLWithPath: destPath)
                        let sourceURL = URL(fileURLWithPath: sourcePath)
                        
                        if FileManager.default.fileExists(atPath: destPath) {
                            try? FileManager.default.removeItem(at: destURL)
                        }
                        
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    } else {
                        try copyItem(at: sourcePath, to: destPath)
                    }
                }
            } catch {
                print("Error: Failed to copy \(source): \(error.localizedDescription)")
                return false
            }
        }
        
        print("✓ Files copied successfully")
        return true
    }
    
    func createService() -> Bool {
        if os == .macOS {
            return createLaunchdService()
        } else {
            return createSystemdService()
        }
    }
    
    func createLaunchdService() -> Bool {
        let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")
        let plistDir = (plistPath as NSString).deletingLastPathComponent
        
        do {
            try ensureDirectoryExists(plistDir)
        } catch {
            print("Error: Failed to create LaunchAgents directory: \(error.localizedDescription)")
            return false
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.teacoffee.torc</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>
            <key>WorkingDirectory</key>
            <string>\(appRoot)</string>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(appRoot)/torc-server.log</string>
            <key>StandardErrorPath</key>
            <string>\(appRoot)/torc-server.error.log</string>
        </dict>
        </plist>
        """
        
        do {
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("✓ Launchd service created")
            return true
        } catch {
            print("Error: Failed to create launchd plist: \(error.localizedDescription)")
            return false
        }
    }
    
    func createSystemdService() -> Bool {
        let servicePath = "/etc/systemd/system/torc-server.service"
        let serviceContent = """
        [Unit]
        Description=Tea or Coffee Server
        After=network.target
        
        [Service]
        Type=simple
        ExecStart=\(binaryPath)
        WorkingDirectory=\(appRoot)
        Restart=always
        RestartSec=5
        StandardOutput=append:\(appRoot)/torc-server.log
        StandardError=append:\(appRoot)/torc-server.error.log
        
        [Install]
        WantedBy=multi-user.target
        """
        
        // Need sudo to write to /etc/systemd/system
        let tempFile = "/tmp/torc-server.service"
        do {
            try serviceContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
        } catch {
            print("Error: Failed to create temporary service file: \(error.localizedDescription)")
            return false
        }
        
        let (_, exitCode) = runShellCommand("sudo cp \(tempFile) \(servicePath) && sudo chmod 644 \(servicePath)")
        
        if exitCode != 0 {
            print("Error: Failed to install systemd service file")
            print("You may need to run with sudo or manually copy the service file")
            return false
        }
        
        let (_, reloadExitCode) = runShellCommand("sudo systemctl daemon-reload")
        if reloadExitCode != 0 {
            print("Warning: Failed to reload systemd daemon")
        }
        
        print("✓ Systemd service created")
        return true
    }
    
    func startService() -> Bool {
        if os == .macOS {
            let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.teacoffee.torc.plist")
            let (_, exitCode) = runShellCommand("launchctl load -w \(plistPath)")
            if exitCode != 0 {
                print("Warning: Failed to load launchd service (it may already be loaded)")
            }
            return true
        } else {
            let (_, exitCode) = runShellCommand("sudo systemctl enable --now torc-server")
            if exitCode != 0 {
                print("Error: Failed to start service")
                print("You may need to run: sudo systemctl enable --now torc-server")
                return false
            }
            return true
        }
    }
    
    func printURLs() {
        let addresses = getIPAddresses()
        
        print("Server is running!")
        print()
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
            print("Manage service:")
            print("  Status:  launchctl list | grep torc")
            print("  Stop:    launchctl unload ~/Library/LaunchAgents/com.teacoffee.torc.plist")
            print("  Start:   launchctl load ~/Library/LaunchAgents/com.teacoffee.torc.plist")
        } else {
            print("Manage service:")
            print("  Status:  sudo systemctl status torc-server")
            print("  Stop:    sudo systemctl stop torc-server")
            print("  Start:   sudo systemctl start torc-server")
            print("  Logs:    sudo journalctl -u torc-server -f")
        }
    }
}
