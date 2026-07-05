import Foundation

enum HTTPError: Error, LocalizedError {
    case badStatus(Int, URL)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code, let url): "HTTP \(code): \(url.absoluteString)"
        case .invalidURL(let s): "Invalid URL: \(s)"
        }
    }
}

enum HTTP {
    static func getJSON<T: Decodable>(_ url: URL, as type: T.Type = T.self) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError.badStatus(http.statusCode, url)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func baseURL(_ string: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host() != nil else {
            throw HTTPError.invalidURL(string)
        }
        return url
    }
}
