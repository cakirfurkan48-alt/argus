import Foundation

// MARK: - BIST Sektör Engine
// Sektör rotasyonu ve güç analizi
// XBANK, XUSIN, XHOLD gibi endeksleri takip eder

actor BistSektorEngine {
    static let shared = BistSektorEngine()
    
    private init() {}
    
    // MARK: - Sektör Listesi
    
    static let sectors: [(code: String, name: String, icon: String)] = [
        ("XBANK", "Bankacılık", "building.columns.fill"),
        ("XUSIN", "Sınai", "gear.circle.fill"),
        ("XHOLD", "Holding", "briefcase.fill"),
        ("XGMYO", "GYO", "building.2.fill"),
        ("XULAS", "Ulaştırma", "airplane"),
        ("XBLSM", "Teknoloji", "cpu.fill"),
        ("XELKT", "Elektrik", "bolt.fill"),
        ("XTRZM", "Turizm", "sun.max.fill")
    ]
    
    // MARK: - Ana Analiz
    
    func analyze() async throws -> BistSektorResult {
        var sectorData: [BistSektorItem] = []
        
        // Her sektör için veri çek
        for sector in Self.sectors {
            do {
                let quote = try await BorsaPyProvider.shared.getSectorIndex(code: sector.code)
                
                // Performans hesapla
                let dailyChange = quote.changePercent
                let momentum: SektorMomentum
                
                if dailyChange > 2 { momentum = .strong }
                else if dailyChange > 0.5 { momentum = .positive }
                else if dailyChange > -0.5 { momentum = .neutral }
                else if dailyChange > -2 { momentum = .negative }
                else { momentum = .weak }
                
                sectorData.append(BistSektorItem(
                    code: sector.code,
                    name: sector.name,
                    icon: sector.icon,
                    value: quote.last,
                    dailyChange: dailyChange,
                    momentum: momentum,
                    volume: quote.volume
                ))
            } catch {
                print("⚠️ Sektör verisi alınamadı: \(sector.code)")
            }
        }
        
        // Sıralama (en güçlüden en zayıfa)
        sectorData.sort { $0.dailyChange > $1.dailyChange }
        
        // Rotasyon Analizi
        let rotation = analyzeRotation(sectors: sectorData)
        
        return BistSektorResult(
            sectors: sectorData,
            strongestSector: sectorData.first,
            weakestSector: sectorData.last,
            rotation: rotation,
            timestamp: Date()
        )
    }
    
    // MARK: - Rotasyon Analizi
    
    private func analyzeRotation(sectors: [BistSektorItem]) -> SektorRotasyon {
        guard !sectors.isEmpty else { return .belirsiz }
        
        let strongest = sectors.first!
        let weakest = sectors.last!
        
        // Bankacılık liderliği - risk iştahı yüksek
        if strongest.code == "XBANK" && strongest.dailyChange > 1 {
            return .riskOn
        }
        
        // Holding/GYO liderliği - defansif
        if strongest.code == "XHOLD" || strongest.code == "XGMYO" {
            return .defansif
        }
        
        // Sınai güçlü - büyüme odaklı
        if strongest.code == "XUSIN" && strongest.dailyChange > 0.5 {
            return .buyume
        }
        
        // Teknoloji liderliği
        if strongest.code == "XBLSM" {
            return .teknoloji
        }
        
        // Genel dağılım
        let avgChange = sectors.map { $0.dailyChange }.reduce(0, +) / Double(sectors.count)
        if avgChange > 1 { return .riskOn }
        if avgChange < -1 { return .riskOff }
        
        return .karisik
    }
    
    // MARK: - Sembolün Sektörünü Bul
    
    func getSector(for symbol: String) -> String? {
        // Basit mapping (gerçek uygulamada API'den alınmalı)
        let cleanSymbol = symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
        
        let bankSymbols = ["AKBNK", "GARAN", "ISCTR", "YKBNK", "HALKB", "VAKBN", "TSKB"]
        let industrialSymbols = ["EREGL", "KRDMD", "TOASO", "FROTO", "TUPRS", "PETKM"]
        let holdingSymbols = ["SAHOL", "KCHOL", "DOHOL", "KOZAL", "TAVHL"]
        let techSymbols = ["ASELS", "LOGO", "NETAS"]
        
        if bankSymbols.contains(cleanSymbol) { return "XBANK" }
        if industrialSymbols.contains(cleanSymbol) { return "XUSIN" }
        if holdingSymbols.contains(cleanSymbol) { return "XHOLD" }
        if techSymbols.contains(cleanSymbol) { return "XBLSM" }
        
        return nil
    }
}

// MARK: - Modeller

struct BistSektorResult: Sendable {
    let sectors: [BistSektorItem]
    let strongestSector: BistSektorItem?
    let weakestSector: BistSektorItem?
    let rotation: SektorRotasyon
    let timestamp: Date
}

struct BistSektorItem: Sendable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let icon: String
    let value: Double
    let dailyChange: Double
    let momentum: SektorMomentum
    let volume: Double
}

enum SektorMomentum: String, Sendable {
    case strong = "Güçlü"
    case positive = "Pozitif"
    case neutral = "Nötr"
    case negative = "Negatif"
    case weak = "Zayıf"
    
    var color: String {
        switch self {
        case .strong, .positive: return "green"
        case .neutral: return "yellow"
        case .negative, .weak: return "red"
        }
    }
}

enum SektorRotasyon: String, Sendable {
    case riskOn = "Risk Açık (Bankalar Lider)"
    case riskOff = "Risk Kapalı"
    case defansif = "Defansif (Holdingler)"
    case buyume = "Büyüme (Sınai)"
    case teknoloji = "Teknoloji Odaklı"
    case karisik = "Karışık/Belirsiz"
    case belirsiz = "Veri Yok"
}
