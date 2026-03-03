// TransformSolver.swift
// CalcPrime — Engine/Solvers
// Integral transforms: Laplace, inverse Laplace, Fourier, inverse Fourier, Z-transform.
// Symbolic lookup tables + numerical inverse (Stehfest, FFT).
// All step-by-step explanations in Spanish.

import Foundation

// MARK: - TransformSolver

struct TransformSolver {
    
    // MARK: - Laplace Transform (Symbolic)
    
    /// Compute the Laplace transform of f(t) → F(s).
    /// L{f(t)} = ∫₀^∞ f(t) e^{-st} dt
    static func laplace(
        _ expr: ExprNode,
        timeVar t: String = "t",
        freqVar s: String = "s"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Transformada de Laplace",
            math: "\\mathcal{L}\\left\\{\(expr.latex)\\right\\} = \\int_0^{\\infty} \(expr.latex) \\, e^{-\(s)\(t)} \\, d\(t)"
        ))
        
        let result = laplaceTransform(expr, t: t, s: s, steps: &steps)
        
        let simplified = Simplifier.simplify(result)
        
        steps.append(SolutionStep(
            title: "Resultado",
            math: "F(\(s)) = \(simplified.latex)"
        ))
        
        return (simplified, steps)
    }
    
    /// Core Laplace transform using table lookup and linearity.
    private static func laplaceTransform(_ expr: ExprNode, t: String, s: String, steps: inout [SolutionStep]) -> ExprNode {
        let sv = ExprNode.variable(s)
        let tv = ExprNode.variable(t)
        
        // Check if expression depends on t
        guard expr.freeVariables.contains(t) else {
            // Constant: L{c} = c/s
            steps.append(SolutionStep(
                title: "Constante",
                explanation: "L{c} = c/s",
                math: "\\mathcal{L}\\{" + expr.latex + "\\} = \\frac{\(expr.latex)}{\(s)}"
            ))
            return ExprNode.div(expr, sv)
        }
        
        // Linearity: L{a·f + b·g} = a·L{f} + b·L{g}
        if case .add(let terms) = expr {
            steps.append(SolutionStep(
                title: "Linealidad",
                explanation: "L{f + g} = L{f} + L{g}"
            ))
            let transformed = terms.map { laplaceTransform($0, t: t, s: s, steps: &steps) }
            return .add(transformed)
        }
        
        // Linearity: L{c·f} = c·L{f}
        if case .multiply(let factors) = expr {
            var constants: [ExprNode] = []
            var tDependent: [ExprNode] = []
            for f in factors {
                if f.freeVariables.contains(t) { tDependent.append(f) }
                else { constants.append(f) }
            }
            
            if !constants.isEmpty && !tDependent.isEmpty {
                let constPart = constants.count == 1 ? constants[0] : .multiply(constants)
                let tPart = tDependent.count == 1 ? tDependent[0] : .multiply(tDependent)
                let inner = laplaceTransform(tPart, t: t, s: s, steps: &steps)
                return .multiply([constPart, inner])
            }
        }
        
        // ── Table Lookup ──
        
        // L{1} = 1/s
        if expr == .one || expr == .number(1) {
            return ExprNode.div(.one, sv)
        }
        
        // L{t} = 1/s²
        if expr == tv {
            steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{L}\\{\(t)\\} = \\frac{1}{\(s)^2}"))
            return ExprNode.div(.one, .power(sv, .two))
        }
        
        // L{t^n} = n!/s^{n+1}
        if case .power(let base, let exp) = expr, base == tv {
            if let n = exp.numericValue, n == Foundation.floor(n), n >= 0 {
                let nInt = Int(n)
                let factVal = (1...max(1, nInt)).reduce(1, *)
                steps.append(SolutionStep(
                    title: "Tabla",
                    math: "\\mathcal{L}\\{\(t)^{\(nInt)}\\} = \\frac{\(factVal)}{\(s)^{\(nInt + 1)}}"
                ))
                return ExprNode.div(.number(Double(factVal)), .power(sv, .number(Double(nInt + 1))))
            }
        }
        
        // L{e^{at}} = 1/(s-a)
        if case .function(.exp, let args) = expr, args.count == 1 {
            let arg = args[0]
            let a = extractLinearCoefficient(arg, variable: t)
            if let a = a {
                steps.append(SolutionStep(
                    title: "Tabla",
                    math: "\\mathcal{L}\\{e^{\(a.latex)\(t)}\\} = \\frac{1}{\(s) - \(a.latex)}"
                ))
                return ExprNode.div(.one, sv - a)
            }
        }
        
        // L{sin(ωt)} = ω/(s² + ω²)
        if case .function(.sin, let args) = expr, args.count == 1 {
            if let omega = extractLinearCoefficient(args[0], variable: t) {
                steps.append(SolutionStep(
                    title: "Tabla",
                    math: "\\mathcal{L}\\{\\sin(\(omega.latex)\(t))\\} = \\frac{\(omega.latex)}{\(s)^2 + (\(omega.latex))^2}"
                ))
                let omSq = Simplifier.simplify(.power(omega, .two))
                return ExprNode.div(omega, .add([.power(sv, .two), omSq]))
            }
        }
        
        // L{cos(ωt)} = s/(s² + ω²)
        if case .function(.cos, let args) = expr, args.count == 1 {
            if let omega = extractLinearCoefficient(args[0], variable: t) {
                steps.append(SolutionStep(
                    title: "Tabla",
                    math: "\\mathcal{L}\\{\\cos(\(omega.latex)\(t))\\} = \\frac{\(s)}{\(s)^2 + (\(omega.latex))^2}"
                ))
                let omSq = Simplifier.simplify(.power(omega, .two))
                return ExprNode.div(sv, .add([.power(sv, .two), omSq]))
            }
        }
        
        // L{sinh(ωt)} = ω/(s² - ω²)
        if case .function(.sinh, let args) = expr, args.count == 1 {
            if let omega = extractLinearCoefficient(args[0], variable: t) {
                let omSq = Simplifier.simplify(.power(omega, .two))
                return ExprNode.div(omega, .add([.power(sv, .two), .negate(omSq)]))
            }
        }
        
        // L{cosh(ωt)} = s/(s² - ω²)
        if case .function(.cosh, let args) = expr, args.count == 1 {
            if let omega = extractLinearCoefficient(args[0], variable: t) {
                let omSq = Simplifier.simplify(.power(omega, .two))
                return ExprNode.div(sv, .add([.power(sv, .two), .negate(omSq)]))
            }
        }
        
        // L{t·e^{at}} = 1/(s-a)²
        if case .multiply(let factors) = expr {
            if factors.count == 2 {
                // Check t^n * e^{at}
                if let (n, a) = matchTnExpAt(factors, t: t) {
                    let factVal = (1...max(1, n)).reduce(1, *)
                    let sMinusA = sv - a
                    steps.append(SolutionStep(
                        title: "Desplazamiento en s",
                        math: "\\mathcal{L}\\{\(t)^{\(n)} e^{\(a.latex)\(t)}\\} = \\frac{\(factVal)}{(\(s)-\(a.latex))^{\(n + 1)}}"
                    ))
                    return ExprNode.div(.number(Double(factVal)), .power(sMinusA, .number(Double(n + 1))))
                }
                
                // Check e^{at} · sin(ωt) or e^{at} · cos(ωt)
                if let (a, fn, omega) = matchExpTrig(factors, t: t) {
                    let sShifted = sv - a
                    let omSq = Simplifier.simplify(.power(omega, .two))
                    let denom = ExprNode.add([.power(sShifted, .two), omSq])
                    
                    if fn == .sin {
                        steps.append(SolutionStep(
                            title: "Desplazamiento + trig",
                            math: "\\mathcal{L}\\{e^{\(a.latex)\(t)}\\sin(\(omega.latex)\(t))\\} = \\frac{\(omega.latex)}{(\(s)-\(a.latex))^2+(\(omega.latex))^2}"
                        ))
                        return ExprNode.div(omega, denom)
                    } else {
                        steps.append(SolutionStep(
                            title: "Desplazamiento + trig",
                            math: "\\mathcal{L}\\{e^{\(a.latex)\(t)}\\cos(\(omega.latex)\(t))\\} = \\frac{\(s)-\(a.latex)}{(\(s)-\(a.latex))^2+(\(omega.latex))^2}"
                        ))
                        return ExprNode.div(sShifted, denom)
                    }
                }
            }
        }
        
        // L{δ(t-a)} = e^{-as}
        if case .diracDelta(let arg) = expr {
            let a = extractShift(arg, variable: t)
            if a.isZero {
                steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{L}\\{\\delta(\(t))\\} = 1"))
                return .one
            } else {
                steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{L}\\{\\delta(\(t)-\(a.latex))\\} = e^{-\(a.latex)\(s)}"))
                return .function(.exp, [.negate(.multiply([a, sv]))])
            }
        }
        
        // L{u(t-a)f(t-a)} = e^{-as}F(s) (second shifting theorem)
        if case .heaviside(let arg) = expr {
            let a = extractShift(arg, variable: t)
            steps.append(SolutionStep(
                title: "Tabla (escalón unitario)",
                math: "\\mathcal{L}\\{u(\(t)-\(a.latex))\\} = \\frac{e^{-\(a.latex)\(s)}}{\(s)}"
            ))
            return ExprNode.div(
                .function(.exp, [.negate(.multiply([a, sv]))]),
                sv
            )
        }
        
        // Fallback: return symbolic notation
        steps.append(SolutionStep(
            title: "Transformada simbólica",
            explanation: "No se encontró una forma cerrada en la tabla. Se deja en forma simbólica."
        ))
        return .laplace(expr, t, s)
    }
    
    // MARK: - Inverse Laplace Transform
    
    /// Compute the inverse Laplace transform F(s) → f(t).
    static func inverseLaplace(
        _ expr: ExprNode,
        freqVar s: String = "s",
        timeVar t: String = "t"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Transformada inversa de Laplace",
            math: "\\mathcal{L}^{-1}\\left\\{\(expr.latex)\\right\\}"
        ))
        
        let result = inverseLaplaceTransform(expr, s: s, t: t, steps: &steps)
        let simplified = Simplifier.simplify(result)
        
        steps.append(SolutionStep(
            title: "Resultado",
            math: "f(\(t)) = \(simplified.latex)"
        ))
        
        return (simplified, steps)
    }
    
    /// Core inverse Laplace using partial fractions + table.
    private static func inverseLaplaceTransform(_ expr: ExprNode, s: String, t: String, steps: inout [SolutionStep]) -> ExprNode {
        let sv = ExprNode.variable(s)
        let tv = ExprNode.variable(t)
        
        // Linearity
        if case .add(let terms) = expr {
            return .add(terms.map { inverseLaplaceTransform($0, s: s, t: t, steps: &steps) })
        }
        
        // Constant multiple
        if case .multiply(let factors) = expr {
            var constants: [ExprNode] = []
            var sDependent: [ExprNode] = []
            for f in factors {
                if f.freeVariables.contains(s) { sDependent.append(f) }
                else { constants.append(f) }
            }
            
            if !constants.isEmpty && !sDependent.isEmpty {
                let constPart = constants.count == 1 ? constants[0] : .multiply(constants)
                let sPart = sDependent.count == 1 ? sDependent[0] : .multiply(sDependent)
                return .multiply([constPart, inverseLaplaceTransform(sPart, s: s, t: t, steps: &steps)])
            }
        }
        
        // ── Table Lookup ──
        
        // L⁻¹{1/s} = 1 (u(t))
        if case .power(let base, let exp) = expr, base == sv {
            if let n = exp.numericValue, n < 0 {
                let nPos = Int(-n)
                // L⁻¹{1/s^n} = t^{n-1}/(n-1)!
                let factVal = max(1, (1..<nPos).reduce(1, *))
                steps.append(SolutionStep(
                    title: "Tabla",
                    math: "\\mathcal{L}^{-1}\\left\\{\\frac{1}{\(s)^{\(nPos)}}\\right\\} = \\frac{\(t)^{\(nPos - 1)}}{\(factVal)}"
                ))
                if nPos == 1 { return .one }
                return ExprNode.div(.power(tv, .number(Double(nPos - 1))), .number(Double(factVal)))
            }
        }
        
        // L⁻¹{1/(s-a)} = e^{at}
        if case .multiply(let factors) = expr {
            // Check for 1/(s-a) pattern
            for (i, f) in factors.enumerated() {
                if case .power(let base, let exp) = f, exp == .negOne {
                    if case .add(let terms) = base {
                        // s - a pattern
                        if let a = extractSminusA(terms, sVar: s) {
                            steps.append(SolutionStep(
                                title: "Tabla",
                                math: "\\mathcal{L}^{-1}\\left\\{\\frac{1}{\(s)-\(a.latex)}\\right\\} = e^{\(a.latex)\(t)}"
                            ))
                            var remaining = factors
                            remaining.remove(at: i)
                            let rest = remaining.isEmpty ? ExprNode.one : (remaining.count == 1 ? remaining[0] : .multiply(remaining))
                            return .multiply([rest, .function(.exp, [.multiply([a, tv])])])
                        }
                    }
                }
            }
        }
        
        // L⁻¹{ω/(s²+ω²)} = sin(ωt)
        // L⁻¹{s/(s²+ω²)} = cos(ωt)
        if let (num, denom) = extractFraction(expr) {
            // Check if denom is s² + ω²
            if case .add(let terms) = denom, terms.count == 2 {
                if case .power(let base, let exp) = terms[0], base == sv, exp == .two {
                    let omegaSq = terms[1]
                    if let omSq = omegaSq.numericValue, omSq > 0 {
                        let omega = Foundation.sqrt(omSq)
                        let omExpr = cleanNumber(omega)
                        
                        if num == sv {
                            steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{L}^{-1}\\left\\{\\frac{\(s)}{\(s)^2+\(fmt(omSq))}\\right\\} = \\cos(\(fmt(omega))\(t))"))
                            return .function(.cos, [.multiply([omExpr, tv])])
                        }
                        
                        if let numVal = num.numericValue, Swift.abs(numVal - omega) < 1e-10 {
                            steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{L}^{-1}\\left\\{\\frac{\(fmt(omega))}{\(s)^2+\(fmt(omSq))}\\right\\} = \\sin(\(fmt(omega))\(t))"))
                            return .function(.sin, [.multiply([omExpr, tv])])
                        }
                    }
                }
            }
        }
        
        // L⁻¹{e^{-as} F(s)} = u(t-a)·f(t-a) (second shifting)
        if case .multiply(let factors) = expr {
            for (i, f) in factors.enumerated() {
                if case .function(.exp, let args) = f, args.count == 1 {
                    if case .negate(let inner) = args[0] {
                        if case .multiply(let ms) = inner, ms.count == 2 {
                            if ms.contains(where: { $0 == sv }) {
                                let a = ms.first(where: { $0 != sv }) ?? .zero
                                var remaining = factors
                                remaining.remove(at: i)
                                let Fs = remaining.count == 1 ? remaining[0] : .multiply(remaining)
                                let ft = inverseLaplaceTransform(Fs, s: s, t: t, steps: &steps)
                                let shifted = ft.substitute(t, with: tv - a)
                                steps.append(SolutionStep(
                                    title: "Segundo teorema de desplazamiento",
                                    math: "\\mathcal{L}^{-1}\\{e^{-\(a.latex)\(s)} F(\(s))\\} = u(\(t)-\(a.latex)) f(\(t)-\(a.latex))"
                                ))
                                return .multiply([.heaviside(tv - a), shifted])
                            }
                        }
                    }
                }
            }
        }
        
        // Fallback
        steps.append(SolutionStep(
            title: "Forma simbólica",
            explanation: "No se encontró inversión directa. Se requiere fracciones parciales o método numérico."
        ))
        return .inverseLaplace(expr, s, t)
    }
    
    // MARK: - Fourier Transform
    
    /// Compute Fourier transform: F(ω) = ∫_{-∞}^{∞} f(t) e^{-iωt} dt
    static func fourierTransform(
        _ expr: ExprNode,
        timeVar t: String = "t",
        freqVar omega: String = "ω"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let w = ExprNode.variable(omega)
        let tv = ExprNode.variable(t)
        
        steps.append(SolutionStep(
            title: "Transformada de Fourier",
            math: "\\hat{f}(\(omega)) = \\int_{-\\infty}^{\\infty} \(expr.latex) \\, e^{-i\(omega)\(t)} \\, d\(t)"
        ))
        
        // Table lookup for common transforms
        
        // F{e^{-at²}} = √(π/a) e^{-ω²/(4a)} (Gaussian)
        if case .function(.exp, let args) = expr, args.count == 1 {
            if case .negate(let inner) = args[0] {
                if case .multiply(let fs) = inner {
                    // Check for a·t²
                    let hasTsq = fs.contains(where: {
                        if case .power(let b, let e) = $0 { return b == tv && e == .two }
                        return false
                    })
                    if hasTsq {
                        let aCoeff = fs.filter({
                            if case .power(let b, let e) = $0 { return !(b == tv && e == .two) }
                            return true
                        })
                        let a = aCoeff.isEmpty ? ExprNode.one : (aCoeff.count == 1 ? aCoeff[0] : .multiply(aCoeff))
                        
                        steps.append(SolutionStep(
                            title: "Tabla (Gaussiana)",
                            math: "\\mathcal{F}\\{e^{-\(a.latex)\(t)^2}\\} = \\sqrt{\\frac{\\pi}{\(a.latex)}} e^{-\\frac{\(omega)^2}{4\(a.latex)}}"
                        ))
                        
                        let result = ExprNode.multiply([
                            .function(.sqrt, [ExprNode.div(.pi, a)]),
                            .function(.exp, [.negate(ExprNode.div(.power(w, .two), .multiply([.number(4), a])))])
                        ])
                        return (Simplifier.simplify(result), steps)
                    }
                }
            }
        }
        
        // F{e^{-a|t|}} = 2a/(a² + ω²) (bilateral exponential)
        // F{rect(t)} = sinc(ω/2)
        // F{δ(t)} = 1
        if case .diracDelta(let arg) = expr, arg == tv {
            steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{F}\\{\\delta(\(t))\\} = 1"))
            return (.one, steps)
        }
        
        // F{1} = 2πδ(ω)
        if !expr.freeVariables.contains(t) {
            steps.append(SolutionStep(
                title: "Tabla",
                math: "\\mathcal{F}\\{\(expr.latex)\\} = 2\\pi \\cdot \(expr.latex) \\cdot \\delta(\(omega))"
            ))
            return (ExprNode.multiply([.number(2), .pi, expr, .diracDelta(w)]), steps)
        }
        
        // Fallback
        steps.append(SolutionStep(
            title: "Forma simbólica",
            explanation: "Se deja en notación integral"
        ))
        return (.fourier(expr, t, omega), steps)
    }
    
    // MARK: - Z-Transform
    
    /// Compute Z-transform: X(z) = Σ_{n=0}^{∞} x[n] z^{-n}
    static func zTransform(
        _ expr: ExprNode,
        seqVar n: String = "n",
        zVar z: String = "z"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let zv = ExprNode.variable(z)
        let nv = ExprNode.variable(n)
        
        steps.append(SolutionStep(
            title: "Transformada Z",
            math: "X(\(z)) = \\sum_{\(n)=0}^{\\infty} x[\(n)] \\, \(z)^{-\(n)}"
        ))
        
        // Z{a^n} = z/(z-a)
        if case .power(let base, let exp) = expr, exp == nv {
            let a = base
            steps.append(SolutionStep(
                title: "Tabla",
                math: "\\mathcal{Z}\\{\(a.latex)^{\(n)}\\} = \\frac{\(z)}{\(z) - \(a.latex)}"
            ))
            return (ExprNode.div(zv, zv - a), steps)
        }
        
        // Z{1} = z/(z-1)
        if !expr.freeVariables.contains(n) {
            steps.append(SolutionStep(
                title: "Tabla",
                math: "\\mathcal{Z}\\{\(expr.latex)\\} = \(expr.latex) \\cdot \\frac{\(z)}{\(z)-1}"
            ))
            return (.multiply([expr, ExprNode.div(zv, zv - .one)]), steps)
        }
        
        // Z{n} = z/(z-1)²
        if expr == nv {
            steps.append(SolutionStep(
                title: "Tabla",
                math: "\\mathcal{Z}\\{\(n)\\} = \\frac{\(z)}{(\(z)-1)^2}"
            ))
            return (ExprNode.div(zv, .power(zv - .one, .two)), steps)
        }
        
        // Z{n²} = z(z+1)/(z-1)³
        if case .power(let base, let exp) = expr, base == nv, exp == .two {
            steps.append(SolutionStep(
                title: "Tabla",
                math: "\\mathcal{Z}\\{\(n)^2\\} = \\frac{\(z)(\(z)+1)}{(\(z)-1)^3}"
            ))
            return (ExprNode.div(
                .multiply([zv, zv + .one]),
                .power(zv - .one, .three)
            ), steps)
        }
        
        // Z{u[n]} = z/(z-1)
        if case .heaviside(let arg) = expr, arg == nv {
            return (ExprNode.div(zv, zv - .one), steps)
        }
        
        // Z{δ[n]} = 1
        if case .diracDelta(let arg) = expr, arg == nv {
            steps.append(SolutionStep(title: "Tabla", math: "\\mathcal{Z}\\{\\delta[\(n)]\\} = 1"))
            return (.one, steps)
        }
        
        // Fallback
        return (.zTransform(expr, n, z), steps)
    }
    
    // MARK: - Numerical Inverse Laplace (Stehfest Algorithm)
    
    /// Stehfest algorithm for numerical inverse Laplace at time t.
    /// f(t) ≈ (ln 2 / t) Σ_{k=1}^{N} V_k F(k·ln2/t)
    static func stehfestInverseLaplace(
        F: (Double) -> Double,
        at t: Double,
        N: Int = 12
    ) -> Double {
        guard t > 0 else { return 0 }
        let ln2 = Foundation.log(2.0)
        let ln2OverT = ln2 / t
        
        var sum = 0.0
        for k in 1...N {
            let Vk = stehfestWeight(k: k, N: N)
            sum += Vk * F(Double(k) * ln2OverT)
        }
        
        return sum * ln2OverT
    }
    
    /// Compute Stehfest weights.
    private static func stehfestWeight(k: Int, N: Int) -> Double {
        let halfN = N / 2
        var sum = 0.0
        
        let jMin = (k + 1) / 2
        let jMax = Swift.min(k, halfN)
        
        for j in jMin...jMax {
            let num = Foundation.pow(Double(j), Double(halfN)) * factorialDouble(2 * j)
            let denom = factorialDouble(halfN - j) * factorialDouble(j) * factorialDouble(j - 1) *
                        factorialDouble(k - j) * factorialDouble(2 * j - k)
            sum += num / denom
        }
        
        return Foundation.pow(-1, Double(k + halfN)) * sum
    }
    
    private static func factorialDouble(_ n: Int) -> Double {
        guard n > 1 else { return 1 }
        return (2...n).reduce(1.0) { $0 * Double($1) }
    }
    
    // MARK: - Numerical FFT (Cooley-Tukey)
    
    /// Compute DFT of a signal.
    static func dft(_ signal: [Double]) -> [(Double, Double)] {
        let N = signal.count
        var result: [(Double, Double)] = []
        
        for k in 0..<N {
            var re = 0.0, im = 0.0
            for n in 0..<N {
                let angle = -2.0 * .pi * Double(k) * Double(n) / Double(N)
                re += signal[n] * Foundation.cos(angle)
                im += signal[n] * Foundation.sin(angle)
            }
            result.append((re, im))
        }
        
        return result
    }
    
    /// Compute IDFT.
    static func idft(_ spectrum: [(Double, Double)]) -> [Double] {
        let N = spectrum.count
        var result: [Double] = []
        
        for n in 0..<N {
            var sum = 0.0
            for k in 0..<N {
                let angle = 2.0 * .pi * Double(k) * Double(n) / Double(N)
                sum += spectrum[k].0 * Foundation.cos(angle) - spectrum[k].1 * Foundation.sin(angle)
            }
            result.append(sum / Double(N))
        }
        
        return result
    }
    
    /// FFT (radix-2, Cooley-Tukey). Input length must be power of 2.
    static func fft(_ signal: [Double]) -> [(Double, Double)] {
        let N = signal.count
        guard N > 1 else { return [(signal[0], 0)] }
        
        // Pad to next power of 2 if needed
        let n2 = nextPow2(N)
        var padded = signal
        while padded.count < n2 { padded.append(0) }
        
        return fftRecursive(padded.map { ($0, 0.0) })
    }
    
    private static func fftRecursive(_ x: [(Double, Double)]) -> [(Double, Double)] {
        let N = x.count
        guard N > 1 else { return x }
        
        let even = fftRecursive(stride(from: 0, to: N, by: 2).map { x[$0] })
        let odd  = fftRecursive(stride(from: 1, to: N, by: 2).map { x[$0] })
        
        var result = Array(repeating: (0.0, 0.0), count: N)
        for k in 0..<(N / 2) {
            let angle = -2.0 * .pi * Double(k) / Double(N)
            let twiddle = (Foundation.cos(angle), Foundation.sin(angle))
            let t = (odd[k].0 * twiddle.0 - odd[k].1 * twiddle.1,
                     odd[k].0 * twiddle.1 + odd[k].1 * twiddle.0)
            result[k] = (even[k].0 + t.0, even[k].1 + t.1)
            result[k + N / 2] = (even[k].0 - t.0, even[k].1 - t.1)
        }
        
        return result
    }
    
    private static func nextPow2(_ n: Int) -> Int {
        var p = 1
        while p < n { p *= 2 }
        return p
    }
    
    // MARK: - Convolution
    
    /// Compute convolution f * g numerically.
    static func convolve(_ f: [Double], _ g: [Double]) -> [Double] {
        let N = f.count + g.count - 1
        let n2 = nextPow2(N)
        
        var fp = f; while fp.count < n2 { fp.append(0) }
        var gp = g; while gp.count < n2 { gp.append(0) }
        
        let Ff = fft(fp)
        let Fg = fft(gp)
        
        // Element-wise multiply in frequency domain
        var product: [(Double, Double)] = []
        for i in 0..<n2 {
            let re = Ff[i].0 * Fg[i].0 - Ff[i].1 * Fg[i].1
            let im = Ff[i].0 * Fg[i].1 + Ff[i].1 * Fg[i].0
            product.append((re, im))
        }
        
        let result = idft(product)
        return Array(result.prefix(N))
    }
    
    // MARK: - Helpers
    
    /// Extract coefficient 'a' from expression of form a*t (linear in t).
    private static func extractLinearCoefficient(_ expr: ExprNode, variable t: String) -> ExprNode? {
        let tv = ExprNode.variable(t)
        
        if expr == tv { return .one }
        
        if case .multiply(let factors) = expr {
            var coeff: [ExprNode] = []
            var hasT = false
            for f in factors {
                if f == tv { hasT = true }
                else { coeff.append(f) }
            }
            if hasT {
                if coeff.isEmpty { return .one }
                return coeff.count == 1 ? coeff[0] : .multiply(coeff)
            }
        }
        
        if case .negate(let inner) = expr {
            if let c = extractLinearCoefficient(inner, variable: t) {
                return .negate(c)
            }
        }
        
        return nil
    }
    
    /// Extract 'a' from expression (t - a).
    private static func extractShift(_ expr: ExprNode, variable t: String) -> ExprNode {
        let tv = ExprNode.variable(t)
        
        if expr == tv { return .zero }
        
        if case .add(let terms) = expr {
            var tPart: ExprNode?
            var rest: [ExprNode] = []
            for term in terms {
                if term == tv { tPart = term }
                else { rest.append(term) }
            }
            if tPart != nil {
                // a is the negation of the rest
                let r = rest.count == 1 ? rest[0] : .add(rest)
                return .negate(r)
            }
        }
        
        return .zero
    }
    
    /// Match t^n * e^{at} pattern in a product.
    private static func matchTnExpAt(_ factors: [ExprNode], t: String) -> (Int, ExprNode)? {
        let tv = ExprNode.variable(t)
        var n: Int?
        var a: ExprNode?
        
        for f in factors {
            if f == tv { n = 1 }
            else if case .power(let base, let exp) = f, base == tv {
                if let v = exp.numericValue { n = Int(v) }
            }
            else if case .function(.exp, let args) = f, args.count == 1 {
                a = extractLinearCoefficient(args[0], variable: t)
            }
        }
        
        if let n = n, let a = a { return (n, a) }
        return nil
    }
    
    /// Match e^{at} * sin/cos(ωt) pattern.
    private static func matchExpTrig(_ factors: [ExprNode], t: String) -> (ExprNode, MathFunc, ExprNode)? {
        var a: ExprNode?
        var fn: MathFunc?
        var omega: ExprNode?
        
        for f in factors {
            if case .function(.exp, let args) = f, args.count == 1 {
                a = extractLinearCoefficient(args[0], variable: t)
            }
            if case .function(.sin, let args) = f, args.count == 1 {
                fn = .sin
                omega = extractLinearCoefficient(args[0], variable: t)
            }
            if case .function(.cos, let args) = f, args.count == 1 {
                fn = .cos
                omega = extractLinearCoefficient(args[0], variable: t)
            }
        }
        
        if let a = a, let fn = fn, let omega = omega { return (a, fn, omega) }
        return nil
    }
    
    /// Extract 'a' from [s, -a] pattern (s - a).
    private static func extractSminusA(_ terms: [ExprNode], sVar s: String) -> ExprNode? {
        let sv = ExprNode.variable(s)
        guard terms.count == 2 else { return nil }
        
        if terms[0] == sv {
            if case .negate(let inner) = terms[1] { return inner }
            return .negate(terms[1])
        }
        if terms[1] == sv {
            if case .negate(let inner) = terms[0] { return inner }
            return .negate(terms[0])
        }
        
        return nil
    }
    
    /// Extract numerator and denominator from a fraction expression.
    private static func extractFraction(_ expr: ExprNode) -> (ExprNode, ExprNode)? {
        if case .multiply(let factors) = expr {
            var num: [ExprNode] = []
            var den: [ExprNode] = []
            for f in factors {
                if case .power(let base, let exp) = f {
                    if case .negate(let inner) = exp {
                        den.append(inner == .one ? base : .power(base, inner))
                        continue
                    }
                    if let v = exp.numericValue, v < 0 {
                        den.append(v == -1 ? base : .power(base, .number(-v)))
                        continue
                    }
                }
                num.append(f)
            }
            if !den.isEmpty {
                let n = num.isEmpty ? ExprNode.one : (num.count == 1 ? num[0] : .multiply(num))
                let d = den.count == 1 ? den[0] : .multiply(den)
                return (n, d)
            }
        }
        return nil
    }
    
    private static func cleanNumber(_ v: Double) -> ExprNode {
        if Swift.abs(v - Double(Int(v))) < 1e-10 && Swift.abs(v) < 1e12 {
            return .number(Double(Int(v)))
        }
        return .number(v)
    }
    
    private static func fmt(_ v: Double) -> String {
        if Swift.abs(v - Double(Int(v))) < 1e-10 && Swift.abs(v) < 1e12 { return "\(Int(v))" }
        return String(format: "%.4g", v)
    }
}
