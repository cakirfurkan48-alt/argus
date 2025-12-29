import SwiftUI

struct SettingsSignalsView: View {
    @AppStorage("notifyOrion") private var notifyOrion = true
    @AppStorage("notifyArgus") private var notifyArgus = false
    @AppStorage("notifyAether") private var notifyAether = true
    @AppStorage("notifyHermes") private var notifyHermes = true
    
    var body: some View {
        Form {
            Section(header: Text("Algoritrmik Sinyaller")) {
                Toggle(isOn: $notifyOrion) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Orion Teknik Sinyaller")
                            Text("RSI, Bollinger ve Trend değişimleri")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.blue)
                    }
                }
                
                Toggle(isOn: $notifyArgus) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Argus Fundamental")
                            Text("Yeni bilanço ve temel skor değişimleri")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        ArgusEyeView(mode: .argus, size: 20)
                    }
                }
                
                Toggle(isOn: $notifyAether) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Aether Makro Rejim")
                            Text("Risk-On / Risk-Off geçiş uyarıları")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cloud.sun.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section(header: Text("Hermes Haber Akışı")) {
                Toggle(isOn: $notifyHermes) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Önemli Haber Uyarıları")
                            Text("Yüksek etkili (High Impact) haberler için bildirim")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "newspaper.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Section(footer: Text("Bu ayarlar bildirimlerin sıklığını etkiler. Aktif piyasa saatlerinde daha sık bildirim alabilirsiniz.")) {
                EmptyView()
            }
        }
        .navigationTitle("Sinyal Tercihleri")
    }
}
