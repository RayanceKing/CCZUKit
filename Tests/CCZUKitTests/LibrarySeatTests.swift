import XCTest
@testable import CCZUKit

final class LibrarySeatTests: XCTestCase {
  func testLibrarySSOPasswordUsesBase64() {
    let encoded = Data("Chengguo1029".utf8).base64EncodedString()
    XCTAssertEqual(encoded, "Q2hlbmdndW8xMDI5")
  }

    func testDecodesLibraryFiltersAndSeats() throws {
        let data = Data("""
        {
          "status": "success",
          "data": {
            "buildings": [[1, "科教城校区馆", 0, ""], [3, "西太湖校区馆", 0, ""]],
            "rooms": [[1, "二楼北区", 1, 2, ""]]
          },
          "message": "",
          "code": "0"
        }
        """.utf8)

        struct Filters: Decodable {
            let buildings: [LibraryBuilding]
            let rooms: [LibraryRoom]
        }
        let response = try JSONDecoder().decode(LibraryAPIResponse<Filters>.self, from: data)
        XCTAssertEqual(response.data.buildings, [LibraryBuilding(id: 1, name: "科教城校区馆"), LibraryBuilding(id: 3, name: "西太湖校区馆")])
        XCTAssertEqual(response.data.rooms.first?.id, 1)
        XCTAssertEqual(response.data.rooms.first?.buildingId, 1)
        XCTAssertEqual(response.data.rooms.first?.floorId, 2)
    }

    func testDecodesRoomLayoutSeatDictionary() throws {
        let data = Data("""
        {
          "status": "success",
          "data": {
            "id": 1,
            "name": "二楼北区",
            "cols": 47,
            "rows": 13,
            "layout": {
              "1001": {
                "id": 16761,
                "name": "011",
                "type": "seat",
                "status": "FREE",
                "window": false,
                "power": false,
                "computer": false,
                "local": false,
                "enabled": true,
                "direction": 2
              }
            }
          },
          "message": "",
          "code": "0"
        }
        """.utf8)

        let response = try JSONDecoder().decode(LibraryAPIResponse<LibraryRoomLayout>.self, from: data)
        XCTAssertEqual(response.data.columns, 47)
        XCTAssertEqual(response.data.layout["1001"]?.id, 16761)
        XCTAssertEqual(response.data.layout["1001"]?.status, "FREE")
    }

    func testDecodesReservationResponse() throws {
        let data = Data("""
        {
          "status": "success",
          "data": [{
            "id": 5790011,
            "receipt": "0204-011-5",
            "onDate": "2026年09月18日",
            "seatId": 44758,
            "status": "RESERVE",
            "location": "科教城校区馆3层",
            "begin": "11:00",
            "end": "15:00",
            "actualBegin": null,
            "awayBegin": null,
            "awayEnd": null,
            "userEnded": false,
            "message": "请签到"
          }],
          "message": "",
          "code": "0"
        }
        """.utf8)

        let response = try JSONDecoder().decode(LibraryAPIResponse<[LibraryReservation]>.self, from: data)
        XCTAssertEqual(response.data.first?.id, 5790011)
        XCTAssertEqual(response.data.first?.seatId, 44758)
        XCTAssertEqual(response.data.first?.status, "RESERVE")
    }

      func testDecodesSeatTimesAndCaptchaPoints() throws {
        let timesData = Data("""
        {
          "status": "success",
          "data": { "startTimes": [{"id": "420", "value": "07:00"}] },
          "message": "",
          "code": "0"
        }
        """.utf8)
        struct StartTimes: Decodable, Sendable { let startTimes: [LibrarySeatTime] }
        let response = try JSONDecoder().decode(LibraryAPIResponse<StartTimes>.self, from: timesData)
        XCTAssertEqual(response.data.startTimes.first?.id, 420)
        XCTAssertEqual(response.data.startTimes.first?.value, "07:00")

        let points = try JSONEncoder().encode([LibraryCaptchaPoint(x: 41, y: 31)])
        XCTAssertEqual(Data(base64Encoded: points.base64EncodedString()), points)
      }
}
