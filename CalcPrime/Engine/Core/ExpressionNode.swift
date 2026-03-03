// ExpressionNode.swift
// CalcPrime — Engine/Core
// Complete AST (Abstract Syntax Tree) for all mathematical expressions.
// Replaces the old Expression.swift with n-ary add/multiply, rational numbers,
// complex numbers, piecewise functions, and all calculus/LA operations.
//
// Ref: Xcas/Giac source (gen.h), Mathematica FullForm, SymPy core

import Foundation

// MARK: - ExprNode (AST)

/// The core expression node. Every mathematical formula is represented as a tree of `ExprNode`.
/// Uses n-ary `add` and `multiply` for efficient collection of like terms.
indirect enum ExprNode: Equatable, Hashable {
    
    // ── Atoms ──────────────────────────────────────────────
    /// Floating-point number
    case number(Double)
    /// Exact rational p/q (always in lowest terms, q > 0)
    case rational(Int, Int)
    /// Mathematical constant: π, e, i, φ, γ, ∞
    case constant(MathConst)
    /// Named variable: "x", "t", "θ", etc.
    case variable(String)
    
    // ── N-ary Arithmetic ──────────────────────────────────
    /// Sum of terms: a + b + c + ... (n-ary)
    case add([ExprNode])
    /// Product of factors: a · b · c · ... (n-ary)
    case multiply([ExprNode])
    /// Power: base^exponent
    case power(ExprNode, ExprNode)
    /// Negation: -x (sugar for multiply([-1, x]))
    case negate(ExprNode)
    
    // ── Functions ─────────────────────────────────────────
    /// Named function with arguments: sin(x), log(x,10), max(a,b,c)
    case function(MathFunc, [ExprNode])
    
    // ── Calculus ──────────────────────────────────────────
    /// Derivative: d^n f / dx^n
    case derivative(ExprNode, String, Int)
    /// Partial derivative: ∂f/∂x
    case partialDerivative(ExprNode, String)
    /// Indefinite integral: ∫ f dx
    case integral(ExprNode, String)
    /// Definite integral: ∫_a^b f dx
    case definiteIntegral(ExprNode, String, ExprNode, ExprNode)
    /// Limit: lim_{x→a} f(x)
    case limit(ExprNode, String, ExprNode, LimitDir)
    /// Summation: Σ_{i=a}^{b} f(i)
    case summation(ExprNode, String, ExprNode, ExprNode)
    /// Product: Π_{i=a}^{b} f(i)
    case productOp(ExprNode, String, ExprNode, ExprNode)
    
    // ── Linear Algebra ───────────────────────────────────
    case vector([ExprNode])
    case matrix([[ExprNode]])
    
    // ── Complex Numbers ──────────────────────────────────
    /// a + bi stored as (real, imag)
    case complexNumber(ExprNode, ExprNode)
    
    // ── Structural ───────────────────────────────────────
    /// Equation: lhs = rhs
    case equation(ExprNode, ExprNode)
    /// Inequality: lhs < rhs, lhs ≤ rhs, etc.
    case inequality(ExprNode, String, ExprNode) // op is "<", "<=", ">", ">=", "!="
    /// Piecewise function: [(condition, value), ...]
    case piecewise([(ExprNode, ExprNode)])
    /// List/set of expressions
    case list([ExprNode])
    /// Assignment: x := expr
    case assignment(String, ExprNode)
    
    // ── Special Functions / Distributions ─────────────────
    /// Heaviside step: u(t-a)
    case heaviside(ExprNode)
    /// Dirac delta: δ(t-a)
    case diracDelta(ExprNode)
    
    // ── Transforms ───────────────────────────────────────
    /// Laplace transform: L{f(t)}(s)
    case laplace(ExprNode, String, String)
    /// Inverse Laplace: L⁻¹{F(s)}(t)
    case inverseLaplace(ExprNode, String, String)
    /// Fourier transform
    case fourier(ExprNode, String, String)
    /// Inverse Fourier
    case inverseFourier(ExprNode, String, String)
    /// Z transform
    case zTransform(ExprNode, String, String)
    
    // ── Sentinel ─────────────────────────────────────────
    /// Undefined / error
    case undefined(String)
}

// MARK: - Mathematical Constants

enum MathConst: String, CaseIterable, Equatable, Hashable, Codable {
    case pi    = "π"
    case e     = "e"
    case i     = "i"       // imaginary unit √(-1)
    case phi   = "φ"       // golden ratio (1+√5)/2
    case euler = "γ"       // Euler-Mascheroni 0.5772...
    case inf   = "∞"       // positive infinity
    case negInf = "-∞"     // negative infinity
}

extension MathConst {
    var numericValue: Double? {
        switch self {
        case .pi:     return .pi
        case .e:      return M_E
        case .phi:    return (1.0 + Foundation.sqrt(5.0)) / 2.0
        case .euler:  return 0.5772156649015329
        case .inf:    return .infinity
        case .negInf: return -.infinity
        case .i:      return nil
        }
    }
}

// MARK: - Limit Direction

enum LimitDir: String, Equatable, Hashable, Codable {
    case left  = "-"
    case right = "+"
    case both  = "±"
}

// MARK: - Math Functions Enum

/// All built-in mathematical functions. Using an enum ensures exhaustive handling.
enum MathFunc: String, Equatable, Hashable, CaseIterable, Codable {
    // Trigonometric
    case sin, cos, tan, csc, sec, cot
    case asin, acos, atan, acsc, asec, acot
    case atan2
    
    // Hyperbolic
    case sinh, cosh, tanh, csch, sech, coth
    case asinh, acosh, atanh, acsch, asech, acoth
    
    // Exponential / Logarithmic
    case exp, ln, log, log2, log10
    
    // Roots
    case sqrt, cbrt
    
    // Rounding / Absolute
    case abs, sign, floor, ceil, round
    
    // Special Functions
    case gamma, lgamma, beta, digamma
    case erf, erfc, erfi
    case Si, Ci, li, Ei               // integral functions
    case besselJ, besselY             // Bessel 1st/2nd kind
    case besselI, besselK             // modified Bessel
    case airyAi, airyBi               // Airy functions
    case legendreP, legendreQ         // Legendre
    case hermiteH                      // Hermite
    case laguerreL                     // Laguerre
    case chebyshevT, chebyshevU       // Chebyshev
    case lambertW                      // Lambert W
    case zeta                          // Riemann zeta
    case polyGamma                     // polygamma ψ^(n)(x)
    case hypergeom                     // generalized hypergeometric
    case fresnelS, fresnelC           // Fresnel integrals
    case ellipticK, ellipticE         // complete elliptic integrals
    
    // Combinatorial
    case factorial
    case binomial       // C(n,k)
    case permutation    // P(n,k)
    
    // Min/Max
    case max, min
    
    // Number Theory
    case gcd, lcm, mod
    
    // Complex
    case real, imag, conj, arg, cabs
    
    // Utility
    case nthRoot        // nthRoot(x, n) = x^(1/n)
    case logBase        // logBase(x, b) = log_b(x)
    case heaviside      // step function
    case delta          // dirac delta
    
    /// Number of expected arguments
    var arity: ClosedRange<Int> {
        switch self {
        // Single-argument
        case .sin, .cos, .tan, .csc, .sec, .cot,
             .asin, .acos, .atan, .acsc, .asec, .acot,
             .sinh, .cosh, .tanh, .csch, .sech, .coth,
             .asinh, .acosh, .atanh, .acsch, .asech, .acoth,
             .exp, .ln, .log, .log2, .log10,
             .sqrt, .cbrt,
             .abs, .sign, .floor, .ceil, .round,
             .gamma, .lgamma, .digamma,
             .erf, .erfc, .erfi,
             .Si, .Ci, .li, .Ei,
             .airyAi, .airyBi,
             .lambertW, .zeta, .factorial,
             .real, .imag, .conj, .arg, .cabs,
             .heaviside, .delta,
             .fresnelS, .fresnelC, .ellipticK, .ellipticE:
            return 1...1
        // Two arguments
        case .atan2, .beta, .binomial, .permutation,
             .nthRoot, .logBase, .gcd, .lcm, .mod,
             .besselJ, .besselY, .besselI, .besselK,
             .legendreP, .legendreQ, .hermiteH,
             .laguerreL, .chebyshevT, .chebyshevU,
             .polyGamma:
            return 2...2
        // Variable arguments
        case .max, .min:
            return 1...99
        case .hypergeom:
            return 3...3
        }
    }
}

// MARK: - Convenience Constructors

extension ExprNode {
    
    // Constants
    static let zero     = ExprNode.number(0)
    static let one      = ExprNode.number(1)
    static let two      = ExprNode.number(2)
    static let three    = ExprNode.number(3)
    static let negOne   = ExprNode.number(-1)
    static let half     = ExprNode.rational(1, 2)
    static let pi       = ExprNode.constant(.pi)
    static let e        = ExprNode.constant(.e)
    static let im       = ExprNode.constant(.i)
    static let infinity = ExprNode.constant(.inf)
    
    // Short helpers
    static func int(_ n: Int) -> ExprNode { .number(Double(n)) }
    static func frac(_ p: Int, _ q: Int) -> ExprNode {
        let g = Self.gcdInt(Swift.abs(p), Swift.abs(q))
        let sign = (q < 0) ? -1 : 1
        return .rational(sign * p / g, Swift.abs(q) / g)
    }
    
    // Arithmetic helpers
    static func sum(_ terms: ExprNode...) -> ExprNode { .add(terms) }
    static func prod(_ factors: ExprNode...) -> ExprNode { .multiply(factors) }
    static func pow(_ base: ExprNode, _ exp: ExprNode) -> ExprNode { .power(base, exp) }
    static func inv(_ x: ExprNode) -> ExprNode { .power(x, .negOne) }
    static func div(_ a: ExprNode, _ b: ExprNode) -> ExprNode { .multiply([a, .power(b, .negOne)]) }
    
    // Function helpers
    static func sin(_ x: ExprNode) -> ExprNode   { .function(.sin, [x]) }
    static func cos(_ x: ExprNode) -> ExprNode   { .function(.cos, [x]) }
    static func tan(_ x: ExprNode) -> ExprNode   { .function(.tan, [x]) }
    static func csc(_ x: ExprNode) -> ExprNode   { .function(.csc, [x]) }
    static func sec(_ x: ExprNode) -> ExprNode   { .function(.sec, [x]) }
    static func cot(_ x: ExprNode) -> ExprNode   { .function(.cot, [x]) }
    static func asin(_ x: ExprNode) -> ExprNode  { .function(.asin, [x]) }
    static func acos(_ x: ExprNode) -> ExprNode  { .function(.acos, [x]) }
    static func atan(_ x: ExprNode) -> ExprNode  { .function(.atan, [x]) }
    static func sinh(_ x: ExprNode) -> ExprNode  { .function(.sinh, [x]) }
    static func cosh(_ x: ExprNode) -> ExprNode  { .function(.cosh, [x]) }
    static func tanh(_ x: ExprNode) -> ExprNode  { .function(.tanh, [x]) }
    static func asinh(_ x: ExprNode) -> ExprNode { .function(.asinh, [x]) }
    static func acosh(_ x: ExprNode) -> ExprNode { .function(.acosh, [x]) }
    static func atanh(_ x: ExprNode) -> ExprNode { .function(.atanh, [x]) }
    static func exp(_ x: ExprNode) -> ExprNode   { .function(.exp, [x]) }
    static func ln(_ x: ExprNode) -> ExprNode    { .function(.ln, [x]) }
    static func log(_ x: ExprNode) -> ExprNode   { .function(.log, [x]) }
    static func log2(_ x: ExprNode) -> ExprNode  { .function(.log2, [x]) }
    static func log10(_ x: ExprNode) -> ExprNode { .function(.log10, [x]) }
    static func sqrt(_ x: ExprNode) -> ExprNode  { .function(.sqrt, [x]) }
    static func cbrt(_ x: ExprNode) -> ExprNode  { .function(.cbrt, [x]) }
    static func abs(_ x: ExprNode) -> ExprNode   { .function(.abs, [x]) }
    static func erf(_ x: ExprNode) -> ExprNode   { .function(.erf, [x]) }
    static func erfc(_ x: ExprNode) -> ExprNode  { .function(.erfc, [x]) }
    static func gamma(_ x: ExprNode) -> ExprNode { .function(.gamma, [x]) }
    static func fact(_ x: ExprNode) -> ExprNode  { .function(.factorial, [x]) }
    
    static func logBase(_ x: ExprNode, _ b: ExprNode) -> ExprNode { .function(.logBase, [x, b]) }
    static func nthRoot(_ x: ExprNode, _ n: ExprNode) -> ExprNode { .function(.nthRoot, [x, n]) }
    static func besselJ(_ n: ExprNode, _ x: ExprNode) -> ExprNode { .function(.besselJ, [n, x]) }
    static func besselY(_ n: ExprNode, _ x: ExprNode) -> ExprNode { .function(.besselY, [n, x]) }
    static func binomial(_ n: ExprNode, _ k: ExprNode) -> ExprNode { .function(.binomial, [n, k]) }
    
    // GCD helper for rationals
    private static func gcdInt(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcdInt(b, a % b)
    }
}

// MARK: - Operator Overloads (DSL)

func + (lhs: ExprNode, rhs: ExprNode) -> ExprNode {
    // Flatten nested adds
    var terms: [ExprNode] = []
    if case .add(let a) = lhs { terms.append(contentsOf: a) } else { terms.append(lhs) }
    if case .add(let b) = rhs { terms.append(contentsOf: b) } else { terms.append(rhs) }
    return .add(terms)
}

func - (lhs: ExprNode, rhs: ExprNode) -> ExprNode {
    lhs + .negate(rhs)
}

func * (lhs: ExprNode, rhs: ExprNode) -> ExprNode {
    var factors: [ExprNode] = []
    if case .multiply(let a) = lhs { factors.append(contentsOf: a) } else { factors.append(lhs) }
    if case .multiply(let b) = rhs { factors.append(contentsOf: b) } else { factors.append(rhs) }
    return .multiply(factors)
}

func / (lhs: ExprNode, rhs: ExprNode) -> ExprNode {
    lhs * .power(rhs, .negOne)
}

prefix func - (expr: ExprNode) -> ExprNode { .negate(expr) }

// MARK: - Properties

extension ExprNode {
    
    /// True if the node contains no free variables.
    var isNumeric: Bool {
        freeVariables.isEmpty
    }
    
    /// True if this is exactly zero.
    var isZero: Bool {
        switch self {
        case .number(let v): return v == 0
        case .rational(let p, _): return p == 0
        default: return false
        }
    }
    
    /// True if this is exactly one.
    var isOne: Bool {
        switch self {
        case .number(let v): return v == 1
        case .rational(let p, let q): return p == q
        default: return false
        }
    }
    
    /// True if this is a negative expression.
    var isNegative: Bool {
        switch self {
        case .number(let v): return v < 0
        case .rational(let p, _): return p < 0
        case .negate: return true
        case .multiply(let factors):
            return factors.first?.isNegative ?? false
        default: return false
        }
    }
    
    /// Attempt numeric evaluation.
    var numericValue: Double? {
        switch self {
        case .number(let v): return v
        case .rational(let p, let q): return Double(p) / Double(q)
        case .constant(let c): return c.numericValue
        case .negate(let a):
            guard let v = a.numericValue else { return nil }
            return -v
        case .add(let terms):
            var sum = 0.0
            for t in terms {
                guard let v = t.numericValue else { return nil }
                sum += v
            }
            return sum
        case .multiply(let factors):
            var prod = 1.0
            for f in factors {
                guard let v = f.numericValue else { return nil }
                prod *= v
            }
            return prod
        case .power(let base, let exp):
            guard let b = base.numericValue, let e = exp.numericValue else { return nil }
            return Foundation.pow(b, e)
        case .function(let fn, let args):
            return evaluateFunction(fn, args: args.compactMap(\.numericValue))
        default: return nil
        }
    }
    
    /// Collect all free (unbound) variable names.
    var freeVariables: Set<String> {
        switch self {
        case .number, .rational, .constant, .undefined: return []
        case .variable(let v): return [v]
        case .negate(let a): return a.freeVariables
        case .add(let terms):
            return terms.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .multiply(let factors):
            return factors.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .power(let a, let b):
            return a.freeVariables.union(b.freeVariables)
        case .function(_, let args):
            return args.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .derivative(let body, let v, _):
            return body.freeVariables // v is the variable of differentiation, still free
        case .partialDerivative(let body, _):
            return body.freeVariables
        case .integral(let body, let v):
            return body.freeVariables.subtracting([v])
        case .definiteIntegral(let body, let v, let lo, let hi):
            return body.freeVariables.subtracting([v]).union(lo.freeVariables).union(hi.freeVariables)
        case .summation(let body, let v, let lo, let hi),
             .productOp(let body, let v, let lo, let hi):
            return body.freeVariables.subtracting([v]).union(lo.freeVariables).union(hi.freeVariables)
        case .limit(let body, let v, let pt, _):
            return body.freeVariables.subtracting([v]).union(pt.freeVariables)
        case .vector(let elems):
            return elems.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .matrix(let rows):
            return rows.flatMap { $0 }.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .complexNumber(let re, let im):
            return re.freeVariables.union(im.freeVariables)
        case .equation(let l, let r), .inequality(let l, _, let r):
            return l.freeVariables.union(r.freeVariables)
        case .piecewise(let pairs):
            return pairs.reduce(into: Set<String>()) { $0.formUnion($1.0.freeVariables); $0.formUnion($1.1.freeVariables) }
        case .list(let elems):
            return elems.reduce(into: Set<String>()) { $0.formUnion($1.freeVariables) }
        case .heaviside(let a), .diracDelta(let a):
            return a.freeVariables
        case .laplace(let body, _, _), .inverseLaplace(let body, _, _),
             .fourier(let body, _, _), .inverseFourier(let body, _, _),
             .zTransform(let body, _, _):
            return body.freeVariables
        case .assignment(_, let expr):
            return expr.freeVariables
        }
    }
    
    /// Substitute a variable with an expression.
    func substitute(_ varName: String, with replacement: ExprNode) -> ExprNode {
        switch self {
        case .variable(let v) where v == varName:
            return replacement
        case .variable, .number, .rational, .constant, .undefined:
            return self
        case .negate(let a):
            return .negate(a.substitute(varName, with: replacement))
        case .add(let terms):
            return .add(terms.map { $0.substitute(varName, with: replacement) })
        case .multiply(let factors):
            return .multiply(factors.map { $0.substitute(varName, with: replacement) })
        case .power(let base, let exp):
            return .power(base.substitute(varName, with: replacement), exp.substitute(varName, with: replacement))
        case .function(let fn, let args):
            return .function(fn, args.map { $0.substitute(varName, with: replacement) })
        case .derivative(let body, let v, let n):
            return .derivative(body.substitute(varName, with: replacement), v, n)
        case .partialDerivative(let body, let v):
            return .partialDerivative(body.substitute(varName, with: replacement), v)
        case .integral(let body, let v):
            if v == varName { return self }
            return .integral(body.substitute(varName, with: replacement), v)
        case .definiteIntegral(let body, let v, let lo, let hi):
            if v == varName { return self }
            return .definiteIntegral(body.substitute(varName, with: replacement), v,
                                     lo.substitute(varName, with: replacement),
                                     hi.substitute(varName, with: replacement))
        case .summation(let body, let v, let lo, let hi):
            if v == varName { return self }
            return .summation(body.substitute(varName, with: replacement), v,
                              lo.substitute(varName, with: replacement),
                              hi.substitute(varName, with: replacement))
        case .productOp(let body, let v, let lo, let hi):
            if v == varName { return self }
            return .productOp(body.substitute(varName, with: replacement), v,
                              lo.substitute(varName, with: replacement),
                              hi.substitute(varName, with: replacement))
        case .limit(let body, let v, let pt, let dir):
            if v == varName { return self }
            return .limit(body.substitute(varName, with: replacement), v,
                          pt.substitute(varName, with: replacement), dir)
        case .vector(let elems):
            return .vector(elems.map { $0.substitute(varName, with: replacement) })
        case .matrix(let rows):
            return .matrix(rows.map { $0.map { $0.substitute(varName, with: replacement) } })
        case .complexNumber(let re, let im):
            return .complexNumber(re.substitute(varName, with: replacement), im.substitute(varName, with: replacement))
        case .equation(let l, let r):
            return .equation(l.substitute(varName, with: replacement), r.substitute(varName, with: replacement))
        case .inequality(let l, let op, let r):
            return .inequality(l.substitute(varName, with: replacement), op, r.substitute(varName, with: replacement))
        case .piecewise(let pairs):
            return .piecewise(pairs.map { ($0.0.substitute(varName, with: replacement), $0.1.substitute(varName, with: replacement)) })
        case .list(let elems):
            return .list(elems.map { $0.substitute(varName, with: replacement) })
        case .heaviside(let a):
            return .heaviside(a.substitute(varName, with: replacement))
        case .diracDelta(let a):
            return .diracDelta(a.substitute(varName, with: replacement))
        case .laplace(let body, let tv, let fv):
            return .laplace(body.substitute(varName, with: replacement), tv, fv)
        case .inverseLaplace(let body, let fv, let tv):
            return .inverseLaplace(body.substitute(varName, with: replacement), fv, tv)
        case .fourier(let body, let tv, let fv):
            return .fourier(body.substitute(varName, with: replacement), tv, fv)
        case .inverseFourier(let body, let fv, let tv):
            return .inverseFourier(body.substitute(varName, with: replacement), fv, tv)
        case .zTransform(let body, let nv, let zv):
            return .zTransform(body.substitute(varName, with: replacement), nv, zv)
        case .assignment(let name, let expr):
            return .assignment(name, expr.substitute(varName, with: replacement))
        }
    }
    
    /// Evaluate with a dictionary of variable → value assignments.
    func evaluate(with vars: [String: Double] = [:]) -> Double? {
        var expr = self
        for (k, v) in vars { expr = expr.substitute(k, with: .number(v)) }
        return expr.numericValue
    }
    
    // MARK: - Function Evaluation
    
    private func evaluateFunction(_ fn: MathFunc, args: [Double]) -> Double? {
        guard !args.isEmpty else { return nil }
        let x = args[0]
        switch fn {
        case .sin:   return Foundation.sin(x)
        case .cos:   return Foundation.cos(x)
        case .tan:   return Foundation.tan(x)
        case .csc:   return 1.0 / Foundation.sin(x)
        case .sec:   return 1.0 / Foundation.cos(x)
        case .cot:   return 1.0 / Foundation.tan(x)
        case .asin:  return Foundation.asin(x)
        case .acos:  return Foundation.acos(x)
        case .atan:  return Foundation.atan(x)
        case .acsc:  return Foundation.asin(1.0 / x)
        case .asec:  return Foundation.acos(1.0 / x)
        case .acot:  return Foundation.atan(1.0 / x)
        case .sinh:  return Foundation.sinh(x)
        case .cosh:  return Foundation.cosh(x)
        case .tanh:  return Foundation.tanh(x)
        case .csch:  return 1.0 / Foundation.sinh(x)
        case .sech:  return 1.0 / Foundation.cosh(x)
        case .coth:  return 1.0 / Foundation.tanh(x)
        case .asinh: return Foundation.asinh(x)
        case .acosh: return Foundation.acosh(x)
        case .atanh: return Foundation.atanh(x)
        case .acsch: return Foundation.asinh(1.0 / x)
        case .asech: return Foundation.acosh(1.0 / x)
        case .acoth: return Foundation.atanh(1.0 / x)
        case .exp:   return Foundation.exp(x)
        case .ln:    return Foundation.log(x)
        case .log:   return Foundation.log10(x)
        case .log2:  return Foundation.log2(x)
        case .log10: return Foundation.log10(x)
        case .sqrt:  return Foundation.sqrt(x)
        case .cbrt:  return Foundation.cbrt(x)
        case .abs:   return Swift.abs(x)
        case .sign:  return x > 0 ? 1 : (x < 0 ? -1 : 0)
        case .floor: return Foundation.floor(x)
        case .ceil:  return Foundation.ceil(x)
        case .round: return Foundation.round(x)
        case .factorial:
            if x == Double(Int(x)) && x >= 0 && x <= 170 {
                var r = 1.0; for i in 2...max(1, Int(x)) { r *= Double(i) }; return r
            }
            return Foundation.tgamma(x + 1) // Gamma(x+1)
        case .gamma:  return Foundation.tgamma(x)
        case .lgamma: return Foundation.lgamma(x)
        case .erf:    return Self.computeErf(x)
        case .erfc:   return 1.0 - Self.computeErf(x)
        case .heaviside: return x >= 0 ? 1 : 0
        case .delta:  return x == 0 ? .infinity : 0
        case .lambertW: return Self.computeLambertW(x)
        case .cabs:   return Swift.abs(x)
        case .real:   return x
        case .imag:   return 0
        case .conj:   return x
        case .arg:    return x >= 0 ? 0 : .pi
        
        // Two-argument functions
        case .atan2:
            guard args.count >= 2 else { return nil }
            return Foundation.atan2(args[0], args[1])
        case .beta:
            guard args.count >= 2 else { return nil }
            return Foundation.tgamma(args[0]) * Foundation.tgamma(args[1]) / Foundation.tgamma(args[0] + args[1])
        case .logBase:
            guard args.count >= 2, args[1] > 0, args[1] != 1 else { return nil }
            return Foundation.log(args[0]) / Foundation.log(args[1])
        case .nthRoot:
            guard args.count >= 2 else { return nil }
            return Foundation.pow(args[0], 1.0 / args[1])
        case .binomial:
            guard args.count >= 2 else { return nil }
            return Self.binomialCoeff(args[0], args[1])
        case .permutation:
            guard args.count >= 2 else { return nil }
            return Foundation.tgamma(args[0] + 1) / Foundation.tgamma(args[0] - args[1] + 1)
        case .gcd:
            guard args.count >= 2 else { return nil }
            return Double(Self.gcdInt(Int(args[0]), Int(args[1])))
        case .lcm:
            guard args.count >= 2 else { return nil }
            let a = Int(args[0]), b = Int(args[1])
            return Double(Swift.abs(a * b) / Self.gcdInt(Swift.abs(a), Swift.abs(b)))
        case .mod:
            guard args.count >= 2, args[1] != 0 else { return nil }
            return args[0].truncatingRemainder(dividingBy: args[1])
        case .besselJ:
            guard args.count >= 2 else { return nil }
            return Self.computeBesselJ(n: Int(args[0]), x: args[1])
        case .max:
            return args.max()
        case .min:
            return args.min()
            
        default: return nil
        }
    }
    
    // MARK: - Numerical Special Functions
    
    private static func computeErf(_ x: Double) -> Double {
        // Abramowitz & Stegun approximation 7.1.26
        let t = 1.0 / (1.0 + 0.3275911 * Swift.abs(x))
        let poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))))
        let result = 1.0 - poly * Foundation.exp(-x * x)
        return x >= 0 ? result : -result
    }
    
    private static func computeLambertW(_ x: Double) -> Double {
        // Newton iteration for W(x): w*e^w = x
        guard x >= -1.0 / M_E else { return .nan }
        var w = x < 1 ? 0.0 : Foundation.log(x)
        for _ in 0..<50 {
            let ew = Foundation.exp(w)
            let wew = w * ew
            let delta = (wew - x) / (ew * (w + 1) - (w + 2) * (wew - x) / (2 * w + 2))
            w -= delta
            if Swift.abs(delta) < 1e-15 { break }
        }
        return w
    }
    
    private static func computeBesselJ(n: Int, x: Double) -> Double {
        // Series expansion for J_n(x) — first 30 terms
        var sum = 0.0
        for m in 0..<30 {
            let sign = (m % 2 == 0) ? 1.0 : -1.0
            let num = Foundation.pow(x / 2.0, Double(2 * m + n))
            let denom = Foundation.tgamma(Double(m + 1)) * Foundation.tgamma(Double(m + n + 1))
            sum += sign * num / denom
        }
        return sum
    }
    
    private static func binomialCoeff(_ n: Double, _ k: Double) -> Double {
        Foundation.tgamma(n + 1) / (Foundation.tgamma(k + 1) * Foundation.tgamma(n - k + 1))
    }
    
    static func gcdInt(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcdInt(b, a % b)
    }
}

// MARK: - LaTeX Rendering

extension ExprNode {
    
    var latex: String {
        switch self {
        case .number(let v):
            if v == Double(Int(v)) && Swift.abs(v) < 1e15 { return "\(Int(v))" }
            return String(format: "%.6g", v)
        case .rational(let p, let q):
            if q == 1 { return "\(p)" }
            return "\\frac{\(p)}{\(q)}"
        case .variable(let v):
            return v.count == 1 ? v : "\\mathrm{\(v)}"
        case .constant(let c):
            switch c {
            case .pi: return "\\pi"
            case .e: return "e"
            case .i: return "i"
            case .phi: return "\\varphi"
            case .euler: return "\\gamma"
            case .inf: return "\\infty"
            case .negInf: return "-\\infty"
            }
        case .negate(let a):
            return "-" + wrapIfNeeded(a, for: .negate(a))
        case .add(let terms):
            var s = ""
            for (i, t) in terms.enumerated() {
                if i == 0 { s = t.latex }
                else if case .negate(let inner) = t {
                    s += " - " + wrapIfNeeded(inner, for: self)
                } else {
                    s += " + " + t.latex
                }
            }
            return s.isEmpty ? "0" : s
        case .multiply(let factors):
            return renderMultiply(factors)
        case .power(let base, let exp):
            // Special cases
            if exp == .half { return "\\sqrt{\(base.latex)}" }
            if exp == .negOne { return "\\frac{1}{\(base.latex)}" }
            if case .rational(1, let q) = exp { return "\\sqrt[\(q)]{\(base.latex)}" }
            let baseStr = wrapIfNeeded(base, for: self)
            return "{\(baseStr)}^{\(exp.latex)}"
        case .function(let fn, let args):
            return renderFunction(fn, args: args)
        case .derivative(let body, let v, let n):
            if n == 1 { return "\\frac{d}{d\(v)}\\left(\(body.latex)\\right)" }
            return "\\frac{d^{\(n)}}{d\(v)^{\(n)}}\\left(\(body.latex)\\right)"
        case .partialDerivative(let body, let v):
            return "\\frac{\\partial}{\\partial \(v)}\\left(\(body.latex)\\right)"
        case .integral(let body, let v):
            return "\\int \(body.latex) \\, d\(v)"
        case .definiteIntegral(let body, let v, let lo, let hi):
            return "\\int_{\(lo.latex)}^{\(hi.latex)} \(body.latex) \\, d\(v)"
        case .limit(let body, let v, let pt, let dir):
            let dirStr = dir == .both ? "" : "^{\(dir.rawValue)}"
            return "\\lim_{\(v) \\to \(pt.latex)\(dirStr)} \(body.latex)"
        case .summation(let body, let v, let lo, let hi):
            return "\\sum_{\(v)=\(lo.latex)}^{\(hi.latex)} \(body.latex)"
        case .productOp(let body, let v, let lo, let hi):
            return "\\prod_{\(v)=\(lo.latex)}^{\(hi.latex)} \(body.latex)"
        case .vector(let elems):
            return "\\begin{pmatrix} \(elems.map(\.latex).joined(separator: " \\\\ ")) \\end{pmatrix}"
        case .matrix(let rows):
            return "\\begin{pmatrix} \(rows.map { $0.map(\.latex).joined(separator: " & ") }.joined(separator: " \\\\ ")) \\end{pmatrix}"
        case .complexNumber(let re, let im):
            return "\(re.latex) + \(im.latex)i"
        case .equation(let l, let r):
            return "\(l.latex) = \(r.latex)"
        case .inequality(let l, let op, let r):
            let tex = ["<": "<", "<=": "\\leq", ">": ">", ">=": "\\geq", "!=": "\\neq"][op] ?? op
            return "\(l.latex) \(tex) \(r.latex)"
        case .piecewise(let pairs):
            let cases = pairs.map { "\($0.1.latex) & \\text{si } \($0.0.latex)" }
            return "\\begin{cases} \(cases.joined(separator: " \\\\ ")) \\end{cases}"
        case .list(let elems):
            return "\\left\\{ \(elems.map(\.latex).joined(separator: ",\\, ")) \\right\\}"
        case .heaviside(let a):
            return "u\\left(\(a.latex)\\right)"
        case .diracDelta(let a):
            return "\\delta\\left(\(a.latex)\\right)"
        case .laplace(let body, _, _):
            return "\\mathcal{L}\\left\\{\(body.latex)\\right\\}"
        case .inverseLaplace(let body, _, _):
            return "\\mathcal{L}^{-1}\\left\\{\(body.latex)\\right\\}"
        case .fourier(let body, _, _):
            return "\\mathcal{F}\\left\\{\(body.latex)\\right\\}"
        case .inverseFourier(let body, _, _):
            return "\\mathcal{F}^{-1}\\left\\{\(body.latex)\\right\\}"
        case .zTransform(let body, _, _):
            return "\\mathcal{Z}\\left\\{\(body.latex)\\right\\}"
        case .assignment(let name, let expr):
            return "\(name) := \(expr.latex)"
        case .undefined(let msg):
            return "\\text{indef: \(msg)}"
        }
    }
    
    private func wrapIfNeeded(_ inner: ExprNode, for outer: ExprNode) -> String {
        switch inner {
        case .add where !(outer == inner): return "\\left(\(inner.latex)\\right)"
        case .negate: return "\\left(\(inner.latex)\\right)"
        default: return inner.latex
        }
    }
    
    private func renderMultiply(_ factors: [ExprNode]) -> String {
        if factors.isEmpty { return "1" }
        if factors.count == 1 { return factors[0].latex }
        
        // Separate numerator and denominator
        var num: [ExprNode] = []
        var den: [ExprNode] = []
        for f in factors {
            if case .power(let base, let exp) = f {
                if case .number(let v) = exp, v < 0 {
                    den.append(v == -1 ? base : .power(base, .number(-v)))
                    continue
                }
                if case .negate(let inner) = exp {
                    den.append(.power(base, inner))
                    continue
                }
            }
            num.append(f)
        }
        
        if !den.isEmpty {
            let numStr = num.isEmpty ? "1" : num.map { wrapIfNeeded($0, for: .multiply(factors)) }.joined(separator: " \\cdot ")
            let denStr = den.map { wrapIfNeeded($0, for: .multiply(factors)) }.joined(separator: " \\cdot ")
            return "\\frac{\(numStr)}{\(denStr)}"
        }
        
        // Coefficient * rest: 2x instead of 2·x
        var parts: [String] = []
        for f in factors {
            parts.append(wrapIfNeeded(f, for: .multiply(factors)))
        }
        return parts.joined(separator: " \\cdot ")
    }
    
    private func renderFunction(_ fn: MathFunc, args: [ExprNode]) -> String {
        let argStr = args.map(\.latex).joined(separator: ",\\, ")
        switch fn {
        case .sin: return "\\sin\\left(\(argStr)\\right)"
        case .cos: return "\\cos\\left(\(argStr)\\right)"
        case .tan: return "\\tan\\left(\(argStr)\\right)"
        case .csc: return "\\csc\\left(\(argStr)\\right)"
        case .sec: return "\\sec\\left(\(argStr)\\right)"
        case .cot: return "\\cot\\left(\(argStr)\\right)"
        case .asin: return "\\arcsin\\left(\(argStr)\\right)"
        case .acos: return "\\arccos\\left(\(argStr)\\right)"
        case .atan: return "\\arctan\\left(\(argStr)\\right)"
        case .acsc: return "\\operatorname{arccsc}\\left(\(argStr)\\right)"
        case .asec: return "\\operatorname{arcsec}\\left(\(argStr)\\right)"
        case .acot: return "\\operatorname{arccot}\\left(\(argStr)\\right)"
        case .sinh: return "\\sinh\\left(\(argStr)\\right)"
        case .cosh: return "\\cosh\\left(\(argStr)\\right)"
        case .tanh: return "\\tanh\\left(\(argStr)\\right)"
        case .csch: return "\\operatorname{csch}\\left(\(argStr)\\right)"
        case .sech: return "\\operatorname{sech}\\left(\(argStr)\\right)"
        case .coth: return "\\coth\\left(\(argStr)\\right)"
        case .asinh: return "\\operatorname{arcsinh}\\left(\(argStr)\\right)"
        case .acosh: return "\\operatorname{arccosh}\\left(\(argStr)\\right)"
        case .atanh: return "\\operatorname{arctanh}\\left(\(argStr)\\right)"
        case .acsch: return "\\operatorname{arccsch}\\left(\(argStr)\\right)"
        case .asech: return "\\operatorname{arcsech}\\left(\(argStr)\\right)"
        case .acoth: return "\\operatorname{arccoth}\\left(\(argStr)\\right)"
        case .exp: return "e^{\(argStr)}"
        case .ln: return "\\ln\\left(\(argStr)\\right)"
        case .log: return "\\log\\left(\(argStr)\\right)"
        case .log2: return "\\log_2\\left(\(argStr)\\right)"
        case .log10: return "\\log_{10}\\left(\(argStr)\\right)"
        case .sqrt: return "\\sqrt{\(argStr)}"
        case .cbrt: return "\\sqrt[3]{\(argStr)}"
        case .abs: return "\\left|\(argStr)\\right|"
        case .floor: return "\\lfloor \(argStr) \\rfloor"
        case .ceil: return "\\lceil \(argStr) \\rceil"
        case .gamma: return "\\Gamma\\left(\(argStr)\\right)"
        case .beta:
            guard args.count >= 2 else { return "\\operatorname{B}\\left(\(argStr)\\right)" }
            return "\\operatorname{B}\\left(\(args[0].latex),\\, \(args[1].latex)\\right)"
        case .erf: return "\\operatorname{erf}\\left(\(argStr)\\right)"
        case .erfc: return "\\operatorname{erfc}\\left(\(argStr)\\right)"
        case .factorial: return "\(wrapIfNeeded(args[0], for: self))!"
        case .binomial:
            guard args.count >= 2 else { return "\\binom{?}{?}" }
            return "\\binom{\(args[0].latex)}{\(args[1].latex)}"
        case .besselJ:
            guard args.count >= 2 else { return "J\\left(\(argStr)\\right)" }
            return "J_{\(args[0].latex)}\\left(\(args[1].latex)\\right)"
        case .besselY:
            guard args.count >= 2 else { return "Y\\left(\(argStr)\\right)" }
            return "Y_{\(args[0].latex)}\\left(\(args[1].latex)\\right)"
        case .lambertW: return "W\\left(\(argStr)\\right)"
        case .zeta: return "\\zeta\\left(\(argStr)\\right)"
        case .logBase:
            guard args.count >= 2 else { return "\\log\\left(\(argStr)\\right)" }
            return "\\log_{\(args[1].latex)}\\left(\(args[0].latex)\\right)"
        case .nthRoot:
            guard args.count >= 2 else { return "\\sqrt{\(argStr)}" }
            return "\\sqrt[\(args[1].latex)]{\(args[0].latex)}"
        default:
            return "\\operatorname{\(fn.rawValue)}\\left(\(argStr)\\right)"
        }
    }
    
    /// Pretty-print for plain text display.
    var pretty: String {
        switch self {
        case .number(let v):
            if v == Double(Int(v)) && Swift.abs(v) < 1e15 { return "\(Int(v))" }
            return String(format: "%.6g", v)
        case .rational(let p, let q):
            return q == 1 ? "\(p)" : "\(p)/\(q)"
        case .variable(let v): return v
        case .constant(let c): return c.rawValue
        case .negate(let a): return "-(\(a.pretty))"
        case .add(let terms):
            return terms.enumerated().map { i, t in
                if i == 0 { return t.pretty }
                if case .negate(let inner) = t { return " - \(inner.pretty)" }
                return " + \(t.pretty)"
            }.joined()
        case .multiply(let factors):
            return factors.map(\.pretty).joined(separator: "·")
        case .power(let b, let e):
            if e == .half { return "√(\(b.pretty))" }
            return "\(b.pretty)^\(e.pretty)"
        case .function(let fn, let args):
            return "\(fn.rawValue)(\(args.map(\.pretty).joined(separator: ", ")))"
        case .equation(let l, let r): return "\(l.pretty) = \(r.pretty)"
        case .undefined(let msg): return "undefined: \(msg)"
        default: return latex
        }
    }
}

// MARK: - CustomStringConvertible

extension ExprNode: CustomStringConvertible {
    var description: String { pretty }
}
