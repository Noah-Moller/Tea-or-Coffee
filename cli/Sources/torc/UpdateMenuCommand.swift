import Foundation

struct UpdateMenuCommand {
    let os = detectOS()
    
    var appRoot: String {
        os == .macOS ? "/usr/local/torc-server" : "/opt/torc-server"
    }
    
    var menuPath: String {
        (appRoot as NSString).appendingPathComponent("menu.txt")
    }
    
    func run() {
        // Try to find menu.txt in app root first, then project root
        var menuFile: String?
        
        if FileManager.default.fileExists(atPath: menuPath) {
            menuFile = menuPath
        } else if let projectRoot = getProjectRoot() {
            let projectMenuPath = (projectRoot as NSString).appendingPathComponent("menu.txt")
            if FileManager.default.fileExists(atPath: projectMenuPath) {
                menuFile = projectMenuPath
            }
        }
        
        guard let menuFile = menuFile else {
            print("Error: menu.txt not found")
            print("Please install the server first with 'torc install'")
            exit(1)
        }
        
        // Load current menu (matching Go server's parsing logic)
        var menuItems: [String] = []
        if let content = try? String(contentsOfFile: menuFile, encoding: .utf8) {
            menuItems = content.components(separatedBy: .newlines)
                .map { line in
                    var cleaned = line.trimmingCharacters(in: .whitespaces)
                    // Remove trailing comma
                    if cleaned.hasSuffix(",") {
                        cleaned = String(cleaned.dropLast())
                    }
                    // Remove leading and trailing quotes
                    cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    return cleaned
                }
                .filter { !$0.isEmpty }
        }
        
        print("Menu Editor")
        print("=" + String(repeating: "=", count: 30))
        print()
        
        // Interactive loop
        while true {
            printCurrentMenu(menuItems)
            print()
            print("Options:")
            print("  [a] Add item")
            print("  [r] Remove item")
            print("  [e] Edit item")
            print("  [s] Save and exit")
            print("  [q] Quit without saving")
            print()
            print("Enter choice: ", terminator: "")
            
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
                continue
            }
            
            switch input {
            case "a":
                menuItems = addItem(menuItems)
            case "r":
                menuItems = removeItem(menuItems)
            case "e":
                menuItems = editItem(menuItems)
            case "s":
                saveMenu(menuItems, to: menuFile)
                print()
                print("✓ Menu saved successfully!")
                return
            case "q":
                print("Exiting without saving...")
                return
            default:
                print("Invalid choice. Please try again.")
            }
            print()
        }
    }
    
    func printCurrentMenu(_ items: [String]) {
        if items.isEmpty {
            print("Menu is empty")
        } else {
            print("Current menu items:")
            for (index, item) in items.enumerated() {
                print("  \(index + 1). \(item)")
            }
        }
    }
    
    func addItem(_ items: [String]) -> [String] {
        print("Enter new menu item name: ", terminator: "")
        guard let name = readLine()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            print("Invalid name")
            return items
        }
        
        var newItems = items
        newItems.append(name)
        return newItems
    }
    
    func removeItem(_ items: [String]) -> [String] {
        guard !items.isEmpty else {
            print("Menu is empty, nothing to remove")
            return items
        }
        
        print("Enter item number to remove: ", terminator: "")
        guard let input = readLine(),
              let index = Int(input),
              index >= 1 && index <= items.count else {
            print("Invalid item number")
            return items
        }
        
        var newItems = items
        let removed = newItems.remove(at: index - 1)
        print("Removed: \(removed)")
        return newItems
    }
    
    func editItem(_ items: [String]) -> [String] {
        guard !items.isEmpty else {
            print("Menu is empty, nothing to edit")
            return items
        }
        
        print("Enter item number to edit: ", terminator: "")
        guard let input = readLine(),
              let index = Int(input),
              index >= 1 && index <= items.count else {
            print("Invalid item number")
            return items
        }
        
        print("Current name: \(items[index - 1])")
        print("Enter new name: ", terminator: "")
        guard let newName = readLine()?.trimmingCharacters(in: .whitespaces), !newName.isEmpty else {
            print("Invalid name")
            return items
        }
        
        var newItems = items
        newItems[index - 1] = newName
        return newItems
    }
    
    func saveMenu(_ items: [String], to path: String) {
        // Save in the same format as the original (with quotes and commas)
        let content = items.map { "\"\($0)\"," }.joined(separator: "\n") + "\n"
        
        do {
            // Ensure directory exists
            let dir = (path as NSString).deletingLastPathComponent
            try ensureDirectoryExists(dir)
            
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error: Failed to save menu: \(error.localizedDescription)")
            exit(1)
        }
    }
}
