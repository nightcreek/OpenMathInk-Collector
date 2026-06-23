import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("1. 本 App 用于自愿采集数学手写样本。")
                Text("2. App 不会自动上传任何数据。")
                Text("3. 所有样本默认保存在本地。")
                Text("4. 用户只有在主动点击导出后，才会生成数据包。")
                Text("5. 导出的数据包可能被用户自行分享到开源数据集项目。")
                Text("6. 不建议用户在公式中写入个人身份信息。")
                Text("7. eMathica 本体不会通过这个 App 自动收集用户笔记或公式。")
            }
            .navigationTitle("隐私说明")
        }
    }
}
