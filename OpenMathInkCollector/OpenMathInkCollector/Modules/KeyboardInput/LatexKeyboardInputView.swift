import EMathicaFormulaKeyboardSwiftUI
import SwiftUI

struct LatexKeyboardInputView: View {
    @ObservedObject var session: CollectorFormulaKeyboardSession
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var keyboardTheme: FormulaKeyboardTheme {
        var theme = FormulaKeyboardTheme.standard
        theme.reduceTransparency = reduceTransparency
        return theme
    }

    var body: some View {
        Group {
            if let viewModel = session.viewModel {
                FormulaKeyboardView(
                    viewModel: viewModel,
                    theme: keyboardTheme,
                    moduleVisibility: .basic
                )
            } else {
                ContentUnavailableView {
                    Label("数学键盘不可用", systemImage: "keyboard.badge.ellipsis")
                } description: {
                    Text(session.errorDescription ?? "共享数学键盘组装失败")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
