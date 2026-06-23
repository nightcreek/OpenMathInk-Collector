import SwiftUI

/// 存储统计信息
struct StorageStats {
    let totalSamples: Int
    let draftSamples: Int
    let confirmedSamples: Int
    let exportedSamples: Int
    let totalFiles: Int
    let storageSize: Int
}

/// 统计视图
struct StatisticsView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState
    @State private var stats: StorageStats = StorageStats(
        totalSamples: 0,
        draftSamples: 0,
        confirmedSamples: 0,
        exportedSamples: 0,
        totalFiles: 0,
        storageSize: 0
    )
    
    var body: some View {
        NavigationStack {
            List {
                Section("样本统计") {
                    StatRow(
                        title: "总样本数",
                        value: "\(stats.totalSamples)",
                        icon: "archivebox",
                        color: .blue
                    )
                    StatRow(
                        title: "草稿样本",
                        value: "\(stats.draftSamples)",
                        icon: "pencil",
                        color: .orange
                    )
                    StatRow(
                        title: "已确认样本",
                        value: "\(stats.confirmedSamples)",
                        icon: "checkmark.seal",
                        color: .green
                    )
                    StatRow(
                        title: "已导出样本",
                        value: "\(stats.exportedSamples)",
                        icon: "tray.and.arrow.up",
                        color: .purple
                    )
                }
                
                Section("存储使用") {
                    StatRow(
                        title: "文件总数",
                        value: "\(stats.totalFiles)",
                        icon: "folder",
                        color: .gray
                    )
                    StatRow(
                        title: "占用空间",
                        value: formattedSize(stats.storageSize),
                        icon: "harddrive",
                        color: .cyan
                    )
                }
                
                Section("统计详情") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressViewRow(
                            title: "草稿",
                            value: stats.totalSamples > 0 ? Double(stats.draftSamples) / Double(stats.totalSamples) : 0,
                            color: .orange
                        )
                        ProgressViewRow(
                            title: "已确认",
                            value: stats.totalSamples > 0 ? Double(stats.confirmedSamples) / Double(stats.totalSamples) : 0,
                            color: .green
                        )
                        ProgressViewRow(
                            title: "已导出",
                            value: stats.totalSamples > 0 ? Double(stats.exportedSamples) / Double(stats.totalSamples) : 0,
                            color: .purple
                        )
                    }
                }
                
                Section("操作") {
                    Button("清理孤立文件") {
                        cleanupOrphanedFiles()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("刷新统计") {
                        refreshStats()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("统计信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // 关闭视图
                    }
                }
            }
            .onAppear {
                refreshStats()
            }
        }
    }
    
    private func refreshStats() {
        stats = StorageStats(
            totalSamples: workspace.samples.count,
            draftSamples: workspace.samples.filter { $0.status == .draft }.count,
            confirmedSamples: workspace.samples.filter { $0.status == .confirmed }.count,
            exportedSamples: workspace.samples.filter { $0.status == .exported }.count,
            totalFiles: 0,
            storageSize: 0
        )
        
        Task {
            let storageUsage = await workspace.getStorageUsage()
            await MainActor.run {
                stats = StorageStats(
                    totalSamples: workspace.samples.count,
                    draftSamples: workspace.samples.filter { $0.status == .draft }.count,
                    confirmedSamples: workspace.samples.filter { $0.status == .confirmed }.count,
                    exportedSamples: workspace.samples.filter { $0.status == .exported }.count,
                    totalFiles: storageUsage.totalFiles,
                    storageSize: storageUsage.storageSize
                )
            }
        }
    }
    
    private func cleanupOrphanedFiles() {
        Task {
            do {
                try await workspace.cleanupOrphanedFiles()
                refreshStats()
                workspace.infoMessage = "清理完成"
            } catch {
                workspace.errorMessage = "清理失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func formattedSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - 统计行视图

private struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

// MARK: - 进度条行视图

private struct ProgressViewRow: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundStyle(color)
            }
            
            ProgressView(value: value)
                .progressViewStyle(.linear)
                .tint(color)
        }
    }
}

#Preview {
    StatisticsView()
}
