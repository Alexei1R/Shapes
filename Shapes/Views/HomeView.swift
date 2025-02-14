//
//  HomeView.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import SwiftUI

struct HomeView: View {

    @State private var selectedTab: TabItem = .modelView



    var body: some View {
        TabView(selection: $selectedTab, content: {
            CameraView(selectedTab: $selectedTab)
                .tag(TabItem.camera)
            ModelView(selectedTab: $selectedTab)
                .tag(TabItem.modelView)
        })
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: selectedTab)
        .ignoresSafeArea()
    }
}

#Preview {
    HomeView()
}

enum TabItem {
    case modelView
    case camera
}
