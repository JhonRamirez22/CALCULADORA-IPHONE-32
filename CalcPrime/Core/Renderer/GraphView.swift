// GraphView.swift
// CalcPrime — MathDF iOS
// Interactive function grapher with CoreGraphics.
// Features: pinch zoom, pan, tap for coordinates, slider for constant C,
// area shading for definite integrals, tangent lines for derivatives.

import SwiftUI

// MARK: - GraphView

struct GraphView: View {
    let functions: [GraphFunction]
    var showSlider: Bool = false
    var sliderLabel: String = "C"
    var shadeArea: ShadeArea? = nil
    
    @State private var sliderValue: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var tapPoint: CGPoint? = nil
    @State private var tapCoord: (Double, Double)? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Graph canvas
            ZStack {
                GraphCanvas(
                    functions: functions,
                    sliderValue: sliderValue,
                    scale: scale,
                    offset: offset,
                    shadeArea: shadeArea,
                    tapPoint: $tapPoint,
                    tapCoord: $tapCoord,
                    colorScheme: colorScheme
                )
                .gesture(magnification)
                .gesture(drag)
                .gesture(tap)
                
                // Coordinate display on tap
                if let coord = tapCoord {
                    VStack {
                        HStack {
                            Spacer()
                            Text(String(format: "(%.3f, %.3f)", coord.0, coord.1))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Reset button
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scale = 1.0
                                offset = .zero
                                tapPoint = nil
                                tapCoord = nil
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Save button
                        Button {
                            // Save handled by share sheet
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : .white)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
            
            // Slider for constant C
            if showSlider {
                VStack(spacing: 4) {
                    HStack {
                        Text("\(sliderLabel) = \(String(format: "%.2f", sliderValue))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Spacer()
                    }
                    Slider(value: $sliderValue, in: -5...5, step: 0.1)
                        .tint(MathDFColors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            // Legend
            if functions.count > 1 {
                HStack(spacing: 16) {
                    ForEach(Array(functions.enumerated()), id: \.offset) { _, f in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(f.color)
                                .frame(width: 8, height: 8)
                            Text(f.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }
    
    // MARK: - Gestures
    
    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(0.2, min(10.0, value.magnification))
            }
    }
    
    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
    }
    
    private var tap: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                tapPoint = value.location
            }
    }
}

// MARK: - Graph Function

struct GraphFunction: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let evaluate: (Double, Double) -> Double  // (x, C) -> y
    let isDashed: Bool
    
    init(label: String, color: Color = .blue, isDashed: Bool = false,
         evaluate: @escaping (Double, Double) -> Double) {
        self.label = label
        self.color = color
        self.isDashed = isDashed
        self.evaluate = evaluate
    }
    
    /// Simple function of x only
    init(label: String, color: Color = .blue, isDashed: Bool = false,
         f: @escaping (Double) -> Double) {
        self.label = label
        self.color = color
        self.isDashed = isDashed
        self.evaluate = { x, _ in f(x) }
    }
}

// MARK: - Shade Area

struct ShadeArea {
    let from: Double
    let to: Double
    let functionIndex: Int
    let color: Color
    
    init(from: Double, to: Double, functionIndex: Int = 0,
         color: Color = Color.blue.opacity(0.2)) {
        self.from = from
        self.to = to
        self.functionIndex = functionIndex
        self.color = color
    }
}

// MARK: - Graph Canvas (CoreGraphics)

struct GraphCanvas: UIViewRepresentable {
    let functions: [GraphFunction]
    let sliderValue: Double
    let scale: CGFloat
    let offset: CGSize
    let shadeArea: ShadeArea?
    @Binding var tapPoint: CGPoint?
    @Binding var tapCoord: (Double, Double)?
    let colorScheme: ColorScheme
    
    func makeUIView(context: Context) -> GraphCanvasUIView {
        let view = GraphCanvasUIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }
    
    func updateUIView(_ uiView: GraphCanvasUIView, context: Context) {
        uiView.functions = functions
        uiView.sliderValue = sliderValue
        uiView.scale = Double(scale)
        uiView.offsetX = Double(offset.width)
        uiView.offsetY = Double(offset.height)
        uiView.shadeArea = shadeArea
        uiView.isDarkMode = colorScheme == .dark
        
        if let tp = tapPoint {
            let (x, y) = uiView.screenToMath(tp)
            // Snap to nearest function
            if let f = functions.first {
                let fy = f.evaluate(x, sliderValue)
                tapCoord = (x, fy)
            } else {
                tapCoord = (x, y)
            }
        }
        
        uiView.setNeedsDisplay()
    }
}

// MARK: - Canvas UIView (CoreGraphics drawing)

class GraphCanvasUIView: UIView {
    var functions: [GraphFunction] = []
    var sliderValue: Double = 1.0
    var scale: Double = 1.0
    var offsetX: Double = 0
    var offsetY: Double = 0
    var shadeArea: ShadeArea? = nil
    var isDarkMode: Bool = false
    
    // Viewport
    private var xMin: Double { -10 / scale + offsetX / 30 }
    private var xMax: Double {  10 / scale + offsetX / 30 }
    private var yMin: Double { -7  / scale - offsetY / 30 }
    private var yMax: Double {  7  / scale - offsetY / 30 }
    
    func screenToMath(_ point: CGPoint) -> (Double, Double) {
        let w = Double(bounds.width)
        let h = Double(bounds.height)
        let x = xMin + (Double(point.x) / w) * (xMax - xMin)
        let y = yMax - (Double(point.y) / h) * (yMax - yMin)
        return (x, y)
    }
    
    private func mathToScreen(_ x: Double, _ y: Double) -> CGPoint {
        let w = Double(bounds.width)
        let h = Double(bounds.height)
        let sx = (x - xMin) / (xMax - xMin) * w
        let sy = (yMax - y) / (yMax - yMin) * h
        return CGPoint(x: sx, y: sy)
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = rect.width
        let h = rect.height
        
        // Background
        let bgColor: UIColor = isDarkMode ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) : .white
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(rect)
        
        // Grid
        drawGrid(ctx, w: Double(w), h: Double(h))
        
        // Axes
        drawAxes(ctx, w: Double(w), h: Double(h))
        
        // Shaded area
        if let shade = shadeArea, shade.functionIndex < functions.count {
            drawShade(ctx, shade: shade, w: Double(w), h: Double(h))
        }
        
        // Functions
        for f in functions {
            drawFunction(ctx, function: f, w: Double(w), h: Double(h))
        }
        
        // Axis labels
        drawLabels(ctx, w: Double(w), h: Double(h))
    }
    
    private func drawGrid(_ ctx: CGContext, w: Double, h: Double) {
        let gridColor: UIColor = isDarkMode
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 0, alpha: 0.06)
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)
        
        let step = gridStep()
        
        var x = (xMin / step).rounded(.down) * step
        while x <= xMax {
            let p = mathToScreen(x, 0)
            ctx.move(to: CGPoint(x: p.x, y: 0))
            ctx.addLine(to: CGPoint(x: p.x, y: h))
            x += step
        }
        
        var y = (yMin / step).rounded(.down) * step
        while y <= yMax {
            let p = mathToScreen(0, y)
            ctx.move(to: CGPoint(x: 0, y: p.y))
            ctx.addLine(to: CGPoint(x: w, y: p.y))
            y += step
        }
        
        ctx.strokePath()
    }
    
    private func drawAxes(_ ctx: CGContext, w: Double, h: Double) {
        let axisColor: UIColor = isDarkMode
            ? UIColor(white: 1, alpha: 0.4)
            : UIColor(white: 0, alpha: 0.4)
        ctx.setStrokeColor(axisColor.cgColor)
        ctx.setLineWidth(1.5)
        
        // X axis
        let origin = mathToScreen(0, 0)
        if origin.y >= 0 && Double(origin.y) <= h {
            ctx.move(to: CGPoint(x: 0, y: origin.y))
            ctx.addLine(to: CGPoint(x: w, y: origin.y))
        }
        // Y axis
        if origin.x >= 0 && Double(origin.x) <= w {
            ctx.move(to: CGPoint(x: origin.x, y: 0))
            ctx.addLine(to: CGPoint(x: origin.x, y: h))
        }
        ctx.strokePath()
    }
    
    private func drawFunction(_ ctx: CGContext, function: GraphFunction, w: Double, h: Double) {
        let color = UIColor(function.color)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2.0)
        
        if function.isDashed {
            ctx.setLineDash(phase: 0, lengths: [6, 4])
        } else {
            ctx.setLineDash(phase: 0, lengths: [])
        }
        
        let steps = Int(w * 2)
        var started = false
        
        for i in 0...steps {
            let x = xMin + (xMax - xMin) * Double(i) / Double(steps)
            let y = function.evaluate(x, sliderValue)
            
            guard y.isFinite && !y.isNaN else {
                started = false
                continue
            }
            
            let clamped = min(max(y, yMin - 10), yMax + 10)
            let p = mathToScreen(x, clamped)
            
            if !started {
                ctx.move(to: p)
                started = true
            } else {
                ctx.addLine(to: p)
            }
        }
        
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
    }
    
    private func drawShade(_ ctx: CGContext, shade: ShadeArea, w: Double, h: Double) {
        let f = functions[shade.functionIndex]
        let color = UIColor(shade.color)
        ctx.setFillColor(color.cgColor)
        
        let steps = 200
        let dx = (shade.to - shade.from) / Double(steps)
        
        let startP = mathToScreen(shade.from, 0)
        ctx.move(to: startP)
        
        for i in 0...steps {
            let x = shade.from + dx * Double(i)
            let y = f.evaluate(x, sliderValue)
            let p = mathToScreen(x, y.isFinite ? y : 0)
            ctx.addLine(to: p)
        }
        
        let endP = mathToScreen(shade.to, 0)
        ctx.addLine(to: endP)
        ctx.closePath()
        ctx.fillPath()
    }
    
    private func drawLabels(_ ctx: CGContext, w: Double, h: Double) {
        let step = gridStep()
        let labelColor: UIColor = isDarkMode
            ? UIColor(white: 1, alpha: 0.5)
            : UIColor(white: 0, alpha: 0.5)
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: labelColor
        ]
        
        let origin = mathToScreen(0, 0)
        
        // X labels
        var x = (xMin / step).rounded(.down) * step
        while x <= xMax {
            if abs(x) > step * 0.1 {
                let p = mathToScreen(x, 0)
                let labelY = min(max(origin.y + 4, 0), CGFloat(h) - 14)
                let str = formatLabel(x)
                (str as NSString).draw(at: CGPoint(x: p.x + 2, y: labelY), withAttributes: attrs)
            }
            x += step
        }
        
        // Y labels
        var y = (yMin / step).rounded(.down) * step
        while y <= yMax {
            if abs(y) > step * 0.1 {
                let p = mathToScreen(0, y)
                let labelX = min(max(origin.x + 4, 0), CGFloat(w) - 30)
                let str = formatLabel(y)
                (str as NSString).draw(at: CGPoint(x: labelX, y: p.y - 12), withAttributes: attrs)
            }
            y += step
        }
    }
    
    private func gridStep() -> Double {
        let range = xMax - xMin
        let raw = range / 10
        let mag = pow(10, floor(log10(raw)))
        let norm = raw / mag
        if norm < 2 { return mag }
        if norm < 5 { return 2 * mag }
        return 5 * mag
    }
    
    private func formatLabel(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1000 { return String(Int(v)) }
        return String(format: "%.1f", v)
    }
}
