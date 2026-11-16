//
//  BuyScreen.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 7. BUY SCREEN  (opened by the Buy navigation link)
// =====================================================================
struct BuyScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: ShopType = .seeds
    @State private var showAsk = true

    var body: some View {
        ZStack {
            SeasonBackdrop()
            VStack(spacing: 12) {
                HStack {
                    // Always lets you go back to the garden
                    GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                        dismiss()
                    }
                    Spacer()
                    PointsPill()
                }

                // Switch between the two shops any time
                HStack(spacing: 10) {
                    GameButton(title: "Seeds", width: 110, height: 40) { type = .seeds }
                        .opacity(type == .seeds ? 1 : 0.45)
                    GameButton(title: "Gears", width: 110, height: 40) { type = .gears }
                        .opacity(type == .gears ? 1 : 0.45)
                }

                Text(type == .seeds ? "Seed Shop" : "Gear Shop")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if type == .seeds {
                            ForEach(Catalog.crops) { crop in
                                ShopRow(
                                    id: "seed:\(crop.name)",
                                    title: crop.name.capitalized + " Seeds",
                                    subtitle: "Grows in \(timeText(crop.growSeconds))",
                                    price: crop.price
                                )
                            }
                        } else {
                            ForEach(Catalog.sprinklers) { sp in
                                ShopRow(
                                    id: "gear:\(sp.tier)",
                                    title: sp.name,
                                    subtitle: "Plants nearby grow x\(sp.speed.formatted()) faster",
                                    price: sp.price
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // The question when you arrive
        
    }
}

struct ShopRow: View {
    let id: String
    let title: String
    let subtitle: String
    let price: Int
    @ObservedObject private var store = GameStore.shared

    var body: some View {
        let stock = store.stockToday(id: id, price: price)
        let canBuy = store.points >= price && stock > 0
        HStack(spacing: 12) {
            ItemIcon(id: id, size: 60)
                .saturation(stock > 0 ? 1 : 0.15)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                    if stock <= 2 && stock > 0 {
                        Text("RARE")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.gold.opacity(0.85)))
                            .foregroundStyle(.black)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
                Text("\(Theme.coin) \(price.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(canBuy ? Theme.gold : Theme.bad)
                HStack(spacing: 8) {
                    Text("You have: \(store.count(id))")
                    Text(stock > 0 ? "In stock: \(stock)" : "Out of stock — check back tomorrow")
                        .foregroundStyle(stock > 0 ? Theme.good : Theme.bad)
                }
                .font(.caption2)
                .foregroundStyle(Theme.subtext)
            }
            Spacer()
            GameButton(title: "Buy", width: 72, height: 44) {
                if store.buy(id, price: price) {
                    SoundPlayer.coin()
                } else {
                    Haptics.warning()
                    SoundPlayer.error()
                }
            }
            .disabled(!canBuy)
            .opacity(canBuy ? 1 : 0.4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.panelBorder, lineWidth: 1))
    }
}
