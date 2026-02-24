import Foundation

// MARK: - 通用响应消息
public struct Message<T: Decodable>: Decodable, Sendable where T: Sendable {
    public let status: Int
    public let message: [T]
    public let token: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case token
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        
        // 使用灵活的方式解析 message，处理任何返回格式
        if container.contains(.message) {
            let msgDecoder = try container.superDecoder(forKey: .message)
            do {
                // 尝试作为数组解析
                let arrayContainer = try msgDecoder.singleValueContainer()
                message = try arrayContainer.decode([T].self)
            } catch {
                // 如果失败，使用空数组
                message = []
            }
        } else {
            message = []
        }
    }
}
