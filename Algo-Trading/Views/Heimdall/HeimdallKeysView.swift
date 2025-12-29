import SwiftUI

struct HeimdallKeysView: View {
    @StateObject private var store = APIKeyStore.shared
    @State private var showingAddSheet = false
    @State private var selectedProvider: ArgusProvider = .fred
    @State private var newKey = ""
    
    var body: some View {
        List {
            Section(header: Text("Kayıtlı Anahtarlar (SSoT)")) {
                if store.keys.isEmpty {
                    Text("Hiç anahtar bulunamadı. Migration bekleniyor veya manuel ekleyin.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(store.keys.values.sorted(by: { $0.provider.rawValue < $1.provider.rawValue })), id: \.provider) { meta in
                        KeyRow(metadata: meta)
                            .swipeActions {
                                Button("Sil", role: .destructive) {
                                    Task { store.deleteKey(provider: meta.provider) }
                                }
                            }
                    }
                }
            }
            
            Section(header: Text("Yeni Anahtar Ekle")) {
                Picker("Sağlayıcı", selection: $selectedProvider) {
                    ForEach(ArgusProvider.allCases.filter { $0.requiresKey }, id: \.self) { prov in
                        Text(prov.displayName).tag(prov)
                    }
                }
                
                TextField("API Key Yapıştır", text: $newKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Anahtarı Kaydet") {
                    guard !newKey.isEmpty else { return }
                    Task {
                        store.setKey(provider: selectedProvider, key: newKey)
                        newKey = ""
                    }
                }
                .disabled(newKey.isEmpty)
            }
            
            Section(footer: Text("SSoT: Single Source of Truth. Bu veriler Keychain'de şifreli saklanır ve tüm uygulama tarafından tek kaynak olarak kullanılır.")) {
                EmptyView()
            }
        }
        .navigationTitle("Anahtar Kasası")
        .task {
            // Force migration check or load on appear if needed, though init handles it.
        }
    }
}

struct KeyRow: View {
    let metadata: APIKeyMetadata
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(metadata.provider.displayName)
                    .font(.headline)
                Text(metadata.maskedPreview)
                    .font(.monospaced(.caption)())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if metadata.isValid {
                Label("Aktif", systemImage: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                VStack(alignment: .trailing) {
                    Label("Hatalı", systemImage: "exclamationmark.shield.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    if let err = metadata.lastErrorCategory {
                        Text(err).font(.caption2).foregroundColor(.red)
                    }
                }
            }
        }
    }
}
