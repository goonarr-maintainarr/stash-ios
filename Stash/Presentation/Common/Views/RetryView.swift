import SwiftUI

/// A generic loading retry view for failed states.
///
/// **Used by:**
/// - `GenericListStateView`
/// - Network error screens
struct RetryView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stashBackground)
    }
}

struct RetryView_Previews: PreviewProvider {
    static var previews: some View {
        RetryView(message: "Failed to connect to server", retryAction: {})
            .preferredColorScheme(.dark)
    }
}
