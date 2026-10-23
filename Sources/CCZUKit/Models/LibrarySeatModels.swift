import Foundation

public struct LibraryAPIResponse<Value: Decodable & Sendable>: Decodable, Sendable {
    public let status: String
    public let data: Value
    public let message: String
    public let code: String

    enum CodingKeys: String, CodingKey { case status, data, message, code }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        data = try container.decode(Value.self, forKey: .data)
        message = try container.decode(String.self, forKey: .message)
        code = try container.decode(String.self, forKey: .code)
        guard status == "success", code == "0" else {
            throw CCZUError.unknown(message.isEmpty ? "图书馆接口请求失败" : message)
        }
    }
}

public struct LibraryBuilding: Codable, Sendable, Equatable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        id = try container.decode(Int.self)
        name = try container.decode(String.self)
    }
}

public struct LibraryRoom: Codable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let buildingId: Int?
    public let floorId: Int?

    public init(id: Int, name: String, buildingId: Int? = nil, floorId: Int? = nil) {
        self.id = id
        self.name = name
        self.buildingId = buildingId
        self.floorId = floorId
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        id = try container.decode(Int.self)
        name = try container.decode(String.self)
        buildingId = try container.decodeIfPresent(Int.self)
        floorId = try container.decodeIfPresent(Int.self)
    }
}

public struct LibraryFloor: Codable, Sendable, Equatable {
    public let buildingId: Int
    public let building: String
    public let floorId: Int
    public let floorName: String
    public let floorNumber: Int

    enum CodingKeys: String, CodingKey { case buildingId, building, floorId, floorName, floorNumber = "floorNum" }
}

public struct LibrarySeat: Codable, Sendable, Equatable {
    public let roomId: Int?
    public let roomName: String?
    public let id: Int
    public let name: String
    public let type: String
    public let status: String
    public let window: Bool
    public let power: Bool
    public let computer: Bool
    public let local: Bool
    public let enabled: Bool
    public let direction: Int?
}

public struct LibrarySeatTime: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: Int
    public let value: String

    private enum CodingKeys: String, CodingKey { case id, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(Int.self, forKey: .id) {
            self.id = id
        } else {
            self.id = try Int(container.decode(String.self, forKey: .id)) ?? 0
        }
        self.value = try container.decode(String.self, forKey: .value)
    }

    public init(id: Int, value: String) {
        self.id = id
        self.value = value
    }
}

public struct LibraryCaptcha: Sendable {
    public let imageData: Data

    public init(imageData: Data) {
        self.imageData = imageData
    }
}

public struct LibraryCaptchaPoint: Codable, Sendable, Equatable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct LibraryRoomLayout: Codable, Sendable {
    public let id: Int
    public let name: String
    public let columns: Int
    public let rows: Int
    public let layout: [String: LibrarySeat]

    enum CodingKeys: String, CodingKey { case id, name, columns = "cols", rows, layout }
}

public struct LibraryUser: Codable, Sendable {
    public let id: Int
    public let name: String
    public let username: String
    public let checkedIn: Bool
}

public struct LibraryReservation: Codable, Sendable {
    public let id: Int
    public let receipt: String?
    public let onDate: String
    public let seatId: Int?
    public let status: String?
    public let location: String?
    public let begin: String?
    public let end: String?
    public let actualBegin: String?
    public let awayBegin: String?
    public let awayEnd: String?
    public let userEnded: Bool?
    public let message: String?
}

public struct LibraryCancelResult: Codable, Sendable {
    public let totalCancelled: Int
    public let allowedCancel: Int
}