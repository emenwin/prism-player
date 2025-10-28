import SwiftUI

@main
struct PrismPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerIntegrationDemoView()
        }
        .defaultSize(width: 1_024, height: 768)
    }
}
