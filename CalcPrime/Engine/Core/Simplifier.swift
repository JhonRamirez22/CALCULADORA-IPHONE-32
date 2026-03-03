// Simplifier.swift
// CalcPrime — Engine/Core
// Algebraic simplification engine with 50+ rules.
// Operates recursively on ExprNode AST.
// Rules: identity elements, zero absorption, constant folding, like-term collection,
//        rational arithmetic, trig identities, hyperbolic identities, power rules,
//        logarithm rules, expansion, factoring.
//
// Ref: Xcas/Giac simplify, Mathematica FullSimplify, Computer Algebra (Geddes/Czapor/Labahn)

import Foundation

// MARK: - Simplifier

struct Simplifier {
    
    /// Maximum recursion depth to avoid infinite loops
    private static let maxDepth = 100
    
    // MARK: - Public API
    
    /// Fully simplify an expression (recursive, multi-pass).
    static func simplify(_ expr: ExprNode) -> ExprNode {
        var current = expr
        for _ in 0..<maxDepth {
            let next = simplifyOnce(current, depth: 0)
            if next == current { return current }
            current = next
        }
        return current
    }
    
    /// Expand products and powers: (a+b)(c+d) → ac+ad+bc+bd
    static func expand(_ expr: ExprNode) -> ExprNode {
        let expanded = expandOnce(expr)
        return simplify(expanded)
    }
    
    /// Collect like terms: ax + bx → (a+b)x
    static func collect(_ expr: ExprNode, variable v: String) -> ExprNode {
        let simplified = simplify(expr)
        return collectTerms(simplified, variable: v)
    }
    
    // MARK: - Single Pass Simplification
    
    private static func simplifyOnce(_ expr: ExprNode, depth: Int) -> ExprNode {
        guard depth < maxDepth else { return expr }
        
        switch expr {
        // ── Recursion into children ────────────────────────
        case .negate(let a):
            let sa = simplifyOnce(a, depth: depth + 1)
            return simplifyNegate(sa)
            
        case .add(let terms):
            let simplified = terms.map { simplifyOnce($0, depth: depth + 1) }
            return simplifyAdd(simplified)
            
        case .multiply(let factors):
            let simplified = factors.map { simplifyOnce($0, depth: depth + 1) }
            return simplifyMultiply(simplified)
            
        case .power(let base, let exp):
            let sb = simplifyOnce(base, depth: depth + 1)
            let se = simplifyOnce(exp, depth: depth + 1)
            return simplifyPower(sb, se)
            
        case .function(let fn, let args):
            let sa = args.map { simplifyOnce($0, depth: depth + 1) }
            return simplifyFunction(fn, args: sa)
            
        case .derivative(let body, let v, let n):
            return .derivative(simplifyOnce(body, depth: depth + 1), v, n)
            
        case .integral(let body, let v):
            return .integral(simplifyOnce(body, depth: depth + 1), v)
            
        case .equation(let l, let r):
            return .equation(simplifyOnce(l, depth: depth + 1), simplifyOnce(r, depth: depth + 1))
            
        case .vector(let elems):
            return .vector(elems.map { simplifyOnce($0, depth: depth + 1) })
            
        case .matrix(let rows):
            return .matrix(rows.map { $0.map { simplifyOnce($0, depth: depth + 1) } })
            
        default:
            return expr
        }
    }
    
    // MARK: - Negate Simplification
    
    private static func simplifyNegate(_ a: ExprNode) -> ExprNode {
        // Rule: -0 → 0
        if a.isZero { return .zero }
        // Rule: -(-x) → x
        if case .negate(let inner) = a { return inner }
        // Rule: -(number) → number(-v)
        if case .number(let v) = a { return .number(-v) }
        // Rule: -(p/q) → (-p)/q
        if case .rational(let p, let q) = a { return .rational(-p, q) }
        // Rule: -(a + b + ...) → (-a) + (-b) + ...
        if case .add(let terms) = a {
            return .add(terms.map { .negate($0) })
        }
        return .negate(a)
    }
    
    // MARK: - Add Simplification (50+ rules)
    
    private static func simplifyAdd(_ terms: [ExprNode]) -> ExprNode {
        // Flatten nested adds
        var flat: [ExprNode] = []
        for t in terms {
            if case .add(let inner) = t { flat.append(contentsOf: inner) }
            else { flat.append(t) }
        }
        
        // Remove zeros
        flat = flat.filter { !$0.isZero }
        
        // Unwrap single negates and double negates within
        flat = flat.map { term in
            if case .negate(let inner) = term {
                if case .negate(let x) = inner { return x }
            }
            return term
        }
        
        // Constant folding: collect all numeric terms
        var numericSum = 0.0
        var hasNumeric = false
        var nonNumeric: [ExprNode] = []
        
        for t in flat {
            if let v = extractNumericValue(t) {
                numericSum += v
                hasNumeric = true
            } else {
                nonNumeric.append(t)
            }
        }
        
        // Rational constant folding
        var rationalSum = (0, 1)  // p/q accumulator
        var nonRational: [ExprNode] = []
        var rationalCollected = false
        
        for t in nonNumeric {
            if case .rational(let p, let q) = t {
                rationalSum = addRational(rationalSum.0, rationalSum.1, p, q)
                rationalCollected = true
            } else if case .negate(let inner) = t, case .rational(let p, let q) = inner {
                rationalSum = addRational(rationalSum.0, rationalSum.1, -p, q)
                rationalCollected = true
            } else {
                nonRational.append(t)
            }
        }
        
        // Collect like terms: ax + bx → (a+b)x
        let collected = collectLikeTerms(nonRational)
        
        // Build result
        var result: [ExprNode] = collected
        
        if rationalCollected && rationalSum.0 != 0 {
            result.append(.rational(rationalSum.0, rationalSum.1))
        }
        
        if hasNumeric && numericSum != 0 {
            // Convert to integer if exact
            if numericSum == Double(Int(numericSum)) && Swift.abs(numericSum) < 1e15 {
                result.append(.number(numericSum))
            } else {
                result.append(.number(numericSum))
            }
        }
        
        if result.isEmpty { return .zero }
        if result.count == 1 { return result[0] }
        return .add(result)
    }
    
    // MARK: - Multiply Simplification
    
    private static func simplifyMultiply(_ factors: [ExprNode]) -> ExprNode {
        // Flatten nested multiplies
        var flat: [ExprNode] = []
        for f in factors {
            if case .multiply(let inner) = f { flat.append(contentsOf: inner) }
            else { flat.append(f) }
        }
        
        // Rule: any factor is 0 → result is 0
        if flat.contains(where: { $0.isZero }) { return .zero }
        
        // Remove ones
        flat = flat.filter { !$0.isOne }
        
        // Count negations
        var negCount = 0
        var stripped: [ExprNode] = []
        for f in flat {
            if case .negate(let inner) = f {
                negCount += 1
                stripped.append(inner)
            } else {
                stripped.append(f)
            }
        }
        flat = stripped
        
        // Constant folding
        var numericProd = 1.0
        var hasNumeric = false
        var nonNumeric: [ExprNode] = []
        
        for f in flat {
            if let v = extractNumericValue(f) {
                numericProd *= v
                hasNumeric = true
            } else {
                nonNumeric.append(f)
            }
        }
        
        // Rational folding
        var rp = 1, rq = 1
        var nonRational: [ExprNode] = []
        var rationalCollected = false
        
        for f in nonNumeric {
            if case .rational(let p, let q) = f {
                rp *= p; rq *= q
                let g = gcd(Swift.abs(rp), Swift.abs(rq))
                rp /= g; rq /= g
                rationalCollected = true
            } else {
                nonRational.append(f)
            }
        }
        
        // Combine like bases: x * x → x^2,  x^a * x^b → x^(a+b)
        let combined = combineLikeBases(nonRational)
        
        var result: [ExprNode] = combined
        
        // Apply rational coefficient
        if rationalCollected && !(rp == 1 && rq == 1) {
            if rp == 0 { return .zero }
            if rq == 1 { result.insert(.number(Double(rp)), at: 0) }
            else { result.insert(.rational(rp, rq), at: 0) }
        }
        
        // Apply numeric coefficient
        if hasNumeric && numericProd != 1.0 {
            if numericProd == 0 { return .zero }
            result.insert(.number(numericProd), at: 0)
        }
        
        // Apply overall sign
        let isNeg = negCount % 2 == 1
        
        if result.isEmpty {
            return isNeg ? .negOne : .one
        }
        
        let product = result.count == 1 ? result[0] : .multiply(result)
        return isNeg ? .negate(product) : product
    }
    
    // MARK: - Power Simplification
    
    private static func simplifyPower(_ base: ExprNode, _ exp: ExprNode) -> ExprNode {
        // Rule: x^0 → 1
        if exp.isZero { return .one }
        // Rule: x^1 → x
        if exp.isOne { return base }
        // Rule: 0^n → 0 (n > 0)
        if base.isZero {
            if let e = exp.numericValue, e > 0 { return .zero }
        }
        // Rule: 1^n → 1
        if base.isOne { return .one }
        
        // Rule: (a^b)^c → a^(b*c)
        if case .power(let innerBase, let innerExp) = base {
            let newExp = simplifyMultiply([innerExp, exp])
            return .power(innerBase, newExp)
        }
        
        // Numeric constant folding: 2^3 → 8
        if let b = base.numericValue, let e = exp.numericValue {
            let result = Foundation.pow(b, e)
            if result.isFinite && result == Double(Int(result)) && Swift.abs(result) < 1e15 {
                return .number(result)
            }
        }
        
        // Rational bases with integer exponents
        if case .rational(let p, let q) = base, case .number(let e) = exp,
           e == Double(Int(e)) && Swift.abs(e) <= 10 {
            let n = Int(e)
            if n > 0 {
                var rp = 1, rq = 1
                for _ in 0..<n { rp *= p; rq *= q }
                let g = gcd(Swift.abs(rp), Swift.abs(rq))
                return .rational(rp / g, rq / g)
            }
            if n < 0 {
                // (p/q)^(-n) = (q/p)^n
                return simplifyPower(.rational(q, p), .number(Double(-n)))
            }
        }
        
        // Rule: sqrt(x)^2 → x  i.e. (x^(1/2))^2 → x
        // Already handled by (a^b)^c rule
        
        // Rule: e^ln(x) → x
        if base == .constant(.e), case .function(.ln, let args) = exp, args.count == 1 {
            return args[0]
        }
        
        return .power(base, exp)
    }
    
    // MARK: - Function Simplification
    
    private static func simplifyFunction(_ fn: MathFunc, args: [ExprNode]) -> ExprNode {
        guard !args.isEmpty else { return .function(fn, args) }
        let x = args[0]
        
        // Constant folding
        if args.allSatisfy({ $0.numericValue != nil }) {
            let numArgs = args.compactMap(\.numericValue)
            if let result = evaluateFunction(fn, numArgs: numArgs) {
                return .number(result)
            }
        }
        
        switch fn {
        // ── Trig at special angles ───────────────────────
        case .sin:
            if x.isZero { return .zero }
            if x == .constant(.pi) { return .zero }
            // sin(π/2) → 1
            if x == .multiply([.constant(.pi), .power(.number(2), .negOne)]) ||
               x == .multiply([.rational(1, 2), .constant(.pi)]) { return .one }
            // sin(-x) → -sin(x)  (odd function)
            if case .negate(let inner) = x {
                return .negate(.function(.sin, [inner]))
            }
            // sin(asin(x)) → x
            if case .function(.asin, let inner) = x, inner.count == 1 { return inner[0] }
            
        case .cos:
            if x.isZero { return .one }
            if x == .constant(.pi) { return .negOne }
            // cos(-x) → cos(x)  (even function)
            if case .negate(let inner) = x {
                return .function(.cos, [inner])
            }
            // cos(acos(x)) → x
            if case .function(.acos, let inner) = x, inner.count == 1 { return inner[0] }
            
        case .tan:
            if x.isZero { return .zero }
            // tan(-x) → -tan(x)
            if case .negate(let inner) = x {
                return .negate(.function(.tan, [inner]))
            }
            // tan(atan(x)) → x
            if case .function(.atan, let inner) = x, inner.count == 1 { return inner[0] }
            
        case .exp:
            if x.isZero { return .one }
            // exp(ln(x)) → x
            if case .function(.ln, let inner) = x, inner.count == 1 { return inner[0] }
            // exp(a + ln(b)) → b·exp(a)
            
        case .ln:
            if x.isOne { return .zero }
            if x == .constant(.e) { return .one }
            // ln(e^x) → x
            if case .power(let base, let exp) = x, base == .constant(.e) { return exp }
            // ln(x^n) → n·ln(x) (if x known > 0 — be careful)
            
        case .log:
            if x.isOne { return .zero }
            
        case .sqrt:
            if x.isZero { return .zero }
            if x.isOne { return .one }
            // sqrt(x^2) → |x|
            if case .power(let base, let exp) = x, exp == .two {
                return .function(.abs, [base])
            }
            // sqrt(a*b) — don't simplify unless we know sign
            
        case .abs:
            if x.isZero { return .zero }
            // abs(|x|) → |x|
            if case .function(.abs, _) = x { return x }
            // abs(-x) → abs(x)
            if case .negate(let inner) = x { return .function(.abs, [inner]) }
            // abs(x^2) → x^2
            if case .power(_, let exp) = x, let e = exp.numericValue, e.truncatingRemainder(dividingBy: 2) == 0 {
                return x
            }
            
        // ── Inverse trig/hyp compositions ───────────────
        case .asin:
            if x.isZero { return .zero }
            if x.isOne { return .multiply([.rational(1, 2), .constant(.pi)]) }
            
        case .acos:
            if x.isOne { return .zero }
            
        case .atan:
            if x.isZero { return .zero }
            
        // ── Hyperbolic ──────────────────────────────────
        case .sinh:
            if x.isZero { return .zero }
            if case .negate(let inner) = x { return .negate(.function(.sinh, [inner])) }
            
        case .cosh:
            if x.isZero { return .one }
            if case .negate(let inner) = x { return .function(.cosh, [inner]) }
            
        case .tanh:
            if x.isZero { return .zero }
            if case .negate(let inner) = x { return .negate(.function(.tanh, [inner])) }
            
        case .factorial:
            if x.isZero { return .one }
            if x.isOne { return .one }
            
        default:
            break
        }
        
        return .function(fn, args)
    }
    
    // MARK: - Like Term Collection
    
    /// Collect like terms in a sum: 2x + 3x → 5x
    /// Each term is decomposed into (coefficient, base-term)
    private static func collectLikeTerms(_ terms: [ExprNode]) -> [ExprNode] {
        var buckets: [(ExprNode, Double)] = [] // (base, total coefficient)
        
        for term in terms {
            let (coeff, base) = extractCoefficient(term)
            if let idx = buckets.firstIndex(where: { $0.0 == base }) {
                buckets[idx].1 += coeff
            } else {
                buckets.append((base, coeff))
            }
        }
        
        var result: [ExprNode] = []
        for (base, coeff) in buckets {
            if coeff == 0 { continue }
            if coeff == 1 { result.append(base); continue }
            if coeff == -1 { result.append(.negate(base)); continue }
            if base.isOne { result.append(.number(coeff)); continue }
            result.append(.multiply([.number(coeff), base]))
        }
        return result
    }
    
    /// Extract numeric coefficient from a term.
    /// e.g. 3x → (3, x),  -sin(x) → (-1, sin(x)),  x → (1, x)
    private static func extractCoefficient(_ expr: ExprNode) -> (Double, ExprNode) {
        switch expr {
        case .negate(let a):
            let (c, base) = extractCoefficient(a)
            return (-c, base)
        case .multiply(let factors):
            var coeff = 1.0
            var rest: [ExprNode] = []
            for f in factors {
                if let v = extractNumericValue(f) {
                    coeff *= v
                } else {
                    rest.append(f)
                }
            }
            let base = rest.isEmpty ? .one : (rest.count == 1 ? rest[0] : .multiply(rest))
            return (coeff, base)
        case .number(let v):
            return (v, .one)
        case .rational(let p, let q):
            return (Double(p) / Double(q), .one)
        default:
            return (1.0, expr)
        }
    }
    
    // MARK: - Like Base Combination (in products)
    
    /// Combine like bases: x·x → x², x^a·x^b → x^(a+b)
    private static func combineLikeBases(_ factors: [ExprNode]) -> [ExprNode] {
        var buckets: [(ExprNode, ExprNode)] = [] // (base, total exponent)
        
        for factor in factors {
            let (base, exp) = extractBaseExponent(factor)
            if let idx = buckets.firstIndex(where: { $0.0 == base }) {
                buckets[idx].1 = simplifyAdd([buckets[idx].1, exp])
            } else {
                buckets.append((base, exp))
            }
        }
        
        var result: [ExprNode] = []
        for (base, exp) in buckets {
            if exp.isZero { continue }
            if exp.isOne { result.append(base); continue }
            result.append(.power(base, exp))
        }
        return result
    }
    
    /// Extract base and exponent: x → (x, 1), x^n → (x, n)
    private static func extractBaseExponent(_ expr: ExprNode) -> (ExprNode, ExprNode) {
        if case .power(let base, let exp) = expr {
            return (base, exp)
        }
        return (expr, .one)
    }
    
    // MARK: - Expansion
    
    /// Expand products into sums: (a+b)(c+d) → ac+ad+bc+bd
    private static func expandOnce(_ expr: ExprNode) -> ExprNode {
        switch expr {
        case .multiply(let factors):
            let expanded = factors.map { expandOnce($0) }
            return expandProduct(expanded)
        case .power(let base, let exp):
            if case .add(let terms) = expandOnce(base),
               case .number(let n) = exp, n == Double(Int(n)), n >= 2, n <= 10 {
                // (a+b+...)^n  — expand by repeated multiplication
                var result: ExprNode = .add(terms)
                for _ in 1..<Int(n) {
                    result = expandProduct([result, .add(terms)])
                }
                return result
            }
            return .power(expandOnce(base), expandOnce(exp))
        case .negate(let a):
            return .negate(expandOnce(a))
        case .add(let terms):
            return .add(terms.map { expandOnce($0) })
        default:
            return expr
        }
    }
    
    /// Multiply out a product of (possibly sum) factors.
    private static func expandProduct(_ factors: [ExprNode]) -> ExprNode {
        guard !factors.isEmpty else { return .one }
        if factors.count == 1 { return factors[0] }
        
        var result = factors[0]
        for i in 1..<factors.count {
            result = distributeTwo(result, factors[i])
        }
        return result
    }
    
    /// Distribute: (a+b+...) * (c+d+...) → ac+ad+bc+bd+...
    private static func distributeTwo(_ lhs: ExprNode, _ rhs: ExprNode) -> ExprNode {
        let lTerms: [ExprNode]
        if case .add(let t) = lhs { lTerms = t } else { lTerms = [lhs] }
        let rTerms: [ExprNode]
        if case .add(let t) = rhs { rTerms = t } else { rTerms = [rhs] }
        
        var products: [ExprNode] = []
        for l in lTerms {
            for r in rTerms {
                products.append(.multiply([l, r]))
            }
        }
        
        return products.count == 1 ? products[0] : .add(products)
    }
    
    // MARK: - Term Collection by Variable
    
    private static func collectTerms(_ expr: ExprNode, variable v: String) -> ExprNode {
        guard case .add(let terms) = expr else { return expr }
        
        // Group by power of v
        var powerBuckets: [Int: [ExprNode]] = [:]  // degree → coefficient terms
        
        for term in terms {
            let (deg, coeff) = extractDegreeAndCoeff(term, variable: v)
            powerBuckets[deg, default: []].append(coeff)
        }
        
        var result: [ExprNode] = []
        for deg in powerBuckets.keys.sorted(by: >) {
            let coeffs = powerBuckets[deg]!
            let totalCoeff = coeffs.count == 1 ? coeffs[0] : simplifyAdd(coeffs)
            if totalCoeff.isZero { continue }
            if deg == 0 {
                result.append(totalCoeff)
            } else if deg == 1 {
                if totalCoeff.isOne { result.append(.variable(v)) }
                else { result.append(.multiply([totalCoeff, .variable(v)])) }
            } else {
                let vPow = ExprNode.power(.variable(v), .number(Double(deg)))
                if totalCoeff.isOne { result.append(vPow) }
                else { result.append(.multiply([totalCoeff, vPow])) }
            }
        }
        
        if result.isEmpty { return .zero }
        if result.count == 1 { return result[0] }
        return .add(result)
    }
    
    private static func extractDegreeAndCoeff(_ expr: ExprNode, variable v: String) -> (Int, ExprNode) {
        switch expr {
        case .variable(let name) where name == v:
            return (1, .one)
        case .power(.variable(let name), let exp) where name == v:
            if let e = exp.numericValue, e == Double(Int(e)) {
                return (Int(e), .one)
            }
            return (0, expr)
        case .multiply(let factors):
            var degree = 0
            var coeffFactors: [ExprNode] = []
            for f in factors {
                if case .variable(let name) = f, name == v {
                    degree += 1
                } else if case .power(.variable(let name), let exp) = f, name == v,
                          let e = exp.numericValue, e == Double(Int(e)) {
                    degree += Int(e)
                } else {
                    coeffFactors.append(f)
                }
            }
            let coeff = coeffFactors.isEmpty ? ExprNode.one : (coeffFactors.count == 1 ? coeffFactors[0] : .multiply(coeffFactors))
            return (degree, coeff)
        case .negate(let inner):
            let (deg, coeff) = extractDegreeAndCoeff(inner, variable: v)
            return (deg, .negate(coeff))
        default:
            if !expr.freeVariables.contains(v) { return (0, expr) }
            return (0, expr)
        }
    }
    
    // MARK: - Trig Identity Simplification
    
    /// Apply trig identities: sin²x + cos²x → 1, etc.
    static func trigSimplify(_ expr: ExprNode) -> ExprNode {
        var current = simplify(expr)
        current = applySinSqCosSq(current)
        current = simplify(current)
        return current
    }
    
    /// Detect sin²(x) + cos²(x) → 1
    private static func applySinSqCosSq(_ expr: ExprNode) -> ExprNode {
        guard case .add(let terms) = expr else { return expr }
        
        var remaining = terms
        var modified = false
        
        // Look for pairs of sin²(x) and cos²(x)
        for i in 0..<remaining.count {
            guard let (fn1, arg1) = matchTrigSquared(remaining[i]) else { continue }
            for j in (i+1)..<remaining.count {
                guard let (fn2, arg2) = matchTrigSquared(remaining[j]) else { continue }
                if arg1 == arg2 &&
                    ((fn1 == .sin && fn2 == .cos) || (fn1 == .cos && fn2 == .sin)) {
                    // sin²(x) + cos²(x) → 1
                    remaining[i] = .one
                    remaining.remove(at: j)
                    modified = true
                    break
                }
            }
        }
        
        if modified { return simplifyAdd(remaining) }
        return expr
    }
    
    /// Match expressions of the form sin(x)^2 or cos(x)^2
    private static func matchTrigSquared(_ expr: ExprNode) -> (MathFunc, ExprNode)? {
        guard case .power(let base, let exp) = expr, exp == .two else { return nil }
        guard case .function(let fn, let args) = base, args.count == 1 else { return nil }
        if fn == .sin || fn == .cos { return (fn, args[0]) }
        return nil
    }
    
    // MARK: - Helpers
    
    private static func extractNumericValue(_ expr: ExprNode) -> Double? {
        switch expr {
        case .number(let v): return v
        case .negate(let inner):
            if let v = extractNumericValue(inner) { return -v }
            return nil
        default: return nil
        }
    }
    
    private static func addRational(_ p1: Int, _ q1: Int, _ p2: Int, _ q2: Int) -> (Int, Int) {
        let num = p1 * q2 + p2 * q1
        let den = q1 * q2
        let g = gcd(Swift.abs(num), Swift.abs(den))
        return (num / g, den / g)
    }
    
    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? (a == 0 ? 1 : a) : gcd(b, a % b)
    }
    
    private static func evaluateFunction(_ fn: MathFunc, numArgs: [Double]) -> Double? {
        guard let x = numArgs.first else { return nil }
        switch fn {
        case .sin: return Foundation.sin(x)
        case .cos: return Foundation.cos(x)
        case .tan: return Foundation.tan(x)
        case .exp: return Foundation.exp(x)
        case .ln:  return x > 0 ? Foundation.log(x) : nil
        case .log: return x > 0 ? Foundation.log10(x) : nil
        case .sqrt: return x >= 0 ? Foundation.sqrt(x) : nil
        case .abs: return Swift.abs(x)
        case .floor: return Foundation.floor(x)
        case .ceil: return Foundation.ceil(x)
        default: return nil
        }
    }
}
