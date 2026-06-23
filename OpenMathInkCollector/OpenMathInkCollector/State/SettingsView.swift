import SwiftUI

/// 设置视图
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspace: CollectorWorkspaceState
    @EnvironmentObject private var consentManager: ContributorConsentManager
    
    @State private var showClearCacheAlert = false
    @State private var showResetDataAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var showPrivacyNotice = false
    @State private var showLicenseInfo = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("数据管理") {
                    Button {
                        showClearCacheAlert = true
                    } label: {
                        SettingsRow(
                            title: "清除缓存",
                            description: "清理临时文件和孤立文件",
                            icon: "trash",
                            role: .destructive
                        )
                    }
                    
                    Button {
                        showResetDataAlert = true
                    } label: {
                        SettingsRow(
                            title: "重置所有数据",
                            description: "删除所有样本和相关文件",
                            icon: "eraser",
                            role: .destructive
                        )
                    }
                }
                
                Section("隐私与同意") {
                    Button {
                        consentManager.requestConsent()
                    } label: {
                        SettingsRow(
                            title: "数据贡献同意",
                            description: consentManager.hasValidConsent ? "已同意" : "未同意",
                            icon: "hand.raised",
                            color: consentManager.hasValidConsent ? .green : .orange
                        )
                    }
                    
                    Button {
                        showPrivacyNotice = true
                    } label: {
                        SettingsRow(
                            title: "隐私说明",
                            description: "了解数据收集和使用政策",
                            icon: "lock"
                        )
                    }
                }
                
                Section("应用") {
                    Button {
                        showResetOnboardingAlert = true
                    } label: {
                        SettingsRow(
                            title: "重置引导流程",
                            description: "下次启动时重新显示引导",
                            icon: "info.circle"
                        )
                    }
                    
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        SettingsRow(
                            title: "统计信息",
                            description: "查看样本数量和存储使用",
                            icon: "chart.bar"
                        )
                    }
                }
                
                Section("关于") {
                    SettingsRow(
                        title: "版本",
                        description: "1.0.0",
                        icon: "info",
                        isAction: false
                    )
                    
                    SettingsRow(
                        title: "开发者",
                        description: "eMathica Team",
                        icon: "person",
                        isAction: false
                    )
                    
                    Button {
                        showLicenseInfo = true
                    } label: {
                        SettingsRow(
                            title: "开源许可证",
                            description: "MIT License",
                            icon: "scroll"
                        )
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("清除缓存", isPresented: $showClearCacheAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("确定要清除缓存吗？这将删除临时文件和孤立文件，但不会影响已保存的样本。")
            }
            .alert("重置数据", isPresented: $showResetDataAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("确定要重置所有数据吗？这将删除所有样本和相关文件，此操作无法撤销！")
            }
            .alert("重置引导", isPresented: $showResetOnboardingAlert) {
                Button("取消", role: .cancel) {}
                Button("重置") {
                    resetOnboarding()
                }
            } message: {
                Text("确定要重置引导流程吗？下次启动时将重新显示引导页面。")
            }
            .sheet(isPresented: $showPrivacyNotice) {
                NavigationStack {
                    PrivacyNoticeView()
                        .navigationTitle("隐私说明")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    showPrivacyNotice = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showLicenseInfo) {
                NavigationStack {
                    LicenseInfoView()
                        .navigationTitle("开源许可证")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    showLicenseInfo = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func clearCache() {
        Task {
            do {
                try await workspace.cleanupOrphanedFiles()
                workspace.infoMessage = "缓存已清除"
            } catch {
                workspace.errorMessage = "清除失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func resetAllData() {
        let sampleIDs = workspace.samples.map(\.id)
        for id in sampleIDs {
            workspace.deleteSample(id: id)
        }
        
        consentManager.clearConsent()
        OnboardingManager.shared.resetOnboarding()
        workspace.infoMessage = "所有数据已重置"
    }
    
    private func resetOnboarding() {
        OnboardingManager.shared.resetOnboarding()
        workspace.infoMessage = "引导流程已重置"
    }
}

// MARK: - 许可证信息视图

private struct LicenseInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MIT License")
                    .font(.title2.bold())
                
                Text("Copyright (c) 2025 eMathica")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("""
Permission is hereby granted, free of charge, to any person obtaining a copy \
of this software and associated documentation files (the "Software"), to deal \
in the Software without restriction, including without limitation the rights \
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
copies of the Software, and to permit persons to whom the Software is \
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all \
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
SOFTWARE.
""")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

// MARK: - 设置行视图

private struct SettingsRow: View {
    let title: String
    let description: String
    let icon: String
    let role: ButtonRole?
    let color: Color
    let isAction: Bool
    
    init(
        title: String,
        description: String,
        icon: String,
        role: ButtonRole? = nil,
        color: Color = .primary,
        isAction: Bool = true
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.role = role
        self.color = color
        self.isAction = isAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isAction {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
