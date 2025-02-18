import SwiftUI
import MetalKit
import ModelIO

// Extension to allow conversion from simd_float4x4 to NSValue.
extension NSValue {
    convenience init(simdMatrix4x4 matrix: simd_float4x4) {
        var matrixCopy = matrix
        self.init(bytes: &matrixCopy, objCType: "{matrix_float4x4=16f}")
    }
}

struct ModelView: View {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var drawable = Drawable(device: MTLCreateSystemDefaultDevice()!)
    @State private var showingSettings = false
    @State private var currentMode = "Rotate Mode"
    @State private var isPlaying = false
    @State private var hasStarted = false
    @State private var showCamera = false
    @State private var showAnimationSelector = false
    @State private var selectedAnimation: CapturedAnimation? = nil
    @Binding var selectedTab: TabItem
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    var body: some View {
        ZStack {
            ScanView(drawable: drawable)
                .edgesIgnoringSafeArea(.all)
                .handleEvents(using: eventManager)
                .onAppear {
                    isPlaying = true
                    hasStarted = true
                }
            
            VStack {
                HStack {
                    // Left side buttons
                    VStack(spacing: 4) {
                        modeButton(iconName: "record.circle", color: .red) {
                            selectedTab = .camera
                        }
                        modeButton(iconName: "gearshape.fill", color: .white) {
                            showingSettings.toggle()
                        }
                        .padding(.bottom, 10)
                        modeButton(iconName: "arrow.triangle.2.circlepath", color: .orange) {
                            drawable.setMovementMode(.rotate)
                            currentMode = "Rotate Mode"
                        }
                        modeButton(iconName: "arrow.up.and.down.and.arrow.left.and.right", color: .green) {
                            drawable.setMovementMode(.moveInPlane)
                            currentMode = "Translate Mode"
                        }
                        modeButton(iconName: isPlaying ? "pause.fill" : "play.fill", color: .blue) {
                            if isPlaying {
                                drawable.pauseAnimation()
                            } else {
                                drawable.resumeAnimation()
                            }
                            isPlaying.toggle()
                        }
                        .padding(.bottom, 10)
                        modeButton(iconName: "scribble.variable", color: .cyan) {
                            showAnimationSelector = true
                        }
                    }
                    .padding(.top, 32)
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Export button
                    VStack {
                        modeButton(iconName: "arrow.up.circle", color: .blue) {
                            drawable.printModelJoints()
                        }
                        
                        modeButton(iconName: "repeat.circle.fill", color: .blue) {
                            drawable.printRecordedJoints()
                        }
                    }
                    .padding(.top, 32)
                    .padding(.trailing, 8)
                }
                
                Spacer()
                
                Text(currentMode)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.bottom, 20)
            }
            
            if showingSettings {
                settingsView
            }
        }
        .sheet(isPresented: $showAnimationSelector) {
            AnimationSelectorView(selectedAnimation: $selectedAnimation)
        }
        .onChange(of: selectedAnimation) { newAnimation in
            if let animation = newAnimation {
                drawable.setAnimation(animation)
            }
        }
    }
    
    private var settingsView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { showingSettings = false }
            
            VStack {
                Spacer()
                VStack(spacing: 16) {
                    Text("Joint Controls")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 16)
                    
                    HStack(spacing: 16) {
                        Button(action: { drawable.selectPreviousJoint() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                        }
                        
                        Text("Joint \(drawable.currentJointIndex)")
                            .foregroundColor(.white)
                            .frame(width: 100)
                        
                        Button(action: { drawable.selectNextJoint() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .frame(width: 300, height: 200)
                .background(Color.black.opacity(0.5))
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.bottom, 20)
            }
        }
    }
    

    
    private func modeButton(iconName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
        }
    }
}

