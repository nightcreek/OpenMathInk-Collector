import SwiftUI

struct AppRootView: View {
    @StateObject private var workspace = CollectorWorkspaceState()
    @EnvironmentObject private var consentManager: ContributorConsentManager
    @State private var showFilesPanel = false
    @State private var showDeleteAlert = false
    @State private var showSettings = false
    @State private var sampleToDelete: MathInkSample?
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                
                GeometryReader { proxy in
                    mainContent(for: proxy)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
            }
            .environmentObject(workspace)
            .overlay(alignment: .bottom) {
                bottomOverlay
            }
            .overlay {
                if workspace.isExporting {
                    exportProgressOverlay
                }
            }
            .alert("错误", isPresented: errorPresentedBinding) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(workspace.errorMessage ?? "未知错误")
            }
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
            .sheet(item: exportItemBinding) { item in
                ExportResultView(url: item.url)
            }
            .sheet(isPresented: $showFilesPanel) {
                DatasetFileBrowserView(onClose: { showFilesPanel = false })
                    .environmentObject(workspace)
                    .presentationDetents([.fraction(0.78), .fraction(0.88)])
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $consentManager.showConsentSheet) {
                ConsentFlowView()
                    .environmentObject(consentManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(workspace)
                    .environmentObject(consentManager)
            }
            // 键盘快捷键
            .onCommand("z") { workspace.undo() }
            .onCommand("Z") { workspace.redo() }
            .onCommand("s") { workspace.saveCurrentDraft() }
            .onCommand("n") { workspace.createNewSample() }
            .onCommand("e") { workspace.confirmCurrentSample() }
            .onCommand("E") { workspace.exportConfirmedSamples() }
        }
    }
    
    // MARK: - 导出进度覆盖层
    
    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在导出")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(workspace.exportStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView(value: workspace.exportProgress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .frame(width: 200)
                
                Text("\(Int(workspace.exportProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - 底部信息覆盖层
    
    private var bottomOverlay: some View {
        VStack(spacing: 8) {
            if let info = workspace.infoMessage {
                Text(info)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
            }
            
            // 撤销/重做快捷操作
            HStack(spacing: 12) {
                Button {
                    workspace.undo()
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(!workspace.canUndo)
                
                Button {
                    workspace.redo()
                } label: {
                    Label("重做", systemImage: "arrow.uturn.forward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(!workspace.canRedo)
            }
            .padding(.bottom, 8)
        }
    }
    
    private func mainContent(for proxy: GeometryProxy) -> some View {
        let width = proxy.size.width
        let topBarHeight: CGFloat = width < 980 ? 92 : 64
        let verticalSpacing: CGFloat = 18
        let contentHeight = max(320, proxy.size.height - topBarHeight - verticalSpacing - 24)
        let isCompact = width < 760
        let leftRatio: CGFloat = width >= 1120 ? 0.60 : 0.56
        
        return VStack(alignment: .leading, spacing: 16) {
            headerBar
                .frame(height: topBarHeight)
            
            if isCompact {
                compactLayout
            } else {
                regularLayout(width: width, contentHeight: contentHeight, leftRatio: leftRatio)
            }
        }
    }
    
    private var compactLayout: some View {
        VStack(spacing: 12) {
            HandwritingCanvasView()
                .frame(maxHeight: .infinity)
            
            GeometryReader { rightProxy in
                let availableHeight = rightProxy.size.height
                let spacing: CGFloat = 12
                let previewHeight = min(max(availableHeight * 0.28, 140), 180)
                let keyboardHeight = max(220, availableHeight - previewHeight - spacing)
                
                VStack(spacing: spacing) {
                    LatexPreviewView()
                        .frame(height: previewHeight)
                    LatexKeyboardInputView()
                        .frame(height: keyboardHeight)
                }
            }
        }
    }
    
    private func regularLayout(width: CGFloat, contentHeight: CGFloat, leftRatio: CGFloat) -> some View {
        let previewHeight = min(max(contentHeight * 0.30, 190), 250)
        let keyboardHeight = min(360, max(320, contentHeight * 0.43))
        
        return HStack(spacing: 18) {
            HandwritingCanvasView()
                .frame(width: max(420, width * leftRatio), height: contentHeight)
            
            VStack(spacing: 14) {
                LatexPreviewView()
                    .frame(height: previewHeight)
                Spacer(minLength: 12)
                LatexKeyboardInputView()
                    .frame(height: keyboardHeight)
            }
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight, alignment: .top)
        }
    }
    
    private var headerBar: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenMathInk Collector")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("本地采集数学手写样本与结构化公式标签")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    topBarLeadingActions
                    topBarPrimaryActions
                }
                VStack(alignment: .trailing, spacing: 8) {
                    topBarPrimaryActions
                    topBarLeadingActions
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var topBarLeadingActions: some View {
        HStack(spacing: 8) {
            Button {
                showFilesPanel = true
            } label: {
                Label("样本文件", systemImage: "sidebar.left")
            }
            .buttonStyle(.bordered)
            
            if let sample = workspace.selectedSample {
                Label(sample.status.displayName, systemImage: sample.status.icon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(sample.status.color.opacity(0.18))
                    .foregroundStyle(sample.status.color)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var topBarPrimaryActions: some View {
        HStack(spacing: 8) {
            Button {
                workspace.saveCurrentDraft()
            } label: {
                Label("保存草稿", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            
            Button {
                workspace.confirmCurrentSample()
            } label: {
                Label("确认样本", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            
            if let selected = workspace.selectedSample {
                Button(role: .destructive) {
                    sampleToDelete = selected
                    showDeleteAlert = true
                } label: {
                    Label("删除样本", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            
            // 同意书按钮
            if !consentManager.hasValidConsent {
                Button {
                    consentManager.requestConsent()
                } label: {
                    Label("同意条款", systemImage: "hand.raised")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            
            // 设置
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gear")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { workspace.errorMessage != nil },
            set: { isPresented in
                if !isPresented { workspace.errorMessage = nil }
            }
        )
    }
    
    private var exportItemBinding: Binding<ExportPackageSheetItem?> {
        Binding(
            get: { workspace.exportedPackageURL.map { ExportPackageSheetItem(url: $0) } },
            set: { newValue in
                workspace.exportedPackageURL = newValue?.url
            }
        )
    }
    
    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.08),
                Color(red: 0.03, green: 0.04, blue: 0.06),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: 60, y: -60)
        }
    }
}

private struct ExportPackageSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ExportResultView: View {
    let url: URL
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("导出完成")
                    .font(.title3).bold()
                Text(url.lastPathComponent)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                ShareLink(item: url) {
                    Label("分享导出文件夹", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                
                Text("数据已导出到文件夹，可使用分享功能发送。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .navigationTitle("数据导出")
        }
    }
}
