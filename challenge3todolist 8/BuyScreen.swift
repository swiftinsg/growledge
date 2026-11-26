//
//  BuyScreen.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 7. BUY SCREEN  (opened by the Buy navigation link)
// =====================================================================
struct BuyScreen: View {
    /// True when shown inside the Fruiterer (which supplies the background and header).
    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }
    @Environment(\.dismiss) private var dismiss
    @State private var type: ShopType = .seeds
    @State private var showAsk = true
    /// "Bought Dewdrop Berry Seeds" — shown briefly at the bottom after each purchase.
    @State private var receipt: String?

    var body: some View {
        ZStack {
            if !embedded { SeasonBackdrop() }
            VStack(spacing: 12) {
                if !embedded {
                    HStack {
                        GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                            dismiss()
                        }
                        Spacer()
                        PointsPill()
                    }
                }

                // Switch between the two shops any time
                HStack(spacing: 10) {
                    shopTab("Seeds", .seeds)
                    shopTab("Gears", .gears)
                }

                Text(type == .seeds ? "Seed Shop" : "Gear Shop")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Wood.cream)
                    .shadow(color: .black.opacity(0.5), radius: 0, y: 2)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if type == .seeds {
                            if let event = SeasonalEvent.current, !Catalog.availableEventCrops.isEmpty {
                                EventBanner(event: event)
                                ForEach(Catalog.availableEventCrops) { crop in
                                    ShopRow(
                                        id: "seed:\(crop.name)",
                                        title: crop.name.capitalized + " Seeds",
                                        subtitle: "Limited time · Grows in \(longTimeText(crop.growSeconds))",
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
                                    subtitle: "Grows in \(longTimeText(crop.growSeconds)) · sells ~\(crop.sellPrice.formatted()) coins",
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
            if !embedded {
                SoundPlayer.whoosh()
                MusicPlayer.shared.loop(Music.hollowEvening)
            }
        }
        .onDisappear {
            if !embedded { MusicPlayer.shared.playPlaylist(Music.gardenPlaylist) }
        }
    }

    private func shopTab(_ title: String, _ value: ShopType) -> some View {
        Button {
            Haptics.tap()
            SoundPlayer.select()
            type = value
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(type == value ? Wood.ink : Wood.cream)
                .frame(width: 110, height: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(type == value ? Wood.trim : Wood.base))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Wood.trim, lineWidth: 2))
        }
        .bouncy(haptic: false)
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
    @State private var showingInfo = false

    /// The crop this row sells seeds of (nil for sprinklers).
    private var crop: Crop? {
        let info = ItemInfo(id: id)
        return info.kind == "seed" ? Catalog.cropByName[info.name] : nil
    }

    var body: some View {
        let stock = store.stockToday(id: id, price: price)
        let canBuy = store.points >= store.effectivePrice(price) && stock > 0
        HStack(spacing: 12) {
            ItemIcon(id: id, size: 60)
                .saturation(stock > 0 ? 1 : 0.15)
                .overlay(alignment: .bottomTrailing) {
                    if crop != nil {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.text)
                            .background(Circle().fill(Theme.card))
                            .offset(x: 4, y: 4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if crop != nil { Haptics.tap(); SoundPlayer.select(); showingInfo = true }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Wood.cream)
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
                    .foregroundStyle(Wood.cream.opacity(0.85))
                if admin.isActive {
                    Text("FREE (admin)")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Wood.gold)
                } else {
                    CoinLabel(amount: store.effectivePrice(price), size: 17, color: canBuy ? Wood.gold : Theme.bad)
                }
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
            Button {
                let paid = store.effectivePrice(price)
                if store.buy(id, price: price) {
                    SoundPlayer.coin()
                    Haptics.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { justBought = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { justBought = false }
                    }
                    onBought(paid == 0 ? "Bought \(title)" : "Bought \(title)  ·  \(paid.formatted()) coins")
                } else {
                    Haptics.warning()
                    SoundPlayer.error()
                }
            } label: {
                if justBought {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Wood.leaf))
                } else {
                    LeafButtonLook(title: "Buy", width: 76, height: 44)
                }
            }
            .bouncy(haptic: false)
            .disabled(!canBuy)
            .opacity(canBuy ? 1 : 0.4)
        }
        .sheet(isPresented: $showingInfo) {
            if let crop { CropInfoSheet(crop: crop) }
        }
        .padding(10)
        .woodPanel(radius: 18, highlighted: justBought)
        .scaleEffect(justBought ? 1.02 : 1)
    }
}

// =====================================================================
// MARK: - Crop info (tap a seed in the shop): numbers + your animations
// =====================================================================
struct CropInfoSheet: View {
    let crop: Crop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ForestBackground(dim: 0.45)
                ScrollView {
                    VStack(spacing: 18) {
                        HStack(spacing: 14) {
                            ItemIcon(id: "seed:\(crop.name)", size: 64)
                            Image(systemName: "arrow.right").foregroundStyle(Theme.subtext)
                            PlantStageView(crop: crop, progress: 1, size: 64)
                                .frame(width: 80, height: 90, alignment: .bottom)
                            Image(systemName: "arrow.right").foregroundStyle(Theme.subtext)
                            ItemIcon(id: "crop:\(crop.name)", size: 64)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 8) {
                            statRow("Seed price", "\(Theme.coin) \(crop.price.formatted())")
                            statRow("Grows in", longTimeText(crop.growSeconds))
                            statRow("Average crop sells for", "\(Theme.coin) \(crop.sellPrice.formatted())")
                            statRow("Average profit", "+\(Theme.coin) \((crop.sellPrice - crop.price).formatted())")
                            statRow("Profit per hour, per plot", "\(Theme.coin) \(Int(crop.profitPerHour.rounded()).formatted())")
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.92)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1))

                        Text("Each harvest has a random weight (0.7x–1.4x) and a small chance of a shiny mutation, which changes the price.")
                            .font(.caption)
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .multilineTextAlignment(.center)

                        if let anims = crop.anim?.all, !anims.isEmpty {
                            Text("How it grows")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 14) {
                                ForEach(anims) { item in
                                    AnimationCard(title: item.title, file: item.file)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(crop.name.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.subtext)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(Theme.text)
        }
        .font(.subheadline)
    }
}
