import SwiftUI

struct MarketView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @ObservedObject var notificationStore = NotificationStore.shared
    
    // UI State
    @State private var showAddSymbolSheet = false
    @State private var showNotifications = false
    @State private var showAetherDetail = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                // Main Content
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Zone 1: Aether HUD (Dynamic Header)
                        AetherHUDView(
                            rating: viewModel.macroRating,
                            onTap: { showAetherDetail = true }
                        )
                        .onAppear {
                            if viewModel.macroRating == nil {
                                viewModel.loadMacroEnvironment()
                            }
                        }
                        
                        // MARK: - Zone 1.5: Scout Stories (Instagram-style)
                        ScoutStoriesBar()
                            .padding(.top, 8)
                        
                        // MARK: - Zone 2: Smart Strip (The Ticker)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PİYASA GÖZLEM")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            
                            SmartTickerStrip(viewModel: viewModel)
                        }
                        
                        
                        // MARK: - Zone 1.5: Demeter Active Shocks (Market Context)
                        if !viewModel.activeShocks.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.activeShocks) { shock in
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(shock.type.displayName)
                                                    .font(.caption)
                                                    .bold()
                                                    .foregroundColor(.primary)
                                                Text(shock.description)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.secondaryBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 8)
                        }
                        
                        Divider()
                            .background(Theme.border)
                            .padding(.vertical, 16)
                        
                        // MARK: - Zone 3: Crystal Watchlist
                        VStack(alignment: .leading, spacing: 12) {
                            // List Header
                            HStack {
                                Text("İZLEME LİSTESİ")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                
                                Spacer()
                                
                                // Live Toggle (Mini)
                                HStack(spacing: 4) {
                                    Circle().fill(viewModel.isLiveMode ? Color.green : Color.gray).frame(width: 6, height: 6)
                                    Text(viewModel.isLiveMode ? "LIVE" : "DELAY")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if viewModel.watchlist.isEmpty {
                                MarketEmptyStateView()
                                    .padding(.top, 40)
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.watchlist, id: \.self) { symbol in
                                        NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                                            CrystalWatchlistRow(
                                                symbol: symbol,
                                                quote: viewModel.quotes[symbol],
                                                candles: viewModel.candles[symbol]
                                            )
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // No grey highlight
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteSymbol(symbol)
                                            } label: {
                                                Label("Listeden Sil", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 120) // Space for FAB + tab bar
                    }
                }
                .refreshable {
                    viewModel.loadData()
                }
                
                // MARK: - Overlays (FAB & Notifications)
                VStack {
                    // Top Bar (Ghost)
                    HStack {
                       Spacer()
                       Button(action: { showNotifications = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                                
                                if notificationStore.unreadCount > 0 {
                                    Circle().fill(Color.red).frame(width: 10, height: 10).offset(x: 2, y: -2)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Floating Action Button (FAB)
                    HStack {
                        Spacer()
                        Button(action: { showAddSymbolSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 56, height: 56)
                                .background(Theme.primary) // Mint/Gold
                                .clipShape(Circle())
                                .shadow(color: Theme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Extra padding to sit above tab bar
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: StockDetailView(symbol: viewModel.selectedSymbolForDetail ?? "", viewModel: viewModel),
                    isActive: Binding(
                        get: { viewModel.selectedSymbolForDetail != nil },
                        set: { if !$0 { viewModel.selectedSymbolForDetail = nil } }
                    )
                ) {
                    EmptyView()
                }
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSymbolSheet) {
                AddSymbolSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAetherDetail) {
                if let macro = viewModel.macroRating {
                    ArgusAetherDetailView(rating: macro)
                } else {
                    Text("Aether Verisi Yükleniyor...")
                        .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(viewModel: viewModel)
            }
        }
    }
    
    private func deleteSymbol(_ symbol: String) {
        if let index = viewModel.watchlist.firstIndex(of: symbol) {
            viewModel.deleteFromWatchlist(at: IndexSet(integer: index))
        }
    }
}

// Preserve existing helpers (AddSymbolSheet etc) unless moved. 
// Assuming they are needed here or in a separate file. 
// For this rewrite, I will assume AddSymbolSheet is available or needs to be re-declared if it was only in this file. 
// The previous view had AddSymbolSheet inside. I should keep it to avoid compilation error.

// ... [Copying AddSymbolSheet struct from previous file content to ensure it compiles] ...
// Ideally this should be moved to its own file, but sticking to "Single File Rewrite" for safety.

struct AddSymbolSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var symbol: String = ""
    @FocusState private var isFocused: Bool
    
    let popularSymbols = ["NVDA", "AMD", "TSLA", "AAPL", "MSFT", "META", "AMZN", "GOOGL", "NFLX", "COIN"]
    
    var body: some View {
        NavigationView {
             ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                     HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.textSecondary)
                        TextField("Sembol Ara (Örn: PLTR)", text: $symbol)
                            .foregroundColor(Theme.textPrimary)
                            .disableAutocorrection(true)
                            .focused($isFocused)
                            .onChange(of: symbol) { _, newValue in viewModel.search(query: newValue) }
                            .onSubmit { addAndDismiss(symbol) }
                        
                        if !symbol.isEmpty {
                            Button(action: { symbol = ""; viewModel.searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if !symbol.isEmpty && !viewModel.searchResults.isEmpty {
                        List(viewModel.searchResults) { result in
                            Button(action: { addAndDismiss(result.symbol) }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.symbol).bold().foregroundColor(Theme.textPrimary)
                                        Text(result.description).font(.caption).foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundColor(Theme.primary)
                                }
                            }
                            .listRowBackground(Theme.secondaryBackground)
                        }
                        .listStyle(.plain)
                        .background(Theme.background)
                    } else {
                        VStack(alignment: .leading) {
                            Text("Popüler").font(.caption).foregroundColor(Theme.textSecondary).padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(popularSymbols, id: \.self) { item in
                                        Button(action: { addAndDismiss(item) }) {
                                            Text(item).padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(Theme.secondaryBackground).foregroundColor(Theme.textPrimary).cornerRadius(20)
                                        }
                                    }
                                }.padding(.horizontal)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Hisse Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Kapat") { presentationMode.wrappedValue.dismiss() } } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true } }
        }
    }
    
    private func addAndDismiss(_ symbolToAdd: String) {
        if !symbolToAdd.isEmpty {
            viewModel.addSymbol(symbolToAdd)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// Keeping MarketEmptyStateView too
struct MarketEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("Takip listen boş")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("İzlemek istediğin hisseleri eklemek için\n+ butonuna bas.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
