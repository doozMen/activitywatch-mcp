import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Logging

// MARK: - Data Models

/// Represents an ActivityWatch bucket that stores events of a specific type.
struct Bucket: Codable, Sendable {
    /// Unique identifier for the bucket
    let id: String
    /// Human-readable name for the bucket
    let name: String?
    /// Type of events stored (e.g., "window", "afk", "web")
    let type: String
    /// Client/watcher that created this bucket
    let client: String?
    /// Hostname where the bucket was created
    let hostname: String?
    /// ISO timestamp when the bucket was created
    let created: String?
    /// Additional data associated with the bucket
    let data: [String: AnyCodable]?
    /// Metadata about the bucket
    let metadata: [String: AnyCodable]?
    /// ISO timestamp of last update
    let last_updated: String?
}

/// Represents a single time-tracking event in ActivityWatch.
struct Event: Codable, Sendable {
    /// Unique identifier for the event
    let id: Int64?
    /// ISO timestamp when the event occurred
    let timestamp: String
    /// Duration of the event in seconds
    let duration: Double
    /// Event-specific data (e.g., window title, app name)
    let data: [String: AnyCodable]
}

/// Represents an AQL (ActivityWatch Query Language) query request.
struct Query: Codable, Sendable {
    /// Time periods to query (e.g., ["2024-01-01T00:00:00/2024-01-02T00:00:00"])
    let timeperiods: [String]
    /// AQL query statements
    let query: [String]
}

/// Result of executing an AQL query.
struct QueryResult: Codable, Sendable {
    /// Array of event arrays (one per query statement)
    let result: [[Event]]
}

// MARK: - Helper Types

/// Type-erased container for encoding/decoding arbitrary JSON values.
///
/// This wrapper allows us to work with ActivityWatch's flexible JSON responses
/// where the structure may vary based on the event type or bucket configuration.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - ActivityWatch API Client

/// Actor-based HTTP client for interacting with the ActivityWatch REST API.
///
/// This client provides thread-safe access to ActivityWatch endpoints and handles
/// all HTTP communication, JSON encoding/decoding, and error handling.
actor ActivityWatchAPI {
    private let client: HTTPClient
    private let logger: Logger
    private let baseURL: String
    
    /// Initializes a new ActivityWatch API client.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for API operations
    ///   - serverUrl: Base URL of the ActivityWatch server (e.g., "http://localhost:5600")
    init(logger: Logger, serverUrl: String) {
        self.logger = logger
        self.baseURL = "\(serverUrl)/api/0"
        self.client = HTTPClient(eventLoopGroupProvider: .singleton)
    }
    
    deinit {
        try? client.syncShutdown()
    }
    
    /// Fetches all buckets from the ActivityWatch server.
    ///
    /// - Returns: Array of Bucket objects
    /// - Throws: ActivityWatchError if the request fails
    func listBuckets() async throws -> [Bucket] {
        let url = "\(baseURL)/buckets"
        logger.debug("Fetching buckets from: \(url)")
        
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/json")
        
        let response = try await client.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
        
        guard response.status.code == 200 else {
            let errorText = String(buffer: body)
            logger.error("Failed to fetch buckets: \(response.status) - \(errorText)")
            throw ActivityWatchError.httpError(status: Int(response.status.code), message: errorText)
        }
        
        let decoder = JSONDecoder()
        let bucketDict = try decoder.decode([String: Bucket].self, from: body)
        return Array(bucketDict.values)
    }
    
    /// Retrieves events from a specific bucket.
    ///
    /// - Parameters:
    ///   - bucketId: The ID of the bucket to query
    ///   - limit: Maximum number of events to return (optional)
    ///   - start: Start time in ISO format (optional)
    ///   - end: End time in ISO format (optional)
    /// - Returns: Array of Event objects
    /// - Throws: ActivityWatchError if the request fails
    func getEvents(bucketId: String, limit: Int? = nil, start: String? = nil, end: String? = nil) async throws -> [Event] {
        var url = "\(baseURL)/buckets/\(bucketId)/events"
        var params: [String] = []
        
        if let limit = limit {
            params.append("limit=\(limit)")
        }
        if let start = start {
            params.append("start=\(start)")
        }
        if let end = end {
            params.append("end=\(end)")
        }
        
        if !params.isEmpty {
            url += "?" + params.joined(separator: "&")
        }
        
        logger.debug("Fetching events from: \(url)")
        
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/json")
        
        let response = try await client.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
        
        guard response.status.code == 200 else {
            let errorText = String(buffer: body)
            logger.error("Failed to fetch events: \(response.status) - \(errorText)")
            throw ActivityWatchError.httpError(status: Int(response.status.code), message: errorText)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Event].self, from: body)
    }
    
    /// Executes an AQL (ActivityWatch Query Language) query.
    ///
    /// - Parameters:
    ///   - timeperiods: Array of ISO date ranges (e.g., ["2024-01-01T00:00:00/2024-01-02T00:00:00"])
    ///   - query: Array of AQL statements to execute
    /// - Returns: Array of event arrays (one per query statement)
    /// - Throws: ActivityWatchError if the query fails
    func runQuery(timeperiods: [String], query: [String]) async throws -> [[Event]] {
        let url = "\(baseURL)/query"
        let queryData = Query(timeperiods: timeperiods, query: query)
        
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(queryData)
        
        logger.debug("Running query at: \(url)")
        logger.debug("Query data: \(String(data: bodyData, encoding: .utf8) ?? "")")
        
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Accept", value: "application/json")
        request.body = .bytes(ByteBuffer(data: bodyData))
        
        let response = try await client.execute(request, timeout: .seconds(60))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
        
        guard response.status.code == 200 else {
            let errorText = String(buffer: body)
            logger.error("Failed to run query: \(response.status) - \(errorText)")
            throw ActivityWatchError.httpError(status: Int(response.status.code), message: errorText)
        }
        
        let decoder = JSONDecoder()
        // ActivityWatch returns results as an array of arrays
        return try decoder.decode([[Event]].self, from: body)
    }
    
    func getSettings(key: String? = nil) async throws -> [String: AnyCodable] {
        var url = "\(baseURL)/settings"
        if let key = key {
            url += "/\(key)"
        }
        
        logger.debug("Fetching settings from: \(url)")
        
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/json")
        
        let response = try await client.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
        
        guard response.status.code == 200 else {
            let errorText = String(buffer: body)
            logger.error("Failed to fetch settings: \(response.status) - \(errorText)")
            throw ActivityWatchError.httpError(status: Int(response.status.code), message: errorText)
        }
        
        let decoder = JSONDecoder()
        // Try to decode as a dictionary of AnyCodable values
        return try decoder.decode([String: AnyCodable].self, from: body)
    }
}

// MARK: - Errors

/// Errors that can occur when interacting with the ActivityWatch API.
enum ActivityWatchError: Error, LocalizedError {
    /// HTTP request failed with a specific status code
    case httpError(status: Int, message: String)
    /// Response data could not be parsed or was invalid
    case invalidResponse(String)
    /// Network connection error
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .httpError(let status, let message):
            return "HTTP \(status): \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}