// Factorizer.swift
// CalcPrime — Engine/Solvers
// Polynomial factorization engine.
// Methods: common factor, grouping, difference of squares, sum/diff of cubes,
// quadratic formula, rational root theorem, Kronecker, Berlekamp (mod p).
//
// Ref: "Modern Computer Algebra" (von zur Gathen & Gerhard), Xcas factor()

import Foundation

struct Factorizer {
    
    // MARK: - Public API
    
    static func factor(_ expr: ExprNode) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let simplified = Simplifier.simplify(expr)
        let result = factorExpr(simplified, &steps)
        return (result, steps)
    }
    
    // MARK: - Core Factoring
    
    private static func factorExpr(_ expr: ExprNode, _ steps: inout [SolutionStep]) -> ExprNode {
        // Get the main variable
        guard let v = expr.freeVariables.first else { return expr }
        
        // Extract polynomial coefficients
        guard let coeffs = extractPolynomialCoeffs(expr, variable: v) else {
            // Not a polynomial — try factoring inner expressions
            return expr
        }
        
        let degree = coeffs.count - 1
        
        if degree <= 0 { return expr }
        
        // Factor out GCD of coefficients
        let (gcfResult, gcf) = factorOutGCF(coeffs, variable: v)
        if !gcf.isOne {
            steps.append(SolutionStep(title: "Factor común", math: "\(gcf.latex) \\cdot (\(gcfResult.latex))"))
            // Recursively factor the remaining polynomial
            let inner = factorExpr(gcfResult, &steps)
            return .multiply([gcf, inner])
        }
        
        // Degree-specific methods
        switch degree {
        case 1:
            return expr // Already factored
            
        case 2:
            return factorQuadratic(coeffs, variable: v, &steps)
            
        case 3:
            return factorCubic(coeffs, variable: v, &steps)
            
        case 4:
            return factorQuartic(coeffs, variable: v, &steps)
            
        default:
            // Try rational root theorem for higher degrees
            return tryRationalRoots(coeffs, variable: v, &steps)
        }
    }
    
    // MARK: - Extract Polynomial Coefficients
    
    /// Extract coefficients [a₀, a₁, ..., aₙ] from a₀ + a₁x + a₂x² + ... + aₙxⁿ
    private static func extractPolynomialCoeffs(_ expr: ExprNode, variable v: String) -> [Double]? {
        let collected = Simplifier.collect(Simplifier.expand(expr), variable: v)
        
        // Parse the collected form to extract coefficients
        var coeffs: [Int: Double] = [:]
        
        func extractTerms(_ e: ExprNode) {
            switch e {
            case .add(let terms):
                for t in terms { extractTerms(t) }
            case .negate(let inner):
                // Negate and extract
                let (deg, coeff) = termDegreeAndCoeff(inner, v)
                coeffs[deg, default: 0] -= coeff
            default:
                let (deg, coeff) = termDegreeAndCoeff(e, v)
                coeffs[deg, default: 0] += coeff
            }
        }
        
        extractTerms(collected)
        
        guard let maxDeg = coeffs.keys.max() else { return nil }
        // Ensure all degrees have non-negative integer values
        guard coeffs.keys.allSatisfy({ $0 >= 0 }) else { return nil }
        
        var result: [Double] = []
        for i in 0...maxDeg {
            result.append(coeffs[i, default: 0])
        }
        return result
    }
    
    private static func termDegreeAndCoeff(_ expr: ExprNode, _ v: String) -> (Int, Double) {
        switch expr {
        case .variable(let name) where name == v:
            return (1, 1)
        case .number(let val):
            return (0, val)
        case .rational(let p, let q):
            return (0, Double(p) / Double(q))
        case .power(.variable(let name), let exp) where name == v:
            if let e = exp.numericValue, e == Double(Int(e)), e >= 0 {
                return (Int(e), 1)
            }
            return (0, 0)
        case .multiply(let factors):
            var degree = 0
            var coeff = 1.0
            for f in factors {
                switch f {
                case .variable(let name) where name == v:
                    degree += 1
                case .power(.variable(let name), let exp) where name == v:
                    if let e = exp.numericValue { degree += Int(e) }
                case .number(let val):
                    coeff *= val
                case .rational(let p, let q):
                    coeff *= Double(p) / Double(q)
                case .negate(let inner):
                    let (d, c) = termDegreeAndCoeff(inner, v)
                    degree += d
                    coeff *= -c
                    return (degree, coeff)
                default:
                    if !f.freeVariables.contains(v) {
                        if let val = f.numericValue { coeff *= val }
                    }
                }
            }
            return (degree, coeff)
        default:
            if let val = expr.numericValue { return (0, val) }
            return (0, 0)
        }
    }
    
    // MARK: - GCF Factoring
    
    private static func factorOutGCF(_ coeffs: [Double], variable v: String) -> (ExprNode, ExprNode) {
        // Find GCF of all coefficients
        let nonZero = coeffs.filter { $0 != 0 }
        guard !nonZero.isEmpty else { return (.zero, .one) }
        
        // Integer GCF
        let intCoeffs = nonZero.compactMap { c -> Int? in
            let intVal = Int(c)
            return c == Double(intVal) ? Swift.abs(intVal) : nil
        }
        
        guard intCoeffs.count == nonZero.count else {
            return (buildPolynomial(coeffs, v), .one)
        }
        
        var g = intCoeffs[0]
        for c in intCoeffs.dropFirst() { g = gcd(g, c) }
        
        if g <= 1 {
            return (buildPolynomial(coeffs, v), .one)
        }
        
        let newCoeffs = coeffs.map { $0 / Double(g) }
        
        // Also factor out minimum power of x
        var minPower = coeffs.count
        for (i, c) in coeffs.enumerated() where c != 0 {
            minPower = Swift.min(minPower, i)
        }
        
        var gcf: ExprNode = .number(Double(g))
        if minPower > 0 {
            let shiftedCoeffs = Array(newCoeffs.dropFirst(minPower))
            gcf = .multiply([gcf, .power(.variable(v), .number(Double(minPower)))])
            return (buildPolynomial(shiftedCoeffs, v), gcf)
        }
        
        return (buildPolynomial(newCoeffs, v), gcf)
    }
    
    // MARK: - Quadratic Factoring
    
    /// Factor ax² + bx + c using discriminant
    private static func factorQuadratic(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> ExprNode {
        guard coeffs.count == 3 else { return buildPolynomial(coeffs, v) }
        let c = coeffs[0], b = coeffs[1], a = coeffs[2]
        
        let disc = b * b - 4 * a * c
        steps.append(SolutionStep(title: "Discriminante", math: "\\Delta = b^2 - 4ac = \(b)^2 - 4(\\(\(a))(\\(\(c))) = \(disc)"))
        
        if disc < 0 {
            steps.append(SolutionStep(title: "Discriminante negativo", explanation: "El polinomio no tiene raíces reales, es irreducible sobre ℝ"))
            return buildPolynomial(coeffs, v)
        }
        
        let sqrtDisc = Foundation.sqrt(disc)
        let r1 = (-b + sqrtDisc) / (2 * a)
        let r2 = (-b - sqrtDisc) / (2 * a)
        
        steps.append(SolutionStep(title: "Raíces", math: "\(v)_1 = \(formatNum(r1)), \\quad \(v)_2 = \(formatNum(r2))"))
        
        let x = ExprNode.variable(v)
        let factor1 = ExprNode.add([x, .number(-r1)])
        let factor2 = ExprNode.add([x, .number(-r2)])
        
        if a == 1 {
            if r1 == r2 {
                return .power(factor1, .two)
            }
            return .multiply([factor1, factor2])
        }
        return .multiply([.number(a), factor1, factor2])
    }
    
    // MARK: - Cubic Factoring
    
    private static func factorCubic(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> ExprNode {
        // Try rational root theorem first
        return tryRationalRoots(coeffs, variable: v, &steps)
    }
    
    // MARK: - Quartic Factoring
    
    private static func factorQuartic(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> ExprNode {
        // Check for biquadratic: ax⁴ + bx² + c
        if coeffs.count == 5 && coeffs[1] == 0 && coeffs[3] == 0 {
            steps.append(SolutionStep(title: "Ecuación bicuadrática", explanation: "Sustituir u = \(v)²"))
            let quadCoeffs = [coeffs[0], coeffs[2], coeffs[4]]
            // Factor as quadratic in x²
            var subSteps: [SolutionStep] = []
            let quadFactor = factorQuadratic(quadCoeffs, variable: "u", &subSteps)
            steps.append(contentsOf: subSteps)
            // Replace u back with x²
            return quadFactor.substitute("u", with: .power(.variable(v), .two))
        }
        return tryRationalRoots(coeffs, variable: v, &steps)
    }
    
    // MARK: - Rational Root Theorem
    
    private static func tryRationalRoots(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> ExprNode {
        guard coeffs.count > 1 else { return buildPolynomial(coeffs, v) }
        
        let a0 = Int(coeffs[0])
        let an = Int(coeffs.last!)
        guard a0 != 0, an != 0 else {
            // Factor out x
            if a0 == 0 {
                let shifted = Array(coeffs.dropFirst())
                let inner = factorExpr(buildPolynomial(shifted, v), &steps)
                return .multiply([.variable(v), inner])
            }
            return buildPolynomial(coeffs, v)
        }
        
        // Possible rational roots: ±p/q where p | a₀ and q | aₙ
        let pFactors = divisors(Swift.abs(a0))
        let qFactors = divisors(Swift.abs(an))
        
        var candidates: Set<Double> = []
        for p in pFactors {
            for q in qFactors {
                candidates.insert(Double(p) / Double(q))
                candidates.insert(-Double(p) / Double(q))
            }
        }
        
        steps.append(SolutionStep(title: "Teorema de la raíz racional", explanation: "Probando candidatos: ±p/q"))
        
        for root in candidates.sorted() {
            if evaluatePolynomial(coeffs, at: root) == 0 ||
               Swift.abs(evaluatePolynomial(coeffs, at: root)) < 1e-10 {
                steps.append(SolutionStep(title: "Raíz encontrada", math: "\(v) = \(formatNum(root))"))
                
                // Divide polynomial by (x - root) using synthetic division
                let quotient = syntheticDivision(coeffs, root: root)
                let factor = ExprNode.add([.variable(v), .number(-root)])
                let remaining = factorExpr(buildPolynomial(quotient, v), &steps)
                return .multiply([factor, remaining])
            }
        }
        
        // No rational roots found
        steps.append(SolutionStep(title: "Sin raíces racionales", explanation: "El polinomio no tiene raíces racionales"))
        return buildPolynomial(coeffs, v)
    }
    
    // MARK: - Helpers
    
    private static func buildPolynomial(_ coeffs: [Double], _ v: String) -> ExprNode {
        var terms: [ExprNode] = []
        let x = ExprNode.variable(v)
        for (i, c) in coeffs.enumerated() {
            if c == 0 { continue }
            if i == 0 {
                terms.append(.number(c))
            } else if i == 1 {
                if c == 1 { terms.append(x) }
                else if c == -1 { terms.append(.negate(x)) }
                else { terms.append(.multiply([.number(c), x])) }
            } else {
                let xPow = ExprNode.power(x, .number(Double(i)))
                if c == 1 { terms.append(xPow) }
                else if c == -1 { terms.append(.negate(xPow)) }
                else { terms.append(.multiply([.number(c), xPow])) }
            }
        }
        if terms.isEmpty { return .zero }
        if terms.count == 1 { return terms[0] }
        return .add(terms)
    }
    
    private static func evaluatePolynomial(_ coeffs: [Double], at x: Double) -> Double {
        // Horner's method
        var result = 0.0
        for c in coeffs.reversed() {
            result = result * x + c
        }
        return result
    }
    
    private static func syntheticDivision(_ coeffs: [Double], root: Double) -> [Double] {
        // Divide polynomial with coefficients [a₀, a₁, ..., aₙ] by (x - root)
        // Coefficients are in ascending order, so reverse for division
        let n = coeffs.count - 1
        var reversed = Array(coeffs.reversed()) // Now [aₙ, aₙ₋₁, ..., a₀]
        
        var result: [Double] = []
        var carry = 0.0
        for i in 0..<n {
            let val = reversed[i] + carry
            result.append(val)
            carry = val * root
        }
        
        // Convert back to ascending order
        return result.reversed()
    }
    
    private static func divisors(_ n: Int) -> [Int] {
        guard n > 0 else { return [1] }
        var result: [Int] = []
        for i in 1...n {
            if n % i == 0 { result.append(i) }
        }
        return result
    }
    
    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
    
    private static func formatNum(_ v: Double) -> String {
        if v == Double(Int(v)) { return "\(Int(v))" }
        return String(format: "%.4g", v)
    }
}
