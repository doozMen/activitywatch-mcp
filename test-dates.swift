#!/usr/bin/env swift

import Foundation
import SwiftDateParser

let tests = ["today", "yesterday", "2 days ago", "3 days ago"]
let formatter = ISO8601DateFormatter()

print("Current date: \(Date())")
print("---")

for test in tests {
    do {
        let date = try SwiftDateParser.parse(test)
        print("\"\(test)\" -> \(formatter.string(from: date))")
    } catch {
        print("\"\(test)\" -> Error: \(error)")
    }
}

// Also test the helper
let helper = """
import Foundation
import SwiftDateParser

enum DateParsingHelper {
    static func parseDate(_ dateString: String) throws -> Date {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        let basicFormatter = DateFormatter()
        basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        basicFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = basicFormatter.date(from: dateString) {
            return date
        }
        
        return try SwiftDateParser.parse(dateString)
    }
    
    static func toISO8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

print("\n--- Using DateParsingHelper ---")
for test in tests {
    do {
        let date = try DateParsingHelper.parseDate(test)
        print("\"\(test)\" -> \(DateParsingHelper.toISO8601String(date))")
    } catch {
        print("\"\(test)\" -> Error: \(error)")
    }
}
"""