//
//  ContentView.swift
//  The app
//
//  Created by T Krobot on 12/11/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("streak") private var streak = 0
    @AppStorage("amountoftimehestudied") private var amountStudied = 67.0
    @AppStorage("hisgoal") private var goalTime = 100.0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var gameStarted = false
    @State private var showBar = true
    @State private var showStreak = true
    @State private var showButton = true
    
    var body: some View {
        if hasCompletedOnboarding {
            mainTabs
        } else {
            firsttimer()
        }
    }
    
    private var mainTabs: some View {
        TabView {
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            Todolist()
                .tabItem {
                    Label("Todoist", systemImage: "checklist")
                }
        }
    }
    
    /// 0...1, safe even if the goal is 0.
    private var progress: Double {
        guard goalTime > 0 else { return 0 }
        return min(max(amountStudied / goalTime, 0), 1)
    }
    
    private var homeTab: some View {
        NavigationStack {
            ZStack {
                GardenPlot(offset: .zero)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !gameStarted && showBar {
                            startGame()
                        }
                    }
                
                // Home HUD: progress bar, streak and the Study link
                VStack {
                    HStack(spacing: 24) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                
                                Rectangle()
                                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * progress)
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 34)
                        .border(Color.white, width: 2)
                        .opacity(showBar ? 1 : 0)
                        .scaleEffect(showBar ? 1 : 0.8)
                        .blur(radius: showBar ? 0 : 10)
                        
                        Text(" \(Image(systemName: "flame.fill")) \(streak)")
                            .bold()
                            .foregroundStyle(.orange)
                            .font(.largeTitle)
                            .fontDesign(.serif)
                            .opacity(showStreak ? 1 : 0)
                            .scaleEffect(showStreak ? 1 : 0.5)
                            .blur(radius: showStreak ? 0 : 10)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // The Study button is now a NavigationLink to the study screen
                    NavigationLink {
                        StudyView()
                    } label: {
                        Text("Study")
                            .bold()
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .frame(width: 240, height: 100)
                            .background {
                                Image("Image 1")
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .opacity(showButton ? 1 : 0)
                    .scaleEffect(showButton ? 1 : 0.5)
                    .blur(radius: showButton ? 0 : 10)
                    .allowsHitTesting(showButton && !gameStarted)
                    
                    Spacer()
                }
                .allowsHitTesting(!gameStarted)
                
                // The garden game sits on top of everything once started
                if gameStarted {
                    Game(onExit: exitGame)
                        .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Hide the tab bar while playing the garden game
            .toolbar(gameStarted ? .hidden : .visible, for: .tabBar)
        }
    }
    
    private func startGame() {
        withAnimation(.easeIn(duration: 0.4)) {
            showBar = false
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
            showStreak = false
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.4)) {
            showButton = false
        }
        withAnimation(.easeIn.delay(0.8)) {
            gameStarted = true
        }
    }
    
    private func exitGame() {
        withAnimation(.easeOut(duration: 0.4)) {
            gameStarted = false
            showBar = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            showStreak = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            showButton = true
        }
    }
}

// Placeholder: your team will fill this in
struct TodoistView: View {
    var body: some View {
        Color.clear
    }
}

#Preview {
    ContentView()
}
