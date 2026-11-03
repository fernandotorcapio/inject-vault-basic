import Foundation

public enum VaultError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public enum Provider: String, Codable, CaseIterable, Identifiable {
    case pixmaq = "Pixmaq", vendpago = "VendPago", nayax = "Nayax", payblu = "Payblu", cashmaq = "CashMAQ"
    public var id: String { rawValue }
    public var domains: [String] {
        switch self {
        case .pixmaq: return ["pixmaq.com.br"]
        case .vendpago, .payblu: return ["vendpago.com.br", "erpvending.com.br"]
        case .nayax: return ["nayax.com.br", "nayax.com"]
        case .cashmaq: return ["cashmaq.com.br"]
        }
    }
    public var documentation: URL {
        switch self {
        case .pixmaq: return URL(string: "https://pixmaq.com.br/qr_interativo_liberacao_automatica")!
        case .vendpago, .payblu: return URL(string: "https://conteudo.vendpago.com.br/faq/compatibilidade-maquinas/")!
        case .nayax: return URL(string: "https://www.nayax.com.br/servico/diversao-eletronica/")!
        case .cashmaq: return URL(string: "https://cashmaq.com.br/solucoes/pix-para-gruas")!
        }
    }
    public func officialURL(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= 2048, let url = URL(string: text),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https", let host = parts.host?.lowercased(),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443,
              domains.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else {
            throw VaultError.invalid("Use um link HTTPS oficial de \(rawValue), fornecido pelo dono. Não use senha na URL.")
        }
        return url
    }
}

public struct Machine: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let provider: Provider
    public let reference: String
    public let officialLink: String
    public let createdAt: Date
}

public enum RequestState: String, Codable {
    case requested, forwarded, cancelled
    public var label: String {
        switch self {
        case .requested: return "Aguardando autorização"
        case .forwarded: return "Encaminhado · sem confirmação"
        case .cancelled: return "Pedido local cancelado"
        }
    }
}

public struct CreditRequest: Identifiable, Codable, Equatable {
    public let id: UUID
    public let machineID: UUID
    public let quantity: Int
    public let reason: String
    public let createdAt: Date
    public var state: RequestState
}

public protocol CreditProvider {
    func destination(for machine: Machine) throws -> URL
}

/// Handoff ao fornecedor; não emite comandos e nunca retorna "crédito liberado".
public struct OfficialPortalProvider: CreditProvider {
    public init() {}
    public func destination(for machine: Machine) throws -> URL {
        guard !machine.officialLink.isEmpty else {
            throw VaultError.invalid("Falta o link oficial da promoção ou do portal, fornecido pelo proprietário.")
        }
        return try machine.provider.officialURL(machine.officialLink)
    }
}

public struct Ledger: Codable {
    public let schemaVersion: Int
    public private(set) var machines: [Machine]
    public private(set) var requests: [CreditRequest]
    public init() { schemaVersion = 1; machines = []; requests = [] }

    @discardableResult public mutating func addMachine(name: String, provider: Provider,
        reference: String, officialLink: String, id: UUID = UUID()) throws -> Machine {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let serial = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = officialLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, serial.count <= 100, machines.count < 100,
              !machines.contains(where: { $0.id == id }) else {
            throw VaultError.invalid("Informe um nome de até 80 caracteres. Limite: 100 máquinas locais.")
        }
        if !link.isEmpty { _ = try provider.officialURL(link) }
        let machine = Machine(id: id, name: title, provider: provider, reference: serial,
                              officialLink: link, createdAt: Date())
        machines.append(machine)
        return machine
    }

    @discardableResult public mutating func request(id: UUID, machineID: UUID,
        quantity: Int, reason: String) throws -> CreditRequest {
        let clean = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard machines.contains(where: { $0.id == machineID }), (1...20).contains(quantity),
              !clean.isEmpty, clean.count <= 240 else {
            throw VaultError.invalid("Escolha uma máquina, 1 a 20 jogadas e um motivo de até 240 caracteres.")
        }
        if let old = requests.first(where: { $0.id == id }) {
            guard old.machineID == machineID, old.quantity == quantity, old.reason == clean else {
                throw VaultError.invalid("A mesma chave já foi usada com dados diferentes.")
            }
            return old
        }
        guard requests.count < 2000 else { throw VaultError.invalid("Limite de registros locais atingido. Exporte o histórico.") }
        let value = CreditRequest(id: id, machineID: machineID, quantity: quantity,
                                  reason: clean, createdAt: Date(), state: .requested)
        requests.append(value)
        return value
    }

    public func destination(for requestID: UUID) throws -> URL {
        guard let request = requests.first(where: { $0.id == requestID }), request.state != .cancelled,
              let machine = machines.first(where: { $0.id == request.machineID }) else {
            throw VaultError.invalid("Pedido indisponível ou cancelado.")
        }
        return try OfficialPortalProvider().destination(for: machine)
    }

    public mutating func markForwarded(_ id: UUID) throws {
        _ = try destination(for: id)
        guard let index = requests.firstIndex(where: { $0.id == id }) else { return }
        requests[index].state = .forwarded
    }

    public mutating func cancel(_ id: UUID) throws {
        guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].state == .requested else {
            throw VaultError.invalid("Após encaminhar, o cancelamento precisa ser tratado com o fornecedor.")
        }
        requests[index].state = .cancelled
    }

    public func validated() throws -> Ledger {
        guard schemaVersion == 1, machines.count <= 100, requests.count <= 2000,
              Set(machines.map(\.id)).count == machines.count,
              Set(requests.map(\.id)).count == requests.count else {
            throw VaultError.invalid("Arquivo local inválido; os dados foram preservados.")
        }
        for machine in machines {
            guard !machine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  machine.name.count <= 80, machine.reference.count <= 100 else {
                throw VaultError.invalid("Cadastro local inválido.")
            }
            if !machine.officialLink.isEmpty { _ = try machine.provider.officialURL(machine.officialLink) }
        }
        for request in requests {
            guard machines.contains(where: { $0.id == request.machineID }), (1...20).contains(request.quantity),
                  !request.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  request.reason.count <= 240 else { throw VaultError.invalid("Histórico local inválido.") }
        }
        return self
    }
}
