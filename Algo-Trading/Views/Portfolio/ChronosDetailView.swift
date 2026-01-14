import SwiftUI

struct ChronosDetailView: View {
    // let result: ChronosResult // REMOVED: Old model no longer exists
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 64))
                        .foregroundColor(Color.gray)
                        .padding(.bottom, 16)
                    
                    Text("Chronos Yükseliyor...")
                        .font(.title)
                        .bold()
                        .foregroundColor(Color.primary)
                    
                    Text("Chronos Modülü, 'İleri Test (Walk-Forward)' motoruna dönüştürülüyor. Artık sadece geçmişi değil, stratejilerin gelecekteki dayanıklılığını test edecek.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal)
                    
                    Text("🚧 Bakım Modu")
                        .font(.caption)
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.yellow)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Chronos Engine")
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
}
