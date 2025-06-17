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
            folders.append(contentsOf: extractFinderFolders(from: title))
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
                let folderPart = parts[0].trimmingCharacters(in: .whitespaces)
                let context = parts[1].trimmingCharacters(in: .whitespaces)
                
                // Try to resolve to absolute path
                let absolutePath = resolveToAbsolutePath(folderPart)
                folders.append((path: absolutePath, context: context))
                return folders
            }
        }
        
        // Pattern 2: Absolute paths (starting with / or ~)
        if title.starts(with: "/") || title.starts(with: "~") {
            // Clean up the path and extract it
            let cleanPath = title.trimmingCharacters(in: .whitespaces)
            if cleanPath.count > 1 {
                // Expand tilde if present
                let expandedPath = NSString(string: cleanPath).expandingTildeInPath
                folders.append((path: expandedPath, context: nil))
                return folders
            }
        }
        
        // Pattern 3: "..folder/subfolder" or "../folder" - relative paths
        if title.starts(with: "..") {
            let cleanTitle = title.trimmingCharacters(in: .whitespaces)
            // For relative paths, we'll keep the folder name but try to guess the full path
            let folderName = cleanTitle.split(separator: "/").first?.replacingOccurrences(of: "..", with: "") ?? cleanTitle
            let trimmedName = folderName.trimmingCharacters(in: CharacterSet(charactersIn: "./"))
            if !trimmedName.isEmpty {
                let absolutePath = resolveToAbsolutePath(trimmedName)
                folders.append((path: absolutePath, context: nil))
            }
        }
        
        // Pattern 4: Simple folder name without path characters
        else if !title.contains("/") && !title.contains("\\") && 
                !title.isEmpty && title.count > 1 &&
                !["zsh", "bash", "sh", "fish", "tcsh", "~", "-", "_", ".", "..", "git", "cd", "ls", "pwd"].contains(title) {
            // Try to resolve to absolute path
            let absolutePath = resolveToAbsolutePath(title)
            folders.append((path: absolutePath, context: nil))
        }
        
        // Pattern 5: Full path - preserve the entire path
        else if title.contains("/") {
            // Check if it's a full path or just contains slashes
            if title.starts(with: "/") || title.starts(with: "~") {
                let expandedPath = NSString(string: title).expandingTildeInPath
                folders.append((path: expandedPath, context: nil))
            } else {
                // Extract the folder name and try to resolve it
                let components = title.split(separator: "/")
                if let lastComponent = components.last,
                   !lastComponent.isEmpty,
                   lastComponent != "~" {
                    let absolutePath = resolveToAbsolutePath(String(lastComponent))
                    folders.append((path: absolutePath, context: nil))
                }
            }
        }
        
        return folders
    }
    
    /// Try to resolve a folder name to an absolute path by checking common locations
    private func resolveToAbsolutePath(_ folderName: String) -> String {
        let cleanName = folderName.trimmingCharacters(in: .whitespaces)
        
        // If already absolute, return as is
        if cleanName.starts(with: "/") {
            return cleanName
        }
        
        // Common development directories to check
        let commonPaths = [
            "~/Developer",
            "~/Documents",
            "~/Projects",
            "~/Code",
            "~/dev",
            "~/src",
            "~/workspace",
            "~/Desktop",
            "~/Downloads",
            "/tmp"
        ]
        
        // Check each common path
        for basePath in commonPaths {
            let expandedBase = NSString(string: basePath).expandingTildeInPath
            let potentialPath = "\(expandedBase)/\(cleanName)"
            
            // Check if directory exists
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: potentialPath, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return potentialPath
            }
            
            // Also check nested one level deep (e.g., ~/Developer/subfolder/project)
            do {
                let subfolders = try FileManager.default.contentsOfDirectory(atPath: expandedBase)
                for subfolder in subfolders {
                    let nestedPath = "\(expandedBase)/\(subfolder)/\(cleanName)"
                    if FileManager.default.fileExists(atPath: nestedPath, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        return nestedPath
                    }
                }
            } catch {
                // Ignore errors and continue
            }
        }
        
        // If not found, return the original name (will show as relative path)
        return cleanName
    }
    
    private func extractEditorFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // Pattern 1: "file.ext — project-name" or "file.ext — /full/path/to/project"
        if let dashRange = title.range(of: " — ") {
            let projectPart = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !projectPart.isEmpty {
                // Check if it's already an absolute path
                if projectPart.starts(with: "/") || projectPart.starts(with: "~") {
                    let expandedPath = NSString(string: projectPart).expandingTildeInPath
                    folders.append((path: expandedPath, context: nil))
                } else {
                    // Try to resolve to absolute path
                    let absolutePath = resolveToAbsolutePath(projectPart)
                    folders.append((path: absolutePath, context: nil))
                }
            }
        }
        
        // Pattern 2: "[project-name] file.ext" or "[/path/to/project] file.ext"
        else if let match = title.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
            let projectPart = String(title[match]).dropFirst().dropLast()
            if projectPart.starts(with: "/") || projectPart.starts(with: "~") {
                let expandedPath = NSString(string: String(projectPart)).expandingTildeInPath
                folders.append((path: expandedPath, context: nil))
            } else {
                let absolutePath = resolveToAbsolutePath(String(projectPart))
                folders.append((path: absolutePath, context: nil))
            }
        }
        
        // Pattern 3: Just the project name (common in Cursor)
        else if !title.contains(".") && !title.contains("/") && !title.isEmpty {
            let absolutePath = resolveToAbsolutePath(title)
            folders.append((path: absolutePath, context: nil))
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
                // Xcode projects are often in Developer folder
                let absolutePath = resolveToAbsolutePath(projectName)
                folders.append((path: absolutePath, context: nil))
            }
        }
        
        return folders
    }
    
    private func extractJetBrainsFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        // JetBrains pattern: "project-name – path/to/file.ext" or "/full/path – file.ext"
        if let dashRange = title.range(of: " – ") {
            let projectPart = String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !projectPart.isEmpty {
                if projectPart.starts(with: "/") || projectPart.starts(with: "~") {
                    let expandedPath = NSString(string: projectPart).expandingTildeInPath
                    folders.append((path: expandedPath, context: nil))
                } else {
                    let absolutePath = resolveToAbsolutePath(projectPart)
                    folders.append((path: absolutePath, context: nil))
                }
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
    
    private func extractFinderFolders(from title: String) -> [(path: String, context: String?)] {
        var folders: [(path: String, context: String?)] = []
        
        if !title.isEmpty {
            // Finder usually shows just the folder name
            // Try to resolve to absolute path
            let absolutePath = resolveToAbsolutePath(title)
            folders.append((path: absolutePath, context: nil))
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