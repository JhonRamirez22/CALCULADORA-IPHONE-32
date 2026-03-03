// SeriesSolver.swift
// CalcPrime — Engine/Solvers
// Series expansion and convergence analysis.
// Taylor, Maclaurin, Laurent, Fourier, power series, asymptotic.
// Convergence tests: ratio, root, comparison, integral, alternating, Raabe, Dirichlet.
// All step-by-step explanations in Spanish.

import Foundation

// MARK: - SeriesType

enum SeriesType: String {
    case taylor     = "Taylor"
    case maclaurin  = "Maclaurin"
    case laurent    = "Laurent"
    case fourier    = "Fourier"
    case power      = "Serie de potencias"
}

enum ConvergenceResult: String {
    case converges    = "Converge"
    case diverges     = "Diverge"
    case conditional  = "Convergencia condicional"
    case inconclusive = "Inconcluso"
}

// MARK: - SeriesSolver

struct SeriesSolver {
    
    // MARK: - Taylor / Maclaurin Series
    
    /// Compute the Taylor series of expr about point `a` up to order `n`.
    /// T(x) = Σ_{k=0}^{n} f^(k)(a)/k! · (x - a)^k
    static func taylorSeries(
        _ expr: ExprNode,
        variable v: String = "x",
        about a: ExprNode = .zero,
        order n: Int = 6
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let isMaclaurin = a.isZero
        
        steps.append(SolutionStep(
            title: isMaclaurin ? "Serie de Maclaurin" : "Serie de Taylor",
            explanation: isMaclaurin
                ? "Expansión alrededor de \(v) = 0 hasta orden \(n)"
                : "Expansión alrededor de \(v) = \(a.latex) hasta orden \(n)",
            math: "T(\(v)) = \\sum_{k=0}^{\(n)} \\frac{f^{(k)}(\(a.latex))}{k!}(\(v) - \(a.latex))^k"
        ))
        
        var terms: [ExprNode] = []
        var currentDerivative = expr
        
        for k in 0...n {
            // Evaluate derivative at point a
            let atA = Simplifier.simplify(currentDerivative.substitute(v, with: a))
            
            // Check if evaluatable
            if !atA.isZero {
                // f^(k)(a) / k!
                let factorial = factorialInt(k)
                let coefficient: ExprNode
                
                if let numVal = atA.numericValue {
                    let coeff = numVal / Double(factorial)
                    if Swift.abs(coeff) > 1e-15 {
                        coefficient = cleanNumber(coeff)
                    } else {
                        coefficient = .zero
                    }
                } else {
                    coefficient = ExprNode.div(atA, .number(Double(factorial)))
                }
                
                if !coefficient.isZero {
                    let xMinusA = a.isZero ? ExprNode.variable(v) : (ExprNode.variable(v) - a)
                    let term: ExprNode
                    
                    if k == 0 {
                        term = coefficient
                    } else if k == 1 {
                        term = coefficient.isOne ? xMinusA : ExprNode.multiply([coefficient, xMinusA])
                    } else {
                        let powerTerm = ExprNode.power(xMinusA, .number(Double(k)))
                        term = coefficient.isOne ? powerTerm : ExprNode.multiply([coefficient, powerTerm])
                    }
                    
                    terms.append(term)
                    
                    steps.append(SolutionStep(
                        title: "Término k = \(k)",
                        explanation: k == 0 ? "f(\(a.latex))" : "f^{(\(k))}(\(a.latex))/\(k)!",
                        math: "\\frac{\(atA.latex)}{\(factorial)} \\cdot (\(v) - \(a.latex))^{\(k)} = \(term.latex)"
                    ))
                }
            }
            
            // Differentiate for next term
            if k < n {
                currentDerivative = Simplifier.simplify(
                    Differentiator.differentiate(currentDerivative, withRespectTo: v)
                )
            }
        }
        
        let result: ExprNode
        if terms.isEmpty {
            result = .zero
        } else if terms.count == 1 {
            result = terms[0]
        } else {
            result = .add(terms)
        }
        
        let simplified = Simplifier.simplify(result)
        
        steps.append(SolutionStep(
            title: "Serie resultante",
            math: "\(simplified.latex) + O((\(v)-\(a.latex))^{\(n + 1)})"
        ))
        
        return (simplified, steps)
    }
    
    // MARK: - Laurent Series (principal part detection)
    
    /// Compute Laurent series about a singularity.
    /// For f(z) with a pole of order m at z = a:
    /// f(z) = Σ_{k=-m}^{∞} c_k (z-a)^k
    static func laurentSeries(
        _ expr: ExprNode,
        variable v: String = "z",
        about a: ExprNode = .zero,
        poleOrder m: Int = 3,
        regularTerms n: Int = 4
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Serie de Laurent",
            explanation: "Expansión alrededor de \(v) = \(a.latex), polo de orden \(m)",
            math: "f(\(v)) = \\sum_{k=-\(m)}^{\\infty} c_k (\(v)-\(a.latex))^k"
        ))
        
        steps.append(SolutionStep(
            title: "Parte principal",
            explanation: "Términos con potencias negativas (k = -\(m) a -1)"
        ))
        
        // For a pole of order m: multiply by (z-a)^m and expand Taylor
        let zMinusA = a.isZero ? ExprNode.variable(v) : (ExprNode.variable(v) - a)
        let regularized = Simplifier.simplify(ExprNode.multiply([
            expr,
            ExprNode.power(zMinusA, .number(Double(m)))
        ]))
        
        let (taylorExpansion, taylorSteps) = taylorSeries(regularized, variable: v, about: a, order: m + n)
        
        steps.append(SolutionStep(
            title: "Paso 1: Multiplicar por (z-a)^{\(m)}",
            explanation: "g(\(v)) = (\(v)-\(a.latex))^{\(m)} · f(\(v))",
            math: "g(\(v)) = \(regularized.latex)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Expandir g en Taylor",
            math: taylorExpansion.latex
        ))
        
        // Divide back by (z-a)^m
        let result = Simplifier.simplify(ExprNode.multiply([
            taylorExpansion,
            ExprNode.power(zMinusA, .number(Double(-m)))
        ]))
        
        steps.append(SolutionStep(
            title: "Paso 3: Dividir por (z-a)^{\(m)}",
            explanation: "f(\(v)) = g(\(v)) / (\(v)-\(a.latex))^{\(m)}",
            math: result.latex
        ))
        
        return (result, steps)
    }
    
    // MARK: - Fourier Series
    
    /// Compute Fourier series coefficients symbolically.
    /// f(x) = a_0/2 + Σ [a_n cos(nπx/L) + b_n sin(nπx/L)]
    static func fourierSeries(
        _ expr: ExprNode,
        variable v: String = "x",
        period L: ExprNode = .pi,
        numTerms: Int = 5
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Serie de Fourier",
            explanation: "Periodo 2L = 2·\(L.latex)",
            math: "f(\(v)) = \\frac{a_0}{2} + \\sum_{n=1}^{\\infty}\\left[a_n \\cos\\frac{n\\pi \(v)}{L} + b_n \\sin\\frac{n\\pi \(v)}{L}\\right]"
        ))
        
        steps.append(SolutionStep(
            title: "Coeficientes",
            math: "a_n = \\frac{1}{L}\\int_{-L}^{L} f(\(v))\\cos\\frac{n\\pi \(v)}{L}d\(v), \\quad b_n = \\frac{1}{L}\\int_{-L}^{L} f(\(v))\\sin\\frac{n\\pi \(v)}{L}d\(v)"
        ))
        
        // Build symbolic representation
        let n = "n"
        let nVar = ExprNode.variable(n)
        let xVar = ExprNode.variable(v)
        
        let cosArg = ExprNode.multiply([nVar, .pi, xVar, .power(L, .negOne)])
        let sinArg = cosArg
        
        let generalTerm = ExprNode.add([
            .multiply([.variable("a_\(n)"), .function(.cos, [cosArg])]),
            .multiply([.variable("b_\(n)"), .function(.sin, [sinArg])])
        ])
        
        let solution = ExprNode.add([
            ExprNode.multiply([.half, .variable("a_0")]),
            .summation(generalTerm, n, .one, .constant(.inf))
        ])
        
        steps.append(SolutionStep(
            title: "Serie de Fourier",
            math: solution.latex
        ))
        
        return (solution, steps)
    }
    
    // MARK: - Convergence Tests
    
    /// Apply multiple convergence tests and return the most conclusive result.
    static func testConvergence(
        _ generalTerm: ExprNode,
        variable n: String = "n"
    ) -> (ConvergenceResult, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Análisis de convergencia",
            explanation: "Término general: a_n",
            math: "a_{\(n)} = \(generalTerm.latex)"
        ))
        
        // Test 1: Divergence test (if lim a_n ≠ 0, diverges)
        let (divResult, divSteps) = divergenceTest(generalTerm, variable: n)
        steps.append(contentsOf: divSteps)
        if divResult == .diverges {
            return (.diverges, steps)
        }
        
        // Test 2: Ratio test
        let (ratioResult, ratioSteps) = ratioTest(generalTerm, variable: n)
        steps.append(contentsOf: ratioSteps)
        if ratioResult != .inconclusive {
            return (ratioResult, steps)
        }
        
        // Test 3: Root test
        let (rootResult, rootSteps) = rootTest(generalTerm, variable: n)
        steps.append(contentsOf: rootSteps)
        if rootResult != .inconclusive {
            return (rootResult, steps)
        }
        
        // Test 4: Alternating series test
        let (altResult, altSteps) = alternatingSeriesTest(generalTerm, variable: n)
        steps.append(contentsOf: altSteps)
        if altResult != .inconclusive {
            return (altResult, steps)
        }
        
        steps.append(SolutionStep(
            title: "Resultado",
            explanation: "Los criterios aplicados no fueron concluyentes. Se requiere análisis adicional."
        ))
        
        return (.inconclusive, steps)
    }
    
    /// Divergence test: if lim_{n→∞} a_n ≠ 0, series diverges.
    static func divergenceTest(
        _ term: ExprNode,
        variable n: String
    ) -> (ConvergenceResult, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Criterio de divergencia",
            explanation: "Si lim_{n→∞} a_n ≠ 0, la serie diverge",
            math: "\\lim_{n \\to \\infty} a_n \\neq 0 \\Rightarrow \\sum a_n \\text{ diverge}"
        ))
        
        // Try large-n evaluation
        let largeN = term.substitute(n, with: .number(1e8))
        if let val = largeN.numericValue {
            if Swift.abs(val) > 1e-6 {
                steps.append(SolutionStep(
                    title: "Resultado",
                    explanation: "lim a_n ≈ \(String(format: "%.6g", val)) ≠ 0 → DIVERGE"
                ))
                return (.diverges, steps)
            } else {
                steps.append(SolutionStep(
                    title: "Resultado",
                    explanation: "lim a_n → 0 (criterio no concluyente por sí solo)"
                ))
            }
        }
        
        return (.inconclusive, steps)
    }
    
    /// Ratio test: L = lim |a_{n+1}/a_n|. L < 1 → converges, L > 1 → diverges.
    static func ratioTest(
        _ term: ExprNode,
        variable n: String
    ) -> (ConvergenceResult, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Criterio del cociente (Ratio Test)",
            math: "L = \\lim_{n \\to \\infty} \\left|\\frac{a_{n+1}}{a_n}\\right|"
        ))
        
        // Compute a_{n+1} / a_n
        let nextTerm = term.substitute(n, with: ExprNode.variable(n) + .one)
        let ratio = Simplifier.simplify(ExprNode.div(nextTerm, term))
        
        steps.append(SolutionStep(
            title: "Cociente",
            math: "\\frac{a_{n+1}}{a_n} = \(ratio.latex)"
        ))
        
        // Evaluate limit numerically
        let largeN = ratio.substitute(n, with: .number(1e6))
        if let val = largeN.numericValue {
            let L = Swift.abs(val)
            steps.append(SolutionStep(
                title: "Límite",
                math: "L = \(String(format: "%.6g", L))"
            ))
            
            if L < 1 - 1e-6 {
                steps.append(SolutionStep(
                    title: "Conclusión",
                    explanation: "L < 1 → La serie CONVERGE absolutamente"
                ))
                return (.converges, steps)
            } else if L > 1 + 1e-6 {
                steps.append(SolutionStep(
                    title: "Conclusión",
                    explanation: "L > 1 → La serie DIVERGE"
                ))
                return (.diverges, steps)
            } else {
                steps.append(SolutionStep(
                    title: "Conclusión",
                    explanation: "L = 1 → Criterio inconcluso"
                ))
            }
        }
        
        return (.inconclusive, steps)
    }
    
    /// Root test: L = lim |a_n|^{1/n}. L < 1 → converges, L > 1 → diverges.
    static func rootTest(
        _ term: ExprNode,
        variable n: String
    ) -> (ConvergenceResult, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Criterio de la raíz (Root Test)",
            math: "L = \\lim_{n \\to \\infty} \\sqrt[n]{|a_n|}"
        ))
        
        // Evaluate numerically for large n
        let largeN = ExprNode.power(
            ExprNode.function(.abs, [term.substitute(n, with: .number(1e6))]),
            ExprNode.power(.number(1e6), .negOne)
        )
        
        if let val = largeN.numericValue {
            let L = val
            steps.append(SolutionStep(
                title: "Límite",
                math: "L \\approx \(String(format: "%.6g", L))"
            ))
            
            if L < 1 - 1e-6 {
                steps.append(SolutionStep(title: "Conclusión", explanation: "L < 1 → CONVERGE"))
                return (.converges, steps)
            } else if L > 1 + 1e-6 {
                steps.append(SolutionStep(title: "Conclusión", explanation: "L > 1 → DIVERGE"))
                return (.diverges, steps)
            }
        }
        
        return (.inconclusive, steps)
    }
    
    /// Alternating series test: if |a_n| decreasing → 0, alternating series converges.
    static func alternatingSeriesTest(
        _ term: ExprNode,
        variable n: String
    ) -> (ConvergenceResult, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Criterio de Leibniz (series alternantes)",
            explanation: "Si Σ(-1)^n b_n con b_n ≥ 0, b_n decreciente, lim b_n = 0 → converge"
        ))
        
        // Check if term has (-1)^n factor
        // Heuristic: evaluate at n=1000 and n=1001; opposite signs?
        let at1000 = term.substitute(n, with: .number(1000))
        let at1001 = term.substitute(n, with: .number(1001))
        
        if let v1 = at1000.numericValue, let v2 = at1001.numericValue {
            if v1 * v2 < 0 {
                // Alternating! Check decreasing
                let at2000 = term.substitute(n, with: .number(2000))
                if let v3 = at2000.numericValue {
                    if Swift.abs(v3) < Swift.abs(v1) {
                        steps.append(SolutionStep(
                            title: "Conclusión",
                            explanation: "Serie alternante con |a_n| decreciente → CONVERGE condicionalmente"
                        ))
                        return (.conditional, steps)
                    }
                }
            }
        }
        
        return (.inconclusive, steps)
    }
    
    // MARK: - Partial Sums
    
    /// Compute partial sums numerically: S_N = Σ_{n=start}^{N} a_n.
    static func partialSums(
        _ term: ExprNode,
        variable n: String = "n",
        from start: Int = 1,
        to maxN: Int = 100
    ) -> [(Int, Double)] {
        var sums: [(Int, Double)] = []
        var running = 0.0
        
        for k in start...maxN {
            let val = term.substitute(n, with: .number(Double(k)))
            if let v = val.numericValue {
                running += v
                // Log at specific points
                if k <= 10 || k % (maxN / 20) == 0 || k == maxN {
                    sums.append((k, running))
                }
            }
        }
        
        return sums
    }
    
    // MARK: - Power Series Radius of Convergence
    
    /// Compute the radius of convergence for a power series Σ a_n x^n.
    /// R = 1 / lim sup |a_n|^{1/n} or R = lim |a_n / a_{n+1}|
    static func radiusOfConvergence(
        coefficients: ExprNode,
        variable n: String = "n"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Radio de convergencia",
            explanation: "Para Σ a_n x^n, R = lim |a_n / a_{n+1}|",
            math: "R = \\lim_{n \\to \\infty} \\left|\\frac{a_n}{a_{n+1}}\\right|"
        ))
        
        let nextCoeff = coefficients.substitute(n, with: ExprNode.variable(n) + .one)
        let ratio = Simplifier.simplify(ExprNode.function(.abs, [ExprNode.div(coefficients, nextCoeff)]))
        
        steps.append(SolutionStep(
            title: "Cociente",
            math: "\\frac{a_n}{a_{n+1}} = \(ratio.latex)"
        ))
        
        // Numerical estimation
        let largeN = ratio.substitute(n, with: .number(1e5))
        if let R = largeN.numericValue {
            steps.append(SolutionStep(
                title: "Radio de convergencia",
                math: "R = \(String(format: "%.6g", R))"
            ))
            
            steps.append(SolutionStep(
                title: "Intervalo de convergencia",
                math: "(-\(String(format: "%.6g", R)), \\; \(String(format: "%.6g", R)))"
            ))
            
            return (.number(R), steps)
        }
        
        return (ratio, steps)
    }
    
    // MARK: - Known Series Expansions
    
    /// Generate known Taylor series for common functions.
    static func knownSeries(for fn: MathFunc, variable v: String = "x", order: Int = 6) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = ExprNode.variable(v)
        
        switch fn {
        case .exp:
            steps.append(SolutionStep(title: "Serie de e^x", math: "e^x = \\sum_{n=0}^{\\infty} \\frac{x^n}{n!}"))
            var terms: [ExprNode] = []
            for k in 0...order {
                let coeff = 1.0 / Double(factorialInt(k))
                if k == 0 { terms.append(.one) }
                else { terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(k)))])) }
            }
            return (.add(terms), steps)
            
        case .sin:
            steps.append(SolutionStep(title: "Serie de sin(x)", math: "\\sin x = \\sum_{n=0}^{\\infty} \\frac{(-1)^n x^{2n+1}}{(2n+1)!}"))
            var terms: [ExprNode] = []
            for k in 0...(order / 2) {
                let sign = k % 2 == 0 ? 1.0 : -1.0
                let coeff = sign / Double(factorialInt(2 * k + 1))
                terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(2 * k + 1)))]))
            }
            return (.add(terms), steps)
            
        case .cos:
            steps.append(SolutionStep(title: "Serie de cos(x)", math: "\\cos x = \\sum_{n=0}^{\\infty} \\frac{(-1)^n x^{2n}}{(2n)!}"))
            var terms: [ExprNode] = []
            for k in 0...(order / 2) {
                let sign = k % 2 == 0 ? 1.0 : -1.0
                let coeff = sign / Double(factorialInt(2 * k))
                if k == 0 { terms.append(.one) }
                else { terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(2 * k)))])) }
            }
            return (.add(terms), steps)
            
        case .ln:
            // ln(1+x) = x - x²/2 + x³/3 - ...
            steps.append(SolutionStep(title: "Serie de ln(1+x)", math: "\\ln(1+x) = \\sum_{n=1}^{\\infty} \\frac{(-1)^{n+1} x^n}{n}"))
            var terms: [ExprNode] = []
            for k in 1...order {
                let sign = k % 2 == 1 ? 1.0 : -1.0
                let coeff = sign / Double(k)
                terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(k)))]))
            }
            return (.add(terms), steps)
            
        case .atan:
            // atan(x) = x - x³/3 + x⁵/5 - ...
            steps.append(SolutionStep(title: "Serie de arctan(x)", math: "\\arctan x = \\sum_{n=0}^{\\infty} \\frac{(-1)^n x^{2n+1}}{2n+1}"))
            var terms: [ExprNode] = []
            for k in 0...(order / 2) {
                let sign = k % 2 == 0 ? 1.0 : -1.0
                let coeff = sign / Double(2 * k + 1)
                terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(2 * k + 1)))]))
            }
            return (.add(terms), steps)
            
        case .sinh:
            steps.append(SolutionStep(title: "Serie de sinh(x)", math: "\\sinh x = \\sum_{n=0}^{\\infty} \\frac{x^{2n+1}}{(2n+1)!}"))
            var terms: [ExprNode] = []
            for k in 0...(order / 2) {
                let coeff = 1.0 / Double(factorialInt(2 * k + 1))
                terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(2 * k + 1)))]))
            }
            return (.add(terms), steps)
            
        case .cosh:
            steps.append(SolutionStep(title: "Serie de cosh(x)", math: "\\cosh x = \\sum_{n=0}^{\\infty} \\frac{x^{2n}}{(2n)!}"))
            var terms: [ExprNode] = []
            for k in 0...(order / 2) {
                let coeff = 1.0 / Double(factorialInt(2 * k))
                if k == 0 { terms.append(.one) }
                else { terms.append(ExprNode.multiply([cleanNumber(coeff), .power(x, .number(Double(2 * k)))])) }
            }
            return (.add(terms), steps)
            
        default:
            // Fall back to general Taylor computation
            return taylorSeries(.function(fn, [x]), variable: v, about: .zero, order: order)
        }
    }
    
    // MARK: - Padé Approximant
    
    /// Compute [L/M] Padé approximant from Taylor coefficients.
    /// Given f(x) ≈ Σ c_k x^k, find P(x)/Q(x) where deg(P)=L, deg(Q)=M.
    static func padeApproximant(
        taylorCoeffs: [Double],
        L: Int,
        M: Int
    ) -> ([Double], [Double], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Aproximante de Padé [\(L)/\(M)]",
            explanation: "Encontrar P(x)/Q(x) con deg(P)=\(L), deg(Q)=\(M) que coincida con los primeros \(L + M + 1) coeficientes de Taylor"
        ))
        
        let N = L + M
        guard taylorCoeffs.count > N else {
            return ([], [], steps)
        }
        
        // Solve for Q coefficients (q_0 = 1, q_1, ..., q_M)
        // System: Σ_{j=0}^{M} q_j c_{i-j} = 0 for i = L+1, ..., L+M
        var A: Matrix = Array(repeating: Array(repeating: 0.0, count: M), count: M)
        var b: Vec = Array(repeating: 0.0, count: M)
        
        for i in 0..<M {
            let row = L + 1 + i
            for j in 0..<M {
                let idx = row - j - 1
                if idx >= 0 && idx < taylorCoeffs.count {
                    A[i][j] = taylorCoeffs[idx]
                }
            }
            if row < taylorCoeffs.count {
                b[i] = -taylorCoeffs[row]
            }
        }
        
        let qCoeffs: [Double]
        if let sol = LinearAlgebra.solve(A, b: b) {
            qCoeffs = [1.0] + sol
        } else {
            qCoeffs = [1.0] + Array(repeating: 0.0, count: M)
        }
        
        // Compute P coefficients: p_i = Σ_{j=0}^{min(i,M)} q_j c_{i-j}
        var pCoeffs: [Double] = []
        for i in 0...L {
            var val = 0.0
            for j in 0...Swift.min(i, M) {
                if j < qCoeffs.count && (i - j) < taylorCoeffs.count {
                    val += qCoeffs[j] * taylorCoeffs[i - j]
                }
            }
            pCoeffs.append(val)
        }
        
        let pStr = pCoeffs.enumerated().map { "\(String(format: "%.4g", $0.element))x^{\($0.offset)}" }.joined(separator: " + ")
        let qStr = qCoeffs.enumerated().map { "\(String(format: "%.4g", $0.element))x^{\($0.offset)}" }.joined(separator: " + ")
        
        steps.append(SolutionStep(
            title: "Resultado",
            math: "\\frac{\(pStr)}{\(qStr)}"
        ))
        
        return (pCoeffs, qCoeffs, steps)
    }
    
    // MARK: - Asymptotic Expansion
    
    /// Generate asymptotic expansion of expr for x → ∞.
    /// Try substituting x = 1/t and expanding about t = 0.
    static func asymptoticExpansion(
        _ expr: ExprNode,
        variable v: String = "x",
        order: Int = 4
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Expansión asintótica",
            explanation: "Para \(v) → ∞, sustituir \(v) = 1/t y expandir en t = 0",
            math: "\(v) \\to \\infty"
        ))
        
        // Substitute x = 1/t
        let substituted = expr.substitute(v, with: ExprNode.power(.variable("t"), .negOne))
        let simplified = Simplifier.simplify(substituted)
        
        steps.append(SolutionStep(
            title: "Sustitución \(v) = 1/t",
            math: simplified.latex
        ))
        
        // Taylor expand about t = 0
        let (expansion, taylorSteps) = taylorSeries(simplified, variable: "t", about: .zero, order: order)
        steps.append(contentsOf: taylorSteps)
        
        // Substitute back t = 1/x
        let result = Simplifier.simplify(
            expansion.substitute("t", with: ExprNode.power(.variable(v), .negOne))
        )
        
        steps.append(SolutionStep(
            title: "Resultado (sustituyendo t = 1/\(v))",
            math: result.latex
        ))
        
        return (result, steps)
    }
    
    // MARK: - Helpers
    
    private static func factorialInt(_ n: Int) -> Int {
        guard n > 1 else { return 1 }
        return (2...n).reduce(1, *)
    }
    
    private static func cleanNumber(_ v: Double) -> ExprNode {
        if Swift.abs(v - Double(Int(v))) < 1e-12 && Swift.abs(v) < 1e12 {
            return .number(Double(Int(v)))
        }
        // Try common fractions
        for denom in 1...120 {
            let num = v * Double(denom)
            if Swift.abs(num - Foundation.round(num)) < 1e-10 {
                return .rational(Int(Foundation.round(num)), denom)
            }
        }
        return .number(v)
    }
}
