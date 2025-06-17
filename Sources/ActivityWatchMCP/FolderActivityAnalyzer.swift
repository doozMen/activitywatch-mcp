import Foundation
import Logging

struct FolderActivity {
    let path: String
    let application: String
    let context: String?
    let totalDuration: Double
    let eventCount: Int
}

actor FolderActivityAnalyzer {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    /// Extract folder activities from window events
    func analyzeFolderActivity(from events: [[String: AnyCodable]], includeWeb: Bool = false) -> [FolderActivity] {
        var folderMap: [String: FolderActivity] = [:]
        
        for event in events {
            guard let data = event["data"]?.value as? [String: Any],
                  let app = data["app"] as? String,
                  let title = data["title"] as? String,
                  let duration = event["duration"]?.value as? Double else {
                continue
            }
            
            let folders = extractFolders(app: app, title: title, includeWeb: includeWeb)
            
            for folder in folders {
                let key = "\(folder.path)|\(app)"
                
                if var existing = folderMap[key] {
                    existing = FolderActivity(
                        path: existing.path,
                        application: existing.application,
                        context: existing.context ?? folder.context,
                        totalDuration: existing.totalDuration + duration,
                        eventCount: existing.eventCount + 1
                    )
                    folderMap[key] = existing
                } else {
                    folderMap[key] = FolderActivity(
                        path: folder.path,
                        application: app,
                        context: folder.context,
                        totalDuration: duration,
                        eventCount: 1
                    )
                }
            }
        }
        
        return Array(folderMap.values).sorted { $0.totalDuration > $1.totalDuration }
    }
    
    private func extractFolders(app: String, title: String, includeWeb: Bool) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Terminal applications (Warp, Terminal, iTerm, etc.)
        if ["Warp", "Terminal", "iTerm", "iTerm2", "Hyper", "Alacritty", "kitty"].contains(app) {
            folders.append(contentsOf: extractTerminalFolders(from: title))
        }
        
        // File managers
        else if ["Finder", "Path Finder"].contains(app) {
            if !title.isEmpty && !title.contains("/") && !title.contains("\\") {
                // Simple folder name without path
                folders.append((path: title, context: nil))
            }
        }
        
        // Code editors
        else if ["Cursor", "Visual Studio Code", "VSCode", "Code", "Sublime Text", "Atom", "TextMate", "Nova", "BBEdit"].contains(app) {
            folders.append(contentsOf: extractEditorFolders(from: title))
        }
        
        // Xcode
        else if app == "Xcode" {
            folders.append(contentsOf: extractXcodeFolders(from: title))
        }
        
        // JetBrains IDEs
        else if ["IntelliJ IDEA", "WebStorm", "PyCharm", "RubyMine", "PhpStorm", "CLion", "GoLand", "DataGrip", "Android Studio"].contains(app) {
            folders.append(contentsOf: extractJetBrainsFolders(from: title))
        }
        
        // Web browsers (if includeWeb is true)
        else if includeWeb && ["Safari", "Chrome", "Firefox", "Edge", "Brave", "Arc", "Vivaldi", "Opera"].contains(app) {
            folders.append(contentsOf: extractWebFolders(from: title))
        }
        
        return folders
    }
    
    private func extractTerminalFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Pattern 1: "folder-name = context" (e.g., "git-mcp = side-project")
        if let match = title.range(of: #"^([^=\s]+)\s*=\s*(.+)$"#, options: .regularExpression) {
            let parts = title[match].split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let folder = parts[0].trimmingCharacters(in: .whitespaces)
                let context = parts[1].trimmingCharacters(in: .whitespaces)
                folders.append((path: folder, context: context))
                return folders
            }
        }
        
        // Pattern 2: "..folder/subfolder" or "../folder"
        if title.starts(with: "..") {
            let cleanTitle = title.dropFirst(2).trimmingCharacters(in: CharacterSet(charactersIn: "./"))
            if !cleanTitle.isEmpty {
                // Extract the main folder name
                let components = cleanTitle.split(separator: "/")
                if let firstComponent = components.first {
                    folders.append((path: String(firstComponent), context: nil))
                }
            }
        }
        
        // Pattern 3: Simple folder name without path characters
        else if !title.contains("/") && !title.contains("\\") && 
                !title.isEmpty && title.count > 1 &&
                !["zsh", "bash", "sh", "fish", "tcsh", "~", "-", "_", ".", ".."].contains(title) {
            folders.append((path: title, context: nil))
        }
        
        // Pattern 4: Full path - extract last component
        else if title.contains("/") {
            let components = title.split(separator: "/")
            if let lastComponent = components.last,
               !lastComponent.isEmpty,
               lastComponent != "~" {
                folders.append((path: String(lastComponent), context: nil))
            }
        }
        
        return folders
    }
    
    private func extractEditorFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Pattern 1: "file.ext — project-name"
        if let dashRange = title.range(of: " — ") {
            let projectName = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !projectName.isEmpty {
                folders.append((path: projectName, context: nil))
            }
        }
        
        // Pattern 2: "[project-name] file.ext"
        else if let match = title.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
            let projectName = String(title[match]).dropFirst().dropLast()
            folders.append((path: String(projectName), context: nil))
        }
        
        // Pattern 3: Just the project name (common in Cursor)
        else if !title.contains(".") && !title.contains("/") && !title.isEmpty {
            folders.append((path: title, context: nil))
        }
        
        return folders
    }
    
    private func extractXcodeFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Pattern: "project-name — file.swift" or "project-name — xcode"
        let parts = title.split(separator: "—", maxSplits: 1)
        if let projectPart = parts.first {
            let projectName = projectPart.trimmingCharacters(in: .whitespaces)
            if !projectName.isEmpty {
                folders.append((path: projectName, context: nil))
            }
        }
        
        return folders
    }
    
    private func extractJetBrainsFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // JetBrains pattern: "project-name – path/to/file.ext"
        if let dashRange = title.range(of: " – ") {
            let projectName = String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !projectName.isEmpty {
                folders.append((path: projectName, context: nil))
            }
        }
        
        return folders
    }
    
    private func extractWebFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Extract URLs and convert to folder-like paths
        if let urlMatch = title.range(of: #"https?://([^/\s]+)(/[^?\s#]*)?"#, options: .regularExpression) {
            let url = String(title[urlMatch])
            if let urlComponents = URLComponents(string: url) {
                var path = urlComponents.host ?? ""
                let urlPath = urlComponents.path
                if !urlPath.isEmpty && urlPath != "/" {
                    path += urlPath
                }
                folders.append((path: path, context: "web"))
            }
        }
        
        return folders
    }
}

// Format helper for displaying folder activities
extension FolderActivity {
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        let seconds = Int(totalDuration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}