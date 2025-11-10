import Testing
import Foundation
@testable import ActivityWatchMCP

@Test("Test natural language date parsing")
func testNaturalLanguageParsing() throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    
    print("Current system date: \(Date())")
    print("Formatted: \(formatter.string(from: Date()))")
    
    // Test basic natural language
    let tests = [
        "today",
        "yesterday", 
        "tomorrow",
        "2 days ago",
        "3 days ago",
        "last week"
    ]
    
    for test in tests {
        do {
            let date = try DateParsingHelper.parseDate(test)
            let formatted = DateParsingHelper.toISO8601String(date)
            print("\"\(test)\" -> \(formatted)")
        } catch {
            print("\"\(test)\" -> Error: \(error)")
        }
    }
    
    // Test date ranges
    print("\n--- Date Ranges ---")
    let rangeTests = [
        ("today", nil),
        ("yesterday", nil),
        ("2 days ago", "yesterday"),
        ("last week", nil)
    ]
    
    for (start, end) in rangeTests {
        do {
            let (startDate, endDate) = try DateParsingHelper.parseDateRange(start: start, end: end)
            print("Range: \(start) to \(end ?? "end of day") -> \(startDate) to \(endDate)")
        } catch {
            print("Range: \(start) to \(end ?? "end of day") -> Error: \(error)")
        }
    }
}

@Test("Test ISO date parsing")
func testISODateParsing() throws {
    let tests = [
        "2025-06-17T00:00:00Z",
        "2025-06-17T12:30:00+00:00",
        "2025-06-17T14:30:00+02:00"
    ]
    
    for test in tests {
        do {
            let date = try DateParsingHelper.parseDate(test)
            let formatted = DateParsingHelper.toISO8601String(date)
            print("ISO: \"\(test)\" -> \(formatted)")
            #expect(formatted != "")
        } catch {
            Issue.record("Failed to parse ISO date: \(test)")
        }
    }
}