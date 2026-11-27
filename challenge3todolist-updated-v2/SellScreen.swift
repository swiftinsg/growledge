//
//  SellScreen.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 8. SELL SCREEN  (drag items into the tray, then confirm)
// =====================================================================

/// Drag crops and gear into the tray at the bottom, see the total you'd
/// earn (crops are worth more or less depending on their weight), then tap
/// Sell once to cash everything in the tray in at once.
struct SellScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = GameStore.shared

    @State private var dragging: DragInfo?
    @State private var trayFrame: CGRect = .zero
    @State private var tray: [TraySellItem] = []

    struct TraySellItem: Identifiable {
        let id = UUID()
        let itemID: String
        let weight: Double
        let unitPrice: Int
    }

    private var trayTotal: Int { tray.reduce(0) { $0 + $1.unitPrice } }

    var body: some View {
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

                Text("Sell")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)

                Text("Press and drag items down into the tray, then tap Sell.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        let sellable = store.sortedInventory.filter { store.count($0) > 0 && store.sellValue($0) != nil }
                        if sellable.isEmpty {
                            Text("Nothing to sell yet — harvest some crops first.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.subtext)
                                .padding(.top, 30)
                        }
                        ForEach(sellable, id: \.self) { id in
                            SellSourceRow(id: id, dragging: $dragging) { point in
                                attemptDrop(id: id, at: point)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                sellTray
            }
            .padding()

            // The icon that follows your finger while dragging.
            DragGhost(drag: dragging)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sellTray: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Sell Tray", systemImage: "tray.full.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if !tray.isEmpty {
                    Button("Clear") { clearTray() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.bad)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if tray.isEmpty {
                        Text("Drag items here")
                            .font(.caption)
                            .foregroundStyle(Theme.subtext)
                            .frame(height: 56)
                    }
                    ForEach(tray) { item in
                        Button {
                            removeFromTray(item)
                        } label: {
                            VStack(spacing: 2) {
                                ItemIcon(id: item.itemID, size: 40)
                                Text("\(Theme.coin)\(item.unitPrice)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.gold)
                            }
                        }
                        .bouncy(haptic: false)
                    }
                }
                .padding(.horizontal, 2)
                .frame(minHeight: 56)
            }

            HStack {
                Text("Total:")
                    .font(.headline)
                    .foregroundStyle(Theme.subtext)
                Text("\(Theme.coin) \(trayTotal.formatted())")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                    .contentTransition(.numericText())
                    .animation(.default, value: trayTotal)
                Spacer()
                GameButton(title: "Sell", icon: "dollarsign.circle.fill", width: 120, height: 46) {
                    confirmSell()
                }
                .disabled(tray.isEmpty)
                .opacity(tray.isEmpty ? 0.4 : 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(dragging != nil ? Theme.good : Theme.panelBorder, lineWidth: dragging != nil ? 3 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: dragging != nil)
        .readFrame($trayFrame)
    }

    // MARK: - Actions

    private func attemptDrop(id: String, at point: CGPoint) {
        guard trayFrame.contains(point) else { return }
        guard let taken = store.takeForTray(id) else {
            Haptics.warning()
            SoundPlayer.error()
            return
        }
        tray.append(TraySellItem(itemID: id, weight: taken.weight, unitPrice: taken.unitPrice))
        Haptics.tap()
        SoundPlayer.pop()
    }

    private func removeFromTray(_ item: TraySellItem) {
        tray.removeAll { $0.id == item.id }
        store.returnFromTray(item.itemID, weight: item.weight)
        Haptics.tap()
    }

    private func clearTray() {
        for item in tray { store.returnFromTray(item.itemID, weight: item.weight) }
        withAnimation { tray.removeAll() }
    }

    private func confirmSell() {
        guard !tray.isEmpty else { return }
        store.points += trayTotal
        Haptics.success()
        SoundPlayer.coin()
        withAnimation { tray.removeAll() }
    }
}

/// One draggable row in the sell list: an item you can press, hold and drag
/// down into the tray.
private struct SellSourceRow: View {
    let id: String
    @Binding var dragging: DragInfo?
    var onDrop: (CGPoint) -> Void

    @ObservedObject private var store = GameStore.shared

    var body: some View {
        let info = ItemInfo(id: id)
        let count = store.count(id)
        let weights = store.cropWeights[id] ?? []
        let isBeingDragged = dragging?.id == id

        HStack(spacing: 12) {
            ItemIcon(id: id, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                if info.kind == "crop", let avg = averageWeight(weights) {
                    Text("Avg. weight \(avg.formatted(.number.precision(.fractionLength(1))))x")
                        .font(.caption2)
                        .foregroundStyle(Theme.subtext)
                }
                Text("You have: \(count)")
                    .font(.caption2)
                    .foregroundStyle(Theme.subtext)
            }
            Spacer()
            Image(systemName: "hand.draw.fill")
                .foregroundStyle(Theme.subtext)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelBorder, lineWidth: 1))
        .opacity(isBeingDragged ? 0.4 : 1)
        .itemDrag(id: id, dragging: $dragging, onDrop: onDrop)
    }

    private func averageWeight(_ weights: [Double]) -> Double? {
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }
}
