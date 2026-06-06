import Foundation

/// Desktop pet animation state with priority ordering.
/// Higher rawValue = higher priority (used to determine which animation wins).
enum PetState: Int, Comparable, CaseIterable {
    case initial = 0
    case idle = 1
    case idleMicro = 2
    case sleeping = 3
    case focusing = 4
    case succeeded = 5
    case failed = 6
    case draggingLeft = 7
    case draggingRight = 8

    static func < (lhs: PetState, rhs: PetState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Base filename used in naming-convention fallback (without extension or pet prefix).
    var animationFileName: String {
        switch self {
        case .initial:        return "waving"
        case .idle:           return "idle"
        case .idleMicro:      return "blink"
        case .sleeping:       return "sleeping"
        case .focusing:       return "waiting"
        case .succeeded:      return "jumping"
        case .failed:         return "failed"
        case .draggingLeft:   return "running-left"
        case .draggingRight:  return "running-right"
        }
    }

    /// Human-readable Chinese label for debugging / logging.
    var label: String {
        switch self {
        case .initial:        return "初始化"
        case .idle:           return "待机"
        case .idleMicro:      return "微动作"
        case .sleeping:       return "睡眠"
        case .focusing:       return "专注中"
        case .succeeded:      return "成功"
        case .failed:         return "失败"
        case .draggingLeft:   return "左拖拽"
        case .draggingRight:  return "右拖拽"
        }
    }

    /// JSON dictionary key used in pet manifest files (e.g. `"idle"`, `"failed"`).
    var manifestKey: String {
        switch self {
        case .initial:       return "initial"
        case .idle:          return "idle"
        case .idleMicro:     return "idleMicro"
        case .sleeping:      return "sleeping"
        case .focusing:      return "focusing"
        case .succeeded:     return "succeeded"
        case .failed:        return "failed"
        case .draggingLeft:  return "draggingLeft"
        case .draggingRight: return "draggingRight"
        }
    }
}
