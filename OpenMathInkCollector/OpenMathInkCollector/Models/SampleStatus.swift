import Foundation
import SwiftUI

enum SampleStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case confirmed
    case exported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .confirmed: return "已确认"
        case .exported: return "已导出"
        }
    }

    var color: Color {
        switch self {
        case .draft: return .orange
        case .confirmed: return .green
        case .exported: return .blue
        }
    }

    var icon: String {
        switch self {
        case .draft: return "pencil"
        case .confirmed: return "checkmark.seal.fill"
        case .exported: return "tray.and.arrow.up.fill"
        }
    }
}
