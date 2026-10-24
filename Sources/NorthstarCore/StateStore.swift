import Foundation

public struct StateStore: Sendable {
    public let stateURL: URL

    public init(stateURL: URL) {
        self.stateURL = stateURL
    }

    public static func defaultStore(fileManager: FileManager = .default) throws -> StateStore {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("Nathstar", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let stateURL = directory.appendingPathComponent("state.json")
        let legacyStateURL = applicationSupport
            .appendingPathComponent("Northstar", isDirectory: true)
            .appendingPathComponent("state.json")
        if !fileManager.fileExists(atPath: stateURL.path),
           fileManager.fileExists(atPath: legacyStateURL.path) {
            try fileManager.copyItem(at: legacyStateURL, to: stateURL)
        }
        return StateStore(stateURL: stateURL)
    }

    public func load() throws -> NorthstarState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return NorthstarState()
        }
        let data = try Data(contentsOf: stateURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(NorthstarState.self, from: data)
    }

    public func save(_ state: NorthstarState) throws {
        let directory = stateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }
}
