import SwiftUI

struct RadarCardView: View {
    let item: RadarItem
    
    var sentimentColor: Color {
        switch item.sentiment {
        case .positive: return Theme.positive
        case .negative: return Theme.negative
        case .neutral: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon / Bank Initial (Simple Visual)
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Header: Bank Name + Badge
                HStack {
                    Text(item.bankName)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text(item.sentiment.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(sentimentColor.opacity(0.2))
                        .foregroundColor(sentimentColor)
                        .cornerRadius(4)
                }
                
                // Content
                Text(item.summary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true) // Allow expansion
                
                // Footer: Time
                HStack(spacing: 2) {
                    Text(item.date, style: .relative)
                    Text(" önce")
                }
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding()
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
