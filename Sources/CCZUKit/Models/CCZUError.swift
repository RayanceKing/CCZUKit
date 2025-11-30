import Foundation

/// CCZU API 错误类型
public enum CCZUError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case loginFailed(String)
    case notLoggedIn
    case decodingError(Error)
    case missingData(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .loginFailed(let reason):
            return "登录失败: \(reason)"
        case .notLoggedIn:
            return "未登录"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .missingData(let description):
            return "缺少数据: \(description)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}
