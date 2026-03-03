// Differentiator.swift
// CalcPrime — Engine/Solvers
// Symbolic differentiation engine.
// Implements all standard differentiation rules:
// sum, product, quotient, chain, power, exponential, logarithmic,
// trig, inverse trig, hyperbolic, inverse hyperbolic, implicit,
// special functions, piecewise, and higher-order derivatives.
//
// Ref: Calculus (Stewart), Xcas diff()

import Foundation

struct Differentiator {
    
    // MARK: - Public API
    
    /// Differentiate an expression with respect to a variable.
    static func differentiate(_ expr: ExprNode, withRespectTo v: String) -> ExprNode {
        let raw = diff(expr, v)
        return Simplifier.simplify(raw)
    }
    
    /// Differentiate with step-by-step explanations.
    static func differentiateWithSteps(_ expr: ExprNode, withRespectTo v: String) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let raw = diffSteps(expr, v, &steps)
        let simplified = Simplifier.simplify(raw)
        steps.append(SolutionStep(title: "Simplificación", math: simplified.latex))
        return (simplified, steps)
    }
    
    // MARK: - Core Differentiation
    
    private static func diff(_ expr: ExprNode, _ v: String) -> ExprNode {
        switch expr {
        // Constants → 0
        case .number, .rational, .constant:
            return .zero
            
        // Variable
        case .variable(let name):
            return name == v ? .one : .zero
            
        // Negation: d(-f)/dx = -df/dx
        case .negate(let a):
            return .negate(diff(a, v))
            
        // Sum rule: d(f+g+...)/dx = df/dx + dg/dx + ...
        case .add(let terms):
            return .add(terms.map { diff($0, v) })
            
        // Product rule (n-ary): d(f·g·h)/dx = f'gh + fg'h + fgh'
        case .multiply(let factors):
            return diffProduct(factors, v)
            
        // Power rule: d(f^g)/dx
        case .power(let base, let exp):
            return diffPower(base, exp, v)
            
        // Function: d(f(u))/dx = f'(u) · du/dx  (chain rule)
        case .function(let fn, let args):
            return diffFunction(fn, args: args, v)
            
        // Derivative: d/dx(d/dx f) = d²f/dx²
        case .derivative(let body, let dv, let n):
            if dv == v {
                return .derivative(body, v, n + 1)
            }
            return .derivative(diff(body, v), dv, n)
            
        // Integral: d/dx ∫ f(x) dx = f(x)
        case .integral(let body, let iv) where iv == v:
            return body
            
        // Definite integral: Leibniz integral rule
        case .definiteIntegral(let body, let iv, let lo, let hi):
            // d/dx ∫_{a(x)}^{b(x)} f(t) dt = f(b(x))·b'(x) - f(a(x))·a'(x) + ∫_a^b ∂f/∂x dt
            if iv != v {
                let fHi = body.substitute(iv, with: hi)
                let fLo = body.substitute(iv, with: lo)
                let dHi = diff(hi, v)
                let dLo = diff(lo, v)
                return .add([.multiply([fHi, dHi]), .negate(.multiply([fLo, dLo]))])
            }
            return diff(body, v) // simplistic fallback
            
        // Piecewise: differentiate each piece
        case .piecewise(let pairs):
            return .piecewise(pairs.map { (cond, val) in (cond, diff(val, v)) })
            
        // Complex number
        case .complexNumber(let re, let im):
            return .complexNumber(diff(re, v), diff(im, v))
            
        // Equation: differentiate both sides
        case .equation(let l, let r):
            return .equation(diff(l, v), diff(r, v))
            
        // Vector/Matrix: element-wise
        case .vector(let elems):
            return .vector(elems.map { diff($0, v) })
        case .matrix(let rows):
            return .matrix(rows.map { $0.map { diff($0, v) } })
            
        // Heaviside: d/dx u(f) = δ(f)·f'
        case .heaviside(let a):
            return .multiply([.diracDelta(a), diff(a, v)])
            
        // Dirac delta: d/dx δ(f) = δ'(f)·f' — symbolic
        case .diracDelta:
            return .undefined("Derivada de delta de Dirac")
            
        default:
            return .derivative(expr, v, 1)
        }
    }
    
    // MARK: - Product Rule (n-ary)
    
    /// d(f₁·f₂·...·fₙ)/dx = Σᵢ (f₁·...·fᵢ'·...·fₙ)
    private static func diffProduct(_ factors: [ExprNode], _ v: String) -> ExprNode {
        var terms: [ExprNode] = []
        for i in 0..<factors.count {
            var productTerms: [ExprNode] = []
            for j in 0..<factors.count {
                if j == i {
                    productTerms.append(diff(factors[j], v))
                } else {
                    productTerms.append(factors[j])
                }
            }
            terms.append(.multiply(productTerms))
        }
        return .add(terms)
    }
    
    // MARK: - Power Rule
    
    private static func diffPower(_ base: ExprNode, _ exp: ExprNode, _ v: String) -> ExprNode {
        let baseHasV = base.freeVariables.contains(v)
        let expHasV = exp.freeVariables.contains(v)
        
        if !baseHasV && !expHasV {
            // d(constant)/dx = 0
            return .zero
        }
        
        if baseHasV && !expHasV {
            // Power rule: d(f^n)/dx = n·f^(n-1)·f'
            let df = diff(base, v)
            return .multiply([exp, .power(base, .add([exp, .negOne])), df])
        }
        
        if !baseHasV && expHasV {
            // Exponential rule: d(a^g)/dx = a^g · ln(a) · g'
            let dg = diff(exp, v)
            return .multiply([.power(base, exp), .function(.ln, [base]), dg])
        }
        
        // General: d(f^g)/dx = f^g · (g'·ln(f) + g·f'/f)
        let df = diff(base, v)
        let dg = diff(exp, v)
        return .multiply([
            .power(base, exp),
            .add([
                .multiply([dg, .function(.ln, [base])]),
                .multiply([exp, df, .power(base, .negOne)])
            ])
        ])
    }
    
    // MARK: - Function Differentiation (Chain Rule)
    
    private static func diffFunction(_ fn: MathFunc, args: [ExprNode], _ v: String) -> ExprNode {
        guard let u = args.first else { return .zero }
        let du = diff(u, v) // chain rule factor
        
        // If du is zero, the whole thing is zero
        if du.isZero { return .zero }
        
        let innerDeriv: ExprNode
        
        switch fn {
        // ── Trigonometric ────────────────────────────────
        case .sin:   innerDeriv = .function(.cos, [u])
        case .cos:   innerDeriv = .negate(.function(.sin, [u]))
        case .tan:   innerDeriv = .power(.function(.cos, [u]), .number(-2))  // sec²(u)
        case .csc:   innerDeriv = .negate(.multiply([.function(.csc, [u]), .function(.cot, [u])]))
        case .sec:   innerDeriv = .multiply([.function(.sec, [u]), .function(.tan, [u])])
        case .cot:   innerDeriv = .negate(.power(.function(.sin, [u]), .number(-2)))  // -csc²(u)
            
        // ── Inverse Trigonometric ────────────────────────
        case .asin:  innerDeriv = .power(.add([.one, .negate(.power(u, .two))]), .rational(-1, 2))
        case .acos:  innerDeriv = .negate(.power(.add([.one, .negate(.power(u, .two))]), .rational(-1, 2)))
        case .atan:  innerDeriv = .power(.add([.one, .power(u, .two)]), .negOne)
        case .acsc:  innerDeriv = .negate(.multiply([.power(.function(.abs, [u]), .negOne), .power(.add([.power(u, .two), .negOne]), .rational(-1, 2))]))
        case .asec:  innerDeriv = .multiply([.power(.function(.abs, [u]), .negOne), .power(.add([.power(u, .two), .negOne]), .rational(-1, 2))])
        case .acot:  innerDeriv = .negate(.power(.add([.one, .power(u, .two)]), .negOne))
            
        // ── Hyperbolic ──────────────────────────────────
        case .sinh:  innerDeriv = .function(.cosh, [u])
        case .cosh:  innerDeriv = .function(.sinh, [u])
        case .tanh:  innerDeriv = .power(.function(.cosh, [u]), .number(-2))  // sech²(u)
        case .csch:  innerDeriv = .negate(.multiply([.function(.csch, [u]), .function(.coth, [u])]))
        case .sech:  innerDeriv = .negate(.multiply([.function(.sech, [u]), .function(.tanh, [u])]))
        case .coth:  innerDeriv = .negate(.power(.function(.sinh, [u]), .number(-2)))  // -csch²(u)
            
        // ── Inverse Hyperbolic ──────────────────────────
        case .asinh: innerDeriv = .power(.add([.power(u, .two), .one]), .rational(-1, 2))
        case .acosh: innerDeriv = .power(.add([.power(u, .two), .negOne]), .rational(-1, 2))
        case .atanh: innerDeriv = .power(.add([.one, .negate(.power(u, .two))]), .negOne)
        case .acsch: innerDeriv = .negate(.multiply([.power(.function(.abs, [u]), .negOne), .power(.add([.one, .power(u, .two)]), .rational(-1, 2))]))
        case .asech: innerDeriv = .negate(.multiply([.power(u, .negOne), .power(.add([.one, .negate(.power(u, .two))]), .rational(-1, 2))]))
        case .acoth: innerDeriv = .power(.add([.one, .negate(.power(u, .two))]), .negOne)
            
        // ── Exponential / Logarithmic ───────────────────
        case .exp:   innerDeriv = .function(.exp, [u])
        case .ln:    innerDeriv = .power(u, .negOne)
        case .log:   innerDeriv = .multiply([.power(u, .negOne), .power(.function(.ln, [.number(10)]), .negOne)])
        case .log2:  innerDeriv = .multiply([.power(u, .negOne), .power(.function(.ln, [.number(2)]), .negOne)])
        case .log10: innerDeriv = .multiply([.power(u, .negOne), .power(.function(.ln, [.number(10)]), .negOne)])
            
        // ── Roots ───────────────────────────────────────
        case .sqrt:  innerDeriv = .multiply([.rational(1, 2), .power(u, .rational(-1, 2))])
        case .cbrt:  innerDeriv = .multiply([.rational(1, 3), .power(u, .rational(-2, 3))])
            
        // ── Absolute / Sign ─────────────────────────────
        case .abs:   innerDeriv = .multiply([.function(.sign, [u])])
        case .sign:  innerDeriv = .zero
            
        // ── Special Functions ───────────────────────────
        case .erf:   innerDeriv = .multiply([.rational(2, 1), .power(.constant(.pi), .rational(-1, 2)), .function(.exp, [.negate(.power(u, .two))])])
        case .erfc:  innerDeriv = .negate(.multiply([.rational(2, 1), .power(.constant(.pi), .rational(-1, 2)), .function(.exp, [.negate(.power(u, .two))])]))
        case .gamma: innerDeriv = .multiply([.function(.gamma, [u]), .function(.digamma, [u])])
        case .factorial:
            // n! = Γ(n+1), so d/dx = Γ(x+1)·ψ(x+1)
            innerDeriv = .multiply([.function(.gamma, [.add([u, .one])]), .function(.digamma, [.add([u, .one])])])
            
        case .lambertW:
            // W'(x) = W(x) / (x(1+W(x)))
            innerDeriv = .multiply([
                .function(.lambertW, [u]),
                .power(.multiply([u, .add([.one, .function(.lambertW, [u])])]), .negOne)
            ])
            
        default:
            // Fallback: symbolic derivative notation
            return .derivative(.function(fn, args), v, 1)
        }
        
        // Apply chain rule: f'(u) · u'
        return .multiply([innerDeriv, du])
    }
    
    // MARK: - Step-by-Step Differentiation
    
    private static func diffSteps(_ expr: ExprNode, _ v: String, _ steps: inout [SolutionStep]) -> ExprNode {
        switch expr {
        case .number, .rational, .constant:
            steps.append(SolutionStep(title: "Derivada de constante", explanation: "La derivada de una constante es 0", math: "\\frac{d}{d\(v)}\\left(\(expr.latex)\\right) = 0"))
            return .zero
            
        case .variable(let name):
            if name == v {
                steps.append(SolutionStep(title: "Derivada de \(v)", explanation: "La derivada de \(v) respecto a \(v) es 1", math: "\\frac{d\(v)}{d\(v)} = 1"))
                return .one
            } else {
                steps.append(SolutionStep(title: "Derivada de constante", explanation: "\(name) es constante respecto a \(v)", math: "\\frac{d}{d\(v)}(\(name)) = 0"))
                return .zero
            }
            
        case .add(let terms):
            steps.append(SolutionStep(title: "Regla de la suma", explanation: "La derivada de una suma es la suma de las derivadas", math: "\\frac{d}{d\(v)}\\left(\(expr.latex)\\right)"))
            return .add(terms.map { diffSteps($0, v, &steps) })
            
        case .multiply(let factors) where factors.count == 2:
            let f = factors[0], g = factors[1]
            steps.append(SolutionStep(title: "Regla del producto", explanation: "(f·g)' = f'·g + f·g'", math: "\\frac{d}{d\(v)}\\left(\(f.latex) \\cdot \(g.latex)\\right)"))
            let df = diffSteps(f, v, &steps)
            let dg = diffSteps(g, v, &steps)
            return .add([.multiply([df, g]), .multiply([f, dg])])
            
        case .power(let base, let exp) where !exp.freeVariables.contains(v):
            steps.append(SolutionStep(title: "Regla de la potencia", explanation: "d/dx[u^n] = n·u^{n-1}·u'", math: "\\frac{d}{d\(v)}\\left(\(base.latex)^{\(exp.latex)}\\right)"))
            let du = diffSteps(base, v, &steps)
            return .multiply([exp, .power(base, .add([exp, .negOne])), du])
            
        case .function(let fn, let args) where !args.isEmpty:
            steps.append(SolutionStep(title: "Regla de la cadena", explanation: "[f(u)]' = f'(u)·u'", math: "\\frac{d}{d\(v)}\\left(\(expr.latex)\\right)"))
            return diffFunction(fn, args: args, v)
            
        default:
            return diff(expr, v)
        }
    }
}
