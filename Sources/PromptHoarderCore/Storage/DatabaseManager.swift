import Foundation
import GRDB

protocol DatabaseManaging: Sendable {
    var isConnected: Bool { get async }
    func initialize() async throws
    func rebuild(progress: @escaping @Sendable (RebuildProgress) -> Void) async throws
    func close() async
}

struct RebuildProgress: Sendable {
    let phase: RebuildPhase
    let filesProcessed: Int
    let totalFiles: Int
}

enum RebuildPhase: Sendable {
    case deletingOldDatabase
    case creatingSchema
    case scanningVault
    case indexingFiles
    case rebuildingFTS
    case complete
}

enum DatabaseError: Error {
    case notInitialized
    case migrationFailed(underlying: Error)
    case rebuildFailed(phase: RebuildPhase, underlying: Error)
}

actor DatabaseManager: DatabaseManaging {
    private var dbQueue: DatabaseQueue?
    private let dbURL: URL

    init(dbURL: URL = DatabaseManager.defaultDatabaseURL()) {
        self.dbURL = dbURL
    }

    var isConnected: Bool {
        dbQueue != nil
    }

    func initialize() async throws {
        let queue = try DatabaseQueue(path: dbURL.path)
        do {
            try DatabaseMigrations.migrator().migrate(queue)
            try queue.inDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode=WAL")
            }
            dbQueue = queue
        } catch {
            throw DatabaseError.migrationFailed(underlying: error)
        }
    }

    func rebuild(progress: @escaping @Sendable (RebuildProgress) -> Void) async throws {
        await close()
        var phase: RebuildPhase = .deletingOldDatabase
        do {
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
            try deleteDatabaseFiles()

            phase = .creatingSchema
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
            try await initialize()

            phase = .scanningVault
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
            phase = .indexingFiles
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
            phase = .rebuildingFTS
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
            phase = .complete
            progress(RebuildProgress(phase: phase, filesProcessed: 0, totalFiles: 0))
        } catch {
            throw DatabaseError.rebuildFailed(phase: phase, underlying: error)
        }
    }

    func close() async {
        dbQueue = nil
    }

    private func deleteDatabaseFiles() throws {
        let fileManager = FileManager.default
        let baseURL = dbURL.deletingLastPathComponent()
        let baseName = dbURL.lastPathComponent
        let candidates = [
            dbURL,
            baseURL.appendingPathComponent("\(baseName)-wal"),
            baseURL.appendingPathComponent("\(baseName)-shm"),
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func defaultDatabaseURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("PromptHoarder", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("index.sqlite")
    }
}
