import SwiftUI

/// Placeholder root view until M2 builds the account store and setup flow.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
            Text("Geist6")
                .font(.largeTitle.bold())
            Text("Setup arrives with M2.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
