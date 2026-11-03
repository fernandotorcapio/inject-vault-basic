import SwiftUI

@MainActor struct BasicInfoView: View {
    @EnvironmentObject var store: AppStore
    @State private var file: URL?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Inject Vault Basic", systemImage: "square.stack.3d.up").font(.title2.bold())
                    Text("Versão nativa básica · 0.2.0")
                    Text("Catálogo pesquisável e cadastro de equipamentos neste iPhone. Os dados permanecem locais; somente os links de documentação abrem um site externo por sua escolha.")
                }
                Section("Recursos desta versão") {
                    Label("Catálogo com fontes oficiais", systemImage: "checkmark.circle")
                    Label("Cadastro local persistente", systemImage: "checkmark.circle")
                    Label("Exportação JSON dos cadastros", systemImage: "checkmark.circle")
                    Text("Esta versão não inclui NFC, conexão com controladores ou liberação de créditos.").foregroundStyle(.secondary)
                }
                Section("Exportar seus dados") {
                    Button("Preparar arquivo JSON") {
                        do { file = try store.export(); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                    if let file { ShareLink("Salvar ou compartilhar arquivo", item: file) }
                    if let error { Text(error).foregroundStyle(.red) }
                    Text("O arquivo contém os cadastros que você informou. Compartilhe somente com quem deve recebê-los.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Teste pessoal no iPhone") {
                    Text("O IPA gerado na nuvem não vem assinado. A instalação pelo Windows usa sua conta Apple no Sideloadly. A validade e a renovação seguem os limites da Apple; não há renovação executada por este app.")
                }
            }.navigationTitle("Sobre")
        }
    }
}
