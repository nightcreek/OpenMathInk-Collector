import SwiftUI

struct DatasetFileBrowserView: View {
    @EnvironmentObject private var workspace: CollectorWorkspaceState
    @State private var showPrivacyNotice = false
    @State private var filterSelection: String = "all"
    @State private var searchText: String = ""
    @State private var showDeleteAlert = false
    @State private var showBatchDeleteAlert = false
    @State private var sampleToDelete: MathInkSample?
    
    // 批量操作状态
    @State private var isMultiSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    
    let onClose: (() -> Void)?
    
    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    private var draftCount: Int {
        workspace.samples.filter { $0.status == .draft }.count
    }
    
    private var confirmedCount: Int {
        workspace.samples.filter { $0.status == .confirmed }.count
    }
    
    private var exportedCount: Int {
        workspace.samples.filter { $0.status == .exported }.count
    }
    
    private var filterOptions: [(id: String, title: String, status: SampleStatus?)] {
        [
            ("all", "全部", nil),
            (SampleStatus.draft.rawValue, "草稿", .draft),
            (SampleStatus.confirmed.rawValue, "已确认", .confirmed),
            (SampleStatus.exported.rawValue, "已导出", .exported)
        ]
    }
    
    /// 搜索过滤后的样本列表
    private var searchFilteredSamples: [MathInkSample] {
        let filtered = workspace.filteredSamples
        
        guard !searchText.isEmpty else {
            return filtered
        }
        
        let query = searchText.lowercased()
        return filtered.filter { sample in
            sample.latex.lowercased().contains(query) ||
            sample.sourceText.lowercased().contains(query) ||
            sample.id.uuidString.lowercased().contains(query)
        }
    }
    
    /// 选中的样本
    private var selectedSamples: [MathInkSample] {
        searchFilteredSamples.filter { selectedIDs.contains($0.id) }
    }
    
    /// 选中的已确认样本（可导出）
    private var selectedConfirmedSamples: [MathInkSample] {
        selectedSamples.filter { $0.status == .confirmed }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(max(proxy.size.width * 0.82, 860), 1200)
            
            VStack(alignment: .leading, spacing: 14) {
                header
                
                // 批量操作栏
                if isMultiSelectMode {
                    batchOperationsBar
                } else {
                    actionGroups
                }
                
                contentArea
                footer
            }
            .padding(20)
            .frame(width: panelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(.ultraThinMaterial)
        .alert("删除样本", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                sampleToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let sample = sampleToDelete {
                    workspace.deleteSample(id: sample.id)
                }
                sampleToDelete = nil
            }
        } message: {
            if let sample = sampleToDelete {
                Text("确定要删除样本 \"\(sample.latex.isEmpty ? "未命名" : sample.latex)\" 吗？此操作无法撤销。")
            }
        }
        .alert("批量删除", isPresented: $showBatchDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                performBatchDelete()
            }
        } message: {
            Text("确定要删除选中的 \(selectedIDs.count) 个样本吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showPrivacyNotice) {
            EnhancedPrivacyNoticeView()
        }
        .onAppear {
            syncFilterSelectionFromState()
        }
    }
    
    // MARK: - 批量操作栏
    
    private var batchOperationsBar: some View {
        HStack(spacing: 12) {
            GroupBox("批量操作") {
                HStack(spacing: 8) {
                    Button("取消选择") {
                        exitMultiSelectMode()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("全选") {
                        selectAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("删除选中", role: .destructive) {
                        showBatchDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedIDs.isEmpty)
                    
                    Button("导出选中") {
                        if !selectedConfirmedSamples.isEmpty {
                            workspace.exportSamples(samples: selectedConfirmedSamples)
                            exitMultiSelectMode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedConfirmedSamples.isEmpty)
                }
            }
            
            Text("已选中 \(selectedIDs.count) 个样本")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            GroupBox("查看操作") {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        TextField("搜索...", text: $searchText)
                            .font(.caption)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Picker("筛选", selection: $filterSelection) {
                        ForEach(filterOptions, id: \.id) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: filterSelection) { _, newValue in
                        workspace.filter = filterOptions.first(where: { $0.id == newValue })?.status ?? nil
                    }
                }
            }
        }
    }
    
    // MARK: - 批量操作方法
    
    private func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedIDs = []
    }
    
    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedIDs = []
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            if selectedIDs.isEmpty {
                exitMultiSelectMode()
            }
        } else {
            if !isMultiSelectMode {
                enterMultiSelectMode()
            }
            selectedIDs.insert(id)
        }
    }
    
    private func selectAll() {
        selectedIDs = Set(searchFilteredSamples.map { $0.id })
    }
    
    private func performBatchDelete() {
        for id in selectedIDs {
            workspace.deleteSample(id: id)
        }
        exitMultiSelectMode()
    }
    
    // MARK: - 原有视图
    
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("样本文件")
                    .font(.title2.bold())
                Text("管理已采集的手写公式样本")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    enterMultiSelectMode()
                } label: {
                    Label("多选", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
                
                Button {
                    onClose?()
                } label: {
                    Label("关闭", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var actionGroups: some View {
        HStack(spacing: 12) {
            GroupBox("采集操作") {
                HStack {
                    Button("新建样本") { workspace.createNewSample() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GroupBox("导出操作") {
                HStack(spacing: 8) {
                    Button("导出数据包") { workspace.exportConfirmedSamples() }
                    Button("隐私说明") { showPrivacyNotice = true }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GroupBox("查看操作") {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        TextField("搜索 LaTeX、源文本...", text: $searchText)
                            .font(.caption)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Picker("筛选", selection: $filterSelection) {
                        ForEach(filterOptions, id: \.id) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: filterSelection) { _, newValue in
                        workspace.filter = filterOptions.first(where: { $0.id == newValue })?.status ?? nil
                    }
                }
            }
        }
        .labelStyle(.titleAndIcon)
    }
    
    private var contentArea: some View {
        HStack(spacing: 14) {
            listColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("样本列表")
                .font(.headline)
            
            List(selection: Binding(
                get: { workspace.selectedSampleID },
                set: { newValue in
                    guard let newValue else { return }
                    if isMultiSelectMode {
                        toggleSelection(newValue)
                    } else {
                        workspace.selectSample(id: newValue)
                    }
                }
            )) {
                ForEach(searchFilteredSamples) { sample in
                    HStack(spacing: 8) {
                        if isMultiSelectMode {
                            Image(systemName: selectedIDs.contains(sample.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(sample.id) ? .blue : .secondary)
                                .onTapGesture {
                                    toggleSelection(sample.id)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.latex.isEmpty ? "未填写公式标签" : sample.latex)
                                .lineLimit(1)
                            Text("\(sample.status.displayName) · \(sample.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(sample.id)
                }
                if searchFilteredSamples.isEmpty {
                    Text("没有找到匹配的样本")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(.plain)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("样本详情")
                .font(.headline)
            
            if let selected = workspace.selectedSample {
                SampleDetailView(sample: selected, imageURL: workspace.imageURL(for: selected))
                
                HStack(spacing: 8) {
                    Button("选择该样本") {
                        workspace.selectSample(id: selected.id)
                        onClose?()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("删除样本", role: .destructive) {
                        sampleToDelete = selected
                        showDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(
                        Text("请选择一个样本")
                            .foregroundStyle(.secondary)
                    )
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var footer: some View {
        HStack(spacing: 14) {
            footerBadge(title: "总样本", value: workspace.samples.count)
            footerBadge(title: "已确认", value: confirmedCount)
            footerBadge(title: "可导出", value: confirmedCount)
            footerBadge(title: "草稿", value: draftCount)
            footerBadge(title: "已导出", value: exportedCount)
            Spacer()
        }
    }
    
    private func footerBadge(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func syncFilterSelectionFromState() {
        if let filter = workspace.filter {
            filterSelection = filter.rawValue
        } else {
            filterSelection = "all"
        }
    }
}
