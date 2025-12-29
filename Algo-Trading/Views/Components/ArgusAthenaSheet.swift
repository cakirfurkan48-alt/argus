import SwiftUI

struct ArgusAthenaSheet: View {
    let result: AthenaFactorResult?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.teal)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Athena Faktör Analizi")
                            .font(.headline)
                        Text("Smart Beta & Strateji")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Theme.secondaryBackground)
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let result = result {
                            // 1. Main Card Reuse
                            AthenaFactorCard(result: result)
                                .padding(.top)
                            
                            // 2. Explanation / Insight
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Analiz Özeti")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Text(generateExplanation(for: result))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                            
                            // 3. Definitions
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Faktör Tanımları")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                definitionRow(title: "Değer (Value)", desc: "Hissenin fiyatının kazanç ve varlıklarına göre ucuzluğunu ölçer.")
                                definitionRow(title: "Kalite (Quality)", desc: "Şirketin karlılık, borçluluk ve yönetim kalitesini ölçer.")
                                definitionRow(title: "Momentum", desc: "Fiyatın yükseliş trendi ve gücünü ölçer.")
                                definitionRow(title: "Risk (Low Vol)", desc: "Fiyat hareketlerindeki dalgalanma ve istikrarı ölçer.")
                            }
                            .padding(.bottom, 40)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                                Text("Analiz verisi bulunamadı.")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func definitionRow(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.teal)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private func generateExplanation(for result: AthenaFactorResult) -> String {
        return "Athena, bu hisse için \(Int(result.factorScore))/100 puan hesapladı. " +
        "Strateji etiketi: '\(result.styleLabel)'. " +
        "Ağırlıklı olarak \(highestFactor(result)) faktörü öne çıkıyor."
    }
    
    private func highestFactor(_ r: AthenaFactorResult) -> String {
        let factors = [
            ("Değer", r.valueFactorScore),
            ("Kalite", r.qualityFactorScore),
            ("Momentum", r.momentumFactorScore),
            ("Risk", r.riskFactorScore)
        ]
        return factors.max(by: { $0.1 < $1.1 })?.0 ?? "Dengeli"
    }
}
