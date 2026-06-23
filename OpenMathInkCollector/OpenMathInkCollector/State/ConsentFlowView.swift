import SwiftUI

/// 贡献者同意书收集视图
struct ConsentFlowView: View {
    @EnvironmentObject var consentManager: ContributorConsentManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    
                    Divider()
                    
                    agreementSection
                    
                    Divider()
                    
                    summarySection
                }
                .padding(24)
            }
            .navigationTitle("数据贡献同意")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        consentManager.cancelConsent()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("同意并继续") {
                        consentManager.submitConsent()
                    }
                    .fontWeight(.semibold)
                    .disabled(!consentManager.allAgreementsAccepted)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("感谢您愿意贡献数据")
                .font(.title2.bold())
            
            Text("OpenMathInk Collector 用于收集数学手写样本，用于开源数学识别模型的研究与开发。在贡献数据之前，请您仔细阅读以下条款。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var agreementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("同意条款")
                .font(.headline)
            
            agreementToggle(
                title: "自愿贡献",
                description: "我确认是自愿贡献这些数据，没有受到任何胁迫或不当影响。",
                isOn: $consentManager.voluntaryContribution,
                icon: "heart.fill"
            )
            
            agreementToggle(
                title: "开源数据集分享",
                description: "我同意将贡献的数据可能被用于开源数学识别数据集，分享给研究社区。",
                isOn: $consentManager.allowsOpenSourceSharing,
                icon: "globe"
            )
            
            agreementToggle(
                title: "无自动上传",
                description: "我了解 App 不会自动上传任何数据，所有数据都存储在本地，只有我主动操作才会生成导出包。",
                isOn: $consentManager.acknowledgesNoAutoUpload,
                icon: "icloud.slash"
            )
        }
    }
    
    private func agreementToggle(title: String, description: String, isOn: Binding<Bool>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Toggle("", isOn: isOn)
                    .labelsHidden()
            }
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOn.wrappedValue ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOn.wrappedValue ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: consentManager.allAgreementsAccepted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(consentManager.allAgreementsAccepted ? .green : .orange)
                Text(consentManager.allAgreementsAccepted ? "已满足所有条件" : "请勾选所有条款")
                    .font(.subheadline.weight(.medium))
            }
            
            Text("您的同意是可选的，您随时可以在设置中撤回同意或删除已贡献的数据。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 隐私说明增强视图
struct EnhancedPrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("数据收集") {
                    LabeledContent("收集内容", value: "数学手写样本、公式文本标签")
                    LabeledContent("数据用途", value: "开源数学识别模型训练")
                    LabeledContent("数据存储", value: "仅本地存储，无云端同步")
                }
                
                Section("您的权利") {
                    Text("您有权随时撤回同意、删除本地数据或拒绝贡献。撤回同意不影响已导出的数据。")
                }
                
                Section("App 行为") {
                    LabeledContent("自动上传", value: "否 - 所有操作需用户主动触发")
                    LabeledContent("第三方传输", value: "仅在用户主动导出时发生")
                    LabeledContent("数据加密", value: "本地存储无加密，建议避免敏感内容")
                }
                
                Section("建议") {
                    Text("请避免在公式中包含个人身份信息，如姓名、电话、地址等。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("隐私说明")
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

#Preview {
    ConsentFlowView()
        .environmentObject(ContributorConsentManager.shared)
}
