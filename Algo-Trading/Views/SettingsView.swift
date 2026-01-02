import SwiftUI

struct SettingsView: View {
    @ObservedObject var tradingViewModel: TradingViewModel
    @StateObject private var settingsViewModel = SettingsViewModel()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isInputFocused: Bool
    @ObservedObject private var safeService = SafeUniverseService.shared
    @State private var showRoadmap = false // Added state
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Profile / Header Card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.tint)
                                    .frame(width: 64, height: 64)
                                Text("EK")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Argus Team")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                Text("Argus Pro Üyesi")
                                    .font(.caption)
                                    .foregroundColor(Theme.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Theme.tint.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        .padding(20)
                        .background(Theme.cardBackground)
                        .cornerRadius(20)
                        
                        // 2. Main Settings
                        VStack(spacing: 2) {
                            SettingsRow(icon: "moon.fill", title: "Karanlık Mod", isToggle: true, isOn: $settingsViewModel.isDarkMode)
                        }
                        .background(Theme.cardBackground)
                        .cornerRadius(20)
                        .clipped()
                        
                        // 3. Trading Intelligence
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRADING INTELLIGENCE")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 12)
                            
                            VStack(spacing: 2) {
                                // Phoenix Picker
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.orange)
                                    }
                                    Text("Phoenix Zaman Dilimi")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Picker("", selection: $settingsViewModel.phoenixTimeframe) {
                                        ForEach(PhoenixTimeframe.allCases, id: \.self) { tf in
                                            Text(tf.rawValue).tag(tf)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                }
                                .padding(16)
                                .background(Theme.cardBackground) // Row styling check
                                
                                Divider().padding(.leading, 56)
                                
                                SettingsRow(icon: "brain.head.profile", title: "Risk Toleransı", value: settingsViewModel.riskTolerance.localizedName)
                                Divider().padding(.leading, 56)
                                
                                VStack(spacing: 8) {
                                    SettingsRow(icon: "number.square.fill", title: "Max Pozisyon", value: "\(settingsViewModel.maxOpenPositions)")
                                    
                                    // Stepper for Max Positions
                                    Stepper("Pozisyon Limiti: \(settingsViewModel.maxOpenPositions)", value: $settingsViewModel.maxOpenPositions, in: 1...20)
                                        .padding(.horizontal, 16)
                                        .onChange(of: settingsViewModel.maxOpenPositions) {
                                            // Auto-save happens via AppStorage in ViewModel
                                        }
                                    
                                    Divider().padding(.leading, 56)
                                    
                                    // Data Collection Toggle (User Request)
                                    Toggle(isOn: $settingsViewModel.isDataCollectionEnabled) {
                                        HStack {
                                            Image(systemName: "server.rack")
                                                .foregroundColor(.purple)
                                            VStack(alignment: .leading) {
                                                Text("Veri Koleksiyonu")
                                                    .font(.subheadline)
                                                    .foregroundColor(Theme.textPrimary)
                                                Text("Gelecekteki AI eğitimi için trade verilerini sakla.")
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    
                                    // Copy Data Button
                                    Button(action: {
                                        let json = tradingViewModel.exportTransactionHistoryJSON()
                                        UIPasteboard.general.string = json
                                        // Feedback handled by UI or just assume works (SwiftUI doesn't have easy toast yet without extra code)
                                        // We can change the button text temporarily if we had state, but for now simple action.
                                    }) {
                                        HStack {
                                            Image(systemName: "doc.on.doc")
                                            Text("Verileri Kopyala (JSON)")
                                        }
                                        .font(.caption)
                                        .foregroundColor(Theme.tint)
                                        .padding(.vertical, 8)
                                    }
                                }
                                Divider().padding(.leading, 56)
                                
                                NavigationLink(destination: StrategyLabView()) {
                                    SettingsRow(icon: "slider.horizontal.3", title: "Aktif Stratejiler", value: "Yönet", hasChevron: true)
                                }
                            }
                            .background(Theme.cardBackground)
                            .cornerRadius(20)
                            .clipped()
                        }
                        
                        // 4. Notifications
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BİLDİRİMLER")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 12)
                            
                            VStack(spacing: 2) {
                                SettingsRow(icon: "bell.fill", title: "Bildirimler", isToggle: true, isOn: $settingsViewModel.notificationsEnabled)
                                Divider().padding(.leading, 56)
                                
                                NavigationLink(destination: PriceAlertSettingsView()) {
                                    SettingsRow(icon: "exclamationmark.bubble.fill", title: "Fiyat Alarmları", hasChevron: true)
                                }
                            }
                            .background(Theme.cardBackground)
                            .cornerRadius(20)
                            .clipped()
                        }
                        
                        // 5. ARGUS LABORATORIES
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ARGUS LABORATORIES")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 12)
                            
                            VStack(spacing: 2) {
                                // Argus Voice
                                NavigationLink(destination: ArgusVoiceView()) {
                                    SettingsRow(icon: "mic.fill", title: "Argus Voice", iconColor: .blue, hasChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                // Core Brain (Simulator)
                                NavigationLink(destination: ArgusSimulatorView()) {
                                    SettingsRow(icon: "brain.head.profile", title: "Argus Simulator", iconColor: Theme.tint, hasChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                // Orion (Technical Analysis)
                                NavigationLink(destination: OrionLabView()) {
                                    SettingsRow(icon: "star.fill", title: "Orion Lab", iconColor: .purple, hasChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                // Data Health / Mimir
                                NavigationLink(destination: ArgusDataHealthView()) {
                                    SettingsRow(icon: "eye.fill", title: "Mimir Intelligence", iconColor: .indigo, hasChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                // Roadmap
                                Button(action: { showRoadmap = true }) {
                                    SettingsRow(icon: "map.circle.fill", title: "Gelişim Yol Haritası", iconColor: .orange, hasChevron: true)
                                }
                            }
                            .background(Theme.cardBackground)
                            .cornerRadius(20)
                            .clipped()
                        }
                        
                        // Footer
                        VStack(spacing: 4) {
                            Text("Argus Terminal v2.1")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                            Text("Made with ❤️ by Argus Team")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary.opacity(0.8))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(settingsViewModel.isDarkMode ? .dark : .light)
        .sheet(isPresented: $showRoadmap) {
            RoadmapView()
        }
    }
}

// MARK: - Helper Components

struct SettingsRow: View {
    var icon: String
    var title: String
    var value: String? = nil
    var iconColor: Color = Theme.tint
    var isToggle: Bool = false
    var isOn: Binding<Bool>? = nil
    var hasChevron: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        if let action = action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            rowContent
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Title
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            // Trailing
            if isToggle, let isOn = isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
            } else {
                if let val = value {
                    Text(val)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                if hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .contentShape(Rectangle()) // Make full row tappable for NavigationLink
    }
}


// MARK: - Components (Legal Document Viewer Preserved)
struct LegalDocumentView: View {
    let document: LegalDocument
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.title)
                    .font(.largeTitle)
                    .bold()
                
                Divider()
                
                Text(document.content)
                    .font(.body)
                    .lineSpacing(6)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(document.title)
    }
}
