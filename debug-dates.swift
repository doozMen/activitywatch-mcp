import Foundation

// Test without SwiftDateParser first
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

print("=== System Date Info ===")
print("Current Date: \(Date())")
print("ISO Format: \(formatter.string(from: Date()))")
print("TimeZone: \(TimeZone.current.identifier)")
print("Calendar: \(Calendar.current.identifier)")

// Test basic date calculations
let calendar = Calendar.current
let now = Date()

print("\n=== Date Calculations ===")
print("Now: \(formatter.string(from: now))")

if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
    print("Yesterday: \(formatter.string(from: yesterday))")
}

if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) {
    print("2 days ago: \(formatter.string(from: twoDaysAgo))")
}

if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) {
    print("Last week: \(formatter.string(from: lastWeek))")
}

// Check what "June 17, 2025" would be
var components = DateComponents()
components.year = 2025
components.month = 6
components.day = 17
components.timeZone = TimeZone(identifier: "UTC")

if let june17 = calendar.date(from: components) {
    print("\n=== June 17, 2025 ===")
    print("June 17, 2025: \(formatter.string(from: june17))")
    print("Days from now: \(calendar.dateComponents([.day], from: now, to: june17).day ?? 0)")
}