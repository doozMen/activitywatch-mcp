import Testing
import Foundation
import Logging
@testable import ActivityWatchMCP

/// Tests for ActivityWatchAPI actor - REST API communication
@Suite("ActivityWatch API Client Tests")
struct APIClientTests {
    
    // MARK: - Bucket API Tests
    
    @Test("List all buckets from ActivityWatch API")
    func testListBuckets() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        
        #expect(!buckets.isEmpty, "Expected at least one bucket from ActivityWatch")
        
        // Verify bucket structure
        for bucket in buckets {
            #expect(!bucket.id.isEmpty, "Bucket ID should not be empty")
            #expect(!bucket.type.isEmpty, "Bucket type should not be empty")
        }
        
        print("Found \(buckets.count) buckets:")
        for bucket in buckets {
            print("  - \(bucket.id) (type: \(bucket.type))")
        }
    }
    
    @Test("List buckets returns correct bucket types")
    func testBucketTypes() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        let types = Set(buckets.map { $0.type })
        
        print("Available bucket types: \(types)")
        
        // Common bucket types we expect
        let expectedTypes = ["currentwindow", "afkstatus", "web.tab.current"]
        let hasExpectedType = expectedTypes.contains { types.contains($0) }
        
        #expect(hasExpectedType, "Expected at least one common bucket type")
    }
    
    // MARK: - Events API Tests
    
    @Test("Get events from a specific bucket")
    func testGetEvents() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // First get buckets to find a valid bucket ID
        let buckets = try await api.listBuckets()
        guard let firstBucket = buckets.first else {
            Issue.record("No buckets available for testing")
            return
        }
        
        let events = try await api.getEvents(bucketId: firstBucket.id, limit: 10)
        
        print("Retrieved \(events.count) events from bucket: \(firstBucket.id)")
        
        // Verify event structure
        for event in events {
            #expect(!event.timestamp.isEmpty, "Event timestamp should not be empty")
            #expect(event.duration >= 0, "Event duration should be non-negative")
            #expect(!event.data.isEmpty, "Event data should not be empty")
        }
    }
    
    @Test("Get events with time range filter")
    func testGetEventsWithTimeRange() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket available for testing")
            return
        }
        
        // Get today's events
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startStr = formatter.string(from: today)
        let endStr = formatter.string(from: Date())
        
        let events = try await api.getEvents(
            bucketId: bucket.id,
            limit: 100,
            start: startStr,
            end: endStr
        )
        
        print("Retrieved \(events.count) events from today")
        
        // Verify all events are within the time range
        for event in events {
            if let eventDate = formatter.date(from: event.timestamp) {
                #expect(eventDate >= today, "Event should be from today or later")
            }
        }
    }
    
    @Test("Get events handles empty results gracefully")
    func testGetEventsEmptyResults() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first else {
            Issue.record("No buckets available for testing")
            return
        }
        
        // Query far in the future (should be empty)
        let future = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let events = try await api.getEvents(
            bucketId: bucket.id,
            limit: 10,
            start: formatter.string(from: future)
        )
        
        #expect(events.isEmpty, "Should have no events from future date")
    }
    
    // MARK: - Query API Tests
    
    @Test("Run basic AQL query")
    func testRunBasicQuery() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // Get today's date range
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        // Find a window bucket
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket available for testing")
            return
        }
        
        let query = ["events = query_bucket('\(windowBucket.id)'); RETURN = events;"]
        
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        #expect(!results.isEmpty, "Query should return at least one result set")
        print("Query returned \(results.count) result sets")
        
        if let firstSet = results.first {
            print("First result set has \(firstSet.count) events")
        }
    }
    
    @Test("Run query with multiple statements")
    func testRunMultiStatementQuery() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket available for testing")
            return
        }
        
        // Multi-statement query
        let query = [
            "events = query_bucket('\(windowBucket.id)');",
            "RETURN = events;"
        ]
        
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        #expect(!results.isEmpty, "Multi-statement query should return results")
    }
    
    @Test("Run query with filter operation")
    func testRunQueryWithFilter() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        let buckets = try await api.listBuckets()
        guard let windowBucket = buckets.first(where: { $0.type == "currentwindow" }) else {
            Issue.record("No window bucket available for testing")
            return
        }
        
        // Query with merge_events_by_keys
        let query = [
            "events = query_bucket('\(windowBucket.id)');",
            "merged = merge_events_by_keys(events, ['app']);",
            "RETURN = merged;"
        ]
        
        let results = try await api.runQuery(timeperiods: [timeperiod], query: query)
        
        #expect(!results.isEmpty, "Filtered query should return results")
        
        if let merged = results.first {
            print("Merged events by app: \(merged.count) unique apps")
        }
    }
    
    // MARK: - Settings API Tests
    
    @Test("Get ActivityWatch settings")
    func testGetSettings() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let settings = try await api.getSettings()
        
        print("Retrieved settings with \(settings.count) keys")
        
        // Settings should be a non-empty dictionary
        #expect(!settings.isEmpty, "Settings should not be empty")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid bucket ID gracefully")
    func testInvalidBucketID() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        do {
            _ = try await api.getEvents(bucketId: "invalid_bucket_that_does_not_exist", limit: 10)
            Issue.record("Expected error for invalid bucket ID")
        } catch let error as ActivityWatchError {
            // Expected error
            print("Caught expected error: \(error)")
            #expect(true, "Should throw ActivityWatchError for invalid bucket")
        }
    }
    
    @Test("Handle connection to wrong port")
    func testConnectionError() async throws {
        let logger = Logger(label: "test")
        // Use a port that's unlikely to be in use
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:9999")
        
        do {
            _ = try await api.listBuckets()
            Issue.record("Expected connection error for wrong port")
        } catch {
            // Expected error
            print("Caught expected connection error: \(error)")
            #expect(true, "Should throw error for connection failure")
        }
    }
    
    @Test("Handle malformed query gracefully")
    func testMalformedQuery() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let timeperiod = "\(formatter.string(from: today))/\(formatter.string(from: tomorrow))"
        
        // Invalid AQL syntax
        let query = ["this is not valid AQL syntax"]
        
        do {
            _ = try await api.runQuery(timeperiods: [timeperiod], query: query)
            Issue.record("Expected error for malformed query")
        } catch {
            // Expected error
            print("Caught expected query error: \(error)")
            #expect(true, "Should throw error for malformed query")
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Handle concurrent API calls")
    func testConcurrentCalls() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        // Make multiple concurrent calls
        async let buckets1 = api.listBuckets()
        async let buckets2 = api.listBuckets()
        async let settings = api.getSettings()
        
        let (b1, b2, s) = try await (buckets1, buckets2, settings)
        
        #expect(b1.count == b2.count, "Concurrent bucket calls should return same count")
        #expect(!s.isEmpty, "Settings should be retrieved successfully")
        
        print("Concurrent calls successful: \(b1.count) buckets, \(s.count) settings")
    }
    
    // MARK: - Data Validation Tests
    
    @Test("Validate bucket data structure")
    func testBucketDataStructure() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        
        for bucket in buckets {
            // Validate required fields
            #expect(!bucket.id.isEmpty, "Bucket ID is required")
            #expect(!bucket.type.isEmpty, "Bucket type is required")
            
            // Validate optional fields if present
            if let hostname = bucket.hostname {
                #expect(!hostname.isEmpty, "Hostname should not be empty if present")
            }
            
            if let created = bucket.created {
                // Should be valid ISO 8601 date (try multiple formats)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                var parsedDate = formatter.date(from: created)

                if parsedDate == nil {
                    // Try with fractional seconds
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    parsedDate = formatter.date(from: created)
                }

                #expect(parsedDate != nil, "Created date should be valid ISO 8601: \(created)")
            }
        }
    }
    
    @Test("Validate event data structure")
    func testEventDataStructure() async throws {
        let logger = Logger(label: "test")
        let api = ActivityWatchAPI(logger: logger, serverUrl: "http://localhost:5600")
        
        let buckets = try await api.listBuckets()
        guard let bucket = buckets.first else {
            Issue.record("No buckets available for testing")
            return
        }
        
        let events = try await api.getEvents(bucketId: bucket.id, limit: 5)
        
        for event in events {
            // Validate timestamp format (try multiple ISO 8601 formats)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            var parsedDate = formatter.date(from: event.timestamp)

            if parsedDate == nil {
                // Try with fractional seconds
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsedDate = formatter.date(from: event.timestamp)
            }

            #expect(parsedDate != nil, "Timestamp should be valid ISO 8601: \(event.timestamp)")

            // Validate duration
            #expect(event.duration >= 0, "Duration should be non-negative")

            // Validate data dictionary
            #expect(!event.data.isEmpty, "Event should have data")
        }
    }
}
