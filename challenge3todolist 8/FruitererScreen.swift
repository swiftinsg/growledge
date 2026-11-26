//
//  FruitererScreen.swift
//  One shop for everything: the Fruiterer. A big animated shop on top, your
//  garden behind it, and two choices underneath: Buy and Sell.
//

import SwiftUI

struct FruitererScreen: View {
    enum Mode: String {
        case buy = "Buy"
        case sell = "Sell"
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .buy
    @State private var shopOpened = false

    var body: some View {
        ZStack {
            // Your garden behind the shop, darkened so the shop stands out
            GardenBackground()
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    GameButton(title: "Garden", icon: "chevron.left", width: 130, height: 44) {
                        dismiss()
                    }
                    Spacer()
                    PointsPill()
                }

                // The big shop animation
                AnimatedSprite(file: "shop.gif", loops: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: shopOpened ? 150 : 110)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
                    .accessibilityHidden(true)

                Text("The Fruiterer")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Wood.gold)
                    .shadow(color: Wood.darker, radius: 0, y: 3)

                // Buy / Sell
                HStack(spacing: 12) {
                    modeButton(.buy, icon: "cart.fill")
                    modeButton(.sell, icon: "dollarsign.circle.fill")
                }

                Group {
                    if mode == .buy {
                        BuyScreen(embedded: true)
                    } else {
                        SellScreen(embedded: true)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .achievementCelebration()
        .onAppear {
            SoundPlayer.shopBell()
            MusicPlayer.shared.loop(Music.hollowEvening)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { shopOpened = true }
        }
        .onDisappear {
            MusicPlayer.shared.playPlaylist(Music.gardenPlaylist)
        }
    }

    private func modeButton(_ value: Mode, icon: String) -> some View {
        let selected = mode == value
        return Button {
            Haptics.tap()
            SoundPlayer.select()
            withAnimation(.easeInOut(duration: 0.2)) { mode = value }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(value.rawValue)
            }
            .font(.system(.title3, design: .rounded).weight(.black))
            .foregroundStyle(selected ? Wood.ink : Wood.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Wood.dark).offset(y: 4)
                    RoundedRectangle(cornerRadius: 16).fill(selected ? Wood.trim : Wood.base)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Wood.gold : Wood.trim, lineWidth: 3))
        }
        .bouncy(haptic: false)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
