import Foundation

enum WeatherError: Error {
    case badURL
    case status(Int)
    case network(URLError.Code)
    case undecodable

    var message: String {
        switch self {
        case .badURL, .undecodable:
            return "天氣資料讀不起來"
        case .status(429):
            return "查詢太頻繁，過一會兒再試"
        case .status:
            return "天氣服務暫時沒有回應"
        case .network(.notConnectedToInternet), .network(.networkConnectionLost), .network(.dataNotAllowed):
            return "沒有網路連線"
        case .network(.timedOut):
            return "連線逾時"
        case .network:
            return "連線出了點問題"
        }
    }
}
