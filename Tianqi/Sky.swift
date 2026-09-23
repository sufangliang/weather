import Foundation

enum Sky {
    case clear
    case partly
    case cloudy
    case fog
    case rain
    case snow
    case thunder

    static func group(_ code: Int) -> Sky {
        switch code {
        case 0:
            return .clear
        case 1, 2:
            return .partly
        case 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 95, 96, 99:
            return .thunder
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return .rain
        default:
            return .cloudy
        }
    }

    static func label(for code: Int) -> String {
        switch code {
        case 0: return "晴朗"
        case 1: return "大致晴朗"
        case 2: return "局部多雲"
        case 3: return "陰天"
        case 45, 48: return "有霧"
        case 51, 56: return "小毛雨"
        case 53, 55, 57: return "毛毛雨"
        case 61, 80: return "小雨"
        case 63, 81: return "下雨"
        case 65, 82: return "大雨"
        case 66, 67: return "凍雨"
        case 71, 85: return "小雪"
        case 73: return "下雪"
        case 75, 86: return "大雪"
        case 77: return "雪粒"
        case 95: return "雷雨"
        case 96, 99: return "雷雨夾冰雹"
        default: return "多雲"
        }
    }

    static func symbol(code: Int, day: Bool) -> String {
        switch group(code) {
        case .clear:
            return day ? "sun.max.fill" : "moon.stars.fill"
        case .partly:
            return day ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy:
            return "cloud.fill"
        case .fog:
            return "cloud.fog.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunder:
            return "cloud.bolt.rain.fill"
        }
    }
}
