import Foundation
import MCP
import Logging

actor ActivityWatchMCPServer {
    private let server: Server
    private let api: ActivityWatchAPI
    private let logger: Logger
    
    init(logger: Logger, serverUrl: String) throws {
        self.logger = logger
        self.api = ActivityWatchAPI(logger: logger, serverUrl: serverUrl)
        
        self.server = Server(
            name: "activitywatch-mcp-server",
            version: "2.0.0",
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: nil,
                tools: .init(listChanged: false)
            )
        )
    }
    
    func run() async throws {
        await setupHandlers()
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
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
                - timeperiods: Array of ISO date ranges (e.g., ["2024-01-01T00:00:00+00:00/2024-01-02T00:00:00+00:00"])
                - query: Array of AQL statements joined by semicolons
                
                Example:
                timeperiods: ["2024-10-28T00:00:00+00:00/2024-10-29T00:00:00+00:00"]
                query: ["events = query_bucket('aw-watcher-window_hostname'); RETURN = events;"]
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "timeperiods": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of time period ranges")
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
                - start: Start time in ISO format (optional)
                - end: End time in ISO format (optional)
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
                            "description": .string("Start time in ISO format")
                        ]),
                        "end": .object([
                            "type": .string("string"),
                            "description": .string("End time in ISO format")
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
        let start = args["start"]?.stringValue
        let end = args["end"]?.stringValue
        
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
    
    private func handleQueryExamples() -> CallTool.Result {
        let examples = """
        # ActivityWatch Query Language (AQL) Examples
        
        ## Basic Queries
        
        ### Get all window events for today
        ```
        timeperiods: ["2024-10-28T00:00:00+00:00/2024-10-29T00:00:00+00:00"]
        query: ["events = query_bucket('aw-watcher-window_hostname'); RETURN = events;"]
        ```
        
        ### Get AFK (Away From Keyboard) events
        ```
        timeperiods: ["2024-10-28T00:00:00+00:00/2024-10-29T00:00:00+00:00"]
        query: ["events = query_bucket('aw-watcher-afk_hostname'); RETURN = events;"]
        ```
        
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
    
    // Helper functions
    private func normalizeQueryInputs(args: [String: Value]) throws -> ([String], [String]) {
        // Extract timeperiods
        let timeperiods: [String]
        switch args["timeperiods"] {
        case .array(let array):
            timeperiods = array.compactMap { $0.stringValue }
        case .string(let str):
            // Handle single string input
            timeperiods = [str]
        default:
            throw MCPError.invalidParams("timeperiods must be an array of strings")
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
}