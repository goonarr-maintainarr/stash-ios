import SwiftUI

/// Displays play count and last played date.
///
/// **Used by:** `SceneDetailView`
struct SceneHistoryView: View {
    let scene: Scene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let oHistory = scene.o_history, !oHistory.isEmpty {
                HistoryList(title: "O History", dates: oHistory)
            }
            
            if let playHistory = scene.play_history, !playHistory.isEmpty {
                HistoryList(title: "Play History", dates: playHistory)
            }
        }
    }
}

private struct HistoryList: View {
    let title: String
    let dates: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(dates.enumerated()), id: \.offset) { index, dateString in
                    if index > 0 { Divider() }
                    Text(SceneHistoryDateFormatters.formatHistoryDate(dateString))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.stashCardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

private struct SceneHistoryDateFormatters {
    static func formatHistoryDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try fractional seconds first
        if let date = isoFormatter.date(from: dateString) {
            return formatDate(date)
        }
        
        // Try standard ISO
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return formatDate(date)
        }
        
        return dateString
    }
    
    static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let suffix = daySuffix(for: day)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d'\(suffix)', yyyy 'at' h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }
    
    static func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
