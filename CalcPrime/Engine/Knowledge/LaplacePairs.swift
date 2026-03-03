// LaplacePairs.swift
// CalcPrime — Engine/Knowledge
// Lookup database of Laplace transform pairs for symbolic computation.
// L{f(t)} = F(s), with both forward and inverse tables.

import Foundation

// MARK: - LaplacePairs

struct LaplacePair {
    let name: String
    let timeDomain: String        // Description / pattern name
    let matchForward: (ExprNode, String) -> Bool    // Match f(t)
    let forward: (ExprNode, String, String) -> ExprNode // f(t) → F(s)
    let matchInverse: (ExprNode, String) -> Bool    // Match F(s)
    let inverse: (ExprNode, String, String) -> ExprNode // F(s) → f(t)
}

struct LaplacePairs {
    
    // MARK: - Quick Lookup
    
    /// Try forward transform: L{f(t)} → F(s)
    static func lookupForward(_ expr: ExprNode, timeVar t: String, freqVar s: String) -> ExprNode? {
        for pair in pairs {
            if pair.matchForward(expr, t) {
                return pair.forward(expr, t, s)
            }
        }
        return nil
    }
    
    /// Try inverse transform: L⁻¹{F(s)} → f(t)
    static func lookupInverse(_ expr: ExprNode, freqVar s: String, timeVar t: String) -> ExprNode? {
        for pair in pairs {
            if pair.matchInverse(expr, s) {
                return pair.inverse(expr, s, t)
            }
        }
        return nil
    }
    
    // MARK: - Pair Database
    
    static let pairs: [LaplacePair] = {
        var table: [LaplacePair] = []
        
        // ─── 1. L{1} = 1/s ───
        table.append(LaplacePair(
            name: "Constant 1",
            timeDomain: "1",
            matchForward: { e, t in e.isOne || (e.numericValue == 1) },
            forward: { _, _, s in .power(.variable(s), .negOne) },
            matchInverse: { e, s in
                if case .power(let b, let n) = e, case .variable(let v) = b, v == s, n.numericValue == -1 { return true }
                return false
            },
            inverse: { _, _, _ in .one }
        ))
        
        // ─── 2. L{t} = 1/s² ───
        table.append(LaplacePair(
            name: "t",
            timeDomain: "t",
            matchForward: { e, t in if case .variable(let v) = e, v == t { return true }; return false },
            forward: { _, _, s in .power(.variable(s), .number(-2)) },
            matchInverse: { e, s in
                if case .power(let b, let n) = e, case .variable(let v) = b, v == s, n.numericValue == -2 { return true }
                return false
            },
            inverse: { _, _, t in .variable(t) }
        ))
        
        // ─── 3. L{t^n} = n!/s^{n+1} ───
        table.append(LaplacePair(
            name: "t^n",
            timeDomain: "t^n",
            matchForward: { e, t in
                if case .power(let b, let n) = e, case .variable(let v) = b, v == t,
                   !n.freeVariables.contains(t), n.numericValue != nil { return true }
                return false
            },
            forward: { e, t, s in
                guard case .power(_, let n) = e, let nVal = n.numericValue else { return e }
                let nInt = Int(nVal)
                let factorial = Double((1...Swift.max(nInt, 1)).reduce(1, *))
                return .multiply([.number(factorial), .power(.variable(s), .number(-(nVal + 1)))])
            },
            matchInverse: { e, s in
                // Match n!/s^{n+1} pattern — complex, skip for inverse
                return false
            },
            inverse: { e, s, t in e }
        ))
        
        // ─── 4. L{e^{at}} = 1/(s-a) ───
        table.append(LaplacePair(
            name: "e^{at}",
            timeDomain: "e^(at)",
            matchForward: { e, t in
                guard case .function(.exp, let args) = e else { return false }
                return IntegralTable.extractLinearCoeff(args[0], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.exp, let args) = e,
                      let (a, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                return .power(.add([.variable(s), .negate(a)]), .negOne)
            },
            matchInverse: { e, s in
                if case .power(let b, let n) = e, n.numericValue == -1,
                   case .add(let terms) = b, terms.count == 2 {
                    let hasS = terms.contains { if case .variable(let v) = $0, v == s { return true }; return false }
                    let hasConst = terms.contains { !$0.freeVariables.contains(s) }
                    return hasS && hasConst
                }
                return false
            },
            inverse: { e, s, t in
                guard case .power(let b, _) = e,
                      case .add(let terms) = b else { return e }
                // Extract a from 1/(s-a)
                let constPart = terms.first { !$0.freeVariables.contains(s) }
                let a: ExprNode = constPart.map { .negate($0) } ?? .zero // -(−a) = a
                return .function(.exp, [.multiply([a, .variable(t)])])
            }
        ))
        
        // ─── 5. L{sin(ωt)} = ω/(s²+ω²) ───
        table.append(LaplacePair(
            name: "sin(ωt)",
            timeDomain: "sin(ωt)",
            matchForward: { e, t in
                guard case .function(.sin, let args) = e else { return false }
                return IntegralTable.extractLinearCoeff(args[0], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.sin, let args) = e,
                      let (omega, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                let s2 = ExprNode.power(.variable(s), .two)
                let w2 = ExprNode.power(omega, .two)
                return .multiply([omega, .power(.add([s2, w2]), .negOne)])
            },
            matchInverse: { e, s in false },
            inverse: { e, s, t in e }
        ))
        
        // ─── 6. L{cos(ωt)} = s/(s²+ω²) ───
        table.append(LaplacePair(
            name: "cos(ωt)",
            timeDomain: "cos(ωt)",
            matchForward: { e, t in
                guard case .function(.cos, let args) = e else { return false }
                return IntegralTable.extractLinearCoeff(args[0], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.cos, let args) = e,
                      let (omega, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                let s2 = ExprNode.power(.variable(s), .two)
                let w2 = ExprNode.power(omega, .two)
                return .multiply([.variable(s), .power(.add([s2, w2]), .negOne)])
            },
            matchInverse: { e, s in false },
            inverse: { e, s, t in e }
        ))
        
        // ─── 7. L{sinh(ωt)} = ω/(s²-ω²) ───
        table.append(LaplacePair(
            name: "sinh(ωt)",
            timeDomain: "sinh(ωt)",
            matchForward: { e, t in
                guard case .function(.sinh, let args) = e else { return false }
                return IntegralTable.extractLinearCoeff(args[0], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.sinh, let args) = e,
                      let (omega, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                let s2 = ExprNode.power(.variable(s), .two)
                let w2 = ExprNode.power(omega, .two)
                return .multiply([omega, .power(.add([s2, .negate(w2)]), .negOne)])
            },
            matchInverse: { e, s in false },
            inverse: { e, s, t in e }
        ))
        
        // ─── 8. L{cosh(ωt)} = s/(s²-ω²) ───
        table.append(LaplacePair(
            name: "cosh(ωt)",
            timeDomain: "cosh(ωt)",
            matchForward: { e, t in
                guard case .function(.cosh, let args) = e else { return false }
                return IntegralTable.extractLinearCoeff(args[0], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.cosh, let args) = e,
                      let (omega, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                let s2 = ExprNode.power(.variable(s), .two)
                let w2 = ExprNode.power(omega, .two)
                return .multiply([.variable(s), .power(.add([s2, .negate(w2)]), .negOne)])
            },
            matchInverse: { e, s in false },
            inverse: { e, s, t in e }
        ))
        
        // ─── 9. L{t·e^{at}} = 1/(s-a)² ───
        table.append(LaplacePair(
            name: "t·e^{at}",
            timeDomain: "t·e^(at)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasT = fs.contains { if case .variable(let v) = $0, v == t { return true }; return false }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasT && hasExp
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let expPart = fs.first {
                    if case .function(.exp, _) = $0 { return true }; return false
                }
                guard case .function(.exp, let args) = expPart,
                      let (a, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                return .power(.add([.variable(s), .negate(a)]), .number(-2))
            },
            matchInverse: { e, s in
                if case .power(let b, let n) = e, n.numericValue == -2,
                   case .add(let terms) = b, terms.count == 2 {
                    return terms.contains { if case .variable(let v) = $0, v == s { return true }; return false }
                }
                return false
            },
            inverse: { e, s, t in
                guard case .power(let b, _) = e,
                      case .add(let terms) = b else { return e }
                let constPart = terms.first { !$0.freeVariables.contains(s) }
                let a: ExprNode = constPart.map { .negate($0) } ?? .zero
                return .multiply([.variable(t), .function(.exp, [.multiply([a, .variable(t)])])])
            }
        ))
        
        // ─── 10. L{t^n · e^{at}} = n!/(s-a)^{n+1} ───
        table.append(LaplacePair(
            name: "t^n·e^{at}",
            timeDomain: "t^n·e^(at)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasTn = fs.contains {
                    if case .power(let b, let n) = $0, case .variable(let v) = b, v == t,
                       !n.freeVariables.contains(t) { return true }
                    return false
                }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasTn && hasExp
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let tnPart = fs.first {
                    if case .power(_, _) = $0 { return true }; return false
                }
                let expPart = fs.first {
                    if case .function(.exp, _) = $0 { return true }; return false
                }
                guard case .power(_, let n) = tnPart, let nVal = n.numericValue,
                      case .function(.exp, let args) = expPart,
                      let (a, _) = IntegralTable.extractLinearParts(args[0], t) else { return e }
                let nInt = Int(nVal)
                let factorial = Double((1...Swift.max(nInt, 1)).reduce(1, *))
                return .multiply([.number(factorial),
                                  .power(.add([.variable(s), .negate(a)]), .number(-(nVal + 1)))])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 11. L{e^{at}·sin(ωt)} = ω/((s-a)²+ω²) ───
        table.append(LaplacePair(
            name: "e^{at}·sin(ωt)",
            timeDomain: "e^(at)·sin(ωt)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasExp = fs.contains {
                    if case .function(.exp, _) = $0 { return true }; return false
                }
                let hasSin = fs.contains {
                    if case .function(.sin, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasExp && hasSin
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let expPart = fs.first { if case .function(.exp, _) = $0 { return true }; return false }
                let sinPart = fs.first { if case .function(.sin, _) = $0 { return true }; return false }
                guard case .function(.exp, let ea) = expPart, let (a, _) = IntegralTable.extractLinearParts(ea[0], t),
                      case .function(.sin, let sa) = sinPart, let (w, _) = IntegralTable.extractLinearParts(sa[0], t) else { return e }
                let sma = ExprNode.add([.variable(s), .negate(a)])
                return .multiply([w, .power(.add([.power(sma, .two), .power(w, .two)]), .negOne)])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 12. L{e^{at}·cos(ωt)} = (s-a)/((s-a)²+ω²) ───
        table.append(LaplacePair(
            name: "e^{at}·cos(ωt)",
            timeDomain: "e^(at)·cos(ωt)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasExp = fs.contains { if case .function(.exp, _) = $0 { return true }; return false }
                let hasCos = fs.contains {
                    if case .function(.cos, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasExp && hasCos
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let expPart = fs.first { if case .function(.exp, _) = $0 { return true }; return false }
                let cosPart = fs.first { if case .function(.cos, _) = $0 { return true }; return false }
                guard case .function(.exp, let ea) = expPart, let (a, _) = IntegralTable.extractLinearParts(ea[0], t),
                      case .function(.cos, let ca) = cosPart, let (w, _) = IntegralTable.extractLinearParts(ca[0], t) else { return e }
                let sma = ExprNode.add([.variable(s), .negate(a)])
                return .multiply([sma, .power(.add([.power(sma, .two), .power(w, .two)]), .negOne)])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 13. L{δ(t)} = 1 ───
        table.append(LaplacePair(
            name: "δ(t)",
            timeDomain: "δ(t)",
            matchForward: { e, t in
                if case .diracDelta(let arg) = e, case .variable(let v) = arg, v == t { return true }
                if case .function(.delta, let a) = e, case .variable(let v) = a.first, v == t { return true }
                return false
            },
            forward: { _, _, _ in .one },
            matchInverse: { e, _ in e.isOne },
            inverse: { _, s, t in .diracDelta(.variable(t)) }
        ))
        
        // ─── 14. L{δ(t-a)} = e^{-as} ───
        table.append(LaplacePair(
            name: "δ(t-a)",
            timeDomain: "δ(t-a)",
            matchForward: { e, t in
                if case .diracDelta(let arg) = e, case .add(let terms) = arg {
                    return terms.contains { if case .variable(let v) = $0, v == t { return true }; return false }
                }
                return false
            },
            forward: { e, t, s in
                guard case .diracDelta(let arg) = e, case .add(let terms) = arg else { return e }
                let constPart = terms.first { !$0.freeVariables.contains(t) }
                let a: ExprNode = constPart.map { .negate($0) } ?? .zero
                return .function(.exp, [.negate(.multiply([a, .variable(s)]))])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 15. L{u(t-a)} = e^{-as}/s ───
        table.append(LaplacePair(
            name: "u(t-a)",
            timeDomain: "u(t-a) (Heaviside)",
            matchForward: { e, t in
                if case .heaviside(let arg) = e, case .add(_) = arg { return true }
                if case .function(.heaviside, _) = e { return true }
                return false
            },
            forward: { e, t, s in
                let a: ExprNode
                if case .heaviside(let arg) = e, case .add(let terms) = arg {
                    a = terms.first { !$0.freeVariables.contains(t) }.map { .negate($0) } ?? .zero
                } else { a = .zero }
                return .multiply([.function(.exp, [.negate(.multiply([a, .variable(s)]))]),
                                  .power(.variable(s), .negOne)])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 16. L{t·sin(ωt)} = 2ωs/(s²+ω²)² ───
        table.append(LaplacePair(
            name: "t·sin(ωt)",
            timeDomain: "t·sin(ωt)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasT = fs.contains { if case .variable(let v) = $0, v == t { return true }; return false }
                let hasSin = fs.contains {
                    if case .function(.sin, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasT && hasSin
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let sinPart = fs.first { if case .function(.sin, _) = $0 { return true }; return false }
                guard case .function(.sin, let sa) = sinPart,
                      let (w, _) = IntegralTable.extractLinearParts(sa[0], t) else { return e }
                let s2w2 = ExprNode.add([.power(.variable(s), .two), .power(w, .two)])
                return .multiply([.two, w, .variable(s), .power(s2w2, .number(-2))])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 17. L{t·cos(ωt)} = (s²-ω²)/(s²+ω²)² ───
        table.append(LaplacePair(
            name: "t·cos(ωt)",
            timeDomain: "t·cos(ωt)",
            matchForward: { e, t in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasT = fs.contains { if case .variable(let v) = $0, v == t { return true }; return false }
                let hasCos = fs.contains {
                    if case .function(.cos, let a) = $0 { return IntegralTable.extractLinearCoeff(a[0], t) != nil }
                    return false
                }
                return hasT && hasCos
            },
            forward: { e, t, s in
                guard case .multiply(let fs) = e else { return e }
                let cosPart = fs.first { if case .function(.cos, _) = $0 { return true }; return false }
                guard case .function(.cos, let ca) = cosPart,
                      let (w, _) = IntegralTable.extractLinearParts(ca[0], t) else { return e }
                let s2 = ExprNode.power(.variable(s), .two)
                let w2 = ExprNode.power(w, .two)
                let s2w2 = ExprNode.add([s2, w2])
                return .multiply([.add([s2, .negate(w2)]), .power(s2w2, .number(-2))])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 18. L{1/√(πt)} = 1/√s ───
        table.append(LaplacePair(
            name: "1/√(πt)",
            timeDomain: "1/√(πt)",
            matchForward: { e, t in
                // Match 1/sqrt(pi*t) — complex pattern, simplified check
                return false
            },
            forward: { e, _, s in .power(.variable(s), .half) },
            matchInverse: { e, s in
                if case .power(let b, let n) = e, case .variable(let v) = b, v == s,
                   n.numericValue == -0.5 { return true }
                return false
            },
            inverse: { _, s, t in
                .multiply([.power(.multiply([.pi, .variable(t)]), .number(-0.5))])
            }
        ))
        
        // ─── 19. L{erf(√t)} = 1/(s·√(s+1)) ───
        table.append(LaplacePair(
            name: "erf(√t)",
            timeDomain: "erf(√t)",
            matchForward: { e, t in
                guard case .function(.erf, let a) = e,
                      case .function(.sqrt, let b) = a.first,
                      case .variable(let v) = b.first, v == t else { return false }
                return true
            },
            forward: { _, _, s in
                let sv = ExprNode.variable(s)
                return .multiply([.power(sv, .negOne), .power(.add([sv, .one]), .number(-0.5))])
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        // ─── 20. L{J_0(at)} = 1/√(s²+a²) ───
        table.append(LaplacePair(
            name: "J₀(at)",
            timeDomain: "J₀(at)",
            matchForward: { e, t in
                guard case .function(.besselJ, let args) = e,
                      args.count >= 2, args[0].numericValue == 0 else { return false }
                return IntegralTable.extractLinearCoeff(args[1], t) != nil
            },
            forward: { e, t, s in
                guard case .function(.besselJ, let args) = e,
                      let (a, _) = IntegralTable.extractLinearParts(args[1], t) else { return e }
                return .power(.add([.power(.variable(s), .two), .power(a, .two)]), .number(-0.5))
            },
            matchInverse: { _, _ in false },
            inverse: { e, _, _ in e }
        ))
        
        return table
    }()
}
