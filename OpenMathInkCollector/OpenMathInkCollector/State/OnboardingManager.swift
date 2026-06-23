import SwiftUI

/// 引导页面数据模型
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

/// 引导流程视图
struct OnboardingView: View {
    @EnvironmentObject private var consentManager: ContributorConsentManager
    @Binding var isPresented: Bool
    
    @State private var currentPage = 0
    @State private var showConsent = false
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "applepencil.tip",
            title: "手写公式采集",
            description: "使用 Apple Pencil 或触控笔直接书写数学公式，保持清晰整洁。"
        ),
        OnboardingPage(
            icon: "keyboard",
            title: "结构化公式标签",
            description: "通过虚拟键盘录入对应的 LaTeX 公式，确保数据标注准确。"
        ),
        OnboardingPage(
            icon: "checkmark.seal",
            title: "确认与导出",
            description: "确认样本后导出为数据集，用于数学识别模型训练。"
        ),
        OnboardingPage(
            icon: "lock",
            title: "隐私保护",
            description: "所有数据仅存储在本地，不会自动上传，您完全掌控数据。"
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 进度指示器
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 32)
                
                // 内容区域
                VStack(spacing: 20) {
                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                        .padding(24)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(pages[currentPage].title)
                        .font(.title2.bold())
                    
                    Text(pages[currentPage].description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 32)
                
                // 操作按钮
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button("上一步") {
                            currentPage -= 1
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button("下一步") {
                            currentPage += 1
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("开始使用") {
                            showConsent = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("欢迎使用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") {
                        completeOnboarding()
                    }
                }
            }
            .sheet(isPresented: $showConsent) {
                ConsentFlowView()
                    .environmentObject(consentManager)
                    .onDisappear {
                        if consentManager.hasValidConsent {
                            completeOnboarding()
                        }
                    }
            }
        }
    }
    
    private func completeOnboarding() {
        consentManager.completeOnboarding()
        isPresented = false
    }
}

/// 引导流程管理器
@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var shouldShowOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(!shouldShowOnboarding, forKey: "onboarding_completed")
        }
    }
    
    private init() {
        self.shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_completed")
    }
    
    func showOnboarding() {
        shouldShowOnboarding = true
    }
    
    func dismissOnboarding() {
        shouldShowOnboarding = false
    }
    
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboarding_completed")
        shouldShowOnboarding = true
    }
}
