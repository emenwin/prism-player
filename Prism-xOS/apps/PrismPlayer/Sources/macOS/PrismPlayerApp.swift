import SwiftUI

/// macOS 主应用入口
@main
struct PrismPlayerApp: App {
    /// 应用视图模型，管理场景切换
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentRootView(viewModel: appViewModel)
        }
        .defaultSize(width: 1_024, height: 768)
        .commands {
            // 添加文件菜单命令
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "welcome.actions.open_file")) {
                    appViewModel.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button(String(localized: "welcome.actions.open_url")) {
                    appViewModel.openURL()
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
}

/// 根视图，根据场景状态切换显示内容
struct ContentRootView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Group {
            switch viewModel.currentScene {
            case .welcome:
                WelcomeView(viewModel: viewModel)
                
            case .player(let url):
                PlayerSceneView(url: url)
            }
        }
        .alert(
            String(localized: "player.error.title"),
            isPresented: .constant(viewModel.errorMessage != nil),
            presenting: viewModel.errorMessage
        ) { _ in
            Button(String(localized: "player.error.dismiss")) {
                viewModel.errorMessage = nil
            }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}
