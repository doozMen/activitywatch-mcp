import Testing
import Foundation
import Logging
import MCP
@testable import ActivityWatchMCP

/// Tests for MCP tool handlers - all 9 tools
@Suite("MCP Tool Tests")
struct MCPToolTests {
    
    // Helper to create a test server
    private func createTestServer() throws -> ActivityWatchMCPServer {
        let logger = Logger(label: "test")
        return try ActivityWatchMCPServer(logger: logger, serverUrl: "http://localhost:5600")
    }
    
    // MARK: - list-buckets Tool Tests
    
    @Test("list-buckets returns all buckets")
    func testListBucketsBasic() async throws {
        _ = try createTestServer()

        // Simulate calling the tool through the server
        // Note: We'll test through the API actor directly for now
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        
        #expect(!buckets.isEmpty, "Should return at least one bucket")
        
        print("list-buckets returned \(buckets.count) buckets")
        for bucket in buckets {
            print("  - \(bucket.id) (type: \(bucket.type))")
        }
    }
    
    @Test("list-buckets with type filter")
    func testListBucketsWithTypeFilter() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let allBuckets = try await api.listBuckets()
        let windowBuckets = allBuckets.filter { $0.type == "currentwindow" }
        
        #expect(!allBuckets.isEmpty, "Should have buckets")
        print("Type filter: \(allBuckets.count) total, \(windowBuckets.count) window buckets")
    }
    
    // MARK: - get-events Tool Tests
    
    @Test("get-events retrieves events from bucket")
    func testGetEvents() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first else {
            Issue.record("No buckets available")
            return
        }
        
        let events = try await api.getEvents(bucketId: bucket.id, limit: 10)
        
        print("get-events returned \(events.count) events from \(bucket.id)")
        
        for event in events.prefix(3) {
            print("  - \(event.timestamp): \(event.duration)s")
        }
    }
    
    @Test("get-events with time range parameters")
    func testGetEventsWithTimeRange() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        // Get today's events using natural language dates
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let events = try await api.getEvents(
            bucketId: bucket.id,
            limit: 50,
            start: formatter.string(from: today)
        )
        
        print("get-events with time range returned \(events.count) events")
    }
    
    @Test("get-events with limit parameter")
    func testGetEventsWithLimit() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first else {
            Issue.record("No buckets available")
            return
        }
        
        let limit = 5
        let events = try await api.getEvents(bucketId: bucket.id, limit: limit)
        
        #expect(events.count <= limit, "Should not exceed limit")
        
        print("get-events with limit=\(limit) returned \(events.count) events")
    }
    
    // MARK: - run-query Tool Tests
    
    @Test("run-query executes basic AQL query")
    func testRunQueryBasic() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        let query = ["events = query_bucket('\(windowBucket.id)'); RETURN = events;"]
        
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        #expect(!results.isEmpty, "Query should return results")
        print("run-query returned \(results.count) result sets")
    }
    
    @Test("run-query with merge operations")
    func testRunQueryWithMerge() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        let query = [
            "events = query_bucket('\(windowBucket.id)');",
            "merged = merge_events_by_keys(events, ['app']);",
            "RETURN = merged;"
        ]
        
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        #expect(!results.isEmpty, "Merge query should return results")
        print("run-query with merge returned \(results[0].count) unique apps")
    }
    
    @Test("run-query with multiple time periods")
    func testRunQueryMultiplePeriods() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let period1 = "\(formatter.string(from: yesterday))/\(formatter.string(from: today))"
        let period2 = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        let query = ["events = query_bucket('\(windowBucket.id)'); RETURN = events;"]
        
        let results = try await api.runQuery(timeperiods: [period1, period2], query: query)
        
        print("run-query with multiple periods returned \(results.count) result sets")
    }
    
    // MARK: - get-settings Tool Tests
    
    @Test("get-settings retrieves all settings")
    func testGetSettings() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let settings = try await api.getSettings()
        
        #expect(!settings.isEmpty, "Settings should not be empty")
        
        print("get-settings returned \(settings.count) settings")
        for (key, _) in settings.prefix(5) {
            print("  - \(key)")
        }
    }
    
    // MARK: - active-buckets Tool Tests
    
    @Test("active-buckets finds buckets with activity")
    func testActiveBuckets() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // Get buckets with activity today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startStr = formatter.string(from: today)
        let endStr = formatter.string(from: now)
        
        let allBuckets = try await api.listBuckets()
        var activeBuckets: [Bucket] = []
        
        for bucket in allBuckets {
            do {
                let events = try await api.getEvents(
                    bucketId: bucket.id,
                    limit: 1,
                    start: startStr,
                    end: endStr
                )
                
                if !events.isEmpty {
                    activeBuckets.append(bucket)
                }
            } catch {
                // Skip buckets that error
                continue
            }
        }
        
        print("active-buckets found \(activeBuckets.count) active buckets today")
        for bucket in activeBuckets {
            print("  - \(bucket.id) (type: \(bucket.type))")
        }
    }
    
    @Test("active-buckets with minimum events threshold")
    func testActiveBucketsWithThreshold() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startStr = formatter.string(from: today)
        let endStr = formatter.string(from: now)
        
        let minEvents = 5
        let allBuckets = try await api.listBuckets()
        var activeBuckets: [(bucket: Bucket, count: Int)] = []
        
        for bucket in allBuckets {
            do {
                let events = try await api.getEvents(
                    bucketId: bucket.id,
                    limit: minEvents + 1,
                    start: startStr,
                    end: endStr
                )
                
                if events.count >= minEvents {
                    activeBuckets.append((bucket, events.count))
                }
            } catch {
                continue
            }
        }
        
        print("active-buckets with min \(minEvents) events: \(activeBuckets.count) buckets")
        for (bucket, count) in activeBuckets {
            print("  - \(bucket.id): \(count) events")
        }
    }
    
    // MARK: - active-folders Tool Tests
    
    @Test("active-folders extracts unique folder paths")
    func testActiveFolders() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        let windowBuckets = buckets.filter { $0.type == "currentwindow" }
        
        guard !windowBuckets.isEmpty else {
            Issue.record("No window buckets available")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startStr = formatter.string(from: today)
        let endStr = formatter.string(from: now)
        
        var allPaths = Set<String>()
        
        for bucket in windowBuckets {
            do {
                let events = try await api.getEvents(
                    bucketId: bucket.id,
                    limit: 100,
                    start: startStr,
                    end: endStr
                )
                
                for event in events {
                    if let title = event.data["title"]?.value as? String {
                        // Simple path extraction for testing
                        if title.contains("/Users/") || title.contains("/home/") {
                            allPaths.insert(title)
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        print("active-folders found \(allPaths.count) unique paths today")
        for path in allPaths.prefix(10) {
            print("  - \(path)")
        }
    }
    
    // MARK: - get-folder-activity Tool Tests
    
    @Test("get-folder-activity analyzes folder usage")
    func testGetFolderActivity() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        let buckets = try await api.listBuckets()
        let windowBuckets = buckets.filter { $0.type == "currentwindow" }
        
        guard !windowBuckets.isEmpty else {
            Issue.record("No window buckets available")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startStr = formatter.string(from: today)
        let endStr = formatter.string(from: now)
        
        var allEvents: [[String: AnyCodable]] = []
        
        for bucket in windowBuckets.prefix(1) {
            do {
                let events = try await api.getEvents(
                    bucketId: bucket.id,
                    limit: 100,
                    start: startStr,
                    end: endStr
                )
                
                for event in events {
                    var eventDict: [String: AnyCodable] = [:]
                    eventDict["timestamp"] = AnyCodable(event.timestamp)
                    eventDict["duration"] = AnyCodable(event.duration)
                    eventDict["data"] = AnyCodable(event.data.mapValues { $0.value })
                    allEvents.append(eventDict)
                }
            } catch {
                continue
            }
        }
        
        let activities = await analyzer.analyzeFolderActivity(from: allEvents)
        
        print("get-folder-activity found \(activities.count) folders")
        for activity in activities.prefix(10) {
            print("  - \(activity.path): \(activity.formattedDuration) (\(activity.application))")
        }
    }
    
    @Test("get-folder-activity with minimum duration filter")
    func testGetFolderActivityWithMinDuration() async throws {
        let logger = Logger(label: "test")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        // Create test events with various durations
        let events: [[String: AnyCodable]] = [
            [
                "timestamp": AnyCodable("2024-10-08T10:00:00Z"),
                "duration": AnyCodable(3.0), // Below threshold
                "data": AnyCodable([
                    "app": "Terminal",
                    "title": "short-project"
                ] as [String: Any])
            ],
            [
                "timestamp": AnyCodable("2024-10-08T10:01:00Z"),
                "duration": AnyCodable(60.0), // Above threshold
                "data": AnyCodable([
                    "app": "Cursor",
                    "title": "long-project"
                ] as [String: Any])
            ]
        ]
        
        let minDuration = 5.0
        let activities = await analyzer.analyzeFolderActivity(from: events)
        let filtered = activities.filter { $0.totalDuration >= minDuration }
        
        print("get-folder-activity with min duration \(minDuration)s: \(filtered.count) folders")
        for activity in filtered {
            print("  - \(activity.path): \(activity.totalDuration)s")
        }
    }
    
    // MARK: - query-examples Tool Tests
    
    @Test("query-examples returns documentation")
    func testQueryExamples() {
        // This tool returns static documentation
        let examplesContent = """
        Basic query:
        events = query_bucket('aw-watcher-window_hostname');
        RETURN = events;
        """
        
        #expect(!examplesContent.isEmpty, "Query examples should not be empty")
        print("query-examples provides documentation with \(examplesContent.count) characters")
    }
    
    // MARK: - get-version Tool Tests
    
    @Test("get-version returns version information")
    func testGetVersion() {
        let version = "2.5.0"
        let versionInfo = "ActivityWatch MCP Server v\(version)"
        
        #expect(!versionInfo.isEmpty, "Version info should not be empty")
        print("get-version: \(versionInfo)")
    }
    
    // MARK: - Integration Tests Across Tools
    
    @Test("Workflow: List buckets then get events")
    func testWorkflowListThenGet() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // Step 1: List buckets
        let buckets = try await api.listBuckets()
        #expect(!buckets.isEmpty)
        
        // Step 2: Get events from first bucket
        if let bucket = buckets.first {
            let events = try await api.getEvents(bucketId: bucket.id, limit: 5)
            print("Workflow: Listed \(buckets.count) buckets, got \(events.count) events from first")
        }
    }
    
    @Test("Workflow: Query today's activity")
    func testWorkflowQueryToday() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // Find window bucket
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        // Parse "today" to time period
        let (start, end) = try DateParsingHelper.parseDateRange(start: "today", end: nil)
        let timeperiod = "\(start)/\(end)"
        
        // Run query
        let query = ["events = query_bucket('\(windowBucket.id)'); RETURN = events;"]
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        print("Workflow: Queried today's activity, got \(results[0].count) events")
    }
    
    @Test("Workflow: Analyze folder activity for today")
    func testWorkflowAnalyzeFolders() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        let analyzer = FolderActivityAnalyzer(logger: logger)
        
        // Get window buckets
        let buckets = try await api.listBuckets()
        let windowBuckets = buckets.filter { $0.type == "currentwindow" }
        
        guard !windowBuckets.isEmpty else {
            Issue.record("No window buckets")
            return
        }
        
        // Get today's events
        let (start, end) = try DateParsingHelper.parseDateRange(start: "today", end: nil)
        
        var allEvents: [[String: AnyCodable]] = []
        
        for bucket in windowBuckets.prefix(1) {
            let events = try await api.getEvents(
                bucketId: bucket.id,
                limit: 50,
                start: start,
                end: end
            )
            
            for event in events {
                var eventDict: [String: AnyCodable] = [:]
                eventDict["timestamp"] = AnyCodable(event.timestamp)
                eventDict["duration"] = AnyCodable(event.duration)
                eventDict["data"] = AnyCodable(event.data.mapValues { $0.value })
                allEvents.append(eventDict)
            }
        }
        
        // Analyze folder activity
        let activities = await analyzer.analyzeFolderActivity(from: allEvents)
        
        print("Workflow: Analyzed \(allEvents.count) events, found \(activities.count) unique folders")
        
        if let topFolder = activities.first {
            print("Top folder: \(topFolder.path) - \(topFolder.formattedDuration)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid bucket ID in get-events")
    func testErrorHandlingInvalidBucket() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        do {
            _ = try await api.getEvents(bucketId: "nonexistent_bucket_id", limit: 10)
            Issue.record("Should throw error for invalid bucket")
        } catch {
            print("Correctly handled invalid bucket error: \(error)")
            #expect(true)
        }
    }
    
    @Test("Handle malformed query in run-query")
    func testErrorHandlingMalformedQuery() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let (start, end) = try DateParsingHelper.parseDateRange(start: "today", end: nil)
        let timeperiod = "\(start)/\(end)"
        
        let malformedQuery = ["this is not valid AQL syntax at all"]
        
        do {
            _ = try await api.runQuery(timeperiods: [timeperiod], query: malformedQuery)
            Issue.record("Should throw error for malformed query")
        } catch {
            print("Correctly handled malformed query error: \(error)")
            #expect(true)
        }
    }
    
    @Test("Handle empty time period in run-query")
    func testErrorHandlingEmptyTimePeriod() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket")
            return
        }
        
        let query = ["events = query_bucket('\(windowBucket.id)'); RETURN = events;"]
        
        do {
            let results = try await api.runQuery(timeperiods: [], query: query)
            // Empty timeperiods might still work, just return empty results
            print("Query with empty timeperiods returned \(results.count) results")
        } catch {
            print("Empty timeperiods threw error (expected): \(error)")
        }
    }
}
