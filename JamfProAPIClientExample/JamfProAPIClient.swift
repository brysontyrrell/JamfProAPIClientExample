//
//  JamfProAPIClient.swift
//  JamfProAPIClient
//
//  Created by Bryson Tyrrell on 8/26/24.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

enum JamfProAPIClientError: Error {
    case AuthError(String)
}

struct AccessToken: Codable {
    let access_token: String
    let expires_in: Int
    let expiration_date: Date
    
    var isExpired: Bool {
        return expiration_date < Date()
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.access_token = try container.decode(String.self, forKey: .access_token)
        self.expires_in = try container.decode(Int.self, forKey: .expires_in)
        self.expiration_date = Date().addingTimeInterval(Double(expires_in))
    }
}

actor AccessTokenManager {
    private let tokenURL: URL
    private let clientID: String
    private let clientSecret: String
    
    var currentToken: AccessToken?
    var activeTokenTask: Task<AccessToken, Error>?
    
    init(tokenURL: URL, clientID: String, clientSecret: String) {
        self.tokenURL = tokenURL
        self.clientID = clientID
        self.clientSecret = clientSecret
    }
    
    func getAccessToken() async throws -> AccessToken {
        if let activeTokenTask {
            return try await activeTokenTask.value
        }
        
        if let currentToken, currentToken.isExpired {
            return currentToken
        }
        
        activeTokenTask = Task {
            try await requestAccessToken()
        }
        
        guard let newToken = try await activeTokenTask?.value else {
            throw JamfProAPIClientError.AuthError("Failed to return access token")
        }
        currentToken = newToken
        activeTokenTask = nil

        return newToken
    }
    
    func requestAccessToken() async throws -> AccessToken {
        var request = URLRequest(url: tokenURL)

        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]
        request.httpBody = body.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JamfProAPIClientError.AuthError("Token request failed with response: \(response)")
        }
        
        if httpResponse.statusCode != 200 {
            throw JamfProAPIClientError.AuthError("Token request failed with status code: \(httpResponse.statusCode)")
        }
        
        guard let newAccessToken = try? JSONDecoder().decode(AccessToken.self, from: data) else {
            throw JamfProAPIClientError.AuthError("Failed to decode access token: \(data)")
        }
        
        return newAccessToken
    }
}

struct APIClientMiddleware: ClientMiddleware {
    let accessTokenManager: AccessTokenManager
    
    init(accessTokenManager: AccessTokenManager) {
        self.accessTokenManager = accessTokenManager
    }
    
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let accessToken = try? await accessTokenManager.getAccessToken() else {
            throw JamfProAPIClientError.AuthError("Failed to fetch access token")
        }
        
        var request = request
        request.headerFields[.authorization] = "Bearer \(accessToken.access_token)"

        return try await next(request, body, baseURL)
    }
}

//struct CustomDateTranscoder: DateTranscoder {
//    private let lock: NSLock
//    
//    public init() {
//        lock = NSLock()
//    }
//    
//    public func encode(_ date: Date) throws -> String {
//        lock.lock()
//        defer { lock.unlock() }
//        return Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date)
//    }
//
//    public func decode(_ dateString: String) throws -> Date {
//        lock.lock()
//        defer { lock.unlock() }
//        do {
//            return try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(dateString)
//        } catch {
//            do {
//                return try Date.ISO8601FormatStyle().parse(dateString)
//            } catch {
//                throw DecodingError.dataCorrupted(
//                    .init(codingPath: [], debugDescription: "Expected date string '\(dateString)' to be ISO8601-formatted.")
//                )
//            }
//        }
//    }
//}

struct JamfProAPIClient: Equatable {
    let api: Client
    
    let hostname: String
    let clientID: String
    private let clientSecret: String
    
    init(hostname: String, clientID: String, clientSecret: String) {
        self.hostname = hostname
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.api = Client(
            serverURL: URL(string: "https://\(hostname):443/api")!,
            configuration: Configuration(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: URLSessionTransport(),
            
            middlewares: [
                APIClientMiddleware(
                    accessTokenManager: .init(
                        tokenURL: URL(string: "https://\(hostname):443/api/oauth/token")!,
                        clientID: clientID,
                        clientSecret: clientSecret
                    )
                )
            ]
        )
    }
    
    static func == (lhs: JamfProAPIClient, rhs: JamfProAPIClient) -> Bool {
        return lhs.hostname == rhs.hostname && lhs.clientID == rhs.clientID && lhs.clientSecret == rhs.clientSecret
        
    }
    
    func AccessToken() async throws -> String? {
        let response = try await api.AccessTokenRequest(
            body: .urlEncodedForm(.init(
                client_id: clientID,
                client_secret: clientSecret,
                grant_type: "client_credentials")
            )
        )
        return try response.ok.body.json.access_token
    }
    
    func ComputerInventoryGetV1AllPages(
        query: Operations.ComputersInventoryGetV1.Input.Query = .init(page: 0, page_hyphen_size: 100)
    ) async throws -> Components.Schemas.ComputerInventorySearchResults {
        var currentPage = max(query.page ?? 0 - 1, -1)
        var computerResults = Components.Schemas.ComputerInventorySearchResults(totalCount: 1, results: [])
        
        while computerResults.results!.count < computerResults.totalCount! {
            currentPage += 1
            
            let nextPage = try await api.ComputersInventoryGetV1(
                .init(
                    query: .init(
                        section: query.section,
                        page: currentPage,
                        page_hyphen_size: query.page_hyphen_size,
                        sort: query.sort,
                        filter: query.filter
                    )
                )
            )
            
            let nextPageResults = try nextPage.ok.body.json
            computerResults.totalCount = nextPageResults.totalCount ?? 0
            
            if nextPageResults.results!.count == 0 {
                return computerResults
            } else {
                computerResults.results?.append(contentsOf: nextPageResults.results!)
            }
        }
        
        return computerResults
    }
}
