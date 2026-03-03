// TrigIdentities.swift
// CalcPrime — Engine/Knowledge
// Database of trigonometric and hyperbolic identities for simplification.
// Used by Simplifier for pattern matching and expression rewriting.

import Foundation

// MARK: - TrigIdentity

struct TrigIdentity {
    let name: String
    let category: IdentityCategory
    let match: (ExprNode) -> Bool
    let apply: (ExprNode) -> ExprNode
    let latex: String
}

enum IdentityCategory: String, CaseIterable {
    case pythagorean    = "Pitagóricas"
    case doubleAngle    = "Ángulo doble"
    case halfAngle      = "Ángulo medio"
    case sumDiff        = "Suma y diferencia"
    case productToSum   = "Producto a suma"
    case sumToProduct   = "Suma a producto"
    case powerReduction = "Reducción de potencia"
    case cofunction     = "Cofunción"
    case hyperbolic     = "Hiperbólicas"
    case euler          = "Euler"
    case other          = "Otras"
}

// MARK: - TrigIdentities

struct TrigIdentities {
    
    // ───────────────────────────────────────────
    // MARK: - Quick Apply
    // ───────────────────────────────────────────
    
    /// Try all identities and return first match, or nil.
    static func simplify(_ expr: ExprNode) -> ExprNode? {
        for identity in allIdentities {
            if identity.match(expr) {
                return identity.apply(expr)
            }
        }
        return nil
    }
    
    /// Get all applicable identities for an expression.
    static func applicableIdentities(for expr: ExprNode) -> [TrigIdentity] {
        allIdentities.filter { $0.match(expr) }
    }
    
    /// Get identities by category.
    static func identities(in category: IdentityCategory) -> [TrigIdentity] {
        allIdentities.filter { $0.category == category }
    }
    
    // ───────────────────────────────────────────
    // MARK: - Identity Database
    // ───────────────────────────────────────────
    
    static let allIdentities: [TrigIdentity] = {
        var ids: [TrigIdentity] = []
        ids.append(contentsOf: pythagoreanIdentities)
        ids.append(contentsOf: doubleAngleIdentities)
        ids.append(contentsOf: powerReductionIdentities)
        ids.append(contentsOf: sumDiffIdentities)
        ids.append(contentsOf: hyperbolicIdentities)
        ids.append(contentsOf: miscIdentities)
        return ids
    }()
    
    // ═══════════════════════════════════════════════
    // MARK: - Pythagorean Identities
    // ═══════════════════════════════════════════════
    
    private static var pythagoreanIdentities: [TrigIdentity] {
        [
            // sin²(θ) + cos²(θ) = 1
            TrigIdentity(
                name: "sin²+cos²=1",
                category: .pythagorean,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    return matchSin2PlusCos2(terms)
                },
                apply: { _ in .one },
                latex: "\\sin^2(\\theta) + \\cos^2(\\theta) = 1"
            ),
            
            // 1 - sin²(θ) = cos²(θ)
            TrigIdentity(
                name: "1-sin²=cos²",
                category: .pythagorean,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    guard terms.contains(where: { $0.isOne }) else { return false }
                    return terms.contains { isNegSin2($0) }
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let sinTerm = terms.first { isNegSin2($0) }
                    let arg = extractTrigArg(sinTerm ?? e) ?? .variable("θ")
                    return .power(.function(.cos, [arg]), .two)
                },
                latex: "1 - \\sin^2(\\theta) = \\cos^2(\\theta)"
            ),
            
            // 1 - cos²(θ) = sin²(θ)
            TrigIdentity(
                name: "1-cos²=sin²",
                category: .pythagorean,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    guard terms.contains(where: { $0.isOne }) else { return false }
                    return terms.contains { isNegCos2($0) }
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let cosTerm = terms.first { isNegCos2($0) }
                    let arg = extractTrigArg(cosTerm ?? e) ?? .variable("θ")
                    return .power(.function(.sin, [arg]), .two)
                },
                latex: "1 - \\cos^2(\\theta) = \\sin^2(\\theta)"
            ),
            
            // tan²(θ) + 1 = sec²(θ)
            TrigIdentity(
                name: "tan²+1=sec²",
                category: .pythagorean,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    let hasOne = terms.contains { $0.isOne }
                    let hasTan2 = terms.contains { isTan2($0) }
                    return hasOne && hasTan2
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let tanTerm = terms.first { isTan2($0) }
                    let arg = extractTrigArg(tanTerm ?? e) ?? .variable("θ")
                    return .power(.function(.sec, [arg]), .two)
                },
                latex: "\\tan^2(\\theta) + 1 = \\sec^2(\\theta)"
            ),
            
            // cot²(θ) + 1 = csc²(θ)
            TrigIdentity(
                name: "cot²+1=csc²",
                category: .pythagorean,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    let hasOne = terms.contains { $0.isOne }
                    let hasCot2 = terms.contains { isCot2($0) }
                    return hasOne && hasCot2
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let cotTerm = terms.first { isCot2($0) }
                    let arg = extractTrigArg(cotTerm ?? e) ?? .variable("θ")
                    return .power(.function(.csc, [arg]), .two)
                },
                latex: "\\cot^2(\\theta) + 1 = \\csc^2(\\theta)"
            ),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Double Angle Identities
    // ═══════════════════════════════════════════════
    
    private static var doubleAngleIdentities: [TrigIdentity] {
        [
            // 2·sin(θ)·cos(θ) = sin(2θ)
            TrigIdentity(
                name: "2sin·cos=sin(2θ)",
                category: .doubleAngle,
                match: { e in
                    guard case .multiply(let fs) = e else { return false }
                    let has2 = fs.contains { $0.numericValue == 2 }
                    let hasSin = fs.contains { isSinOf($0) }
                    let hasCos = fs.contains { isCosOf($0) }
                    guard has2 && hasSin && hasCos else { return false }
                    let sinArg = fs.compactMap { extractSinArg($0) }.first
                    let cosArg = fs.compactMap { extractCosArg($0) }.first
                    return sinArg != nil && cosArg != nil && sameStructure(sinArg!, cosArg!)
                },
                apply: { e in
                    guard case .multiply(let fs) = e else { return e }
                    let arg = fs.compactMap { extractSinArg($0) }.first ?? .variable("θ")
                    return .function(.sin, [.multiply([.two, arg])])
                },
                latex: "2\\sin(\\theta)\\cos(\\theta) = \\sin(2\\theta)"
            ),
            
            // cos²(θ) - sin²(θ) = cos(2θ)
            TrigIdentity(
                name: "cos²-sin²=cos(2θ)",
                category: .doubleAngle,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    let hasCos2 = terms.contains { isCos2($0) }
                    let hasNegSin2 = terms.contains { isNegSin2($0) }
                    if hasCos2 && hasNegSin2 {
                        let cosArg = terms.compactMap { extractCos2Arg($0) }.first
                        let sinArg = terms.compactMap { extractNegSin2Arg($0) }.first
                        return cosArg != nil && sinArg != nil && sameStructure(cosArg!, sinArg!)
                    }
                    return false
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let arg = terms.compactMap { extractCos2Arg($0) }.first ?? .variable("θ")
                    return .function(.cos, [.multiply([.two, arg])])
                },
                latex: "\\cos^2(\\theta) - \\sin^2(\\theta) = \\cos(2\\theta)"
            ),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Power Reduction Identities
    // ═══════════════════════════════════════════════
    
    private static var powerReductionIdentities: [TrigIdentity] {
        [
            // sin²(θ) = (1 - cos(2θ))/2
            TrigIdentity(
                name: "sin²→(1-cos2θ)/2",
                category: .powerReduction,
                match: { e in isSin2(e) },
                apply: { e in
                    let arg = extractTrigArg(e) ?? .variable("θ")
                    return .multiply([.half, .add([.one, .negate(.function(.cos, [.multiply([.two, arg])]))])])
                },
                latex: "\\sin^2(\\theta) = \\frac{1 - \\cos(2\\theta)}{2}"
            ),
            
            // cos²(θ) = (1 + cos(2θ))/2
            TrigIdentity(
                name: "cos²→(1+cos2θ)/2",
                category: .powerReduction,
                match: { e in isCos2(e) },
                apply: { e in
                    let arg = extractTrigArg(e) ?? .variable("θ")
                    return .multiply([.half, .add([.one, .function(.cos, [.multiply([.two, arg])])])])
                },
                latex: "\\cos^2(\\theta) = \\frac{1 + \\cos(2\\theta)}{2}"
            ),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Sum and Difference Identities
    // ═══════════════════════════════════════════════
    
    private static var sumDiffIdentities: [TrigIdentity] {
        [
            // sin(a)cos(b)+cos(a)sin(b) = sin(a+b)
            // These are complex pattern matches; provide reference only
            TrigIdentity(
                name: "sin(a+b) expansion",
                category: .sumDiff,
                match: { _ in false }, // Complex pattern, handled by Simplifier heuristics
                apply: { e in e },
                latex: "\\sin(a+b) = \\sin a \\cos b + \\cos a \\sin b"
            ),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Hyperbolic Identities
    // ═══════════════════════════════════════════════
    
    private static var hyperbolicIdentities: [TrigIdentity] {
        [
            // cosh²(θ) - sinh²(θ) = 1
            TrigIdentity(
                name: "cosh²-sinh²=1",
                category: .hyperbolic,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    let hasCosh2 = terms.contains { isCosh2($0) }
                    let hasNegSinh2 = terms.contains { isNegSinh2($0) }
                    return hasCosh2 && hasNegSinh2
                },
                apply: { _ in .one },
                latex: "\\cosh^2(\\theta) - \\sinh^2(\\theta) = 1"
            ),
            
            // 1 - tanh²(θ) = sech²(θ)
            TrigIdentity(
                name: "1-tanh²=sech²",
                category: .hyperbolic,
                match: { e in
                    guard case .add(let terms) = e, terms.count == 2 else { return false }
                    let hasOne = terms.contains { $0.isOne }
                    let hasNegTanh2 = terms.contains { isNegTanh2($0) }
                    return hasOne && hasNegTanh2
                },
                apply: { e in
                    guard case .add(let terms) = e else { return e }
                    let tanhTerm = terms.first { isNegTanh2($0) }
                    let arg = extractTrigArg(tanhTerm ?? e) ?? .variable("θ")
                    return .power(.function(.sech, [arg]), .two)
                },
                latex: "1 - \\tanh^2(\\theta) = \\text{sech}^2(\\theta)"
            ),
            
            // sinh(2θ) = 2sinh(θ)cosh(θ)
            TrigIdentity(
                name: "2sinh·cosh=sinh(2θ)",
                category: .hyperbolic,
                match: { e in
                    guard case .multiply(let fs) = e else { return false }
                    let has2 = fs.contains { $0.numericValue == 2 }
                    let hasSinh = fs.contains { if case .function(.sinh, _) = $0 { return true }; return false }
                    let hasCosh = fs.contains { if case .function(.cosh, _) = $0 { return true }; return false }
                    return has2 && hasSinh && hasCosh
                },
                apply: { e in
                    guard case .multiply(let fs) = e else { return e }
                    let arg = fs.compactMap { (node: ExprNode) -> ExprNode? in
                        if case .function(.sinh, let a) = node { return a.first }
                        return nil
                    }.first ?? .variable("θ")
                    return .function(.sinh, [.multiply([.two, arg])])
                },
                latex: "2\\sinh(\\theta)\\cosh(\\theta) = \\sinh(2\\theta)"
            ),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Miscellaneous
    // ═══════════════════════════════════════════════
    
    private static var miscIdentities: [TrigIdentity] {
        [
            // sin(-θ) = -sin(θ) (odd function)
            TrigIdentity(
                name: "sin(-θ)=-sin(θ)",
                category: .other,
                match: { e in
                    guard case .function(.sin, let a) = e,
                          case .negate(_) = a.first else { return false }
                    return true
                },
                apply: { e in
                    guard case .function(.sin, let a) = e,
                          case .negate(let inner) = a.first else { return e }
                    return .negate(.function(.sin, [inner]))
                },
                latex: "\\sin(-\\theta) = -\\sin(\\theta)"
            ),
            
            // cos(-θ) = cos(θ) (even function)
            TrigIdentity(
                name: "cos(-θ)=cos(θ)",
                category: .other,
                match: { e in
                    guard case .function(.cos, let a) = e,
                          case .negate(_) = a.first else { return false }
                    return true
                },
                apply: { e in
                    guard case .function(.cos, let a) = e,
                          case .negate(let inner) = a.first else { return e }
                    return .function(.cos, [inner])
                },
                latex: "\\cos(-\\theta) = \\cos(\\theta)"
            ),
            
            // tan(-θ) = -tan(θ)
            TrigIdentity(
                name: "tan(-θ)=-tan(θ)",
                category: .other,
                match: { e in
                    guard case .function(.tan, let a) = e,
                          case .negate(_) = a.first else { return false }
                    return true
                },
                apply: { e in
                    guard case .function(.tan, let a) = e,
                          case .negate(let inner) = a.first else { return e }
                    return .negate(.function(.tan, [inner]))
                },
                latex: "\\tan(-\\theta) = -\\tan(\\theta)"
            ),
        ]
    }
    
    // ───────────────────────────────────────────
    // MARK: - Pattern Helpers
    // ───────────────────────────────────────────
    
    private static func isSinOf(_ e: ExprNode) -> Bool {
        if case .function(.sin, _) = e { return true }
        return false
    }
    
    private static func isCosOf(_ e: ExprNode) -> Bool {
        if case .function(.cos, _) = e { return true }
        return false
    }
    
    private static func extractSinArg(_ e: ExprNode) -> ExprNode? {
        if case .function(.sin, let a) = e { return a.first }
        return nil
    }
    
    private static func extractCosArg(_ e: ExprNode) -> ExprNode? {
        if case .function(.cos, let a) = e { return a.first }
        return nil
    }
    
    private static func isSin2(_ e: ExprNode) -> Bool {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.sin, _) = b { return true }
        return false
    }
    
    private static func isCos2(_ e: ExprNode) -> Bool {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.cos, _) = b { return true }
        return false
    }
    
    private static func isTan2(_ e: ExprNode) -> Bool {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.tan, _) = b { return true }
        return false
    }
    
    private static func isCot2(_ e: ExprNode) -> Bool {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.cot, _) = b { return true }
        return false
    }
    
    private static func isCosh2(_ e: ExprNode) -> Bool {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.cosh, _) = b { return true }
        return false
    }
    
    private static func isNegSin2(_ e: ExprNode) -> Bool {
        if case .negate(let inner) = e { return isSin2(inner) }
        return false
    }
    
    private static func isNegCos2(_ e: ExprNode) -> Bool {
        if case .negate(let inner) = e { return isCos2(inner) }
        return false
    }
    
    private static func isNegSinh2(_ e: ExprNode) -> Bool {
        if case .negate(let inner) = e {
            if case .power(let b, let n) = inner, n.numericValue == 2, case .function(.sinh, _) = b { return true }
        }
        return false
    }
    
    private static func isNegTanh2(_ e: ExprNode) -> Bool {
        if case .negate(let inner) = e {
            if case .power(let b, let n) = inner, n.numericValue == 2, case .function(.tanh, _) = b { return true }
        }
        return false
    }
    
    private static func extractCos2Arg(_ e: ExprNode) -> ExprNode? {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.cos, let a) = b { return a.first }
        return nil
    }
    
    private static func extractNegSin2Arg(_ e: ExprNode) -> ExprNode? {
        if case .negate(let inner) = e { return extractSin2Arg(inner) }
        return nil
    }
    
    private static func extractSin2Arg(_ e: ExprNode) -> ExprNode? {
        if case .power(let b, let n) = e, n.numericValue == 2, case .function(.sin, let a) = b { return a.first }
        return nil
    }
    
    private static func extractTrigArg(_ e: ExprNode) -> ExprNode? {
        if case .power(let b, _) = e {
            if case .function(_, let a) = b { return a.first }
        }
        if case .negate(let inner) = e { return extractTrigArg(inner) }
        if case .function(_, let a) = e { return a.first }
        return nil
    }
    
    private static func matchSin2PlusCos2(_ terms: [ExprNode]) -> Bool {
        let hasSin2 = terms.contains { isSin2($0) }
        let hasCos2 = terms.contains { isCos2($0) }
        if hasSin2 && hasCos2 {
            let sinArg = terms.compactMap { extractSin2Arg($0) }.first
            let cosArg = terms.compactMap { extractCos2Arg($0) }.first
            return sinArg != nil && cosArg != nil && sameStructure(sinArg!, cosArg!)
        }
        return false
    }
    
    /// Rough structural equality check.
    private static func sameStructure(_ a: ExprNode, _ b: ExprNode) -> Bool {
        // Use pretty-print comparison as a simple structural check
        return a.pretty == b.pretty
    }
    
    // ───────────────────────────────────────────
    // MARK: - Reference Tables (for UI display)
    // ───────────────────────────────────────────
    
    struct IdentityReference {
        let name: String
        let latex: String
        let category: IdentityCategory
    }
    
    /// Full reference table of all trig identities (for display in the app).
    static let referenceTable: [IdentityReference] = [
        // Pythagorean
        IdentityReference(name: "sin²+cos²=1", latex: "\\sin^2\\theta + \\cos^2\\theta = 1", category: .pythagorean),
        IdentityReference(name: "1+tan²=sec²", latex: "1 + \\tan^2\\theta = \\sec^2\\theta", category: .pythagorean),
        IdentityReference(name: "1+cot²=csc²", latex: "1 + \\cot^2\\theta = \\csc^2\\theta", category: .pythagorean),
        // Double angle
        IdentityReference(name: "sin(2θ)", latex: "\\sin 2\\theta = 2\\sin\\theta\\cos\\theta", category: .doubleAngle),
        IdentityReference(name: "cos(2θ)", latex: "\\cos 2\\theta = \\cos^2\\theta - \\sin^2\\theta", category: .doubleAngle),
        IdentityReference(name: "cos(2θ) v2", latex: "\\cos 2\\theta = 2\\cos^2\\theta - 1", category: .doubleAngle),
        IdentityReference(name: "cos(2θ) v3", latex: "\\cos 2\\theta = 1 - 2\\sin^2\\theta", category: .doubleAngle),
        IdentityReference(name: "tan(2θ)", latex: "\\tan 2\\theta = \\frac{2\\tan\\theta}{1-\\tan^2\\theta}", category: .doubleAngle),
        // Half angle
        IdentityReference(name: "sin(θ/2)", latex: "\\sin\\frac{\\theta}{2} = \\pm\\sqrt{\\frac{1-\\cos\\theta}{2}}", category: .halfAngle),
        IdentityReference(name: "cos(θ/2)", latex: "\\cos\\frac{\\theta}{2} = \\pm\\sqrt{\\frac{1+\\cos\\theta}{2}}", category: .halfAngle),
        IdentityReference(name: "tan(θ/2)", latex: "\\tan\\frac{\\theta}{2} = \\frac{1-\\cos\\theta}{\\sin\\theta}", category: .halfAngle),
        // Sum/Difference
        IdentityReference(name: "sin(a+b)", latex: "\\sin(a+b) = \\sin a\\cos b + \\cos a\\sin b", category: .sumDiff),
        IdentityReference(name: "sin(a-b)", latex: "\\sin(a-b) = \\sin a\\cos b - \\cos a\\sin b", category: .sumDiff),
        IdentityReference(name: "cos(a+b)", latex: "\\cos(a+b) = \\cos a\\cos b - \\sin a\\sin b", category: .sumDiff),
        IdentityReference(name: "cos(a-b)", latex: "\\cos(a-b) = \\cos a\\cos b + \\sin a\\sin b", category: .sumDiff),
        IdentityReference(name: "tan(a+b)", latex: "\\tan(a+b) = \\frac{\\tan a + \\tan b}{1 - \\tan a\\tan b}", category: .sumDiff),
        // Product to sum
        IdentityReference(name: "sin·sin", latex: "\\sin a \\sin b = \\frac{1}{2}[\\cos(a-b) - \\cos(a+b)]", category: .productToSum),
        IdentityReference(name: "cos·cos", latex: "\\cos a \\cos b = \\frac{1}{2}[\\cos(a-b) + \\cos(a+b)]", category: .productToSum),
        IdentityReference(name: "sin·cos", latex: "\\sin a \\cos b = \\frac{1}{2}[\\sin(a+b) + \\sin(a-b)]", category: .productToSum),
        // Sum to product
        IdentityReference(name: "sin+sin", latex: "\\sin a + \\sin b = 2\\sin\\frac{a+b}{2}\\cos\\frac{a-b}{2}", category: .sumToProduct),
        IdentityReference(name: "sin-sin", latex: "\\sin a - \\sin b = 2\\cos\\frac{a+b}{2}\\sin\\frac{a-b}{2}", category: .sumToProduct),
        IdentityReference(name: "cos+cos", latex: "\\cos a + \\cos b = 2\\cos\\frac{a+b}{2}\\cos\\frac{a-b}{2}", category: .sumToProduct),
        IdentityReference(name: "cos-cos", latex: "\\cos a - \\cos b = -2\\sin\\frac{a+b}{2}\\sin\\frac{a-b}{2}", category: .sumToProduct),
        // Power reduction
        IdentityReference(name: "sin²", latex: "\\sin^2\\theta = \\frac{1-\\cos 2\\theta}{2}", category: .powerReduction),
        IdentityReference(name: "cos²", latex: "\\cos^2\\theta = \\frac{1+\\cos 2\\theta}{2}", category: .powerReduction),
        IdentityReference(name: "sin³", latex: "\\sin^3\\theta = \\frac{3\\sin\\theta - \\sin 3\\theta}{4}", category: .powerReduction),
        IdentityReference(name: "cos³", latex: "\\cos^3\\theta = \\frac{3\\cos\\theta + \\cos 3\\theta}{4}", category: .powerReduction),
        // Hyperbolic
        IdentityReference(name: "cosh²-sinh²=1", latex: "\\cosh^2 x - \\sinh^2 x = 1", category: .hyperbolic),
        IdentityReference(name: "1-tanh²=sech²", latex: "1 - \\tanh^2 x = \\text{sech}^2 x", category: .hyperbolic),
        IdentityReference(name: "coth²-1=csch²", latex: "\\coth^2 x - 1 = \\text{csch}^2 x", category: .hyperbolic),
        IdentityReference(name: "sinh(2x)", latex: "\\sinh 2x = 2\\sinh x \\cosh x", category: .hyperbolic),
        IdentityReference(name: "cosh(2x)", latex: "\\cosh 2x = \\cosh^2 x + \\sinh^2 x", category: .hyperbolic),
        // Euler
        IdentityReference(name: "Euler", latex: "e^{i\\theta} = \\cos\\theta + i\\sin\\theta", category: .euler),
        IdentityReference(name: "sin→exp", latex: "\\sin\\theta = \\frac{e^{i\\theta} - e^{-i\\theta}}{2i}", category: .euler),
        IdentityReference(name: "cos→exp", latex: "\\cos\\theta = \\frac{e^{i\\theta} + e^{-i\\theta}}{2}", category: .euler),
    ]
}
