#if VAULT_BASIC
import Foundation
import Combine

struct NFCRecordView: Identifiable {
    let id = UUID()
    let kind: String
    let text: String
    let hex: String
}

final class NFCReader: ObservableObject {
    @Published var records: [NFCRecordView] = []
    @Published var status = "A versão básica não inclui NFC."
    @Published var active = false
    var available: Bool { false }
    func scan() { status = "A versão básica não inclui NFC." }
}
#else
import CoreNFC
import Foundation
import Combine

struct NFCRecordView: Identifiable {
    let id = UUID()
    let kind: String
    let text: String
    let hex: String
}

final class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    @Published var records: [NFCRecordView] = []
    @Published var status = "Pronto para ler uma etiqueta NDEF."
    @Published var active = false
    private var session: NFCTagReaderSession?
    private var readCompleted = false
    var available: Bool { NFCTagReaderSession.readingAvailable }

    func scan() {
        guard !active else { return }
        guard available else { status = "NFC indisponível neste dispositivo. Use um iPhone físico compatível."; return }
        active = true
        readCompleted = false
        status = "Aproxime a parte superior do iPhone da etiqueta."
        guard let reader = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil) else {
            active = false; status = "Não foi possível iniciar o leitor NFC."; return
        }
        reader.alertMessage = "Leia uma etiqueta própria. Nenhum crédito será autorizado pela leitura."
        session = reader
        reader.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "Aproxime apenas uma etiqueta por vez."
            session.restartPolling(); return
        }
        let ndef: NFCNDEFTag
        switch tag {
        case .miFare(let value): ndef = value
        case .iso15693(let value): ndef = value
        case .iso7816(let value): ndef = value
        case .feliCa(let value): ndef = value
        @unknown default: session.invalidate(errorMessage: "Tipo de etiqueta não suportado."); return
        }
        session.connect(to: tag) { [weak self] error in
            guard error == nil else { session.invalidate(errorMessage: "Não foi possível conectar à etiqueta."); return }
            ndef.queryNDEFStatus { status, _, error in
                guard error == nil, status != .notSupported else {
                    session.invalidate(errorMessage: "Esta etiqueta não oferece NDEF legível."); return
                }
                ndef.readNDEF { message, error in
                    guard error == nil, let message = message else {
                        session.invalidate(errorMessage: "Não foi possível ler o conteúdo NDEF."); return
                    }
                    self?.receive(message)
                    session.alertMessage = "Etiqueta lida. Nenhuma ação externa foi executada."
                    session.invalidate()
                }
            }
        }
    }

    private func receive(_ message: NFCNDEFMessage) {
        let values = message.records.prefix(32).map { record -> NFCRecordView in
            let text: String
            let payload = record.wellKnownTypeTextPayload()
            if let value = payload.0, !value.isEmpty {
                text = String(value.prefix(4096))
            } else if let uri = record.wellKnownTypeURIPayload() {
                text = String(uri.absoluteString.prefix(4096))
            } else { text = "Conteúdo binário — exibido em hexadecimal." }
            return NFCRecordView(kind: String(data: record.type, encoding: .utf8) ?? "NDEF",
                text: text, hex: record.payload.prefix(1024).map { String(format: "%02X", $0) }.joined(separator: " "))
        }
        DispatchQueue.main.async { [weak self] in
            self?.records = values
            self?.readCompleted = true
            self?.status = "\(values.count) registro(s) lido(s). Links não foram abertos."
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfc = error as? NFCReaderError
        DispatchQueue.main.async { [weak self] in
            self?.active = false
            self?.session = nil
            if self?.readCompleted != true {
                self?.status = nfc?.code == .readerSessionInvalidationErrorUserCanceled
                    ? "Leitura cancelada."
                    : "Leitura encerrada: \(error.localizedDescription)"
            }
        }
    }
}
#endif
