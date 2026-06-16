//
//  MainTabView.swift
//  GrowRate
//
//  Custom tab bar shell. Five sections; per-batch detail screens are pushed
//  from the Board and from the Forecast / FCR overviews.
//

import SwiftUI

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            GR.bg.ignoresSafeArea()

            Group {
                switch tab {
                case 0: NavigationView { BoardScreen() }.navigationViewStyle(StackNavigationViewStyle())
                case 1: NavigationView { ForecastOverviewScreen() }.navigationViewStyle(StackNavigationViewStyle())
                case 2: NavigationView { FCROverviewScreen() }.navigationViewStyle(StackNavigationViewStyle())
                case 3: NavigationView { ReportsScreen() }.navigationViewStyle(StackNavigationViewStyle())
                default: NavigationView { SettingsScreen() }.navigationViewStyle(StackNavigationViewStyle())
                }
            }
            .padding(.bottom, 6)

            GRTabBar(selection: $tab)
        }
    }
}

struct GRTabBar: View {
    @Binding var selection: Int

    private let items: [(String, String)] = [
        ("chart.bar.fill", "Board"),
        ("calendar.badge.clock", "Forecast"),
        ("speedometer", "FCR"),
        ("doc.text.fill", "Reports"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                Button(action: {
                    withAnimation(GR.spring) { selection = i }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].0)
                            .font(.system(size: 18, weight: .semibold))
                            .scaleEffect(selection == i ? 1.12 : 1)
                        Text(items[i].1).font(.gr(10, .semibold))
                    }
                    .foregroundColor(selection == i ? GR.orange : GR.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        VStack {
                            if selection == i {
                                Capsule().fill(GR.orange).frame(width: 22, height: 3)
                                    .offset(y: -8)
                            }
                            Spacer()
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 6)
        .background(
            GR.card
                .overlay(Rectangle().fill(GR.border).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
