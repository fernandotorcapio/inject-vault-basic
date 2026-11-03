import XCTest
@testable import VaultCore

final class DomainTests: XCTestCase {
    func configured() throws -> (Ledger, Machine) {
        var ledger = Ledger()
        let machine = try ledger.addMachine(name: "Bancada própria", provider: .pixmaq,
            reference: "QA", officialLink: "https://pixmaq.com.br/")
        return (ledger, machine)
    }
    func testIdempotencyAndConflict() throws {
        var (ledger, machine) = try configured()
        let key = UUID()
        let first = try ledger.request(id: key, machineID: machine.id, quantity: 2, reason: "Promoção")
        XCTAssertEqual(first, try ledger.request(id: key, machineID: machine.id, quantity: 2, reason: "Promoção"))
        XCTAssertThrowsError(try ledger.request(id: key, machineID: machine.id, quantity: 3, reason: "Promoção"))
        XCTAssertEqual(ledger.requests.count, 1)
    }
    func testInvalidQuantitiesAndReason() throws {
        var (ledger, machine) = try configured()
        for value in [-1, 0, 21, Int.max] {
            XCTAssertThrowsError(try ledger.request(id: UUID(), machineID: machine.id, quantity: value, reason: "Teste"))
        }
        XCTAssertThrowsError(try ledger.request(id: UUID(), machineID: machine.id, quantity: 1, reason: "  "))
        XCTAssertTrue(ledger.requests.isEmpty)
    }
    func testNoLinkNeverForwards() throws {
        var ledger = Ledger()
        let machine = try ledger.addMachine(name: "Sem integração", provider: .nayax, reference: "", officialLink: "")
        let request = try ledger.request(id: UUID(), machineID: machine.id, quantity: 1, reason: "Teste")
        XCTAssertThrowsError(try ledger.markForwarded(request.id))
        XCTAssertEqual(ledger.requests[0].state, .requested)
    }
    func testCancelAndForwardAreDistinct() throws {
        var (ledger, machine) = try configured()
        let request = try ledger.request(id: UUID(), machineID: machine.id, quantity: 1, reason: "Teste")
        try ledger.cancel(request.id)
        XCTAssertThrowsError(try ledger.markForwarded(request.id))
        XCTAssertEqual(ledger.requests[0].state, .cancelled)
    }
    func testOpeningPortalIsNeverReleaseConfirmation() throws {
        var (ledger, machine) = try configured()
        let request = try ledger.request(id: UUID(), machineID: machine.id, quantity: 1, reason: "Teste")
        try ledger.markForwarded(request.id)
        XCTAssertEqual(ledger.requests[0].state, .forwarded)
        XCTAssertThrowsError(try ledger.cancel(request.id))
    }
    func testRejectHostConfusionAndCredentials() {
        for link in ["http://pixmaq.com.br/", "https://pixmaq.com.br.attacker.test/", "https://pixmaq.com.br@attacker.test/", "https://user:pass@pixmaq.com.br/", "javascript:alert(1)", "https://pixmaq.com.br:8443/"] {
            XCTAssertThrowsError(try Provider.pixmaq.officialURL(link))
        }
        XCTAssertNoThrow(try Provider.pixmaq.officialURL("https://www.pixmaq.com.br/"))
    }
    func testPersistenceDoesNotMarkPendingAsSuccess() throws {
        var (ledger, machine) = try configured()
        _ = try ledger.request(id: UUID(), machineID: machine.id, quantity: 2, reason: "Promoção")
        let restored = try JSONDecoder().decode(Ledger.self, from: JSONEncoder().encode(ledger)).validated()
        XCTAssertEqual(restored.requests.first?.state, .requested)
    }
}
