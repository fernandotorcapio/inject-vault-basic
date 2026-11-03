import Foundation
import SwiftUI

@MainActor final class AppStore: ObservableObject {
    @Published private(set) var ledger = Ledger()
    @Published var message: String?
    @Published private(set) var writable = true
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = base.appendingPathComponent("InjectVault/ledger.json")
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: fileURL)).validated()
            }
        } catch { writable = false; message = "Não foi possível ler os dados locais. O arquivo foi preservado: \(error.localizedDescription)" }
    }

    func commit(_ mutation: (inout Ledger) throws -> Void) throws {
        guard writable else { throw VaultError.invalid("Gravação bloqueada para preservar os dados locais.") }
        var next = ledger
        try mutation(&next)
        let data = try JSONEncoder().encode(next)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        ledger = next
    }

    func export() throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("InjectVault-registro.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ledger).write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }
}
