import Foundation

enum BlockStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case missed
}

extension BlockStatus {
    var displayName: String {
        switch self {
        case .pending:    return "进行中"
        case .completed:  return "已完成"
        case .missed:     return "未完成"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:    return "circle"
        case .completed:  return "checkmark.circle.fill"
        case .missed:     return "xmark.circle.fill"
        }
    }
}
