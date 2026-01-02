import Foundation
import Combine
import SwiftUI

/// FAZ 2: WatchlistViewModel
/// Watchlist yönetimi ve quote verilerini kontrol eden ViewModel.
/// TradingViewModel'den ayrıştırıldı.
@MainActor
final class WatchlistViewModel: ObservableObject {
    
    // MARK: - Watchlist State
    @Published var watchlist: [String] = [] {
        didSet {
            saveWatchlist()
        }
    }
    
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Discovery Lists
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    
    // MARK: - Search State
    @Published var searchResults: [SearchResult] = []
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Services
    private let marketDataProvider = MarketDataProvider.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    private let watchlistKey = "user_watchlist"
    
    // MARK: - Init
    init() {
        loadWatchlist()
        observeMarketDataStore()
    }
    
    // MARK: - Market Data Store Binding
    private func observeMarketDataStore() {
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                guard let self = self else { return }
                // DataValue<Quote> -> Quote dönüşümü
                self.quotes = storeQuotes.compactMapValues { $0.value }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Watchlist Management
    
    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        guard !watchlist.contains(upper) else { return }
        watchlist.append(upper)
        
        // Yeni sembol için veri çek
        Task {
            await loadQuote(for: upper)
        }
    }
    
    func removeSymbol(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
    }
    
    func removeSymbols(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
    }
    
    func moveSymbols(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
    }
    
    func contains(_ symbol: String) -> Bool {
        watchlist.contains(symbol.uppercased())
    }
    
    // MARK: - Quote Loading
    
    func loadQuote(for symbol: String) async {
        let dataValue = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        if let quote = dataValue.value {
            await MainActor.run {
                self.quotes[symbol] = quote
            }
        }
    }
    
    func refreshAllQuotes() async {
        isLoading = true
        defer { isLoading = false }
        
        for symbol in watchlist {
            await loadQuote(for: symbol)
        }
    }
    
    // MARK: - Search
    
    func search(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await marketDataProvider.searchSymbols(query: query)
                await MainActor.run {
                    self.searchResults = results
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveWatchlist() {
        UserDefaults.standard.set(watchlist, forKey: watchlistKey)
    }
    
    private func loadWatchlist() {
        if let saved = UserDefaults.standard.array(forKey: watchlistKey) as? [String] {
            watchlist = saved
        } else {
            // Varsayılan watchlist
            watchlist = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA"]
        }
    }
    
    // MARK: - Discovery
    
    func loadDiscoveryLists() async {
        // MarketDataProvider üzerinden gainers/losers çek
        // Bu fonksiyon TradingViewModel+MarketData'dan taşınacak
    }
}
