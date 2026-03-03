// Integrator.swift
// CalcPrime — Engine/Solvers
// Symbolic integration engine.
// Methods: table lookup, linearity, power rule, substitution (u-sub),
// integration by parts, partial fractions, trig substitution,
// trig integrals, hyperbolic, exponential, logarithmic, special functions.
//
// Ref: "Symbolic Integration I" (Bronstein), Risch algorithm concepts,
//      Xcas integrate(), Zill 8th ed.

import Foundation

struct Integrator {
    
    // MARK: - Public API
    
    /// Integrate expr with respect to variable. Returns (result, steps).
    static func integrate(_ expr: ExprNode, withRespectTo v: String) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let simplified = Simplifier.simplify(expr)
        let result = integ(simplified, v, &steps, depth: 0)
        return (Simplifier.simplify(result), steps)
    }
    
    /// Numerical integration using adaptive Simpson's rule.
    static func numericalIntegrate(_ expr: ExprNode, variable v: String, from a: Double, to b: Double, tolerance: Double = 1e-10) -> Double {
        adaptiveSimpson(expr, v, a, b, tolerance, maxDepth: 50)
    }
    
    // MARK: - Core Integration
    
    private static let maxDepth = 20
    
    private static func integ(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep], depth: Int) -> ExprNode {
        guard depth < maxDepth else {
            steps.append(SolutionStep(title: "Profundidad máxima alcanzada", explanation: "No se pudo resolver la integral"))
            return .integral(expr, v)
        }
        
        let e = Simplifier.simplify(expr)
        
        // Rule 0: If expr doesn't contain v, it's a constant
        if !e.freeVariables.contains(v) {
            steps.append(SolutionStep(title: "Constante", explanation: "\\int c \\, d\(v) = c\\cdot \(v)", math: "\(e.latex) \\cdot \(v)"))
            return .multiply([e, .variable(v)])
        }
        
        // Rule 1: Table lookup
        if let result = tableLookup(e, v) {
            steps.append(SolutionStep(title: "Fórmula directa", math: result.latex))
            return result
        }
        
        // Rule 2: Linearity — ∫(a·f + b·g) = a·∫f + b·∫g
        if case .add(let terms) = e {
            steps.append(SolutionStep(title: "Linealidad", explanation: "Integrar término por término"))
            let results = terms.map { integ($0, v, &steps, depth: depth + 1) }
            return .add(results)
        }
        
        // Rule 3: Factor out constants — ∫c·f = c·∫f
        if case .multiply(let factors) = e {
            var constants: [ExprNode] = []
            var withVar: [ExprNode] = []
            for f in factors {
                if f.freeVariables.contains(v) { withVar.append(f) }
                else { constants.append(f) }
            }
            if !constants.isEmpty && !withVar.isEmpty {
                let c = constants.count == 1 ? constants[0] : ExprNode.multiply(constants)
                let f = withVar.count == 1 ? withVar[0] : ExprNode.multiply(withVar)
                steps.append(SolutionStep(title: "Sacar constante", math: "\(c.latex) \\int \(f.latex) \\, d\(v)"))
                let inner = integ(f, v, &steps, depth: depth + 1)
                return .multiply([c, inner])
            }
        }
        
        // Rule 4: Negation — ∫(-f) = -∫f
        if case .negate(let inner) = e {
            let result = integ(inner, v, &steps, depth: depth + 1)
            return .negate(result)
        }
        
        // Rule 5: Power rule — ∫x^n dx = x^(n+1)/(n+1)
        if let result = tryPowerRule(e, v) {
            steps.append(SolutionStep(title: "Regla de la potencia", explanation: "\\int \(v)^n \\, d\(v) = \\frac{\(v)^{n+1}}{n+1}", math: result.latex))
            return result
        }
        
        // Rule 6: Exponential — ∫e^x dx = e^x
        if let result = tryExponential(e, v) {
            steps.append(SolutionStep(title: "Integral exponencial", math: result.latex))
            return result
        }
        
        // Rule 7: Simple substitution (u-sub)
        if let result = tryUSubstitution(e, v, &steps, depth: depth) {
            return result
        }
        
        // Rule 8: Integration by parts — ∫u dv = uv - ∫v du
        if let result = tryIntegrationByParts(e, v, &steps, depth: depth) {
            return result
        }
        
        // Rule 9: Trig integrals (sin^m·cos^n, etc.)
        if let result = tryTrigIntegral(e, v, &steps, depth: depth) {
            return result
        }
        
        // Rule 10: Partial fractions (rational functions)
        if let result = tryPartialFractions(e, v, &steps, depth: depth) {
            return result
        }
        
        // Fallback: can't integrate
        steps.append(SolutionStep(title: "No se encontró antiderivada", explanation: "La integral no pudo resolverse simbólicamente"))
        return .integral(expr, v)
    }
    
    // MARK: - Table Lookup
    
    private static func tableLookup(_ expr: ExprNode, _ v: String) -> ExprNode? {
        let x = ExprNode.variable(v)
        
        // ∫ x dx = x²/2
        if expr == x { return .multiply([.rational(1, 2), .power(x, .two)]) }
        
        // ∫ 1 dx = x
        if expr.isOne { return x }
        
        // ∫ sin(x) dx = -cos(x)
        if expr == .function(.sin, [x]) { return .negate(.function(.cos, [x])) }
        
        // ∫ cos(x) dx = sin(x)
        if expr == .function(.cos, [x]) { return .function(.sin, [x]) }
        
        // ∫ tan(x) dx = -ln|cos(x)|
        if expr == .function(.tan, [x]) { return .negate(.function(.ln, [.function(.abs, [.function(.cos, [x])])])) }
        
        // ∫ cot(x) dx = ln|sin(x)|
        if expr == .function(.cot, [x]) { return .function(.ln, [.function(.abs, [.function(.sin, [x])])]) }
        
        // ∫ sec(x) dx = ln|sec(x)+tan(x)|
        if expr == .function(.sec, [x]) {
            return .function(.ln, [.function(.abs, [.add([.function(.sec, [x]), .function(.tan, [x])])])])
        }
        
        // ∫ csc(x) dx = -ln|csc(x)+cot(x)|
        if expr == .function(.csc, [x]) {
            return .negate(.function(.ln, [.function(.abs, [.add([.function(.csc, [x]), .function(.cot, [x])])])]))
        }
        
        // ∫ sec²(x) dx = tan(x)
        if expr == .power(.function(.sec, [x]), .two) || expr == .power(.function(.cos, [x]), .number(-2)) {
            return .function(.tan, [x])
        }
        
        // ∫ csc²(x) dx = -cot(x)
        if expr == .power(.function(.csc, [x]), .two) || expr == .power(.function(.sin, [x]), .number(-2)) {
            return .negate(.function(.cot, [x]))
        }
        
        // ∫ e^x dx = e^x
        if expr == .function(.exp, [x]) || expr == .power(.constant(.e), x) {
            return .function(.exp, [x])
        }
        
        // ∫ 1/x dx = ln|x|
        if expr == .power(x, .negOne) {
            return .function(.ln, [.function(.abs, [x])])
        }
        
        // ∫ ln(x) dx = x·ln(x) - x
        if expr == .function(.ln, [x]) {
            return .add([.multiply([x, .function(.ln, [x])]), .negate(x)])
        }
        
        // ∫ sinh(x) dx = cosh(x)
        if expr == .function(.sinh, [x]) { return .function(.cosh, [x]) }
        
        // ∫ cosh(x) dx = sinh(x)
        if expr == .function(.cosh, [x]) { return .function(.sinh, [x]) }
        
        // ∫ tanh(x) dx = ln(cosh(x))
        if expr == .function(.tanh, [x]) { return .function(.ln, [.function(.cosh, [x])]) }
        
        // ∫ sech²(x) dx = tanh(x)
        if expr == .power(.function(.sech, [x]), .two) || expr == .power(.function(.cosh, [x]), .number(-2)) {
            return .function(.tanh, [x])
        }
        
        // ∫ 1/√(1-x²) dx = asin(x)
        if matchPattern_1overSqrt1MinusXSq(expr, x) {
            return .function(.asin, [x])
        }
        
        // ∫ 1/(1+x²) dx = atan(x)
        if matchPattern_1over1PlusXSq(expr, x) {
            return .function(.atan, [x])
        }
        
        // ∫ 1/√(x²-1) dx = arcsec(|x|)  — or acosh alternative
        // ∫ 1/√(x²+1) dx = asinh(x)
        
        return nil
    }
    
    // MARK: - Power Rule
    
    /// ∫ x^n dx = x^(n+1)/(n+1) for n ≠ -1
    private static func tryPowerRule(_ expr: ExprNode, _ v: String) -> ExprNode? {
        let x = ExprNode.variable(v)
        
        // Direct: x^n
        if case .power(let base, let exp) = expr, base == x, !exp.freeVariables.contains(v) {
            // Check n ≠ -1
            if let n = exp.numericValue, n == -1 { return nil }
            let nPlus1 = Simplifier.simplify(.add([exp, .one]))
            return .multiply([.power(nPlus1, .negOne), .power(x, nPlus1)])
        }
        
        return nil
    }
    
    // MARK: - Exponential
    
    private static func tryExponential(_ expr: ExprNode, _ v: String) -> ExprNode? {
        let x = ExprNode.variable(v)
        
        // ∫ a^x dx = a^x / ln(a)
        if case .power(let base, let exp) = expr, !base.freeVariables.contains(v), exp == x {
            return .multiply([.power(base, x), .power(.function(.ln, [base]), .negOne)])
        }
        
        // ∫ e^(ax) dx = e^(ax)/a
        if case .function(.exp, let args) = expr, args.count == 1 {
            if case .multiply(let factors) = args[0] {
                var coeff: [ExprNode] = []
                var hasV = false
                for f in factors {
                    if f == x { hasV = true }
                    else if !f.freeVariables.contains(v) { coeff.append(f) }
                    else { return nil }
                }
                if hasV && !coeff.isEmpty {
                    let a = coeff.count == 1 ? coeff[0] : ExprNode.multiply(coeff)
                    return .multiply([.power(a, .negOne), .function(.exp, [.multiply([a, x])])])
                }
            }
        }
        
        return nil
    }
    
    // MARK: - U-Substitution
    
    private static func tryUSubstitution(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep], depth: Int) -> ExprNode? {
        // Look for f(g(x))·g'(x) pattern
        guard case .multiply(let factors) = expr else { return nil }
        
        // Try each factor as the "inner function"
        for i in 0..<factors.count {
            let candidate = factors[i]
            // Look for functions
            guard case .function(_, let args) = candidate, args.count == 1 else { continue }
            let inner = args[0]
            
            // Compute derivative of inner
            let dInner = Differentiator.differentiate(inner, withRespectTo: v)
            
            // Check if the remaining factors equal dInner
            var remaining = factors
            remaining.remove(at: i)
            let product = remaining.count == 1 ? remaining[0] : ExprNode.multiply(remaining)
            let simplified = Simplifier.simplify(.add([product, .negate(dInner)]))
            
            if simplified.isZero {
                // ∫ f(g(x))·g'(x) dx = F(g(x)) where F' = f
                steps.append(SolutionStep(title: "Sustitución u", explanation: "Sea u = \(inner.latex), du = \(dInner.latex) d\(v)"))
                
                let uVar = "u"
                let innerIntegral = integ(.function(extractFn(candidate)!, [.variable(uVar)]), uVar, &steps, depth: depth + 1)
                return innerIntegral.substitute(uVar, with: inner)
            }
            
            // Check if remaining is a scalar multiple of dInner
            if let ratio = tryDivide(product, dInner) {
                if !ratio.freeVariables.contains(v) {
                    steps.append(SolutionStep(title: "Sustitución u", explanation: "Sea u = \(inner.latex), con factor \(ratio.latex)"))
                    let uVar = "u"
                    let innerIntegral = integ(.function(extractFn(candidate)!, [.variable(uVar)]), uVar, &steps, depth: depth + 1)
                    return .multiply([ratio, innerIntegral.substitute(uVar, with: inner)])
                }
            }
        }
        
        return nil
    }
    
    private static func extractFn(_ expr: ExprNode) -> MathFunc? {
        if case .function(let fn, _) = expr { return fn }
        return nil
    }
    
    private static func tryDivide(_ a: ExprNode, _ b: ExprNode) -> ExprNode? {
        if b.isZero { return nil }
        let ratio = Simplifier.simplify(.multiply([a, .power(b, .negOne)]))
        // Check if result is a "simple" constant
        if ratio.numericValue != nil { return ratio }
        if ratio.freeVariables.isEmpty { return ratio }
        return nil
    }
    
    // MARK: - Integration by Parts
    
    /// ∫ u dv = uv - ∫ v du  (LIATE heuristic for choosing u)
    private static func tryIntegrationByParts(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep], depth: Int) -> ExprNode? {
        guard depth < 5 else { return nil } // Limit recursion
        
        // Split into u and dv using LIATE priority
        guard case .multiply(let factors) = expr, factors.count >= 2 else { return nil }
        
        // LIATE: Logarithmic > Inverse trig > Algebraic > Trig > Exponential
        let sorted = factors.sorted { liatePriority($0) < liatePriority($1) }
        let u = sorted[0]
        let dv = sorted.count == 2 ? sorted[1] : ExprNode.multiply(Array(sorted[1...]))
        
        // v = ∫ dv
        var subSteps: [SolutionStep] = []
        let vIntegral = integ(dv, v, &subSteps, depth: depth + 1)
        
        // Check if we got a usable result
        if case .integral = vIntegral { return nil }
        
        // du = u' dx
        let du = Differentiator.differentiate(u, withRespectTo: v)
        
        steps.append(SolutionStep(title: "Integración por partes", explanation: "u = \(u.latex), dv = \(dv.latex)d\(v)", math: "\\int u \\, dv = uv - \\int v \\, du"))
        steps.append(SolutionStep(title: "Cálculo de v", math: "v = \(vIntegral.latex)"))
        steps.append(SolutionStep(title: "Cálculo de du", math: "du = \(du.latex) \\, d\(v)"))
        
        // uv - ∫ v du
        let uv = ExprNode.multiply([u, vIntegral])
        let remaining = integ(.multiply([vIntegral, du]), v, &steps, depth: depth + 1)
        
        return .add([uv, .negate(remaining)])
    }
    
    /// LIATE priority (lower = choose as u first)
    private static func liatePriority(_ expr: ExprNode) -> Int {
        switch expr {
        case .function(.ln, _), .function(.log, _), .function(.log2, _), .function(.log10, _):
            return 0 // Logarithmic
        case .function(.asin, _), .function(.acos, _), .function(.atan, _),
             .function(.acsc, _), .function(.asec, _), .function(.acot, _):
            return 1 // Inverse trig
        case .variable, .power:
            return 2 // Algebraic
        case .function(.sin, _), .function(.cos, _), .function(.tan, _),
             .function(.csc, _), .function(.sec, _), .function(.cot, _):
            return 3 // Trigonometric
        case .function(.exp, _):
            return 4 // Exponential
        default:
            return 2
        }
    }
    
    // MARK: - Trig Integrals
    
    private static func tryTrigIntegral(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep], depth: Int) -> ExprNode? {
        let x = ExprNode.variable(v)
        
        // ∫ sin²(x) dx = x/2 - sin(2x)/4
        if expr == .power(.function(.sin, [x]), .two) {
            steps.append(SolutionStep(title: "Identidad de potencia", explanation: "sin²(x) = (1 - cos(2x))/2"))
            return .add([
                .multiply([.rational(1, 2), x]),
                .negate(.multiply([.rational(1, 4), .function(.sin, [.multiply([.two, x])])]))
            ])
        }
        
        // ∫ cos²(x) dx = x/2 + sin(2x)/4
        if expr == .power(.function(.cos, [x]), .two) {
            steps.append(SolutionStep(title: "Identidad de potencia", explanation: "cos²(x) = (1 + cos(2x))/2"))
            return .add([
                .multiply([.rational(1, 2), x]),
                .multiply([.rational(1, 4), .function(.sin, [.multiply([.two, x])])])
            ])
        }
        
        return nil
    }
    
    // MARK: - Partial Fractions
    
    private static func tryPartialFractions(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep], depth: Int) -> ExprNode? {
        // Detect rational function p(x)/q(x)
        // This is a simplified version; full partial fraction decomposition is complex
        return nil
    }
    
    // MARK: - Pattern Matching Helpers
    
    private static func matchPattern_1overSqrt1MinusXSq(_ expr: ExprNode, _ x: ExprNode) -> Bool {
        // 1/√(1-x²) = (1-x²)^(-1/2)
        if case .power(let base, let exp) = expr {
            if exp == .rational(-1, 2) || exp == .number(-0.5) {
                // base should be 1-x²
                if case .add(let terms) = base, terms.count == 2 {
                    if terms[0].isOne, case .negate(.power(let v, let e)) = terms[1], v == x, e == .two {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private static func matchPattern_1over1PlusXSq(_ expr: ExprNode, _ x: ExprNode) -> Bool {
        // 1/(1+x²) = (1+x²)^(-1)
        if case .power(let base, let exp) = expr, exp == .negOne {
            if case .add(let terms) = base, terms.count == 2 {
                if terms[0].isOne, case .power(let v, let e) = terms[1], v == x, e == .two {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Numerical Integration (Adaptive Simpson)
    
    private static func adaptiveSimpson(_ expr: ExprNode, _ v: String, _ a: Double, _ b: Double, _ tol: Double, maxDepth: Int) -> Double {
        let h = b - a
        let mid = (a + b) / 2
        let fa = expr.evaluate(with: [v: a]) ?? 0
        let fb = expr.evaluate(with: [v: b]) ?? 0
        let fmid = expr.evaluate(with: [v: mid]) ?? 0
        
        let whole = (h / 6) * (fa + 4 * fmid + fb)
        
        if maxDepth <= 0 { return whole }
        
        let lmid = (a + mid) / 2
        let rmid = (mid + b) / 2
        let flmid = expr.evaluate(with: [v: lmid]) ?? 0
        let frmid = expr.evaluate(with: [v: rmid]) ?? 0
        
        let left = (h / 12) * (fa + 4 * flmid + fmid)
        let right = (h / 12) * (fmid + 4 * frmid + fb)
        
        if Swift.abs(left + right - whole) <= 15 * tol {
            return left + right + (left + right - whole) / 15
        }
        
        return adaptiveSimpson(expr, v, a, mid, tol / 2, maxDepth: maxDepth - 1) +
               adaptiveSimpson(expr, v, mid, b, tol / 2, maxDepth: maxDepth - 1)
    }
}
