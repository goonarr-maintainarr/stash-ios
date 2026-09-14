import Foundation

/// Shared date formatting utilities optimized for performance
enum DateFormatters {
    
    // MARK: - Cached Formatters
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoDateOnlyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
    
    // ... (keep existing properties)


    
    private static let ymdFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    private static let parsingFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "MM-dd-yyyy",
            "MMM d, yyyy",
            "yyyy"
        ]
        return patterns.map { pattern in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = pattern
            return df
        }
    }()
    
    private static let displayMonthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()
    
    private static let displayYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df
    }()
    
    private static let mediumDateShortTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    // MARK: - Public Methods
    
    /// Formats a date string to "MMM dth, yyyy" format with ordinal suffix (e.g., "Aug 8th, 2025")
    /// Handles multiple input formats: ISO8601, yyyy-MM-dd, etc.
    static func formatDateString(_ input: String) -> String {
        guard !input.isEmpty else { return "" }
        
        // 1. Try ISO variants first
        if let date = isoFormatter.date(from: input) ?? isoDateOnlyFormatter.date(from: input) {
            return formatDate(date)
        }
        
        // 2. Try common patterns
        for formatter in parsingFormatters {
            if let date = formatter.date(from: input) {
                return formatDate(date)
            }
        }
        
        return input
    }
    
    /// Formats a Date to "MMM dth, yyyy" format with ordinal suffix (e.g., "Aug 8th, 2025")
    static func formatDate(_ date: Date) -> String {
        let monthDay = displayMonthDayFormatter.string(from: date)
        let year = displayYearFormatter.string(from: date)
        
        // Add ordinal suffix
        let day = Calendar.current.component(.day, from: date)
        let suffix = ordinalSuffix(for: day)
        
        return "\(monthDay)\(suffix), \(year)"
    }
    

    /// Formats an ISO8601 timestamp to medium date + short time (e.g., "Jan 15th, 2024 at 3:45 PM")
    static func formatTimestamp(_ isoString: String) -> String {
        guard !isoString.isEmpty else { return "" }
        
        // Try strict ISO (with fractional seconds) first, then fallback to standard ISO
        let date = isoFormatter.date(from: isoString) ?? isoFormatterNoFractional.date(from: isoString)
        
        if let date = date {
            let datePart = formatDate(date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .none
            let timeString = timeFormatter.string(from: date)
            
            return "\(datePart) at \(timeString)"
        }
        return isoString
    }
    
    /// Calculates age from birthdate string (yyyy-MM-dd)
    static func calculateAge(from birthdate: String, deathDate: String? = nil) -> Int? {
        guard let birthDate = ymdFormatter.date(from: birthdate) else {
            return nil
        }
        
        let end: Date
        if let deathDate = deathDate, let death = ymdFormatter.date(from: deathDate) {
            end = death
        } else {
            end = Date()
        }
        
        return Calendar.current.dateComponents([.year], from: birthDate, to: end).year
    }
    
    // MARK: - Helper Methods
    
    private static func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
