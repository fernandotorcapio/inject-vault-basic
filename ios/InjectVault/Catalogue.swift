import Foundation

struct Catalogue: Decodable {
    let schemaVersion: Int
    let verifiedAt: String
    let scope: String
    let entries: [CatalogueEntry]

    static func load() throws -> Catalogue {
        guard let url = Bundle.main.url(forResource: "catalogue", withExtension: "json") else {
            throw VaultError.invalid("O catálogo não está incluído neste build.")
        }
        let value = try JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url))
        guard value.schemaVersion == 1, Set(value.entries.map(\.id)).count == value.entries.count else {
            throw VaultError.invalid("Catálogo inválido.")
        }
        return value
    }
}

struct CatalogueEntry: Decodable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let family: String
    let summary: String
    let products: [String]
    let applications: [String]
    let operatorFeature: String
    let machineModelsVerified: [String]
    let integrationState: String
    let sources: [CatalogueSource]

    func matches(_ query: String) -> Bool {
        let text = ([name, kind, family, summary] + products + applications).joined(separator: " ")
        return query.isEmpty || text.localizedStandardContains(query)
    }
}

struct CatalogueSource: Decodable {
    let title: String
    let url: String
}
