import Foundation
import SwiftDateParser

/// Helper for parsing natural language dates in ActivityWatch MCP
enum DateParsingHelper {
    /// Parse a date string that could be in ISO 8601 format or natural language
    static func parseDate(_ dateString: String) throws -> Date {
        // First try to parse as ISO 8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try with fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without timezone (assume UTC)
        let basicFormatter = DateFormatter()
        basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        basicFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = basicFormatter.date(from: dateString) {
            return date
        }
        
        // Fall back to natural language parsing
        return try SwiftDateParser.parse(dateString)
    }
    
    /// Convert a date to ISO 8601 string format for ActivityWatch API
    static func toISO8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
    
    /// Parse a date range from natural language or explicit start/end
    static func parseDateRange(start: String?, end: String?) throws -> (start: String, end: String) {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        // Handle common patterns
        if let start = start, start.lowercased() == "today" && end == nil {
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            return (toISO8601String(startOfDay), toISO8601String(endOfDay))
        }
        
        if let start = start, start.lowercased() == "yesterday" && end == nil {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfDay = calendar.startOfDay(for: yesterday)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            return (toISO8601String(startOfDay), toISO8601String(endOfDay))
        }
        
        if let start = start, start.lowercased() == "this week" && end == nil {
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.end.addingTimeInterval(-1)
            return (toISO8601String(startOfWeek), toISO8601String(endOfWeek))
        }
        
        if let start = start, start.lowercased() == "last week" && end == nil {
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!.start
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!.end.addingTimeInterval(-1)
            return (toISO8601String(startOfWeek), toISO8601String(endOfWeek))
        }
        
        // Parse individual dates
        guard let start = start else {
            throw DateParserError.unableToParseDate("Start date is required")
        }
        
        let startDate = try parseDate(start)
        let endDate: Date
        
        if let end = end {
            endDate = try parseDate(end)
        } else {
            // If no end date, assume end of the same day
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate))!.addingTimeInterval(-1)
        }
        
        return (toISO8601String(startDate), toISO8601String(endDate))
    }
    
    /// Parse time periods for AQL queries (format: start/end)
    static func parseTimePeriod(_ period: String) throws -> String {
        let components = period.split(separator: "/", maxSplits: 1).map(String.init)
        
        if components.count == 2 {
            let startDate = try parseDate(components[0])
            let endDate = try parseDate(components[1])
            
            // For AQL, use +00:00 format instead of Z
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            return "\(formatter.string(from: startDate))/\(formatter.string(from: endDate))"
        } else if components.count == 1 {
            // Single date - assume full day
            let date = try parseDate(components[0])
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            return "\(formatter.string(from: startOfDay))/\(formatter.string(from: endOfDay))"
        }
        
        throw DateParserError.unableToParseDate("Invalid time period format: \(period)")
    }
}