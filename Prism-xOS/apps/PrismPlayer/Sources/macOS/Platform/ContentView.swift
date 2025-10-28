import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityLabel(String(localized: "app.icon.player"))

            Text(String(localized: "app.name"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "app.welcome"))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ContentView()
}
