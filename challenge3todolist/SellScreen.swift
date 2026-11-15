//
//  SellScreen.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 8. SELL SCREEN  (opened by the Sell navigation link)
// =====================================================================
struct SellScreen: View {
    @ObservedObject private var store = GameStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message = "Drag an item into the box (or tap an item, then tap the box)"
    @State private var showAsk = true
    @State private var dragging: DragInfo?
    @State private var selected: String?
    @State private var boxFrame: CGRect = .zero

    var body: some View {
        // seeds can't be sold, so they are not shown here
        let sellable = store.sortedInventory.filter { ItemInfo(id: $0).kind != "seed" }
        let hovering = dragging.map { boxFrame.contains($0.location) } ?? false

        ZStack {
            SeasonBackdrop()
            VStack(spacing: 12) {
                HStack {
                    GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                        dismiss()
                    }
                    Spacer()
                    PointsPill()
                }

                Text("Sell Shop")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)

                // Drop zone
                RoundedRectangle(cornerRadius: 24)
                    .fill(hovering ? Theme.good.opacity(0.3) : Theme.card.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(hovering ? Theme.good : Theme.accent.opacity(0.6),
                                          style: StrokeStyle(lineWidth: 2, dash: [10]))
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 34))
                                .foregroundStyle(Theme.accent)
                            Text(message)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .frame(height: 150)
                    .readFrame($boxFrame)
                    .onTapGesture {
                        if let id = selected {
                            sellItem(id)
                        } else {
                            message = "Tap an item first, or drag it here"
                        }
                    }

                // Your inventory (scrollable). Press, hold and drag up into the box.
                ScrollView {
                    if sellable.isEmpty {
                        Text("Nothing to sell yet. Harvest some crops.")
                            .font(.body)
                            .foregroundStyle(Theme.subtext)
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(sellable, id: \.self) { id in
                                let info = ItemInfo(id: id)
                                VStack(spacing: 3) {
                                    ItemIcon(id: id, size: 60)
                                    Text(info.displayName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                    Text("x\(store.count(id))  •  \(Theme.coin) \((store.sellValue(id) ?? 0).formatted())")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Theme.gold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.92)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.accent, lineWidth: selected == id ? 3 : 0)
                                )
                                .opacity(dragging?.id == id ? 0.4 : 1)
                                .onTapGesture { selected = (selected == id) ? nil : id }
                                .itemDrag(id: id, dragging: $dragging) { point in
                                    if boxFrame.contains(point) { sellItem(id) }
                                }
                            }
                        }
                    }
                }
                .scrollDisabled(dragging != nil)
            }
            .padding()
        }
        .overlay { DragGhost(drag: dragging) }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // The question when you arrive
        
    }

    func sellItem(_ id: String) {
        if let earned = store.sell(id) {
            SoundPlayer.pop()
            message = "Sold for \(Theme.coin) \(earned.formatted())"
            if store.count(id) == 0 { selected = nil }
        } else {
            message = "That can't be sold"
        }
    }
}
