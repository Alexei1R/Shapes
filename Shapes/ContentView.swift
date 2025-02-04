//
//  ContentView.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var eventManager = EventManager()
    
    
    var body: some View {
        ZStack {
            ScanView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .handleEvents(using: eventManager)
            
            VStack {
                Spacer()
                Text("Shape")
                    .foregroundColor(.gray)
                    .bold()
            }
        }
    }
    
}

#Preview {
    ContentView()
}
