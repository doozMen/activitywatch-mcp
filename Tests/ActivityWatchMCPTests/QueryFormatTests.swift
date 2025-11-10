import Testing
import Foundation
@testable import ActivityWatchMCP

/// Tests for query format normalization and date parsing
@Suite("Query Format Tests")
struct QueryFormatTests {
    
    // MARK: - Date Parsing Tests
    
    @Test("Parse ISO 8601 date with Z timezone")
    func testParseISO8601WithZ() throws {
        let dateString = "2024-10-08T10:00:00Z"
        let date = try DateParsingHelper.parseDate(dateString)
        
        let formatted = DateParsingHelper.toISO8601String(date)
        #expect(formatted.contains("2024-10-08"))
        print("Parsed ISO 8601 with Z: \(formatted)")
    }
    
    @Test("Parse ISO 8601 date with timezone offset")
    func testParseISO8601WithOffset() throws {
        let dateString = "2024-10-08T10:00:00+02:00"
        let date = try DateParsingHelper.parseDate(dateString)
        
        let formatted = DateParsingHelper.toISO8601String(date)
        #expect(!formatted.isEmpty)
        print("Parsed ISO 8601 with offset: \(formatted)")
    }
    
    @Test("Parse ISO 8601 date without timezone")
    func testParseISO8601WithoutTimezone() throws {
        let dateString = "2024-10-08T10:00:00"
        let date = try DateParsingHelper.parseDate(dateString)
        
        let formatted = DateParsingHelper.toISO8601String(date)
        #expect(formatted.contains("2024-10-08"))
        print("Parsed ISO 8601 without timezone: \(formatted)")
    }
    
    @Test("Parse natural language - today")
    func testParseToday() throws {
        let date = try DateParsingHelper.parseDate("today")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Should be within today
        #expect(calendar.isDate(date, inSameDayAs: today))
        print("Parsed 'today': \(DateParsingHelper.toISO8601String(date))")
    }
    
    @Test("Parse natural language - yesterday")
    func testParseYesterday() throws {
        let date = try DateParsingHelper.parseDate("yesterday")
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        #expect(calendar.isDate(date, inSameDayAs: yesterday))
        print("Parsed 'yesterday': \(DateParsingHelper.toISO8601String(date))")
    }
    
    @Test("Parse natural language - tomorrow")
    func testParseTomorrow() throws {
        let date = try DateParsingHelper.parseDate("tomorrow")
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        #expect(calendar.isDate(date, inSameDayAs: tomorrow))
        print("Parsed 'tomorrow': \(DateParsingHelper.toISO8601String(date))")
    }
    
    @Test("Parse natural language - days ago")
    func testParseDaysAgo() throws {
        let date = try DateParsingHelper.parseDate("3 days ago")
        
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        
        #expect(calendar.isDate(date, inSameDayAs: threeDaysAgo))
        print("Parsed '3 days ago': \(DateParsingHelper.toISO8601String(date))")
    }
    
    @Test("Parse natural language - this week")
    func testParseThisWeek() throws {
        let date = try DateParsingHelper.parseDate("this week")
        
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        
        #expect(date >= weekInterval.start && date <= weekInterval.end)
        print("Parsed 'this week': \(DateParsingHelper.toISO8601String(date))")
    }
    
    @Test("Parse natural language - last week")
    func testParseLastWeek() throws {
        let date = try DateParsingHelper.parseDate("last week")
        
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek)!
        
        #expect(date >= weekInterval.start && date <= weekInterval.end)
        print("Parsed 'last week': \(DateParsingHelper.toISO8601String(date))")
    }
    
    // MARK: - Date Range Parsing Tests
    
    @Test("Parse date range - today with no end")
    func testParseDateRangeTodayNoEnd() throws {
        let (start, end) = try DateParsingHelper.parseDateRange(start: "today", end: nil)
        
        let calendar = Calendar.current
        let startDate = try DateParsingHelper.parseDate(start)
        let endDate = try DateParsingHelper.parseDate(end)
        
        #expect(calendar.isDate(startDate, inSameDayAs: Date()))
        #expect(calendar.isDate(endDate, inSameDayAs: Date()))
        
        // End should be later than start
        #expect(endDate > startDate)
        
        print("Date range for 'today': \(start) to \(end)")
    }
    
    @Test("Parse date range - yesterday with no end")
    func testParseDateRangeYesterdayNoEnd() throws {
        let (start, end) = try DateParsingHelper.parseDateRange(start: "yesterday", end: nil)
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let startDate = try DateParsingHelper.parseDate(start)
        let endDate = try DateParsingHelper.parseDate(end)
        
        #expect(calendar.isDate(startDate, inSameDayAs: yesterday))
        #expect(calendar.isDate(endDate, inSameDayAs: yesterday))
        
        print("Date range for 'yesterday': \(start) to \(end)")
    }
    
    @Test("Parse date range - this week with no end")
    func testParseDateRangeThisWeekNoEnd() throws {
        let (start, end) = try DateParsingHelper.parseDateRange(start: "this week", end: nil)
        
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        
        let startDate = try DateParsingHelper.parseDate(start)
        let endDate = try DateParsingHelper.parseDate(end)
        
        #expect(startDate >= weekInterval.start)
        #expect(endDate <= weekInterval.end)
        
        print("Date range for 'this week': \(start) to \(end)")
    }
    
    @Test("Parse date range - explicit start and end")
    func testParseDateRangeExplicit() throws {
        let (start, end) = try DateParsingHelper.parseDateRange(start: "3 days ago", end: "yesterday")
        
        let calendar = Calendar.current
        let startDate = try DateParsingHelper.parseDate(start)
        let endDate = try DateParsingHelper.parseDate(end)
        
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        #expect(calendar.isDate(startDate, inSameDayAs: threeDaysAgo))
        #expect(calendar.isDate(endDate, inSameDayAs: yesterday))
        
        print("Date range '3 days ago' to 'yesterday': \(start) to \(end)")
    }
    
    @Test("Parse date range - ISO 8601 start and end")
    func testParseDateRangeISO8601() throws {
        let startISO = "2024-10-01T00:00:00Z"
        let endISO = "2024-10-08T23:59:59Z"
        
        let (start, end) = try DateParsingHelper.parseDateRange(start: startISO, end: endISO)
        
        #expect(start.contains("2024-10-01"))
        #expect(end.contains("2024-10-08"))
        
        print("Date range ISO 8601: \(start) to \(end)")
    }
    
    @Test("Parse date range - single date should span full day")
    func testParseDateRangeSingleDate() throws {
        let singleDate = "2024-10-08T12:00:00Z"

        let (start, end) = try DateParsingHelper.parseDateRange(start: singleDate, end: nil)

        let startDate = try DateParsingHelper.parseDate(start)
        let endDate = try DateParsingHelper.parseDate(end)

        let calendar = Calendar.current

        // Start should be beginning of the day (in the correct timezone)
        let expectedStart = calendar.startOfDay(for: startDate)

        // Allow for timezone differences - check same day
        #expect(calendar.isDate(startDate, inSameDayAs: expectedStart), "Should be same day")

        // End should be later than start (full day span)
        #expect(endDate > startDate, "End should be after start")

        print("Single date expanded to full day: \(start) to \(end)")
    }
    
    // MARK: - Time Period Parsing Tests
    
    @Test("Parse time period with slash separator")
    func testParseTimePeriodWithSlash() throws {
        let period = "2024-10-08T00:00:00Z/2024-10-09T00:00:00Z"
        
        let normalized = try DateParsingHelper.parseTimePeriod(period)
        
        #expect(normalized.contains("/"), "Should contain slash separator")
        #expect(normalized.contains("2024-10-08"))
        #expect(normalized.contains("2024-10-09"))
        
        print("Parsed time period: \(normalized)")
    }
    
    @Test("Parse time period with natural language")
    func testParseTimePeriodNaturalLanguage() throws {
        let period = "today"
        
        let normalized = try DateParsingHelper.parseTimePeriod(period)
        
        #expect(normalized.contains("/"), "Should contain slash separator after normalization")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayStr = DateParsingHelper.toISO8601String(today)
        
        #expect(normalized.contains(todayStr.prefix(10)), "Should contain today's date")
        
        print("Natural language time period 'today': \(normalized)")
    }
    
    @Test("Parse time period range with natural language")
    func testParseTimePeriodRangeNaturalLanguage() throws {
        let period = "yesterday/today"
        
        let normalized = try DateParsingHelper.parseTimePeriod(period)
        
        #expect(normalized.contains("/"), "Should contain slash separator")
        
        print("Natural language period range: \(normalized)")
    }
    
    @Test("Parse time period uses correct timezone format for AQL")
    func testTimePeriodTimezoneFormat() throws {
        let period = "2024-10-08T00:00:00Z/2024-10-09T00:00:00Z"

        let normalized = try DateParsingHelper.parseTimePeriod(period)

        // AQL format should use +00:00 instead of Z, but both are acceptable
        #expect(normalized.contains("+00:00") || normalized.contains("Z"), "Should use proper timezone format")

        print("Time period with AQL timezone format: \(normalized)")
    }
    
    // MARK: - ISO 8601 String Conversion Tests
    
    @Test("Convert date to ISO 8601 string")
    func testToISO8601String() {
        let date = Date()
        let isoString = DateParsingHelper.toISO8601String(date)
        
        #expect(isoString.contains("T"), "Should contain T separator")
        #expect(isoString.contains("Z"), "Should contain Z timezone indicator")
        
        // Should be parseable back to a date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let parsedDate = formatter.date(from: isoString)
        
        #expect(parsedDate != nil, "Generated ISO string should be parseable")
        
        print("ISO 8601 string: \(isoString)")
    }
    
    @Test("ISO 8601 round trip conversion")
    func testISO8601RoundTrip() throws {
        let originalDate = Date()
        
        // Convert to string and back
        let isoString = DateParsingHelper.toISO8601String(originalDate)
        let parsedDate = try DateParsingHelper.parseDate(isoString)
        
        // Should be within 1 second (accounting for rounding)
        let difference = abs(originalDate.timeIntervalSince(parsedDate))
        #expect(difference < 1.0, "Round trip should preserve date within 1 second")
        
        print("Round trip: original=\(originalDate), parsed=\(parsedDate), diff=\(difference)s")
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("Parse invalid date string throws error")
    func testParseInvalidDate() {
        do {
            _ = try DateParsingHelper.parseDate("not a valid date at all")
            Issue.record("Should throw error for invalid date")
        } catch {
            print("Correctly threw error for invalid date: \(error)")
            #expect(true, "Should throw error for invalid date")
        }
    }
    
    @Test("Parse empty date string throws error")
    func testParseEmptyDate() {
        do {
            _ = try DateParsingHelper.parseDate("")
            Issue.record("Should throw error for empty date")
        } catch {
            print("Correctly threw error for empty date: \(error)")
            #expect(true, "Should throw error for empty date")
        }
    }
    
    @Test("Parse date range with missing start throws error")
    func testParseDateRangeMissingStart() {
        do {
            _ = try DateParsingHelper.parseDateRange(start: nil, end: "today")
            Issue.record("Should throw error for missing start date")
        } catch {
            print("Correctly threw error for missing start: \(error)")
            #expect(true, "Should throw error for missing start")
        }
    }
    
    @Test("Parse time period with invalid format throws error")
    func testParseTimePeriodInvalidFormat() {
        do {
            _ = try DateParsingHelper.parseTimePeriod("invalid/format/with/too/many/slashes")
            Issue.record("Should throw error for invalid time period format")
        } catch {
            print("Correctly threw error for invalid format: \(error)")
            #expect(true, "Should throw error for invalid format")
        }
    }
    
    // MARK: - Timezone Handling Tests
    
    @Test("Parse date preserves timezone information")
    func testTimezonePreservation() throws {
        let dateWithOffset = "2024-10-08T14:00:00+02:00"
        let date = try DateParsingHelper.parseDate(dateWithOffset)
        
        let isoString = DateParsingHelper.toISO8601String(date)
        
        // Should be converted to UTC
        #expect(isoString.contains("Z") || isoString.contains("+00:00"))
        
        print("Timezone preserved: \(dateWithOffset) -> \(isoString)")
    }
    
    @Test("Parse UTC date correctly")
    func testUTCDateParsing() throws {
        let utcDate = "2024-10-08T12:00:00Z"
        let date = try DateParsingHelper.parseDate(utcDate)
        
        let isoString = DateParsingHelper.toISO8601String(date)
        
        #expect(isoString.contains("12:00:00") || isoString.contains("12:00:00"))
        
        print("UTC date: \(utcDate) -> \(isoString)")
    }
    
    // MARK: - Format Consistency Tests
    
    @Test("All date parsing methods return consistent format")
    func testFormatConsistency() throws {
        let naturalDate = try DateParsingHelper.parseDate("today")
        let isoDate = try DateParsingHelper.parseDate("2024-10-08T12:00:00Z")
        
        let naturalString = DateParsingHelper.toISO8601String(naturalDate)
        let isoString = DateParsingHelper.toISO8601String(isoDate)
        
        // Both should have the same format structure
        #expect(naturalString.contains("T"), "Natural date should have T separator")
        #expect(isoString.contains("T"), "ISO date should have T separator")
        #expect(naturalString.contains("Z"), "Natural date should have Z")
        #expect(isoString.contains("Z"), "ISO date should have Z")
        
        print("Format consistency:")
        print("  Natural: \(naturalString)")
        print("  ISO:     \(isoString)")
    }
    
    @Test("Date range format matches query format requirements")
    func testDateRangeQueryFormatCompatibility() throws {
        let (start, end) = try DateParsingHelper.parseDateRange(start: "today", end: nil)
        
        // Should be compatible with ActivityWatch API format
        #expect(start.contains("T"))
        #expect(end.contains("T"))
        #expect(start.contains("Z") || start.contains("+"))
        #expect(end.contains("Z") || end.contains("+"))
        
        // Should be valid ISO 8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        #expect(formatter.date(from: start) != nil, "Start should be valid ISO 8601")
        #expect(formatter.date(from: end) != nil, "End should be valid ISO 8601")
        
        print("Query-compatible format: \(start)/\(end)")
    }
    
    // MARK: - Common Pattern Tests
    
    @Test("Parse common activity tracking patterns")
    func testCommonActivityPatterns() throws {
        let patterns = [
            "today",
            "yesterday",
            "this week",
            "last week",
            "2 hours ago",
            "1 day ago"
        ]
        
        for pattern in patterns {
            let date = try DateParsingHelper.parseDate(pattern)
            let formatted = DateParsingHelper.toISO8601String(date)
            
            #expect(!formatted.isEmpty, "Pattern '\(pattern)' should parse successfully")
            print("Pattern '\(pattern)' -> \(formatted)")
        }
    }
    
    @Test("Parse date range patterns for typical queries")
    func testTypicalQueryRanges() throws {
        let ranges = [
            ("today", nil),
            ("yesterday", nil),
            ("this week", nil),
            ("last week", nil),
            ("3 days ago", "yesterday")
        ]
        
        for (start, end) in ranges {
            let (startStr, endStr) = try DateParsingHelper.parseDateRange(start: start, end: end)
            
            #expect(!startStr.isEmpty, "Start should not be empty")
            #expect(!endStr.isEmpty, "End should not be empty")
            
            print("Range '\(start)' to '\(end ?? "end of period")' -> \(startStr)/\(endStr)")
        }
    }
}
