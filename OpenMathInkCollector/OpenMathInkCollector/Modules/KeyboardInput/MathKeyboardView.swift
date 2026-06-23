import SwiftUI

struct MathKeyboardView: View {
    let keys: [MathKeyboardKey]
    let onTapKey: (MathKeyboardKey) -> Void

    @State private var selectedTab: MathKeyboardKey.Tab = .numeric
    @State private var selectedSubgroup: MathKeyboardKey.Subgroup?

    private let columns = Array(repeating: GridItem(.flexible(minimum: 46), spacing: 8), count: 5)

    private var tabKeys: [MathKeyboardKey] {
        keys.filter { $0.tab == selectedTab }
    }

    private var availableSubgroups: [MathKeyboardKey.Subgroup] {
        let groups = Set(tabKeys.compactMap(\.subgroup))
        return MathKeyboardKey.Subgroup.allCases.filter { groups.contains($0) }
    }

    private var visibleKeys: [MathKeyboardKey] {
        guard let selectedSubgroup else { return tabKeys }
        return tabKeys.filter { $0.subgroup == selectedSubgroup }
    }

    var body: some View {
        GeometryReader { proxy in
            let totalHeight = proxy.size.height
            let topTabHeight: CGFloat = 34
            let subgroupHeight: CGFloat = availableSubgroups.isEmpty ? 0 : 30
            let chromeSpacing: CGFloat = availableSubgroups.isEmpty ? 10 : 14
            let gridAreaHeight = max(120, totalHeight - topTabHeight - subgroupHeight - chromeSpacing - 28)
            let rowCount = max(1, Int(ceil(Double(visibleKeys.count) / 5.0)))
            let adaptiveHeight = max(38, min(52, (gridAreaHeight - CGFloat(max(0, rowCount - 1)) * 8) / CGFloat(rowCount)))

            VStack(spacing: 8) {
                Picker("键盘分类", selection: $selectedTab) {
                    ForEach(MathKeyboardKey.Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: topTabHeight)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .onChange(of: selectedTab) { _, _ in
                    selectedSubgroup = availableSubgroups.first
                }
                .onAppear {
                    selectedSubgroup = availableSubgroups.first
                }

                if !availableSubgroups.isEmpty {
                    Picker("子分类", selection: Binding(
                        get: { selectedSubgroup ?? availableSubgroups.first },
                        set: { selectedSubgroup = $0 }
                    )) {
                        ForEach(availableSubgroups) { subgroup in
                            Text(subgroup.rawValue).tag(Optional(subgroup))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(height: subgroupHeight)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(visibleKeys) { key in
                            Button {
                                onTapKey(key)
                            } label: {
                                VStack(spacing: 1) {
                                    Text(key.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
                                    if let subtitle = key.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 9, weight: .medium))
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: adaptiveHeight, maxHeight: adaptiveHeight)
                                .foregroundStyle(key.isEnabled ? (key.isAccent ? Color.white : Color.primary) : Color.secondary)
                                .background(
                                    key.isEnabled
                                    ? (key.isAccent ? Color.accentColor.opacity(0.92) : Color.white.opacity(0.13))
                                    : Color.gray.opacity(0.12)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!key.isEnabled)
                        }
                    }
                }
                .frame(height: gridAreaHeight)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
