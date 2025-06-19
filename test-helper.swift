#!/usr/bin/env swift

// Run this from the activitywatch-mcp directory with:
// swift run --skip-build test-helper.swift

import Foundation

print("Testing DateParsingHelper date outputs...")
print("Current system time: \(Date())")
print("---")

// We'll manually implement the same logic to debug
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

// Test "2 days ago"
let calendar = Calendar.current
let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
let startOfDay = calendar.startOfDay(for: twoDaysAgo)
let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)

print("2 days ago (June 17):")
print("  Start of day: \(formatter.string(from: startOfDay))")
print("  End of day: \(formatter.string(from: endOfDay))")

// Let's see what the actual timestamp range should be for June 17
var june17Components = DateComponents()
june17Components.year = 2025
june17Components.month = 6
june17Components.day = 17
june17Components.hour = 0
june17Components.minute = 0
june17Components.second = 0
june17Components.timeZone = TimeZone(identifier: "UTC")

if let june17Start = calendar.date(from: june17Components) {
    june17Components.hour = 23
    june17Components.minute = 59
    june17Components.second = 59
    
    if let june17End = calendar.date(from: june17Components) {
        print("\nExplicit June 17 UTC range:")
        print("  Start: \(formatter.string(from: june17Start))")
        print("  End: \(formatter.string(from: june17End))")
    }
}