import Foundation
import MCP
import Logging
import SwiftDateParser

/// ActivityWatch MCP Server implementation that provides structured access to ActivityWatch data
/// through the Model Context Protocol.
///
/// This server wraps the ActivityWatch REST API and exposes it through MCP tools,
/// allowing AI assistants to query time tracking data, analyze productivity patterns,
/// and extract insights from computer usage.
actor ActivityWatchMCPServer {
    private let server: Server
    private let api: ActivityWatchAPI
    private let logger: Logger
    private let version = "2.4.1"
    
    /// Initializes a new ActivityWatch MCP Server instance.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for server operations
    ///   - serverUrl: The URL of the ActivityWatch server (e.g., "http://localhost:5600")
    /// - Throws: An error if server initialization fails
    init(logger: Logger, serverUrl: String) throws {
        self.logger = logger
        self.api = ActivityWatchAPI(logger: logger, serverUrl: serverUrl)
        
        self.server = Server(
            name: "activitywatch-mcp-server",
            version: version,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: nil,
                tools: .init(listChanged: false)
            )
        )
    }
    
    /// Starts the MCP server and waits for incoming requests.
    ///
    /// This method sets up all handlers, creates a stdio transport,
    /// and runs the server until it's terminated.
    func run() async throws {
        await setupHandlers()
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    // MARK: - Handler Setup
    
    /// Sets up all MCP protocol handlers for tools, prompts, and capabilities.
    private func setupHandlers() async {
        // List tools
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            await ListTools.Result(tools: self?.getStaticTools() ?? [])
        }
        
        // Call tool
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server not available")
            }
            return try await self.handleToolCall(name: params.name, arguments: params.arguments)
        }
        
        // List prompts
        await server.withMethodHandler(ListPrompts.self) { [weak self] _ in
            await self?.getPrompts() ?? ListPrompts.Result(prompts: [])
        }
        
        // Get prompt
        await server.withMethodHandler(GetPrompt.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server not available")
            }
            return try await self.handleGetPrompt(name: params.name, arguments: params.arguments)
        }
    }
    
    private func getStaticTools() -> [Tool] {
        [
            Tool(
                name: "list-buckets",
                description: """
                List all ActivityWatch buckets.
                
                Optional parameters:
                - type_filter: Filter buckets by type (e.g., "window", "afk")
                - include_data: Include bucket data and metadata (default: false)
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "type_filter": .object([
                            "type": .string("string"),
                            "description": .string("Filter buckets by type")
                        ]),
                        "include_data": .object([
                            "type": .string("boolean"),
                            "description": .string("Include bucket data and metadata"),
                            "default": .bool(false)
                        ])
                    ])
                ])
            ),
            
            Tool(
                name: "run-query",
                description: """
                Execute an AQL (ActivityWatch Query Language) query.
                
                Parameters:
                - timeperiods: Array of date ranges (natural language or ISO 8601 separated by "/")
                - query: Array of AQL statements joined by semicolons
                
                Natural language timeperiod examples:
                - ["today"] - Query today's data
                - ["yesterday"] - Query yesterday's data
                - ["this week"] - Query this week
                - ["monday/friday"] - Query Monday to Friday
                - ["3 days ago/yesterday"] - Custom range
                
                ISO 8601 format also supported:
                - ["2024-01-01T00:00:00Z/2024-01-02T00:00:00Z"]
                
                Example:
                timeperiods: ["today"]
                query: ["events = query_bucket('aw-watcher-window_hostname'); RETURN = events;"]
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "timeperiods": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of time period ranges - natural language or ISO 8601 (format: start/end)")
                        ]),
                        "query": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of AQL query statements")
                        ])
                    ]),
                    "required": .array([.string("timeperiods"), .string("query")])
                ])
            ),
            
            Tool(
                name: "get-events",
                description: """
                Get raw events from a specific bucket.
                
                Parameters:
                - bucket_id: The ID of the bucket to query
                - limit: Maximum number of events to return (optional)
                - start: Start time - natural language or ISO 8601 (optional)
                - end: End time - natural language or ISO 8601 (optional)
                
                Natural language examples:
                - start="today" - Today's events
                - start="yesterday", end="today" - Yesterday's events
                - start="1 hour ago" - Events from the last hour
                - start="last monday" - Events since last Monday
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "bucket_id": .object([
                            "type": .string("string"),
                            "description": .string("The bucket ID to query")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum number of events to return")
                        ]),
                        "start": .object([
                            "type": .string("string"),
                            "description": .string("Start time - natural language (\"today\", \"yesterday\") or ISO 8601")
                        ]),
                        "end": .object([
                            "type": .string("string"),
                            "description": .string("End time - natural language or ISO 8601 (optional)")
                        ])
                    ]),
                    "required": .array([.string("bucket_id")])
                ])
            ),
            
            Tool(
                name: "get-settings",
                description: """
                Get ActivityWatch settings.
                
                Parameters:
                - key: Specific setting key to retrieve (optional)
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "key": .object([
                            "type": .string("string"),
                            "description": .string("Specific setting key to retrieve")
                        ])
                    ])
                ])
            ),
            
            Tool(
                name: "query-examples",
                description: "Get examples of ActivityWatch Query Language (AQL) queries",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            
            Tool(
                name: "active-buckets",
                description: """
                Find all buckets that have activity within a specific time range.
                This is useful for identifying which watchers/data sources were active during a period.
                
                Parameters:
                - start: Start time (supports natural language like "today", "yesterday", "3 days ago", or ISO 8601)
                - end: End time (OPTIONAL - defaults to end of start day if omitted. DO NOT provide end="now" for single day queries)
                - min_events: Minimum number of events to consider bucket active (default: 1)
                
                Natural language examples:
                - start="today" - Gets today's active buckets (DO NOT add end parameter)
                - start="yesterday" - Gets yesterday's data (DO NOT add end parameter)
                - start="last week" - Gets last week's data (DO NOT add end parameter)
                - start="3 days ago", end="yesterday" - Custom range (end parameter needed for ranges)
                
                IMPORTANT: For single day queries like "today" or "yesterday", omit the end parameter entirely.
                The tool will automatically calculate the end of the day.
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start": .object([
                            "type": .string("string"),
                            "description": .string("Start time - natural language (\"today\", \"yesterday\") or ISO 8601")
                        ]),
                        "end": .object([
                            "type": .string("string"),
                            "description": .string("End time - natural language or ISO 8601 (optional)")
                        ]),
                        "min_events": .object([
                            "type": .string("integer"),
                            "description": .string("Minimum number of events to consider bucket active"),
                            "default": .int(1)
                        ])
                    ]),
                    "required": .array([.string("start")])
                ])
            ),
            
            Tool(
                name: "active-folders",
                description: """
                Extract unique folder paths from window titles during a time period.
                This analyzes window events to find which folders/directories were accessed.
                Works best with file managers, terminals, and code editors that show paths in titles.
                
                Parameters:
                - start: Start time (supports natural language like "today", "yesterday", or ISO 8601)
                - end: End time (OPTIONAL - defaults to end of start day if omitted. DO NOT provide end="now" for single day queries)
                - bucket_filter: Optional bucket ID pattern to filter (e.g., "window")
                
                Natural language examples:
                - start="today" - Today's folders (DO NOT add end parameter)
                - start="yesterday" - Yesterday's folders (DO NOT add end parameter)
                - start="this week" - This week's folders (DO NOT add end parameter)
                - start="2 hours ago", end="now" - Recent activity (end parameter ok for "now")
                
                IMPORTANT: For single day queries, omit the end parameter entirely.
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start": .object([
                            "type": .string("string"),
                            "description": .string("Start time - natural language (\"today\", \"yesterday\") or ISO 8601")
                        ]),
                        "end": .object([
                            "type": .string("string"),
                            "description": .string("End time - natural language or ISO 8601 (optional)")
                        ]),
                        "bucket_filter": .object([
                            "type": .string("string"),
                            "description": .string("Optional bucket ID pattern to filter")
                        ])
                    ]),
                    "required": .array([.string("start")])
                ])
            ),
            
            Tool(
                name: "get-folder-activity",
                description: """
                Get a summary of local folders you've been active in during a time period.
                Analyzes window titles from terminals, editors, and file managers to extract folder names.
                
                Parameters:
                - start: Start time (natural language or ISO 8601) - REQUIRED
                - end: End time - OPTIONAL! Defaults to end of start day. DO NOT provide end="now" for single day queries!
                - includeWeb: Include web URLs as folders (default: false)
                - minDuration: Minimum duration in seconds to consider a folder active (default: 5)
                
                Natural language examples:
                - start="today" - Today's folder activity (DO NOT add end parameter)
                - start="yesterday" - Yesterday's activity (DO NOT add end parameter)
                - start="this week" - This week's folders (DO NOT add end parameter)
                - start="monday", end="friday" - Work week activity (end parameter needed for ranges)
                - start="3 hours ago" - Recent folder activity (DO NOT add end parameter)
                
                IMPORTANT: When the user asks for "today's activity", use ONLY start="today". 
                DO NOT add end="now" or any end parameter - the tool handles this automatically!
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start": .object([
                            "type": .string("string"),
                            "description": .string("Start time - natural language (\"today\", \"yesterday\") or ISO 8601")
                        ]),
                        "end": .object([
                            "type": .string("string"),
                            "description": .string("End time - natural language or ISO 8601 (optional)")
                        ]),
                        "includeWeb": .object([
                            "type": .string("boolean"),
                            "description": .string("Include web URLs as folders"),
                            "default": .bool(false)
                        ]),
                        "minDuration": .object([
                            "type": .string("number"),
                            "description": .string("Minimum duration in seconds to consider a folder active"),
                            "default": .int(5)
                        ])
                    ]),
                    "required": .array([.string("start")])
                ])
            ),
            
            Tool(
                name: "get-version",
                description: "Get the version of the ActivityWatch MCP Server",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            )
        ]
    }
    
    private func getPrompts() -> ListPrompts.Result {
        let prompts = [
            Prompt(
                name: "analyze-productivity",
                description: "Analyze productivity for a specific time period",
                arguments: [
                    .init(name: "date", description: "Date to analyze (YYYY-MM-DD)", required: true),
                    .init(name: "focus", description: "Specific application or category to focus on", required: false)
                ]
            ),
            Prompt(
                name: "compare-periods",
                description: "Compare activity between two time periods",
                arguments: [
                    .init(name: "period1_start", description: "Start of first period (YYYY-MM-DD)", required: true),
                    .init(name: "period1_end", description: "End of first period (YYYY-MM-DD)", required: true),
                    .init(name: "period2_start", description: "Start of second period (YYYY-MM-DD)", required: true),
                    .init(name: "period2_end", description: "End of second period (YYYY-MM-DD)", required: true)
                ]
            )
        ]
        return ListPrompts.Result(prompts: prompts)
    }
    
    private func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        let args = arguments ?? [:]
        
        switch name {
        case "list-buckets":
            return try await handleListBuckets(args: args)
        case "run-query":
            return try await handleRunQuery(args: args)
        case "get-events":
            return try await handleGetEvents(args: args)
        case "get-settings":
            return try await handleGetSettings(args: args)
        case "query-examples":
            return handleQueryExamples()
        case "active-buckets":
            return try await handleActiveBuckets(args: args)
        case "active-folders":
            return try await handleActiveFolders(args: args)
        case "get-folder-activity":
            return try await handleGetFolderActivity(args: args)
        case "get-version":
            return handleGetVersion()
        default:
            throw MCPError.methodNotFound("Unknown tool: \(name)")
        }
    }
    
    private func handleListBuckets(args: [String: Value]) async throws -> CallTool.Result {
        let typeFilter = args["type_filter"]?.stringValue
        let includeData = args["include_data"]?.boolValue ?? false
        
        do {
            let buckets = try await api.listBuckets()
            
            // Filter buckets if type filter is provided
            let filteredBuckets = if let typeFilter = typeFilter {
                buckets.filter { $0.type == typeFilter }
            } else {
                buckets
            }
            
            // Format response
            var response = "Found \(filteredBuckets.count) bucket(s):\n\n"
            
            for bucket in filteredBuckets {
                response += "**\(bucket.id)**\n"
                response += "- Type: \(bucket.type)\n"
                if let client = bucket.client {
                    response += "- Client: \(client)\n"
                }
                if let hostname = bucket.hostname {
                    response += "- Hostname: \(hostname)\n"
                }
                if let created = bucket.created {
                    response += "- Created: \(created)\n"
                }
                
                if includeData {
                    if let data = bucket.data, !data.isEmpty {
                        response += "- Data: \(formatJSON(data))\n"
                    }
                    if let metadata = bucket.metadata, !metadata.isEmpty {
                        response += "- Metadata: \(formatJSON(metadata))\n"
                    }
                }
                
                response += "\n"
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to list buckets: \(error)")
            return CallTool.Result(
                content: [.text("Failed to list buckets: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func handleRunQuery(args: [String: Value]) async throws -> CallTool.Result {
        // Handle various input formats for timeperiods and query
        let (timeperiods, query) = try normalizeQueryInputs(args: args)
        
        logger.debug("Normalized query input - timeperiods: \(timeperiods), query: \(query)")
        
        do {
            let results = try await api.runQuery(timeperiods: timeperiods, query: query)
            
            // Format results
            var response = "Query executed successfully.\n\n"
            
            if results.isEmpty {
                response += "No results returned."
            } else {
                response += "Results:\n```json\n"
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let jsonData = try? encoder.encode(results),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response += jsonString
                } else {
                    response += "Unable to format results as JSON"
                }
                response += "\n```"
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to run query: \(error)")
            return CallTool.Result(
                content: [.text("Failed to run query: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func handleGetEvents(args: [String: Value]) async throws -> CallTool.Result {
        guard let bucketId = args["bucket_id"]?.stringValue else {
            throw MCPError.invalidParams("bucket_id is required")
        }
        
        let limit = args["limit"]?.intValue
        let startStr = args["start"]?.stringValue
        let endStr = args["end"]?.stringValue
        
        // Parse dates if provided
        var start: String? = nil
        var end: String? = nil
        
        if let startStr = startStr {
            start = DateParsingHelper.toISO8601String(try DateParsingHelper.parseDate(startStr))
        }
        
        if let endStr = endStr {
            end = DateParsingHelper.toISO8601String(try DateParsingHelper.parseDate(endStr))
        }
        
        do {
            let events = try await api.getEvents(
                bucketId: bucketId,
                limit: limit,
                start: start,
                end: end
            )
            
            var response = "Retrieved \(events.count) event(s) from bucket '\(bucketId)':\n\n"
            
            if events.isEmpty {
                response += "No events found."
            } else {
                response += "```json\n"
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let jsonData = try? encoder.encode(events),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response += jsonString
                } else {
                    response += "Unable to format events as JSON"
                }
                response += "\n```"
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to get events: \(error)")
            return CallTool.Result(
                content: [.text("Failed to get events: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func handleGetSettings(args: [String: Value]) async throws -> CallTool.Result {
        let key = args["key"]?.stringValue
        
        do {
            let settings = try await api.getSettings(key: key)
            
            var response = "ActivityWatch Settings"
            if let key = key {
                response += " (key: \(key))"
            }
            response += ":\n\n```json\n"
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let jsonData = try? encoder.encode(settings),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response += jsonString
            } else {
                response += "Unable to format settings as JSON"
            }
            response += "\n```"
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to get settings: \(error)")
            return CallTool.Result(
                content: [.text("Failed to get settings: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func handleActiveBuckets(args: [String: Value]) async throws -> CallTool.Result {
        let startStr = args["start"]?.stringValue
        let endStr = args["end"]?.stringValue
        
        // Check for common AI mistakes
        if let endStr = endStr, endStr.lowercased() == "now" && 
           (startStr?.lowercased() == "today" || startStr?.lowercased() == "yesterday" || 
            startStr?.lowercased() == "this week" || startStr?.lowercased() == "last week") {
            logger.warning("AI provided end=\"now\" with single period query. Ignoring end parameter.")
            // Ignore the end parameter for single period queries
            let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: nil)
            return try await performActiveBuckets(start: start, end: end, minEvents: args["min_events"]?.intValue ?? 1)
        }
        
        // Parse dates using natural language
        let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: endStr)
        return try await performActiveBuckets(start: start, end: end, minEvents: args["min_events"]?.intValue ?? 1)
    }
    
    private func performActiveBuckets(start: String, end: String, minEvents: Int) async throws -> CallTool.Result {
        logger.debug("Active buckets query - Parsed: start=\(start), end=\(end)")
        
        do {
            // First, get all buckets
            let buckets = try await api.listBuckets()
            
            // Check each bucket for activity in the time range
            var activeBuckets: [(bucket: Bucket, eventCount: Int)] = []
            
            for bucket in buckets {
                do {
                    // Try to get events for this bucket in the time range
                    let events = try await api.getEvents(
                        bucketId: bucket.id,
                        limit: minEvents + 1, // Just need to know if it has enough events
                        start: start,
                        end: end
                    )
                    
                    if events.count >= minEvents {
                        activeBuckets.append((bucket: bucket, eventCount: events.count))
                    }
                } catch {
                    // Skip buckets that error (might be empty or inaccessible)
                    logger.debug("Skipping bucket \(bucket.id): \(error)")
                }
            }
            
            // Sort by event count (most active first)
            activeBuckets.sort { $0.eventCount > $1.eventCount }
            
            // Format response
            var response = "Found \(activeBuckets.count) active bucket(s) between \(start) and \(end):\n\n"
            
            if activeBuckets.isEmpty {
                response += "No buckets have activity in the specified time range."
            } else {
                for (bucket, eventCount) in activeBuckets {
                    response += "**\(bucket.id)** (\(eventCount) events)\n"
                    response += "- Type: \(bucket.type)\n"
                    if let client = bucket.client {
                        response += "- Client: \(client)\n"
                    }
                    if let hostname = bucket.hostname {
                        response += "- Hostname: \(hostname)\n"
                    }
                    response += "\n"
                }
                
                // Add summary by type
                let bucketsByType = Dictionary(grouping: activeBuckets) { $0.bucket.type }
                response += "### Summary by Type:\n"
                for (type, typeBuckets) in bucketsByType.sorted(by: { $0.key < $1.key }) {
                    let totalEvents = typeBuckets.reduce(0) { $0 + $1.eventCount }
                    response += "- **\(type)**: \(typeBuckets.count) bucket(s), \(totalEvents) total events\n"
                }
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to find active buckets: \(error)")
            return CallTool.Result(
                content: [.text("Failed to find active buckets: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func handleActiveFolders(args: [String: Value]) async throws -> CallTool.Result {
        let startStr = args["start"]?.stringValue
        let endStr = args["end"]?.stringValue
        
        // Check for common AI mistakes
        if let endStr = endStr, endStr.lowercased() == "now" && 
           (startStr?.lowercased() == "today" || startStr?.lowercased() == "yesterday" || 
            startStr?.lowercased() == "this week" || startStr?.lowercased() == "last week") {
            logger.warning("AI provided end=\"now\" with single period query. Ignoring end parameter.")
            // Ignore the end parameter for single period queries
            let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: nil)
            return try await performActiveFolders(start: start, end: end, bucketFilter: args["bucket_filter"]?.stringValue)
        }
        
        // Parse dates using natural language
        let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: endStr)
        return try await performActiveFolders(start: start, end: end, bucketFilter: args["bucket_filter"]?.stringValue)
    }
    
    private func performActiveFolders(start: String, end: String, bucketFilter: String?) async throws -> CallTool.Result {
        do {
            // Get all window buckets
            let buckets = try await api.listBuckets()
            let windowBuckets = buckets.filter { bucket in
                // Filter for window watchers
                if bucket.type == "currentwindow" {
                    if let filter = bucketFilter {
                        return bucket.id.contains(filter)
                    }
                    return true
                }
                return false
            }
            
            // Collect all unique folder paths
            var folderPaths = Set<String>()
            var totalEvents = 0
            
            for bucket in windowBuckets {
                do {
                    let events = try await api.getEvents(
                        bucketId: bucket.id,
                        limit: 10000, // Get more events to find all folders
                        start: start,
                        end: end
                    )
                    
                    totalEvents += events.count
                    
                    // Extract folder paths from window titles
                    for event in events {
                        if let title = event.data["title"]?.value as? String {
                            let paths = extractPaths(from: title)
                            folderPaths.formUnion(paths)
                        }
                    }
                } catch {
                    logger.debug("Skipping bucket \(bucket.id): \(error)")
                }
            }
            
            // Sort paths for better readability
            let sortedPaths = folderPaths.sorted()
            
            // Format response
            var response = "Found \(sortedPaths.count) unique folder(s) between \(start) and \(end):\n"
            response += "(Analyzed \(totalEvents) window events from \(windowBuckets.count) bucket(s))\n\n"
            
            if sortedPaths.isEmpty {
                response += "No folder paths found in window titles.\n"
                response += "This tool works best with:\n"
                response += "- File managers (Finder, Explorer)\n"
                response += "- Terminal/console windows\n"
                response += "- Code editors (VSCode, Xcode, etc.)\n"
                response += "- Applications that show file paths in window titles"
            } else {
                // Group by parent directory for better organization
                let groupedPaths = Dictionary(grouping: sortedPaths) { path in
                    // Get the parent directory or root
                    if let parentRange = path.range(of: "/", options: .backwards) {
                        return String(path[..<parentRange.lowerBound])
                    }
                    return "/"
                }
                
                for (parent, paths) in groupedPaths.sorted(by: { $0.key < $1.key }) {
                    response += "\n**\(parent)/**\n"
                    for path in paths.sorted() {
                        let relativePath = path.replacingOccurrences(of: parent + "/", with: "")
                        response += "  - \(relativePath)\n"
                    }
                }
                
                // Add summary
                response += "\n### Summary:\n"
                response += "- Total unique folders: \(sortedPaths.count)\n"
                response += "- Time range: \(start) to \(end)\n"
                response += "- Window events analyzed: \(totalEvents)\n"
                
                // Find most common root directories
                let rootDirs = Dictionary(grouping: sortedPaths) { path -> String in
                    let components = path.split(separator: "/")
                    if components.count > 2 {
                        return "/" + components[1...2].joined(separator: "/")
                    }
                    return "/" + (components.first ?? "")
                }
                
                response += "\n### Most active areas:\n"
                for (root, paths) in rootDirs.sorted(by: { $0.value.count > $1.value.count }).prefix(5) {
                    response += "- \(root): \(paths.count) folder(s)\n"
                }
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to find active folders: \(error)")
            return CallTool.Result(
                content: [.text("Failed to find active folders: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    // Helper function to extract paths from window titles
    private func extractPaths(from title: String) -> Set<String> {
        var paths = Set<String>()
        
        // Common patterns for paths in window titles
        let patterns = [
            // Unix/Mac paths
            #"(/(?:Users|home|var|tmp|opt|usr|Applications|System|Library|Volumes|private|etc|Users/[^/]+/[^/\s]+)[^:\s]*)"#,
            // Code editor patterns (VSCode, Xcode, etc.)
            #"(?:^|[\s—–-]+)(/[^—–\s]+(?:/[^—–\s]+)*)"#,
            // Terminal/Shell patterns
            #"(?:^|[\s:~])(/[^\s:]+(?:/[^\s:]+)*)"#,
            // File manager patterns
            #"(?:^|\s)(/[^|<>:"\s]+(?:/[^|<>:"\s]+)*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: title) {
                        let path = String(title[range])
                        
                        // Clean up the path
                        let cleanPath = path
                            .replacingOccurrences(of: "//", with: "/")
                            .trimmingCharacters(in: .whitespaces)
                        
                        // Validate it's a reasonable path
                        if cleanPath.count > 3 && 
                           cleanPath.hasPrefix("/") &&
                           !cleanPath.contains("...") &&
                           cleanPath.split(separator: "/").count > 1 {
                            
                            // For files, get the directory
                            if !cleanPath.hasSuffix("/") && cleanPath.contains(".") {
                                if let lastSlash = cleanPath.lastIndex(of: "/") {
                                    let dirPath = String(cleanPath[..<lastSlash])
                                    if dirPath.count > 1 {
                                        paths.insert(dirPath)
                                    }
                                }
                            } else {
                                paths.insert(cleanPath)
                            }
                        }
                    }
                }
            }
        }
        
        return paths
    }
    
    private func handleQueryExamples() -> CallTool.Result {
        let examples = """
        # ActivityWatch Query Language (AQL) Examples
        
        ## Date and Time Format Guide
        
        ### Time Period Format
        For the `timeperiods` parameter, use ISO 8601 format with a slash separator:
        - **UTC format**: `["2024-01-15T00:00:00Z/2024-01-16T00:00:00Z"]`
        - **With timezone offset**: `["2024-01-15T00:00:00+00:00/2024-01-16T00:00:00+00:00"]`
        - **Multiple periods**: `["2024-01-01T00:00:00Z/2024-01-02T00:00:00Z", "2024-01-15T00:00:00Z/2024-01-16T00:00:00Z"]`
        
        ### Common Date Patterns
        When instructing the AI to query ActivityWatch, use these relative descriptions:
        - **"Get today's data"** → AI should calculate today's date for the time period
        - **"Show this week"** → AI should calculate Monday to Sunday of current week
        - **"Last 30 days"** → AI should calculate from 30 days ago to today
        - **"Yesterday"** → AI should calculate yesterday's full day range
        
        The AI will convert these to proper ISO 8601 format with the current date.
        
        ## Basic Queries
        
        ### Get all window events for today
        ```
        timeperiods: ["<today>T00:00:00+00:00/<tomorrow>T00:00:00+00:00"]
        query: ["events = query_bucket('aw-watcher-window_hostname'); RETURN = events;"]
        ```
        Note: Replace <today> and <tomorrow> with actual dates
        
        ### Get AFK (Away From Keyboard) events
        ```
        timeperiods: ["<today>T00:00:00+00:00/<tomorrow>T00:00:00+00:00"]
        query: ["events = query_bucket('aw-watcher-afk_hostname'); RETURN = events;"]
        ```
        Note: The AI should calculate the actual dates based on the current date
        
        ## Advanced Queries
        
        ### Get events for a specific application
        ```
        query: [
            "events = query_bucket('aw-watcher-window_hostname');",
            "chrome_events = filter_keyvals(events, 'app', ['Google Chrome', 'Chrome']);",
            "RETURN = chrome_events;"
        ]
        ```
        
        ### Calculate total time per application
        ```
        query: [
            "events = query_bucket('aw-watcher-window_hostname');",
            "app_events = merge_events_by_keys(events, ['app']);",
            "RETURN = sort_by_duration(app_events);"
        ]
        ```
        
        ### Get productive vs unproductive time
        ```
        query: [
            "events = query_bucket('aw-watcher-window_hostname');",
            "productive = filter_keyvals(events, 'app', ['VSCode', 'Terminal', 'Xcode']);",
            "unproductive = filter_keyvals(events, 'app', ['Twitter', 'YouTube', 'Reddit']);",
            "RETURN = {",
            "  'productive': sum_durations(productive),",
            "  'unproductive': sum_durations(unproductive)",
            "};"
        ]
        ```
        
        ### Combine window and AFK data
        ```
        query: [
            "afk_events = query_bucket('aw-watcher-afk_hostname');",
            "window_events = query_bucket('aw-watcher-window_hostname');",
            "active_events = filter_keyvals(afk_events, 'status', ['not-afk']);",
            "active_window_events = filter_period_intersect(window_events, active_events);",
            "RETURN = active_window_events;"
        ]
        ```
        
        ## Common Functions
        
        - `query_bucket(bucket_id)` - Get events from a bucket
        - `filter_keyvals(events, key, values)` - Filter events by key-value pairs
        - `merge_events_by_keys(events, keys)` - Merge events with same key values
        - `sort_by_duration(events)` - Sort events by duration
        - `sum_durations(events)` - Calculate total duration
        - `filter_period_intersect(events1, events2)` - Get events that overlap in time
        
        ## Important Notes
        
        1. **Always include timezone** in your date strings (use Z for UTC or +/-HH:MM)
        2. **Bucket names** include the hostname (e.g., 'aw-watcher-window_hostname')
        3. **Time periods** must be in the format "start/end" with a forward slash
        4. **Query statements** are separated by semicolons when in the same string
        """
        
        return CallTool.Result(content: [.text(examples)])
    }
    
    private func handleGetPrompt(name: String, arguments: [String: Value]?) async throws -> GetPrompt.Result {
        let args = arguments ?? [:]
        
        switch name {
        case "analyze-productivity":
            return try handleAnalyzeProductivityPrompt(args: args)
        case "compare-periods":
            return try handleComparePeriodsPrompt(args: args)
        default:
            throw MCPError.methodNotFound("Unknown prompt: \(name)")
        }
    }
    
    private func handleAnalyzeProductivityPrompt(args: [String: Value]) throws -> GetPrompt.Result {
        guard let date = args["date"]?.stringValue else {
            throw MCPError.invalidParams("date is required")
        }
        
        let focus = args["focus"]?.stringValue
        
        var content = "I'll analyze your productivity for \(date).\n\n"
        
        if let focus = focus {
            content += "Focusing on: \(focus)\n\n"
        }
        
        content += """
        To analyze your productivity, I'll:
        1. Query your window activity data
        2. Calculate time spent in different applications
        3. Identify your most productive periods
        4. Provide insights and suggestions
        
        Let me start by fetching your activity data...
        """
        
        return GetPrompt.Result(
            description: "Analyze productivity for the specified date",
            messages: [
                .user(.text(text: content))
            ]
        )
    }
    
    private func handleComparePeriodsPrompt(args: [String: Value]) throws -> GetPrompt.Result {
        guard let period1Start = args["period1_start"]?.stringValue,
              let period1End = args["period1_end"]?.stringValue,
              let period2Start = args["period2_start"]?.stringValue,
              let period2End = args["period2_end"]?.stringValue else {
            throw MCPError.invalidParams("All period parameters are required")
        }
        
        let content = """
        I'll compare your activity between two periods:
        - Period 1: \(period1Start) to \(period1End)
        - Period 2: \(period2Start) to \(period2End)
        
        The comparison will include:
        1. Total active time
        2. Application usage differences
        3. Productivity patterns
        4. Key changes in behavior
        
        Starting the analysis...
        """
        
        return GetPrompt.Result(
            description: "Compare activity between two time periods",
            messages: [
                .user(.text(text: content))
            ]
        )
    }
    
    private func handleGetFolderActivity(args: [String: Value]) async throws -> CallTool.Result {
        let startStr = args["start"]?.stringValue
        let endStr = args["end"]?.stringValue
        
        // Check for common AI mistakes
        if let endStr = endStr, endStr.lowercased() == "now" && startStr?.lowercased() == "today" {
            logger.warning("AI provided end=\"now\" with start=\"today\". Ignoring end parameter for single day query.")
            // Ignore the end parameter for single day queries
            let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: nil)
            return try await performGetFolderActivity(start: start, end: end, args: args)
        }
        
        // Parse dates using natural language
        let (start, end) = try DateParsingHelper.parseDateRange(start: startStr, end: endStr)
        return try await performGetFolderActivity(start: start, end: end, args: args)
    }
    
    private func performGetFolderActivity(start: String, end: String, args: [String: Value]) async throws -> CallTool.Result {
        let includeWeb = args["includeWeb"]?.boolValue ?? false
        let minDuration = args["minDuration"]?.doubleValue ?? 5.0
        
        do {
            // Get all window buckets
            let buckets = try await api.listBuckets()
            let windowBuckets = buckets.filter { bucket in
                bucket.type == "currentwindow"
            }
            
            // Create the analyzer
            let analyzer = FolderActivityAnalyzer(logger: logger)
            
            // Collect all window events
            var allEvents: [[String: AnyCodable]] = []
            var totalEvents = 0
            
            for bucket in windowBuckets {
                do {
                    let events = try await api.getEvents(
                        bucketId: bucket.id,
                        limit: 10000,
                        start: start,
                        end: end
                    )
                    
                    totalEvents += events.count
                    
                    // Convert Event objects to dictionary format for the analyzer
                    for event in events {
                        var eventDict: [String: AnyCodable] = [:]
                        eventDict["timestamp"] = AnyCodable(event.timestamp)
                        eventDict["duration"] = AnyCodable(event.duration)
                        eventDict["data"] = AnyCodable(event.data.mapValues { $0.value })
                        if let id = event.id {
                            eventDict["id"] = AnyCodable(id)
                        }
                        allEvents.append(eventDict)
                    }
                } catch {
                    logger.debug("Skipping bucket \(bucket.id): \(error)")
                }
            }
            
            // Analyze folder activity
            let folderActivities = await analyzer.analyzeFolderActivity(
                from: allEvents,
                includeWeb: includeWeb
            ).filter { $0.totalDuration >= minDuration }
            
            // Format response
            var response = "# Folder Activity Summary\n\n"
            response += "Time range: \(start) to \(end)\n"
            response += "Total events analyzed: \(totalEvents)\n"
            response += "Folders found: \(folderActivities.count)\n\n"
            
            if folderActivities.isEmpty {
                response += "No folder activity found in the specified time range.\n"
            } else {
                // Group by application
                let byApp = Dictionary(grouping: folderActivities) { $0.application }
                
                response += "## Folders by Application\n\n"
                
                for (app, activities) in byApp.sorted(by: { $0.key < $1.key }) {
                    response += "### \(app)\n\n"
                    
                    for activity in activities.sorted(by: { $0.totalDuration > $1.totalDuration }) {
                        response += "- **\(activity.path)**"
                        if let context = activity.context {
                            response += " (\(context))"
                        }
                        response += "\n"
                        response += "  - Time: \(activity.formattedDuration)\n"
                        response += "  - Events: \(activity.eventCount)\n\n"
                    }
                }
                
                // Overall summary
                response += "## Top 10 Most Active Folders\n\n"
                
                for (index, activity) in folderActivities.prefix(10).enumerated() {
                    response += "\(index + 1). **\(activity.path)** - \(activity.formattedDuration) (\(activity.application))"
                    if let context = activity.context {
                        response += " [\(context)]"
                    }
                    response += "\n"
                }
            }
            
            return CallTool.Result(content: [.text(response)])
        } catch {
            logger.error("Failed to get folder activity: \(error)")
            return CallTool.Result(
                content: [.text("Failed to get folder activity: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    // Helper functions
    private func normalizeQueryInputs(args: [String: Value]) throws -> ([String], [String]) {
        // Extract timeperiods
        let rawTimeperiods: [String]
        switch args["timeperiods"] {
        case .array(let array):
            rawTimeperiods = array.compactMap { $0.stringValue }
        case .string(let str):
            // Handle single string input
            rawTimeperiods = [str]
        default:
            throw MCPError.invalidParams("timeperiods must be an array of strings")
        }
        
        // Parse time periods using natural language
        let timeperiods = try rawTimeperiods.map { period in
            try DateParsingHelper.parseTimePeriod(period)
        }
        
        // Extract query
        let query: [String]
        switch args["query"] {
        case .array(let array):
            // Handle nested arrays (some clients double-wrap)
            if array.count == 1, case .array(let nested) = array[0] {
                query = nested.compactMap { $0.stringValue }
            } else {
                query = array.compactMap { $0.stringValue }
            }
        case .string(let str):
            // Handle single string query
            query = [str]
        default:
            throw MCPError.invalidParams("query must be an array of strings")
        }
        
        return (timeperiods, query)
    }
    
    private func formatJSON(_ dict: [String: AnyCodable]) -> String {
        var result = "{ "
        let items = dict.map { key, value in
            "\(key): \(formatValue(value.value))"
        }
        result += items.joined(separator: ", ")
        result += " }"
        return result
    }
    
    private func formatValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            return "\"\(str)\""
        case let num as NSNumber:
            return "\(num)"
        case let bool as Bool:
            return "\(bool)"
        case let array as [Any]:
            return "[\(array.map { formatValue($0) }.joined(separator: ", "))]"
        case let dict as [String: Any]:
            let items = dict.map { "\($0.key): \(formatValue($0.value))" }
            return "{ \(items.joined(separator: ", ")) }"
        default:
            return "null"
        }
    }
    
    private func handleGetVersion() -> CallTool.Result {
        let response = """
        ActivityWatch MCP Server
        Version: \(version)
        
        Swift implementation of the ActivityWatch Model Context Protocol (MCP) Server.
        Provides structured access to ActivityWatch time tracking data.
        
        For more information, visit: https://github.com/doozMen/opens-time-chat
        """
        
        return CallTool.Result(
            content: [.text(response)]
        )
    }
}

// Extension to help with Value type conversions
extension Value {
    var stringValue: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let num) = self {
            return num
        }
        // Also handle double case for compatibility
        if case .double(let num) = self {
            return Int(num)
        }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let bool) = self {
            return bool
        }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let num) = self {
            return num
        }
        if case .int(let num) = self {
            return Double(num)
        }
        return nil
    }
}