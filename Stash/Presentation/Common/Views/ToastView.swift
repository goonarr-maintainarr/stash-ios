import SwiftUI

/// A transient toast notification view.
///
/// **Used by:**
/// - `MainTabView` (Overlay for global notifications)
struct ToastView: View {
    let message: String
    let type: ToastType
    
    enum ToastType {
        case info
        case success
        case error
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding()
        .background(type.color)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        ToastView(message: "Identify Finished", type: .success)
        ToastView(message: "Something went wrong", type: .error)
    }
}
