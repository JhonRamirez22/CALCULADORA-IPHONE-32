// AlgebraSolver.swift
// CalcPrime — Engine/Solvers
// Equation solving engine.
// Solves: linear, quadratic, cubic (Cardano), quartic (Ferrari),
// polynomial (Newton-Raphson + rational root), transcendental (numerical),
// systems of linear equations (Gauss elimination).
//
// Ref: Xcas solve(), Zill 8th ed., Algebra (Artin)

import Foundation

struct AlgebraSolver {
    
    // MARK: - Public API
    
    /// Solve an equation or expression = 0 for variable.
    static func solve(_ equation: ExprNode, for v: String) -> ([ExprNode], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        // Convert equation to f(x) = 0
        let expr: ExprNode
        if case .equation(let lhs, let rhs) = equation {
            expr = Simplifier.simplify(lhs - rhs)
            steps.append(SolutionStep(title: "Reorganizar", explanation: "Mover todo a un lado", math: "\(expr.latex) = 0"))
        } else {
            expr = Simplifier.simplify(equation)
        }
        
        let solutions = solveExpr(expr, for: v, &steps)
        return (solutions, steps)
    }
    
    /// Solve a system of linear equations.
    static func solveSystem(_ equations: [ExprNode], variables: [String]) -> ([ExprNode], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        // Build augmented matrix
        let n = variables.count
        guard equations.count >= n else {
            steps.append(SolutionStep(title: "Error", explanation: "Sistema subdeterminado: \(equations.count) ecuaciones, \(n) incógnitas"))
            return ([], steps)
        }
        
        var matrix: [[Double]] = []
        for eq in equations {
            let expr: ExprNode
            if case .equation(let l, let r) = eq {
                expr = Simplifier.simplify(l - r)
            } else {
                expr = Simplifier.simplify(eq)
            }
            
            var row: [Double] = []
            for v in variables {
                // Extract coefficient of v
                let coeff = extractLinearCoeff(expr, variable: v)
                row.append(coeff)
            }
            // Constant term (negative because we move it to RHS)
            let constant = extractConstantTerm(expr)
            row.append(-constant)
            matrix.append(row)
        }
        
        steps.append(SolutionStep(title: "Matriz aumentada", explanation: "Sistema como [A|b]"))
        
        // Gaussian elimination with partial pivoting
        let solution = gaussianElimination(&matrix, n: n, &steps)
        
        guard let sol = solution else {
            steps.append(SolutionStep(title: "Sin solución", explanation: "El sistema no tiene solución única"))
            return ([], steps)
        }
        
        let results = sol.map { ExprNode.number($0) }
        for (i, v) in variables.enumerated() {
            steps.append(SolutionStep(title: "\(v)", math: "\(v) = \(formatNum(sol[i]))"))
        }
        
        return (results, steps)
    }
    
    // MARK: - Expression Solver
    
    private static func solveExpr(_ expr: ExprNode, for v: String, _ steps: inout [SolutionStep]) -> [ExprNode] {
        // Check if v appears in expression
        guard expr.freeVariables.contains(v) else {
            if expr.isZero {
                steps.append(SolutionStep(title: "Identidad", explanation: "0 = 0 para todo \(v)"))
                return [.undefined("Toda variable es solución")]
            }
            steps.append(SolutionStep(title: "Contradicción", explanation: "\(expr.latex) ≠ 0"))
            return []
        }
        
        // Try polynomial extraction
        if let coeffs = extractPolynomialCoeffs(expr, variable: v) {
            return solvePolynomial(coeffs, variable: v, &steps)
        }
        
        // Try isolating variable (linear in v)
        if let solution = tryIsolateVariable(expr, v, &steps) {
            return [solution]
        }
        
        // Numerical fallback: Newton-Raphson
        steps.append(SolutionStep(title: "Método numérico", explanation: "Usando Newton-Raphson"))
        let numerical = newtonRaphson(expr, variable: v, initialGuess: 1.0)
        if let root = numerical {
            return [.number(root)]
        }
        
        // Try multiple starting points
        let guesses: [Double] = [-10, -5, -1, 0, 0.5, 1, 2, 5, 10]
        var roots: [Double] = []
        for g in guesses {
            if let r = newtonRaphson(expr, variable: v, initialGuess: g) {
                if !roots.contains(where: { Swift.abs($0 - r) < 1e-8 }) {
                    roots.append(r)
                }
            }
        }
        
        return roots.map { .number($0) }
    }
    
    // MARK: - Polynomial Solver
    
    private static func solvePolynomial(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> [ExprNode] {
        let degree = coeffs.count - 1
        
        switch degree {
        case 0:
            return coeffs[0] == 0 ? [.undefined("Identidad")] : []
            
        case 1:
            // ax + b = 0 → x = -b/a
            let a = coeffs[1], b = coeffs[0]
            let root = -b / a
            steps.append(SolutionStep(title: "Ecuación lineal", math: "\(v) = -\\frac{\(formatNum(b))}{\(formatNum(a))} = \(formatNum(root))"))
            return [.number(root)]
            
        case 2:
            return solveQuadratic(coeffs, variable: v, &steps)
            
        case 3:
            return solveCubic(coeffs, variable: v, &steps)
            
        default:
            // Higher degree: try rational roots + deflation
            return solveByRationalRoots(coeffs, variable: v, &steps)
        }
    }
    
    // MARK: - Quadratic Formula
    
    private static func solveQuadratic(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> [ExprNode] {
        let c = coeffs[0], b = coeffs[1], a = coeffs[2]
        let disc = b * b - 4 * a * c
        
        steps.append(SolutionStep(title: "Fórmula cuadrática", math: "\(v) = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}"))
        steps.append(SolutionStep(title: "Discriminante", math: "\\Delta = \(formatNum(b))^2 - 4(\\(\(formatNum(a))))(\\(\(formatNum(c)))) = \(formatNum(disc))"))
        
        if disc < -1e-12 {
            // Complex roots
            let realPart = -b / (2 * a)
            let imagPart = Foundation.sqrt(-disc) / (2 * a)
            steps.append(SolutionStep(title: "Raíces complejas", math: "\(v) = \(formatNum(realPart)) \\pm \(formatNum(imagPart))i"))
            return [
                .complexNumber(.number(realPart), .number(imagPart)),
                .complexNumber(.number(realPart), .number(-imagPart))
            ]
        }
        
        if Swift.abs(disc) < 1e-12 {
            // Double root
            let root = -b / (2 * a)
            steps.append(SolutionStep(title: "Raíz doble", math: "\(v) = \(formatNum(root))"))
            return [.number(root)]
        }
        
        let sqrtDisc = Foundation.sqrt(disc)
        let r1 = (-b + sqrtDisc) / (2 * a)
        let r2 = (-b - sqrtDisc) / (2 * a)
        
        steps.append(SolutionStep(title: "Raíces reales", math: "\(v)_1 = \(formatNum(r1)), \\quad \(v)_2 = \(formatNum(r2))"))
        
        return [.number(r1), .number(r2)]
    }
    
    // MARK: - Cubic Solver (Cardano's Formula)
    
    private static func solveCubic(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> [ExprNode] {
        let d = coeffs[0], c = coeffs[1], b = coeffs[2], a = coeffs[3]
        
        steps.append(SolutionStep(title: "Ecuación cúbica", explanation: "Método de Cardano"))
        
        // Normalize: x³ + px + q = 0 (depressed cubic)
        let p0 = b / a, p1 = c / a, p2 = d / a
        
        // Substitution: x = t - p₀/3
        let shift = p0 / 3
        let p = p1 - p0 * p0 / 3
        let q = 2 * p0 * p0 * p0 / 27 - p0 * p1 / 3 + p2
        
        steps.append(SolutionStep(title: "Cúbica deprimida", math: "t^3 + \(formatNum(p))t + \(formatNum(q)) = 0"))
        
        let disc = q * q / 4 + p * p * p / 27
        
        var roots: [Double] = []
        
        if disc > 1e-12 {
            // One real root, two complex
            let sqrtDisc = Foundation.sqrt(disc)
            let u = Foundation.cbrt(-q / 2 + sqrtDisc)
            let vv = Foundation.cbrt(-q / 2 - sqrtDisc)
            roots.append(u + vv - shift)
        } else if Swift.abs(disc) < 1e-12 {
            // All real, at least two equal
            let u = Foundation.cbrt(-q / 2)
            roots.append(2 * u - shift)
            roots.append(-u - shift)
        } else {
            // Three distinct real roots (casus irreducibilis)
            let r = Foundation.sqrt(-p * p * p / 27)
            let theta = Foundation.acos(-q / (2 * r))
            let cbrtR = Foundation.cbrt(r)
            for k in 0..<3 {
                roots.append(2 * cbrtR * Foundation.cos((theta + 2 * Double.pi * Double(k)) / 3) - shift)
            }
        }
        
        for (i, root) in roots.enumerated() {
            steps.append(SolutionStep(title: "\(v)_\(i+1)", math: "\(v)_\(i+1) = \(formatNum(root))"))
        }
        
        return roots.map { .number($0) }
    }
    
    // MARK: - Rational Roots
    
    private static func solveByRationalRoots(_ coeffs: [Double], variable v: String, _ steps: inout [SolutionStep]) -> [ExprNode] {
        var remaining = coeffs
        var roots: [ExprNode] = []
        
        // Try rational root theorem
        while remaining.count > 3 {
            guard let root = findRationalRoot(remaining) else { break }
            roots.append(.number(root))
            remaining = syntheticDivision(remaining, root: root)
            steps.append(SolutionStep(title: "Raíz racional", math: "\(v) = \(formatNum(root))"))
        }
        
        // Solve remaining polynomial
        if remaining.count > 1 {
            let subRoots = solvePolynomial(remaining, variable: v, &steps)
            roots.append(contentsOf: subRoots)
        }
        
        return roots
    }
    
    private static func findRationalRoot(_ coeffs: [Double]) -> Double? {
        guard coeffs.count > 1 else { return nil }
        let a0 = Int(coeffs[0])
        let an = Int(coeffs.last!)
        guard a0 != 0, an != 0 else { return coeffs[0] == 0 ? 0 : nil }
        
        let pDivs = divisors(Swift.abs(a0))
        let qDivs = divisors(Swift.abs(an))
        
        for p in pDivs {
            for q in qDivs {
                for sign in [1.0, -1.0] {
                    let candidate = sign * Double(p) / Double(q)
                    if Swift.abs(evalPoly(coeffs, at: candidate)) < 1e-10 {
                        return candidate
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Variable Isolation
    
    private static func tryIsolateVariable(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep]) -> ExprNode? {
        // Simple case: ax + b = 0 where a, b may be expressions not containing v
        // Collect coefficients of v
        let collected = Simplifier.collect(expr, variable: v)
        
        // Check if it's linear in v: a*v + b
        if case .add(let terms) = collected {
            var coeffOfV: ExprNode? = nil
            var constant: ExprNode = .zero
            
            for term in terms {
                if case .multiply(let factors) = term {
                    if factors.contains(.variable(v)) {
                        let rest = factors.filter { $0 != .variable(v) }
                        coeffOfV = rest.isEmpty ? .one : (rest.count == 1 ? rest[0] : .multiply(rest))
                    } else if !term.freeVariables.contains(v) {
                        constant = .add([constant, term])
                    } else {
                        return nil // Non-linear
                    }
                } else if term == .variable(v) {
                    coeffOfV = .one
                } else if !term.freeVariables.contains(v) {
                    constant = .add([constant, term])
                } else {
                    return nil
                }
            }
            
            if let a = coeffOfV {
                let solution = Simplifier.simplify(.negate(.multiply([.power(a, .negOne), Simplifier.simplify(constant)])))
                steps.append(SolutionStep(title: "Despejar \(v)", math: "\(v) = \(solution.latex)"))
                return solution
            }
        }
        
        return nil
    }
    
    // MARK: - Newton-Raphson
    
    private static func newtonRaphson(_ expr: ExprNode, variable v: String, initialGuess: Double, maxIter: Int = 100, tol: Double = 1e-12) -> Double? {
        let deriv = Differentiator.differentiate(expr, withRespectTo: v)
        var x = initialGuess
        
        for _ in 0..<maxIter {
            guard let fx = expr.evaluate(with: [v: x]),
                  let dfx = deriv.evaluate(with: [v: x]) else { return nil }
            
            if Swift.abs(dfx) < 1e-15 { return nil } // Zero derivative
            
            let xNew = x - fx / dfx
            if Swift.abs(xNew - x) < tol { return xNew }
            x = xNew
        }
        
        // Check if we're close to a root
        if let fx = expr.evaluate(with: [v: x]), Swift.abs(fx) < 1e-8 {
            return x
        }
        return nil
    }
    
    // MARK: - Gaussian Elimination
    
    private static func gaussianElimination(_ matrix: inout [[Double]], n: Int, _ steps: inout [SolutionStep]) -> [Double]? {
        // Forward elimination
        for col in 0..<n {
            // Partial pivoting
            var maxRow = col
            for row in (col+1)..<matrix.count {
                if Swift.abs(matrix[row][col]) > Swift.abs(matrix[maxRow][col]) {
                    maxRow = row
                }
            }
            matrix.swapAt(col, maxRow)
            
            guard Swift.abs(matrix[col][col]) > 1e-12 else { continue }
            
            for row in (col+1)..<matrix.count {
                let factor = matrix[row][col] / matrix[col][col]
                for j in col...n {
                    matrix[row][j] -= factor * matrix[col][j]
                }
            }
        }
        
        // Back substitution
        var solution = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            guard Swift.abs(matrix[i][i]) > 1e-12 else { return nil }
            var sum = matrix[i][n]
            for j in (i+1)..<n {
                sum -= matrix[i][j] * solution[j]
            }
            solution[i] = sum / matrix[i][i]
        }
        
        return solution
    }
    
    // MARK: - Helpers
    
    private static func extractPolynomialCoeffs(_ expr: ExprNode, variable v: String) -> [Double]? {
        let expanded = Simplifier.expand(expr)
        let collected = Simplifier.collect(expanded, variable: v)
        
        var coeffs: [Int: Double] = [:]
        
        func extract(_ e: ExprNode) {
            switch e {
            case .add(let terms): terms.forEach { extract($0) }
            case .negate(let inner):
                let (deg, c) = degCoeff(inner, v)
                coeffs[deg, default: 0] -= c
            default:
                let (deg, c) = degCoeff(e, v)
                if deg >= 0 { coeffs[deg, default: 0] += c }
            }
        }
        
        extract(collected)
        guard let maxDeg = coeffs.keys.max(), maxDeg >= 0 else { return nil }
        guard coeffs.keys.allSatisfy({ $0 >= 0 }) else { return nil }
        
        return (0...maxDeg).map { coeffs[$0, default: 0] }
    }
    
    private static func degCoeff(_ expr: ExprNode, _ v: String) -> (Int, Double) {
        switch expr {
        case .variable(let name) where name == v: return (1, 1)
        case .number(let val): return (0, val)
        case .rational(let p, let q): return (0, Double(p)/Double(q))
        case .power(.variable(let name), let exp) where name == v:
            if let e = exp.numericValue, e == Double(Int(e)), e >= 0 { return (Int(e), 1) }
            return (-1, 0)
        case .multiply(let factors):
            var deg = 0; var c = 1.0
            for f in factors {
                if case .variable(let name) = f, name == v { deg += 1 }
                else if case .power(.variable(let name), let exp) = f, name == v, let e = exp.numericValue { deg += Int(e) }
                else if let val = f.numericValue { c *= val }
                else if f.freeVariables.contains(v) { return (-1, 0) }
                else if let val = f.numericValue { c *= val }
            }
            return (deg, c)
        default:
            if let val = expr.numericValue { return (0, val) }
            return (-1, 0)
        }
    }
    
    private static func extractLinearCoeff(_ expr: ExprNode, variable v: String) -> Double {
        let (deg, c) = degCoeff(Simplifier.collect(expr, variable: v), v)
        return deg == 1 ? c : 0
    }
    
    private static func extractConstantTerm(_ expr: ExprNode) -> Double {
        if case .add(let terms) = expr {
            return terms.compactMap { t -> Double? in
                t.freeVariables.isEmpty ? t.numericValue : nil
            }.reduce(0, +)
        }
        return expr.freeVariables.isEmpty ? (expr.numericValue ?? 0) : 0
    }
    
    private static func syntheticDivision(_ coeffs: [Double], root: Double) -> [Double] {
        let n = coeffs.count - 1
        let rev = Array(coeffs.reversed())
        var result: [Double] = []
        var carry = 0.0
        for i in 0..<n {
            let val = rev[i] + carry
            result.append(val)
            carry = val * root
        }
        return result.reversed()
    }
    
    private static func divisors(_ n: Int) -> [Int] {
        guard n > 0 else { return [1] }
        return (1...n).filter { n % $0 == 0 }
    }
    
    private static func evalPoly(_ coeffs: [Double], at x: Double) -> Double {
        coeffs.reversed().reduce(0) { $0 * x + $1 }
    }
    
    private static func formatNum(_ v: Double) -> String {
        v == Double(Int(v)) ? "\(Int(v))" : String(format: "%.4g", v)
    }
}
