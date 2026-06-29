import Foundation
import Observation

struct VibeMovie: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
    let posterPath: String?
    
    func toTitle() -> Title {
        return Title(id: id, title: title, posterPath: posterPath)
    }
}

struct VibeCluster: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let emoji: String
    let movies: [VibeMovie]
}

struct VibeClusterStore: Codable {
    let clusters: [VibeCluster]
}

@Observable
class VibeClusterManager {
    static let shared = VibeClusterManager()
    var store: VibeClusterStore?
    
    init() {
        load()
    }
    
    private func load() {
        guard let url = Bundle.main.url(forResource: "vibe_clusters", withExtension: "json") else {
            print("Vibe clusters JSON not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            store = try JSONDecoder().decode(VibeClusterStore.self, from: data)
            print("Successfully loaded vibe clusters")
        } catch {
            print("Failed to decode vibe clusters: \(error)")
        }
    }
}
