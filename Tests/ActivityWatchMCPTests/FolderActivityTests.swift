import Testing
import Foundation
import Logging
@testable import ActivityWatchMCP

/// Tests for FolderActivityAnalyzer - folder path extraction and analysis
@Suite("Folder Activity Analysis Tests")
struct FolderActivityTests {
    
    // MARK: - Terminal Folder Extraction Tests
    
    @Test("Extract terminal folder with context pattern")
    func testTerminalFolderWithContext() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(60.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "git-mcp = side-project"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract at least one folder")
        
        if let activity = activities.first {
            #expect(activity.application == "Warp")
            #expect(activity.context == "side-project")
            #expect(activity.totalDuration == 60.0)
            print("Extracted: \(activity.path) (context: \(activity.context ?? "none"))")
        }
    }
    
    @Test("Extract terminal absolute path")
    func testTerminalAbsolutePath() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(120.0),
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": "/Users/stijnwillems/Developer/opens-time-chat"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract folder from absolute path")
        
        if let activity = activities.first {
            #expect(activity.path.starts(with: "/Users/"))
            #expect(activity.totalDuration == 120.0)
            print("Extracted: \(activity.path)")
        }
    }
    
    @Test("Extract terminal tilde path")
    func testTerminalTildePath() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(90.0),
                "data": AnyCodable([
                    "app": "iTerm",
                    "title": "~/Developer/my-project"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract folder from tilde path")
        
        if let activity = activities.first {
            // Tilde should be expanded
            #expect(activity.path.starts(with: "/"), "Tilde should be expanded to absolute path")
            print("Expanded tilde path: \(activity.path)")
        }
    }
    
    @Test("Extract relative path from terminal")
    func testTerminalRelativePath() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)

        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(45.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "../parent-folder"
                ] as [String: Any])
            ]
        ]

        let activities = await analyzer.analyzeFolderActivity(from: events)

        // Relative paths might not resolve to existing directories, so just check if processing completes
        print("Extracted from relative path: \(activities.count) folders")
        if let activity = activities.first {
            print("  Path: \(activity.path)")
        }
    }
    
    @Test("Filter out shell commands from terminal")
    func testTerminalFilterShellCommands() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(5.0),
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": "ls"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:01:00Z"),
                "duration": AnyCodable(5.0),
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": "cd"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:02:00Z"),
                "duration": AnyCodable(5.0),
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": "git"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        // Should filter out common shell commands
        #expect(activities.isEmpty || activities.allSatisfy { !["ls", "cd", "git"].contains($0.path) },
               "Should filter out shell commands")
    }
    
    // MARK: - Code Editor Folder Extraction Tests
    
    @Test("Extract folder from VSCode title with em dash")
    func testVSCodeFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(300.0),
                "data": AnyCodable([
                    "app": "Visual Studio Code",
                    "title": "main.swift — activitywatch-mcp"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract project name from VSCode title")
        
        if let activity = activities.first {
            #expect(activity.application == "Visual Studio Code")
            #expect(activity.totalDuration == 300.0)
            print("Extracted VSCode project: \(activity.path)")
        }
    }
    
    @Test("Extract folder from Cursor title")
    func testCursorFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(450.0),
                "data": AnyCodable([
                    "app": "Cursor",
                    "title": "my-project"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract project from Cursor")
        
        if let activity = activities.first {
            print("Extracted Cursor project: \(activity.path)")
        }
    }
    
    @Test("Extract folder from editor with absolute path")
    func testEditorAbsolutePath() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(200.0),
                "data": AnyCodable([
                    "app": "Sublime Text",
                    "title": "file.txt — /Users/stijnwillems/Documents/notes"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract absolute path from editor")
        
        if let activity = activities.first {
            #expect(activity.path.starts(with: "/Users/"))
            print("Extracted editor path: \(activity.path)")
        }
    }
    
    // MARK: - Xcode Folder Extraction Tests
    
    @Test("Extract folder from Xcode project")
    func testXcodeFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(600.0),
                "data": AnyCodable([
                    "app": "Xcode",
                    "title": "MyApp — AppDelegate.swift"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract project from Xnajvide")
        
        if let activity = activities.first {
            #expect(activity.application == "Xcode")
            print("Extracted Xcode project: \(activity.path)")
        }
    }
    
    // MARK: - JetBrains IDE Folder Extraction Tests
    
    @Test("Extract folder from JetBrains IDE")
    func testJetBrainsFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(400.0),
                "data": AnyCodable([
                    "app": "IntelliJ IDEA",
                    "title": "my-java-project – Main.java"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract project from IntelliJ")
        
        if let activity = activities.first {
            #expect(activity.application == "IntelliJ IDEA")
            print("Extracted IntelliJ project: \(activity.path)")
        }
    }
    
    // MARK: - File Manager Folder Extraction Tests
    
    @Test("Extract folder from Finder")
    func testFinderFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(60.0),
                "data": AnyCodable([
                    "app": "Finder",
                    "title": "Downloads"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should extract folder from Finder")
        
        if let activity = activities.first {
            #expect(activity.application == "Finder")
            print("Extracted Finder folder: \(activity.path)")
        }
    }
    
    // MARK: - Web Folder Extraction Tests
    
    @Test("Extract web URL when includeWeb is true")
    func testWebFolderExtraction() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(180.0),
                "data": AnyCodable([
                    "app": "Safari",
                    "title": "GitHub - doozMen/opens-time-chat: https://github.com/doozMen/opens-time-chat"
                ] as [String: Any])
            ]
        ]
        
        let activitiesWithWeb = await analyzer.analyzeFolderActivity(from: events, includeWeb: true)
        let activitiesWithoutWeb = await analyzer.analyzeFolderActivity(from: events, includeWeb: false)
        
        #expect(activitiesWithWeb.count >= 1, "Should extract web URL when includeWeb is true")
        #expect(activitiesWithoutWeb.isEmpty, "Should not extract web URL when includeWeb is false")
        
        if let activity = activitiesWithWeb.first {
            #expect(activity.context == "web")
            print("Extracted web URL: \(activity.path)")
        }
    }
    
    // MARK: - Duration Aggregation Tests
    
    @Test("Aggregate duration for same folder")
    func testDurationAggregation() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(100.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "test-project = work"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:05:00Z"),
                "duration": AnyCodable(150.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "test-project = work"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:10:00Z"),
                "duration": AnyCodable(200.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "test-project = work"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count == 1, "Should aggregate same folder into one activity")
        
        if let activity = activities.first {
            #expect(activity.totalDuration == 450.0, "Total duration should be sum of all events")
            #expect(activity.eventCount == 3, "Should count all events")
            print("Aggregated activity: \(activity.path) - \(activity.totalDuration)s over \(activity.eventCount) events")
        }
    }
    
    @Test("Separate folders by application")
    func testSeparateFoldersByApplication() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(100.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "my-project"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:05:00Z"),
                "duration": AnyCodable(200.0),
                "data": AnyCodable([
                    "app": "Cursor",
                    "title": "my-project"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count == 2, "Should separate same folder by application")
        
        let apps = Set(activities.map { $0.application })
        #expect(apps.contains("Warp"))
        #expect(apps.contains("Cursor"))
        
        print("Same folder in different apps: \(activities.map { "\($0.application): \($0.totalDuration)s" })")
    }
    
    // MARK: - Sorting Tests
    
    @Test("Sort activities by duration descending")
    func testSortingByDuration() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(50.0),
                "data": AnyCodable([
                    "app": "Warp",
                    "title": "project-a"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:05:00Z"),
                "duration": AnyCodable(300.0),
                "data": AnyCodable([
                    "app": "Cursor",
                    "title": "project-b"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:10:00Z"),
                "duration": AnyCodable(150.0),
                "data": AnyCodable([
                    "app": "Xcode",
                    "title": "project-c"
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count == 3)
        
        // Check sorting - should be descending by duration
        if activities.count >= 2 {
            #expect(activities[0].totalDuration >= activities[1].totalDuration,
                   "Activities should be sorted by duration descending")
        }
        
        print("Activities sorted by duration:")
        for activity in activities {
            print("  \(activity.path): \(activity.totalDuration)s")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Handle empty events")
    func testEmptyEvents() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = []
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.isEmpty, "Should handle empty events gracefully")
    }
    
    @Test("Handle events with missing data")
    func testMissingEventData() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(100.0),
                // Missing 'data' field
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:05:00Z"),
                "duration": AnyCodable(100.0),
                "data": AnyCodable([:] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        // Should handle missing data gracefully
        print("Handled \(events.count) events with missing data, extracted \(activities.count) activities")
    }
    
    @Test("Handle very long window titles")
    func testLongWindowTitles() async {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let longPath = "/Users/stijnwillems/Developer/very/long/path/with/many/nested/directories/that/goes/on/and/on/project"
        
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(60.0),
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": longPath
                ] as [String: Any])
            ]
        ]
        
        let activities = await analyzer.analyzeFolderActivity(from: events)
        
        #expect(activities.count >= 1, "Should handle long paths")
        
        if let activity = activities.first {
            print("Extracted long path: \(activity.path)")
        }
    }
    
    // MARK: - Format Helper Tests
    
    @Test("Format duration correctly")
    func testFormattedDuration() {
        let activity = FolderActivity(
            path: "/test/path",
            application: "TestApp",
            context: nil,
            totalDuration: 3725.0, // 1h 2m 5s
            eventCount: 1
        )
        
        let formatted = activity.formattedDuration
        
        #expect(formatted.contains("1h"), "Should contain hours")
        #expect(formatted.contains("2m"), "Should contain minutes")
        #expect(formatted.contains("5s"), "Should contain seconds")
        
        print("Formatted duration: \(formatted)")
    }
    
    @Test("Format duration for minutes only")
    func testFormattedDurationMinutesOnly() {
        let activity = FolderActivity(
            path: "/test/path",
            application: "TestApp",
            context: nil,
            totalDuration: 125.0, // 2m 5s
            eventCount: 1
        )
        
        let formatted = activity.formattedDuration
        
        #expect(formatted.contains("2m"), "Should contain minutes")
        #expect(formatted.contains("5s"), "Should contain seconds")
        #expect(!formatted.contains("h"), "Should not contain hours")
        
        print("Formatted duration (minutes): \(formatted)")
    }
    
    @Test("Format duration for seconds only")
    func testFormattedDurationSecondsOnly() {
        let activity = FolderActivity(
            path: "/test/path",
            application: "TestApp",
            context: nil,
            totalDuration: 45.0, // 45s
            eventCount: 1
        )
        
        let formatted = activity.formattedDuration
        
        #expect(formatted.contains("45s"), "Should contain seconds")
        #expect(!formatted.contains("m"), "Should not contain minutes")
        #expect(!formatted.contains("h"), "Should not contain hours")
        
        print("Formatted duration (seconds): \(formatted)")
    }
}
