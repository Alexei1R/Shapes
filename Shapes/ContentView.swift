//
//  ContentView.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var drawable = Drawable(device: MTLCreateSystemDefaultDevice()!)
    
    var body: some View {
        ZStack {
            ScanView(drawable: drawable)
                .edgesIgnoringSafeArea(.all)
                .handleEvents(using: eventManager)
            
            VStack {
                Spacer()
                HStack{
                    Button(action: {
                        drawable.start()
                    }) {
                        Text("start")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button(action: {
                        drawable.stop()
                    }) {
                        Text("stop")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            
                .padding()
            }
        }
    }
}
