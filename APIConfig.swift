import Foundation

struct APIConfig: Decodable {
    let tmdbBaseURL: String
    var tmdbAPIKey: String
    let omdbBaseURL: String
    var omdbAPIKey: String
    let youtubeBaseURL: String
    var youtubeAPIKey: String
    let youtubeSearchURL: String

    /// Indicates if the configuration is valid and ready to use
    var isValid: Bool {
        hasValue(tmdbAPIKey, key: "TMDB_API_KEY")
    }

    var hasOMDBConfig: Bool {
        hasValue(omdbAPIKey, key: "OMDB_API_KEY")
    }

    var hasYouTubeConfig: Bool {
        hasValue(youtubeAPIKey, key: "YOUTUBE_API_KEY")
    }

    var tmdbBase: URL {
        get throws { try validatedURL(tmdbBaseURL, key: "tmdbBaseURL") }
    }

    var omdbBase: URL {
        get throws { try validatedURL(omdbBaseURL, key: "omdbBaseURL") }
    }

    var youtubeBase: URL {
        get throws { try validatedURL(youtubeBaseURL, key: "youtubeBaseURL") }
    }

    var youtubeSearchBase: URL {
        get throws { try validatedURL(youtubeSearchURL, key: "youtubeSearchURL") }
    }

    static let shared: APIConfig? = {
        do {
            return try validatedForStartup()
        } catch {
            print("Failed to load API config: \(error.localizedDescription)")
            return nil
        }
    }()

    static let startupError: APIConfigError? = {
        do {
            _ = try validatedForStartup()
            return nil
        } catch let error as APIConfigError {
            return error
        } catch {
            return .dataLoadingFailed(underlyingError: error)
        }
    }()

    static func validated() throws -> APIConfig {
        try validatedForStartup()
    }

    static func validatedForStartup() throws -> APIConfig {
        let config = try loadConfig()
        try config.validateTMDB()
        try config.validateBaseURLs()
        return config
    }

    private static func loadConfig() throws -> APIConfig {
        guard let url = Bundle.main.url(forResource: "APIConfig", withExtension: "json") else {
            throw APIConfigError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            var config = try JSONDecoder().decode(APIConfig.self, from: data)

            // Replace placeholder values with actual environment variables
            config.tmdbAPIKey = resolvedValue(config.tmdbAPIKey, key: "TMDB_API_KEY")
            config.omdbAPIKey = resolvedValue(config.omdbAPIKey, key: "OMDB_API_KEY")
            config.youtubeAPIKey = resolvedValue(config.youtubeAPIKey, key: "YOUTUBE_API_KEY")

            return config
        } catch let error as DecodingError {
            throw APIConfigError.decodingFailed(underlyingError: error)
        } catch {
            throw APIConfigError.dataLoadingFailed(underlyingError: error)
        }
    }

    private func validateTMDB() throws {
        try requireValue(tmdbAPIKey, key: "TMDB_API_KEY")
    }

    private func validateBaseURLs() throws {
        _ = try tmdbBase
        _ = try omdbBase
        _ = try youtubeBase
        _ = try youtubeSearchBase
    }

    private func requireValue(_ value: String, key: String) throws {
        if !hasValue(value, key: key) {
            throw APIConfigError.missingValue(key)
        }
    }

    private func hasValue(_ value: String, key: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "$(\(key))" && !trimmed.hasPrefix("your_")
    }

    private static func resolvedValue(_ value: String, key: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "$(\(key))" || trimmed.isEmpty || trimmed.hasPrefix("your_") else {
            return value
        }
        if let environmentValue = ProcessInfo.processInfo.environment[key],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue
        }
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !infoValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           infoValue != "$(\(key))" {
            return infoValue
        }
        return ""
    }

    private func validatedURL(_ string: String, key: String) throws -> URL {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              !scheme.isEmpty,
              url.host != nil else {
            throw APIConfigError.invalidURL(key)
        }
        return url
    }
}
