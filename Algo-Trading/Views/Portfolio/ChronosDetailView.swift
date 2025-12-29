import SwiftUI

struct ChronosDetailView: View {
    let result: ChronosResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Hero Verdict Section
                        VStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 48))
                                .foregroundColor(result.ageVerdict.color)
                                .shadow(color: result.ageVerdict.color.opacity(0.5), radius: 10)
                            
                            Text(result.ageVerdict.rawValue)
                                .font(.title2)
                                .bold()
                                .foregroundColor(result.ageVerdict.color)
                            
                            Text("\(result.trendAgeDays) Gündür Trendde")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 24)
                        
                        // 2. Sequential Counter (Exhaustion)
                        sequentialCard
                        
                        // 3. Aroon Energy Chart (Simplified Visual)
                        aroonCard
                        
                        // 4. Explanation
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Chronos Analizi")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(getExplanation())
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Chronos Zaman Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var sequentialCard: some View {
        VStack(spacing: 12) {
            Text("Yorulma Sayacı (Sequential)")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            HStack(spacing: 20) {
                // Circle Counter
                ZStack {
                    Circle()
                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(13, abs(result.sequentialCount))) / 13.0)
                        .stroke(
                            result.sequentialCount > 0 ? Color.red : Color.green,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                    
                    Text("\(abs(result.sequentialCount))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                
                VStack(alignment: .leading) {
                    if result.sequentialCount > 0 {
                        Text("Yükseliş Sayımı")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("9 veya 13 olunca düşüş riski artar.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    } else if result.sequentialCount < 0 {
                        Text("Düşüş Sayımı")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text("9 veya 13 olunca tepki (alış) ihtimali artar.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Text("Nötr")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var aroonCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Trend Enerjisi (Aroon)")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Up Bar
                VStack {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 30, height: 100)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: 30, height: CGFloat(result.aroonUp))
                    }
                    Text("UP")
                        .font(.caption)
                        .bold()
                }
                
                // Down Bar
                VStack {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 30, height: 100)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 30, height: CGFloat(result.aroonDown))
                    }
                    Text("DOWN")
                        .font(.caption)
                        .bold()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if result.aroonUp > 70 {
                        Text("Boğalar Güçlü 💪")
                            .foregroundColor(.green)
                    } else if result.aroonDown > 70 {
                        Text("Ayılar Güçlü 🐻")
                            .foregroundColor(.red)
                    } else {
                        Text("Kararsız Piyasa 😴")
                            .foregroundColor(.gray)
                    }
                    
                    Text("Trendin gücünü ve yönünü ölçer. 70 üstü baskın demektir.")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private func getExplanation() -> String {
        switch result.ageVerdict {
        case .baby:
            return "Trend henüz çok yeni (Bebek). Otoritesini ispatlamadı, volatilite yüksek olabilir."
        case .prime:
            return "Trend en verimli çağında (Olgun). Momentum oturmuş, güvenli bölge."
        case .old:
            return "Trend yaşlanmaya başladı. Kar realizasyonları görülebilir."
        case .ancient:
            return "Trend çok yaşlı (Lanetli). Ortalamaya dönüş riski çok yüksek. Dikkat et."
        case .downtrend:
            return "Şu an bir yükseliş trendi yok, düşüş hakim."
        default:
            return "Veri yetersiz."
        }
    }
}
