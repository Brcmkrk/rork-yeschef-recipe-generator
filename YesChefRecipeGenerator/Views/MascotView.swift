import SwiftUI

enum MascotMood {
    case idle
    case cooking
    case presenting
    case excited
}

struct MascotView: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 120

    @State private var wobblePhase: Bool = false
    @State private var bobPhase: Bool = false


    var body: some View {
        ZStack {
            tentacleWaves

            Image("MascotImage")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(wobbleRotation), anchor: .bottom)
                .animation(.easeInOut(duration: wobbleDuration).repeatForever(autoreverses: true), value: wobblePhase)
                .offset(y: bobOffset)
                .scaleEffect(pulseScale, anchor: .bottom)
                .animation(.easeInOut(duration: bobDuration).repeatForever(autoreverses: true), value: bobPhase)
        }
        .onAppear {
            wobblePhase = true
            bobPhase = true
        }
    }

    private var wobbleRotation: Double {
        switch mood {
        case .idle: return wobblePhase ? 2.5 : -2.5
        case .cooking: return wobblePhase ? 5 : -5
        case .presenting: return wobblePhase ? 3 : -3
        case .excited: return wobblePhase ? 8 : -8
        }
    }

    private var bobOffset: CGFloat {
        switch mood {
        case .idle: return bobPhase ? -3 : 3
        case .cooking: return bobPhase ? -6 : 2
        case .presenting: return bobPhase ? -4 : 4
        case .excited: return bobPhase ? -8 : 4
        }
    }

    private var pulseScale: CGFloat {
        switch mood {
        case .idle: return bobPhase ? 1.02 : 0.98
        case .cooking: return bobPhase ? 1.05 : 0.96
        case .presenting: return 1.0
        case .excited: return bobPhase ? 1.08 : 0.94
        }
    }

    private var wobbleDuration: Double {
        switch mood {
        case .idle: return 2.0
        case .cooking: return 0.8
        case .presenting: return 1.5
        case .excited: return 0.5
        }
    }

    private var bobDuration: Double {
        switch mood {
        case .idle: return 2.5
        case .cooking: return 1.0
        case .presenting: return 2.0
        case .excited: return 0.6
        }
    }

    @ViewBuilder
    private var tentacleWaves: some View {
        let count = 6
        ForEach(0..<count, id: \.self) { i in
            TentacleArc(
                index: i,
                total: count,
                radius: size * 0.55,
                mood: mood
            )
        }
    }
}

struct TentacleArc: View {
    let index: Int
    let total: Int
    let radius: CGFloat
    let mood: MascotMood

    @State private var phase: Bool = false

    private var baseAngle: Double {
        let spread = 200.0
        let start = 170.0
        return start + (spread / Double(total - 1)) * Double(index)
    }

    var body: some View {
        let angle = Angle.degrees(baseAngle)
        let x = cos(angle.radians) * radius
        let y = sin(angle.radians) * radius * 0.6

        Circle()
            .fill(
                RadialGradient(
                    colors: [.orange.opacity(0.25), .orange.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 12
                )
            )
            .frame(width: 24, height: 24)
            .offset(x: x + (phase ? wiggleX : -wiggleX), y: y + 20 + (phase ? wiggleY : -wiggleY))
            .animation(
                .easeInOut(duration: animDuration).repeatForever(autoreverses: true).delay(Double(index) * 0.15),
                value: phase
            )
            .onAppear { phase = true }
    }

    private var wiggleX: CGFloat {
        switch mood {
        case .idle: return 4
        case .cooking: return 8
        case .presenting: return 6
        case .excited: return 12
        }
    }

    private var wiggleY: CGFloat {
        switch mood {
        case .idle: return 3
        case .cooking: return 6
        case .presenting: return 4
        case .excited: return 10
        }
    }

    private var animDuration: Double {
        switch mood {
        case .idle: return 1.8 + Double(index) * 0.1
        case .cooking: return 0.6 + Double(index) * 0.05
        case .presenting: return 1.2 + Double(index) * 0.08
        case .excited: return 0.4 + Double(index) * 0.03
        }
    }
}

struct TentaclePath: Shape {
    var wavePhase: CGFloat

    var animatableData: CGFloat {
        get { wavePhase }
        set { wavePhase = newValue }
    }

    let startAngle: Double
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startRad = startAngle * .pi / 180

        let startX = center.x + cos(startRad) * 20
        let startY = center.y + sin(startRad) * 15

        path.move(to: CGPoint(x: startX, y: startY))

        let segments = 8
        for s in 1...segments {
            let t = CGFloat(s) / CGFloat(segments)
            let wave = sin((t * 3 + wavePhase) * .pi) * 12
            let endX = startX + cos(startRad) * length * t + wave * CGFloat(sin(startRad))
            let endY = startY + sin(startRad) * length * t + wave * CGFloat(cos(startRad))

            let cpX = startX + cos(startRad) * length * (t - 0.5 / CGFloat(segments))
            let cpY = startY + sin(startRad) * length * (t - 0.5 / CGFloat(segments))

            path.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: cpX + wave * 0.5, y: cpY + wave * 0.5)
            )
        }

        return path
    }
}
