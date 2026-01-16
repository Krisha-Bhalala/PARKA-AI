import SwiftUI

struct ContentView: View {
    @State private var animateWave = false
    @State private var showButtons = false
    @State private var pulseAnimation = false
    @State private var sparkleOffset = false
    @State private var floatingElements = false
    @State private var colorShift = false
    @State private var morphAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic gradient background
                LinearGradient(gradient: Gradient(colors: [
                    colorShift ? Color(red: 0.96, green: 0.99, blue: 1.0) : Color(red: 0.98, green: 0.99, blue: 1.0),
                    colorShift ? Color(red: 0.92, green: 0.97, blue: 1.0) : Color(red: 0.94, green: 0.97, blue: 1.0)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: colorShift)
                
                // Subtle floating elements
                GeometryReader { geometry in
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.05))
                            .frame(width: CGFloat.random(in: 60...100))
                            .position(
                                x: geometry.size.width * Double.random(in: 0.1...0.9),
                                y: geometry.size.height * Double.random(in: 0.1...0.5)
                            )
                            .scaleEffect(floatingElements ? 1.1 : 0.9)
                            .animation(
                                Animation.easeInOut(duration: Double.random(in: 4.0...7.0))
                                    .repeatForever(autoreverses: true),
                                value: floatingElements
                            )
                    }
                }
                
                VStack(spacing: 0) {
                    // Compact header
                    VStack(spacing: 20) {
                        // Brand icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color(red: 0.96, green: 0.98, blue: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.7, blue: 0.9),
                                            Color(red: 0.3, green: 0.8, blue: 0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        VStack(spacing: 8) {
                            Text("PARKA AI")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.7, blue: 0.9),
                                            Color(red: 0.3, green: 0.8, blue: 0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Smart Health Insights")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.6))
                        }
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    // Feature cards - compact version
                    VStack(spacing: 16) {
                        CompactFeatureCard(
                            destination: SimpleDataDisplayView()
                                .navigationBarTitleDisplayMode(.inline),
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Health Analytics",
                            gradientColors: [
                                Color(red: 0.2, green: 0.7, blue: 0.9),
                                Color(red: 0.3, green: 0.8, blue: 0.7)
                            ]
                        )
                        
                        CompactFeatureCard(
                            destination: AICoachView(),
                            icon: "brain.head.profile",
                            title: "AI Health Coach",
                            gradientColors: [
                                Color(red: 0.4, green: 0.6, blue: 0.9),
                                Color(red: 0.5, green: 0.7, blue: 0.8)
                            ]
                        )
                        
                        CompactFeatureCard(
                            destination: SelfReportView(),
                            icon: "doc.text",
                            title: "Daily Assessment",
                            gradientColors: [
                                Color(red: 0.6, green: 0.8, blue: 0.4),
                                Color(red: 0.7, green: 0.9, blue: 0.5)
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 20)
                    
                    // Apple Health integration badge
                    VStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                        
                        Text("Apple Health Integration")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.6))
                    }
                    .padding(12)
                    
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) {
                    pulseAnimation = true
                    colorShift = true
                    floatingElements = true
                }
                
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showButtons = true
                }
            }
        }
    }
}

struct CompactFeatureCard<Destination: View>: View {
    let destination: Destination
    let icon: String
    let title: String
    let gradientColors: [Color]
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                    .padding(.leading, 8)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 14")
    }
}
