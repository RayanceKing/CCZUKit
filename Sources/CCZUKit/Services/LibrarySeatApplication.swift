import Foundation

public typealias LibrarySeatRequestSigner = @Sendable (_ url: URL, _ requestID: String, _ requestDate: String) throws -> String

@MainActor
public final class LibrarySeatApplication {
    public let client: DefaultHTTPClient
    public let requestSigner: LibrarySeatRequestSigner?
    public private(set) var token: String?
    public private(set) var user: LibraryUser?

    public init(client: DefaultHTTPClient, requestSigner: LibrarySeatRequestSigner? = nil) {
        self.client = client
        self.requestSigner = requestSigner
    }

    @discardableResult
    public func login() async throws -> LibraryUser {
        let casToken = try await obtainCASToken()
        let authURL = try makeURL(path: CCZUConstants.LibrarySeat.ssoAuthPath, query: ["token": casToken])
        var authHeaders = baseHeaders(for: authURL)
        authHeaders["Content-Type"] = "application/json"
        let (authData, authResponse) = try await client.postJSON(
            url: authURL,
            headers: signedHeaders(authHeaders, url: authURL),
            json: ["token": casToken]
        )
        guard authResponse.statusCode == 200 else {
            throw CCZUError.loginFailed("座位系统登录 HTTP 状态码: \(authResponse.statusCode)")
        }
        let auth = try decode(LibraryAPIResponse<LibraryToken>.self, from: authData)
        token = auth.data.token
        return try await getUser()
    }

    public func getBuildings() async throws -> [LibraryBuilding] {
        let filters = try await getFilters()
        return filters.buildings
    }

    public func getRooms() async throws -> [LibraryRoom] {
        let filters = try await getFilters()
        return filters.rooms
    }

    public func getFloors(buildingId: Int) async throws -> [LibraryFloor] {
        let url = try authenticatedURL(path: "\(CCZUConstants.LibrarySeat.floorsPath)/\(buildingId)")
        let (data, response) = try await client.post(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<[LibraryFloor]>.self, from: data).data
    }

    public func getRoomLayout(roomId: Int, date: String, begin: Int) async throws -> LibraryRoomLayout {
        let url = try authenticatedURL(
            path: "\(CCZUConstants.LibrarySeat.layoutPath)/\(roomId)/\(date)",
            query: ["id": String(roomId), "date": date, "begin": String(begin)]
        )
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<LibraryRoomLayout>.self, from: data).data
    }

    public func getStartTimes(seatId: Int, date: String) async throws -> [LibrarySeatTime] {
        let url = try authenticatedURL(
            path: "/rest/v2/startTimesForSeat/\(seatId)/\(date)",
            query: ["seatId": String(seatId), "date": date]
        )
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<SeatTimesData>.self, from: data).data.startTimesValue
    }

    public func getEndTimes(seatId: Int, date: String, start: Int) async throws -> [LibrarySeatTime] {
        let url = try authenticatedURL(
            path: "/rest/v2/endTimesForSeat/\(seatId)/\(date)/\(start)",
            query: ["seatId": String(seatId), "date": date, "start": String(start)]
        )
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<SeatTimesData>.self, from: data).data.endTimesValue
    }

    public func getCaptcha() async throws -> LibraryCaptcha {
        guard let token else { throw CCZUError.notLoggedIn }
        var urlComponents = URLComponents(url: CCZUConstants.LibrarySeat.baseURL.appendingPathComponent("/cap/captcha/\(token)"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "username", value: client.account.username)]
        guard let url = urlComponents?.url else { throw CCZUError.invalidResponse }
        let (data, response) = try await client.post(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        struct CaptchaResponse: Decodable { let image: String }
        let value = try JSONDecoder().decode(CaptchaResponse.self, from: data)
        let encoded = value.image.split(separator: ",", maxSplits: 1).last.map(String.init) ?? value.image
        guard let imageData = Data(base64Encoded: encoded) else { throw CCZUError.invalidResponse }
        return LibraryCaptcha(imageData: imageData)
    }

    public func searchSeats(roomId: Int, date: String, begin: Int, end: Int, batch: Int = 999, page: Int = 1) async throws -> [LibrarySeat] {
        let url = try authenticatedURL(
            path: "\(CCZUConstants.LibrarySeat.searchSeatsPath)/\(date)/\(begin)/\(end)",
            query: [
                "date": date, "roomId": String(roomId), "begin": String(begin),
                "end": String(end), "batch": String(batch), "page": String(page)
            ]
        )
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        let responseData = try decode(LibraryAPIResponse<SeatSearchData>.self, from: data).data
        return Array(responseData.seats.values)
    }

    public func getReservations() async throws -> [LibraryReservation] {
        let url = try authenticatedURL(path: CCZUConstants.LibrarySeat.reservationsPath)
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<[LibraryReservation]>.self, from: data).data
    }

    @discardableResult
    public func reserveSeat(
        seatId: Int,
        date: String,
        startTime: Int,
        endTime: Int,
        authId: String
    ) async throws -> LibraryReservation {
        let currentUser = try await getUser()
        let url = try authenticatedURL(path: CCZUConstants.LibrarySeat.freeBookPath, includeToken: false)
        let fields = [
            "startTime": String(startTime),
            "endTime": String(endTime),
            "seat": String(seatId),
            "date": date,
            "token": try seatToken(),
            "userId": String(currentUser.id),
            "username": currentUser.username,
            "authid": authId
        ]
        let (data, response) = try await client.postMultipart(
            url: url,
            headers: signedHeaders(baseHeaders(for: url), url: url),
            fields: fields
        )
        try validate(response)
        return try decode(LibraryAPIResponse<LibraryReservation>.self, from: data).data
    }

    public func cancelReservation(id: Int) async throws -> LibraryCancelResult {
        let url = try authenticatedURL(
            path: "\(CCZUConstants.LibrarySeat.cancelPath)/\(id)",
            query: ["id": String(id)]
        )
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<LibraryCancelResult>.self, from: data).data
    }

    private func getUser() async throws -> LibraryUser {
        let url = try authenticatedURL(path: CCZUConstants.LibrarySeat.userPath)
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        let value = try decode(LibraryAPIResponse<LibraryUser>.self, from: data).data
        user = value
        return value
    }

    private struct LibraryToken: Decodable, Sendable { let token: String }
    private struct SeatSearchData: Decodable, Sendable { let seats: [String: LibrarySeat] }
    private struct SeatTimesData: Decodable, Sendable {
        let startTimes: [LibrarySeatTime]?
        let endTimes: [LibrarySeatTime]?

        var startTimesValue: [LibrarySeatTime] { startTimes ?? [] }
        var endTimesValue: [LibrarySeatTime] { endTimes ?? [] }
    }
    private struct LibraryFilters: Decodable, Sendable {
        let buildings: [LibraryBuilding]
        let rooms: [LibraryRoom]
    }

    private func getFilters() async throws -> LibraryFilters {
        let url = try authenticatedURL(path: CCZUConstants.LibrarySeat.filtersPath)
        let (data, response) = try await client.get(url: url, headers: signedHeaders(baseHeaders(for: url), url: url))
        try validate(response)
        return try decode(LibraryAPIResponse<LibraryFilters>.self, from: data).data
    }

    private func obtainCASToken() async throws -> String {
        var components = URLComponents(string: CCZUConstants.rootSSOLogin)!
        components.queryItems = [URLQueryItem(name: "service", value: CCZUConstants.LibrarySeat.ssoService)]
        guard let loginURL = components.url else { throw CCZUError.loginFailed("无法构造统一认证地址") }
        let (pageData, pageResponse) = try await client.get(url: loginURL)
        if let token = tokenFromURL(pageResponse.url) { return token }

        guard let html = String(data: pageData, encoding: .utf8) else { throw CCZUError.invalidResponse }
        let form = hiddenValues(from: html)
        guard let loginTicket = form["lt"], !loginTicket.isEmpty,
              let execution = form["execution"], !execution.isEmpty else {
            throw CCZUError.loginFailed("统一认证页面缺少 lt 或 execution 参数")
        }

        let fields: [(String, String)] = [
            ("username", client.account.username),
            ("password", Data(client.account.password.utf8).base64EncodedString()),
            ("lt", loginTicket),
            ("execution", execution),
            ("_eventId", "submit")
        ]
        let (_, response) = try await client.postForm(url: loginURL, fields: fields)
        if let token = tokenFromURL(response.url) { return token }
        if let location = response.value(forHTTPHeaderField: "Location"), let url = URL(string: location), let token = tokenFromURL(url) {
            return token
        }
        throw CCZUError.invalidCredentials
    }

    private func tokenFromURL(_ url: URL?) -> String? {
        guard let fragment = url?.fragment, let question = fragment.firstIndex(of: "?") else { return nil }
        let query = String(fragment[fragment.index(after: question)...])
        return URLComponents(string: "https://seat.invalid/?\(query)")?.queryItems?.first(where: { $0.name == "token" })?.value
    }

    private func hiddenValues(from html: String) -> [String: String] {
        let inputPattern = #"<input\b[^>]*>"#
        let attributePattern = #"([A-Za-z_:][A-Za-z0-9_:.-]*)\s*=\s*(?:[\"']([^\"']*)[\"']|([^\s>]+))"#
        guard let inputRegex = try? NSRegularExpression(pattern: inputPattern, options: .caseInsensitive),
              let attributeRegex = try? NSRegularExpression(pattern: attributePattern, options: .caseInsensitive) else {
            return [:]
        }

        var result: [String: String] = [:]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for inputMatch in inputRegex.matches(in: html, range: range) {
            let input = (html as NSString).substring(with: inputMatch.range)
            let inputRange = NSRange(input.startIndex..<input.endIndex, in: input)
            var attributes: [String: String] = [:]

            for attributeMatch in attributeRegex.matches(in: input, range: inputRange) {
                let nsInput = input as NSString
                let name = nsInput.substring(with: attributeMatch.range(at: 1)).lowercased()
                let quotedValue = attributeMatch.range(at: 2)
                let unquotedValue = attributeMatch.range(at: 3)
                let valueRange = quotedValue.location != NSNotFound ? quotedValue : unquotedValue
                attributes[name] = valueRange.location == NSNotFound ? "" : nsInput.substring(with: valueRange)
            }

            guard let name = attributes["name"], !name.isEmpty,
                  let value = attributes["value"] else { continue }
            if attributes["type"]?.lowercased() == "hidden" || name == "lt" || name == "execution" || name == "pages" {
                result[name] = value
            }
        }
        return result
    }

    private func seatToken() throws -> String {
        guard let token else { throw CCZUError.notLoggedIn }
        return token
    }

    private func authenticatedURL(path: String, query: [String: String] = [:], includeToken: Bool = true) throws -> URL {
        var query = query
        if includeToken { query["token"] = try seatToken() }
        return try makeURL(path: path, query: query)
    }

    private func makeURL(path: String, query: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(url: CCZUConstants.LibrarySeat.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw CCZUError.invalidResponse
        }
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw CCZUError.invalidResponse }
        return url
    }

    private func baseHeaders(for url: URL) -> [String: String] {
        var headers = CCZUConstants.defaultHeaders
        headers["Accept"] = "*/*"
        headers["Referer"] = CCZUConstants.LibrarySeat.referer
        headers["Origin"] = CCZUConstants.LibrarySeat.baseURL.absoluteString
        headers["loginType"] = CCZUConstants.LibrarySeat.loginType
        return headers
    }

    private func signedHeaders(_ headers: [String: String], url: URL) throws -> [String: String] {
        var result = headers
        let requestID = UUID().uuidString
        let requestDate = String(Int(Date().timeIntervalSince1970 * 1000))
        result["X-request-id"] = requestID
        result["X-request-date"] = requestDate
        if let requestSigner {
            result["X-hmac-request-key"] = try requestSigner(url, requestID, requestDate)
        }
        return result
    }

    private func validate(_ response: HTTPURLResponse) throws {
        guard (200..<300).contains(response.statusCode) else { throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode)) }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw CCZUError.decodingError(error) }
    }
}