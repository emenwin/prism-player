import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityLabel("app.icon.player")

            Text("app.name")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("app.welcome")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
