//
//  MediaPickeriOS.swift
//  PrismPlayer (iOS)
//
//  Created on 2025-10-28.
//

#if os(iOS)
import Foundation
import UniformTypeIdentifiers
import OSLog

/// iOS 平台媒体选择器实现（占位）
///
/// 当前状态：占位实现，返回 nil
/// Sprint 1 目标：编译通过，不崩溃
/// Sprint 2 计划：基于 UIDocumentPickerViewController 完整实现
final class MediaPickeriOS: MediaPicker {
    private let logger = Logger(subsystem: "com.prismplayer.app", category: "MediaPicker")

    /// 选择媒体文件（占位实现）
    /// - Parameter allowedTypes: 允许的文件类型
    /// - Returns: 当前返回 nil（占位）
    func selectMedia(allowedTypes: [UTType]) async throws -> URL? {
        logger.info("iOS 文件选择功能占位调用")

        // TODO: Sprint 1 PR3 实现 UIDocumentPickerViewController
        // let picker = UIDocumentPickerViewController(
        //     forOpeningContentTypes: allowedTypes,
        //     asCopy: true
        // )
        // picker.allowsMultipleSelection = false
        // ...

        return nil  // 占位返回，不触发后续加载
    }
}
#endif
