//
//  MediaPickeriOS.swift
//  PrismPlayer (iOS)
//
//  Created on 2025-10-28.
//

#if os(iOS)
    import Foundation
    import SwiftUI
    import UniformTypeIdentifiers
    import OSLog

    /// iOS 平台媒体选择器实现
    ///
    /// 基于 UIDocumentPickerViewController 实现文件选择
    /// 使用 UIViewControllerRepresentable 桥接到 SwiftUI
    @MainActor
    final class MediaPickeriOS: MediaPicker {
        private let logger = Logger(subsystem: "com.prismplayer.app", category: "MediaPicker")

        /// 选择媒体文件
        /// - Parameter allowedTypes: 允许的文件类型（UTType）
        /// - Returns: 选中的文件 URL，用户取消返回 nil
        /// - Throws: 文件访问权限错误或系统错误
        func selectMedia(allowedTypes: [UTType]) async throws -> URL? {
            logger.info("iOS 文件选择开始，允许类型: \(allowedTypes.map { $0.identifier })")

            // 使用 continuation 将 callback-based API 转换为 async/await
            return await withCheckedContinuation { continuation in
                // 获取当前的 window scene
                guard
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                    let rootViewController = windowScene.windows.first?.rootViewController
                else {
                    logger.error("无法获取 rootViewController")
                    continuation.resume(returning: nil)
                    return
                }

                // 创建 UIDocumentPickerViewController
                let picker = UIDocumentPickerViewController(
                    forOpeningContentTypes: allowedTypes,
                    asCopy: true  // 复制到应用沙盒，避免权限问题
                )
                picker.allowsMultipleSelection = false

                // 创建 Coordinator 处理回调
                let coordinator = DocumentPickerCoordinator(
                    continuation: continuation,
                    logger: logger
                )
                picker.delegate = coordinator

                // 保持 coordinator 引用，防止被释放
                objc_setAssociatedObject(
                    picker,
                    &AssociatedKeys.coordinator,
                    coordinator,
                    .OBJC_ASSOCIATION_RETAIN
                )

                // 显示文件选择器
                rootViewController.present(picker, animated: true)

                logger.debug("UIDocumentPickerViewController 已显示")
            }
        }
    }

    // MARK: - Document Picker Coordinator

    /// UIDocumentPickerDelegate 协调器
    ///
    /// 职责：
    /// - 处理文件选择结果
    /// - 处理用户取消操作
    /// - 管理 async/await continuation
    private final class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
        private let continuation: CheckedContinuation<URL?, Never>
        private let logger: Logger
        private var hasResumed = false

        init(
            continuation: CheckedContinuation<URL?, Never>,
            logger: Logger
        ) {
            self.continuation = continuation
            self.logger = logger
            super.init()
        }

        // MARK: - UIDocumentPickerDelegate

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            guard !hasResumed else {
                logger.warning("documentPicker 重复调用，已忽略")
                return
            }

            hasResumed = true

            guard let url = urls.first else {
                logger.warning("用户选择了文件，但 URL 数组为空")
                continuation.resume(returning: nil)
                return
            }

            logger.info("用户选择文件: \(url.lastPathComponent)")
            continuation.resume(returning: url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !hasResumed else {
                logger.warning("documentPickerWasCancelled 重复调用，已忽略")
                return
            }

            hasResumed = true
            logger.debug("用户取消选择文件")
            continuation.resume(returning: nil)
        }
    }

    // MARK: - Associated Object Keys

    private enum AssociatedKeys {
        static var coordinator: UInt8 = 0
    }

#endif
