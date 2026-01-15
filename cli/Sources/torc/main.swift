import Foundation

enum Command {
    case install
    case status
    case updateMenu
    case uninstall
    case update
    case help
}

func parseArguments(_ args: [String]) -> Command {
    guard args.count > 1 else {
        return .help
    }
    
    let command = args[1]
    switch command {
    case "install":
        return .install
    case "status":
        return .status
    case "update-menu":
        return .updateMenu
    case "uninstall":
        return .uninstall
    case "update":
        return .update
    case "help", "--help", "-h":
        return .help
    default:
        print("Unknown command: \(command)")
        print("Run 'torc help' for usage information.")
        exit(1)
    }
}

func printHelp() {
    print("""
    Tea or Coffee (torc) - Server Installer CLI
    
    USAGE:
        torc <command>
    
    COMMANDS:
        install       Install and start the Tea or Coffee server
        status        Show server status and access URLs
        update-menu   Edit the menu items
        uninstall     Remove the server installation
        update        Update the CLI and server to latest version
        help          Show this help message
    
    EXAMPLES:
        sudo torc install
        torc status
        sudo torc update-menu
        sudo torc uninstall
        sudo torc update
    
    NOTE: Most commands require sudo privileges for installation and service management.
    """)
}

func main() {
    let args = CommandLine.arguments
    let command = parseArguments(args)
    
    switch command {
    case .install:
        InstallCommand().run()
    case .status:
        StatusCommand().run()
    case .updateMenu:
        UpdateMenuCommand().run()
    case .uninstall:
        UninstallCommand().run()
    case .update:
        UpdateCommand().run()
    case .help:
        printHelp()
    }
}

main()
