import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Logging

struct Bucket: Codable, Sendable {
    let id: String
    let name: String?
    let type: String
    let client: String?
    let hostname: String?
    let created: String?
    let data: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
    let last_updated: String?
}

struct Event: Codable, Sendable {
    let id: Int64?
    let timestamp: String
    let duration: Double
    let data: [String: AnyCodable]
}

struct Query: Codable, Sendable {
    let timeperiods: [String]
    let query: [String]
}

struct QueryResult: Codable, Sendable {
    let result: [[Event]]
}

// Helper for encoding/decoding arbitrary JSON
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

actor ActivityWatchAPI {
    private let client: HTTPClient
    private let logger: Logger
    private let baseURL: String
    
    init(logger: Logger, serverUrl: String) {
        self.logger = logger
        self.baseURL = "\(serverUrl)/api/0"
        self.client = HTTPClient(eventLoopGroupProvider: .singleton)
    }
    
    deinit {
        try? client.syncShutdown()
    }
    
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

enum ActivityWatchError: Error, LocalizedError {
    case httpError(status: Int, message: String)
    case invalidResponse(String)
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