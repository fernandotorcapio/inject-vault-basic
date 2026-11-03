import SwiftUI

@MainActor struct ContentView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        TabView {
            CatalogueView().tabItem { Label("Catálogo", systemImage: "square.grid.2x2") }
            LocalMachinesView().tabItem { Label("Meus cadastros", systemImage: "tray") }
            #if VAULT_BASIC
            BasicInfoView().tabItem { Label("Sobre", systemImage: "info.circle") }
            #else
            TagInspectionView().tabItem { Label("NFC", systemImage: "wave.3.right") }
            #endif
        }
        .alert("Dados locais", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("Entendi") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

@MainActor struct CatalogueView: View {
    @State private var query = ""
    private let catalogue: Catalogue?
    private let error: String?
    init() {
        do { catalogue = try Catalogue.load(); error = nil }
        catch { catalogue = nil; self.error = error.localizedDescription }
    }
    private var filtered: [CatalogueEntry] { catalogue?.entries.filter { $0.matches(query) } ?? [] }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("INJECT VAULT", systemImage: "wave.3.right.circle").font(.caption.weight(.bold))
                        Text("Conheça o sistema.\nConfira a origem.").font(.title.bold())
                        Text("Catálogo informativo e leitura de etiquetas próprias.").foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                if let catalogue {
                    Section {
                        Text(catalogue.scope).font(.subheadline)
                        Text("\(catalogue.entries.count) entradas · fontes conferidas em \(catalogue.verifiedAt)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section("Sistemas e produtos") {
                    ForEach(filtered) { entry in
                        NavigationLink {
                            CatalogueDetailView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.name).font(.headline)
                                Text(entry.kind).font(.subheadline).foregroundStyle(.secondary)
                                Text(entry.products.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                Label("Não conectado", systemImage: "circle.dashed").font(.caption).foregroundStyle(.orange)
                            }.padding(.vertical, 8)
                        }
                    }
                    if filtered.isEmpty && catalogue != nil { Text("Nenhum resultado. Tente o nome do fornecedor ou produto.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Catálogo").searchable(text: $query, prompt: "Sistema, produto ou aplicação")
        }
    }
}

@MainActor struct CatalogueDetailView: View {
    let entry: CatalogueEntry
    var body: some View {
        List {
            Section {
                Text(entry.kind).font(.subheadline).foregroundStyle(.secondary)
                Text(entry.summary)
                LabeledContent("Ecossistema", value: entry.family)
                Label("Integração não conectada", systemImage: "circle.dashed").foregroundStyle(.orange)
            }
            Section("Produtos citados pelo fornecedor") { ForEach(entry.products, id: \.self) { Text($0) } }
            Section("Aplicações documentadas") { ForEach(entry.applications, id: \.self) { Text($0) } }
            Section("Recursos do operador") { Text(entry.operatorFeature) }
            Section("Compatibilidade com máquinas") {
                if entry.machineModelsVerified.isEmpty {
                    Text("Nenhum modelo específico de máquina foi validado neste app. O fornecedor precisa confirmar a compatibilidade do equipamento do proprietário.")
                } else { ForEach(entry.machineModelsVerified, id: \.self) { Text($0) } }
            }
            Section("Fontes oficiais") {
                ForEach(entry.sources, id: \.url) { source in
                    if let url = URL(string: source.url), url.scheme == "https" {
                        Link(destination: url) { Label(source.title, systemImage: "arrow.up.right.square") }
                    }
                }
            }
            Section {
                Text("Consultar um fornecedor ou cadastrar uma máquina não autoriza pagamentos, não confirma créditos e não identifica vulnerabilidades.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(entry.name).navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor struct LocalMachinesView: View {
    @EnvironmentObject var store: AppStore
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Cadastros informados por você. Não representam máquinas descobertas ou conexões verificadas.").foregroundStyle(.secondary)
                }
                if store.ledger.machines.isEmpty {
                    Section { Label("Nenhuma máquina cadastrada", systemImage: "tray") }
                }
                ForEach(store.ledger.machines) { machine in
                    Section {
                        Text(machine.name).font(.headline)
                        LabeledContent("Sistema informado", value: machine.provider.rawValue)
                        if !machine.reference.isEmpty { LabeledContent("Referência", value: machine.reference) }
                        Label("Sem integração com a máquina", systemImage: "circle.dashed").font(.caption).foregroundStyle(.orange)
                    }
                }
                Section { Button { adding = true } label: { Label("Adicionar cadastro local", systemImage: "plus") }.disabled(!store.writable) }
            }.navigationTitle("Meus cadastros").sheet(isPresented: $adding) { LocalMachineForm() }
        }
    }
}

@MainActor struct LocalMachineForm: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var reference = ""
    @State private var provider: Provider = .pixmaq
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Dados do equipamento próprio") {
                    TextField("Nome da máquina", text: $name)
                    TextField("Referência ou modelo (opcional)", text: $reference)
                    Picker("Sistema", selection: $provider) {
                        ForEach(Provider.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section { Text("Este cadastro é local e não autentica o proprietário em sistemas externos. Não informe senhas ou chaves.").foregroundStyle(.secondary) }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Novo cadastro").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salvar") {
                            do {
                                try store.commit { _ = try $0.addMachine(name: name, provider: provider, reference: reference, officialLink: "") }
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.writable)
                    }
                }
        }
    }
}

@MainActor struct TagInspectionView: View {
    @StateObject private var reader = NFCReader()
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image(systemName: "wave.3.right.circle").font(.system(size: 64, weight: .light)).foregroundStyle(.blue)
                    Text("Leitura NDEF").font(.title2.bold())
                    Text("Inspecione uma etiqueta própria. Conteúdo é exibido como dado, sem executar comandos ou abrir links.")
                    Button("Ler etiqueta NFC") { reader.scan() }.disabled(!reader.available || reader.active)
                    Text(reader.available ? reader.status : "NFC indisponível neste aparelho ou simulador. É necessário um iPhone físico compatível e assinatura com a capacidade NFC.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(reader.records) { record in
                    Section(record.kind) {
                        Text(record.text).textSelection(.enabled)
                        DisclosureGroup("Bytes do conteúdo") { Text(record.hex).font(.caption.monospaced()).textSelection(.enabled) }
                    }
                }
                Section { Text("Esta função não lê cartões protegidos, não emula pagamentos e não libera créditos.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("NFC")
        }
    }
}
