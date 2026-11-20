//
//  InventoryBar.swift
//  The app
//

import SwiftUI

// =====================================================================
// MARK: - 6. INVENTORY BAR  (scrollable, right side of the garden)
// =====================================================================
struct InventoryBar: View {
    @ObservedObject private var store = GameStore.shared
    @Binding var dragging: DragInfo?
    var onPlantAll: () -> Void = {}
    var onDrop: (String, CGPoint) -> Void

    /// "Plant All" only shows up once there are more seeds than this, because
    /// with a few seeds dragging them is just as quick.
    static let plantAllMinimumSeeds = 10

    var body: some View {
        let items = store.sortedInventory
        let seedCount = store.seedsInBag.reduce(0) { $0 + store.count($1) }
        VStack(spacing: 4) {
            Image(systemName: "bag.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            if seedCount > Self.plantAllMinimumSeeds {
                Button(action: onPlantAll) {
                    VStack(spacing: 1) {
                        Image(systemName: "leaf.fill")
                        Text("Plant All")
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.85)))
                }
                .bouncy(haptic: false)
            }
            if items.isEmpty {
                Text("Empty")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.subtext)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(items, id: \.self) { id in
                            InventoryCell(
                                id: id,
                                count: store.count(id),
                                dragging: $dragging,
                                onDrop: { point in onDrop(id, point) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollDisabled(dragging != nil)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 80, height: 400)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelBorder, lineWidth: 1))
    }
}

// One item: press and hold for a moment, then drag it onto a tile.
struct InventoryCell: View {
    let id: String
    let count: Int
    @Binding var dragging: DragInfo?
    var onDrop: (CGPoint) -> Void

    var body: some View {
        let info = ItemInfo(id: id)
        VStack(spacing: 2) {
            ItemIcon(id: id, size: 46)
                .overlay(alignment: .topTrailing) {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.bad))
                        .offset(x: 6, y: -4)
                }
            Text(info.kind == "gear" ? info.displayName : info.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if info.kind == "seed" {
                Text("SEEDS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.8)))
            }
        }
        .frame(width: 64)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
        .opacity(dragging?.id == id ? 0.4 : 1)
        .itemDrag(id: id, dragging: $dragging, onDrop: onDrop)
    }
}
