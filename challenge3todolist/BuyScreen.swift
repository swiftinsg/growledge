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
    /// "Bought Dewdrop Berry Seeds" — shown briefly at the bottom after each purchase.
    @State private var receipt: String?

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
                            if let event = SeasonalEvent.current, !Catalog.availableEventCrops.isEmpty {
                                EventBanner(event: event)
                                ForEach(Catalog.availableEventCrops) { crop in
                                    ShopRow(
                                        id: "seed:\(crop.name)",
                                        title: crop.name.capitalized + " Seeds",
                                        subtitle: "Limited time · Grows in \(shortTimeText(crop.growSeconds))",
                                        price: crop.price,
                                        onBought: showReceipt
                                    )
                                }
                                Divider().overlay(Theme.panelBorder).padding(.vertical, 4)
                            }
                            ForEach(Catalog.crops) { crop in
                                ShopRow(
                                    id: "seed:\(crop.name)",
                                    title: crop.name.capitalized + " Seeds",
                                    subtitle: "Grows in \(shortTimeText(crop.growSeconds))",
                                    price: crop.price,
                                    onBought: showReceipt
                                )
                            }
                        } else {
                            ForEach(Catalog.sprinklers) { sp in
                                ShopRow(
                                    id: "gear:\(sp.tier)",
                                    title: sp.name,
                                    subtitle: "Plants around it grow x\(sp.speed.formatted()) faster for \(sprinklerDurationText(sp.duration))",
                                    price: sp.price,
                                    onBought: showReceipt
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
        // A clear "you bought it" message at the bottom
        .overlay(alignment: .bottom) {
            if let receipt {
                Label(receipt, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.buttonText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.good))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: receipt)
        // Special shop music while you're browsing, then back to the garden's
        // own playlist the moment you leave.
        .onAppear {
            SoundPlayer.whoosh()
            MusicPlayer.shared.loop(Music.hollowEvening)
        }
        .onDisappear {
            MusicPlayer.shared.playPlaylist(Music.gardenPlaylist)
        }
    }
}

extension BuyScreen {
    /// Shows the receipt for a couple of seconds.
    fileprivate func showReceipt(_ text: String) {
        receipt = text
        let shown = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if receipt == shown { receipt = nil }
        }
    }
}

/// Shown above the shop list while Halloween or Christmas is running.
struct EventBanner: View {
    let event: SeasonalEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.title) Event")
                    .font(.headline)
                Text("These seeds are only here for a limited time!")
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(
            LinearGradient(
                colors: event == .halloween
                    ? [Color(red: 0.55, green: 0.25, blue: 0.75), Color(red: 0.95, green: 0.45, blue: 0.10)]
                    : [Color(red: 0.70, green: 0.10, blue: 0.15), Color(red: 0.10, green: 0.45, blue: 0.30)],
                startPoint: .leading, endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }
}

struct ShopRow: View {
    let id: String
    let title: String
    let subtitle: String
    let price: Int
    /// Called after a successful purchase with a short message ("Bought ...").
    var onBought: (String) -> Void = { _ in }
    @ObservedObject private var store = GameStore.shared
    @ObservedObject private var admin = AdminMode.shared
    /// True for a moment after buying, so the row visibly reacts.
    @State private var justBought = false

    var body: some View {
        let stock = store.stockToday(id: id, price: price)
        let canBuy = store.points >= store.effectivePrice(price) && stock > 0
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
                Text(admin.isActive ? "FREE (admin)" : "\(Theme.coin) \(price.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(canBuy ? Theme.gold : Theme.bad)
                HStack(spacing: 8) {
                    Text("You have: \(store.count(id))")
                        .fontWeight(justBought ? .bold : .regular)
                        .foregroundStyle(justBought ? Theme.good : Theme.subtext)
                        .contentTransition(.numericText())
                    Text(stock > 0 ? "In stock: \(stock)" : "Out of stock — check back tomorrow")
                        .foregroundStyle(stock > 0 ? Theme.good : Theme.bad)
                }
                .font(.caption2)
                .foregroundStyle(Theme.subtext)
            }
            Spacer()
            GameButton(title: justBought ? nil : "Buy", icon: justBought ? "checkmark" : nil,
                       width: 76, height: 44) {
                let paid = store.effectivePrice(price)
                if store.buy(id, price: price) {
                    SoundPlayer.coin()
                    Haptics.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { justBought = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { justBought = false }
                    }
                    onBought(paid == 0 ? "Bought \(title)" : "Bought \(title)  ·  \(Theme.coin) \(paid.formatted())")
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
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(justBought ? Theme.good : Theme.panelBorder,
                                                          lineWidth: justBought ? 3 : 1))
        .scaleEffect(justBought ? 1.02 : 1)
    }
}
