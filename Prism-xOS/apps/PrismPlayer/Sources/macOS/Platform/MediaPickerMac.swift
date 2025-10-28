//
//  MediaPickerMac.swift
//  PrismPlayer (macOS)
//
//  Created on 2025-10-28.
//

#if os(macOS)
    import AppKit
    import Foundation
    import UniformTypeIdentifiers
    import OSLog

    /// macOS 平台媒体选择器实现
    ///
    /// 基于 NSOpenPanel 实现文件选择
    /// 使用 async/await 包装 completion handler
    @MainActor
    final class MediaPickerMac: MediaPicker {
        private let logger = Logger(subsystem: "com.prismplayer.app", category: "MediaPicker")

        /// 选择媒体文件
        /// - Parameter allowedTypes: 允许的文件类型（UTType）
        /// - Returns: 选中的文件 URL，用户取消返回 nil
        /// - Throws: 文件访问权限错误或系统错误
        func selectMedia(allowedTypes: [UTType]) async throws -> URL? {
            logger.info("macOS 文件选择开始，允许类型: \(allowedTypes.map { $0.identifier })")

            return await withCheckedContinuation { continuation in
                let panel = createOpenPanel(allowedTypes: allowedTypes)
                logger.debug("NSOpenPanel 已配置")

                panel.begin { [weak self] response in
                    self?.handlePanelResponse(response, panel: panel, continuation: continuation)
                }
            }
        }

        // MARK: - Private Helpers

        /// 创建配置好的 NSOpenPanel
        private func createOpenPanel(allowedTypes: [UTType]) -> NSOpenPanel {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = allowedTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.canCreateDirectories = false

            // 设置提示信息
            panel.message = String(
                localized: "player.select_media_prompt",
                defaultValue: "Please select a media file to play",
                comment: "文件选择器提示信息")
            panel.prompt = String(
                localized: "player.select_media",
                defaultValue: "Select Media",
                comment: "选择按钮文本")

            return panel
        }

        /// 处理 NSOpenPanel 响应
        private func handlePanelResponse(
            _ response: NSApplication.ModalResponse,
            panel: NSOpenPanel,
            continuation: CheckedContinuation<URL?, Never>
        ) {
            switch response {
            case .OK:
                if let url = panel.url {
                    logger.info("用户选择文件: \(url.lastPathComponent)")
                    continuation.resume(returning: url)
                } else {
                    logger.warning("用户点击 OK，但 URL 为空")
                    continuation.resume(returning: nil)
                }

            case .cancel:
                logger.debug("用户取消选择文件")
                continuation.resume(returning: nil)

            default:
                logger.warning("NSOpenPanel 返回未知响应: \(response.rawValue)")
                continuation.resume(returning: nil)
            }
        }
    }
#endif
