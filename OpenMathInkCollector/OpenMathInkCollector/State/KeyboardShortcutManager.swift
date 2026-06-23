import Foundation
import SwiftUI

/// 键盘快捷键映射
struct KeyboardShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void
    
    init(key: KeyEquivalent, modifiers: EventModifiers = [], action: @escaping () -> Void) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
}

/// 键盘快捷键管理器
@MainActor
final class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    @Published private(set) var activeShortcuts: [KeyboardShortcut] = []
    
    private init() {
        registerDefaultShortcuts()
    }
    
    private func registerDefaultShortcuts() {
        activeShortcuts = [
            // 撤销
            KeyboardShortcut(key: "z", modifiers: [.command]) {
                guard let workspace = appWorkspace() else { return }
                workspace.undo()
            },
            
            // 重做
            KeyboardShortcut(key: "z", modifiers: [.command, .shift]) {
                guard let workspace = appWorkspace() else { return }
                workspace.redo()
            },
            
            // 保存草稿
            KeyboardShortcut(key: "s", modifiers: [.command]) {
                guard let workspace = appWorkspace() else { return }
                workspace.saveCurrentDraft()
            },
            
            // 新建样本
            KeyboardShortcut(key: "n", modifiers: [.command]) {
                guard let workspace = appWorkspace() else { return }
                workspace.createNewSample()
            },
            
            // 确认样本
            KeyboardShortcut(key: "e", modifiers: [.command]) {
                guard let workspace = appWorkspace() else { return }
                workspace.confirmCurrentSample()
            },
            
            // 导出
            KeyboardShortcut(key: "e", modifiers: [.command, .shift]) {
                guard let workspace = appWorkspace() else { return }
                workspace.exportConfirmedSamples()
            },
            
            // 删除当前样本
            KeyboardShortcut(key: KeyEquivalent.delete, modifiers: [.command]) {
                guard let workspace = appWorkspace(), let sample = workspace.selectedSample else { return }
                workspace.requestDeleteSample(id: sample.id)
            },
            
            // 清空画布
            KeyboardShortcut(key: KeyEquivalent.delete, modifiers: [.command, .shift]) {
                guard let workspace = appWorkspace() else { return }
                workspace.clearCurrentDrawing()
            },
            
            // 清空公式输入
            KeyboardShortcut(key: "x", modifiers: [.command, .shift]) {
                guard let workspace = appWorkspace() else { return }
                workspace.clearFormulaInput()
            }
        ]
    }
    
    /// 获取快捷键列表（用于显示）
    var shortcutList: [ShortcutDisplayItem] {
        return [
            ("撤销", "Cmd+Z"),
            ("重做", "Cmd+Shift+Z"),
            ("保存", "Cmd+S"),
            ("新建", "Cmd+N"),
            ("确认", "Cmd+E"),
            ("导出", "Cmd+Shift+E"),
            ("删除", "Cmd+Delete"),
            ("清空画布", "Cmd+Shift+Delete"),
            ("清空公式", "Cmd+Shift+X")
        ].map { ShortcutDisplayItem(action: $0.0, keys: $1) }
    }
    
    /// 执行快捷键
    func executeShortcut(_ key: KeyEquivalent, modifiers: EventModifiers) {
        for shortcut in activeShortcuts {
            if shortcut.key == key && shortcut.modifiers == modifiers {
                shortcut.action()
                return
            }
        }
    }
    
    private func appWorkspace() -> CollectorWorkspaceState? {
        return nil
    }
}

/// 快捷键显示项
struct ShortcutDisplayItem {
    let action: String
    let keys: String
}

/// SwiftUI 视图扩展，添加键盘快捷键支持
extension View {
    func keyboardShortcuts() -> some View {
        self
            .onCommand("z") {
                KeyboardShortcutManager.shared.executeShortcut("z", modifiers: [.command])
            }
            .onCommand("Z") {
                KeyboardShortcutManager.shared.executeShortcut("z", modifiers: [.command, .shift])
            }
            .onCommand("s") {
                KeyboardShortcutManager.shared.executeShortcut("s", modifiers: [.command])
            }
            .onCommand("n") {
                KeyboardShortcutManager.shared.executeShortcut("n", modifiers: [.command])
            }
            .onCommand("e") {
                KeyboardShortcutManager.shared.executeShortcut("e", modifiers: [.command])
            }
            .onCommand("E") {
                KeyboardShortcutManager.shared.executeShortcut("e", modifiers: [.command, .shift])
            }
            .onCommand(KeyEquivalent.delete) {
                KeyboardShortcutManager.shared.executeShortcut(KeyEquivalent.delete, modifiers: [.command])
            }
    }
}

/// 快捷键提示视图
struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(KeyboardShortcutManager.shared.shortcutList, id: \.action) { item in
                HStack {
                    Text(item.action)
                    Spacer()
                    Text(item.keys)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("键盘快捷键")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
