import SwiftUI

@main
struct PrismPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerView()
        }
        .defaultSize(width: 1_024, height: 768)
    }
}
