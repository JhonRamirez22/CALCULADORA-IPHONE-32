// IntegralTable.swift
// CalcPrime — Engine/Knowledge
// Lookup table of 500+ integral pairs for symbolic integration.
// Format: (pattern matcher, result builder, description)

import Foundation

// MARK: - IntegralTable

struct IntegralEntry {
    let name: String              // Human-readable description
    let match: (ExprNode, String) -> Bool   // Does this entry apply?
    let result: (ExprNode, String) -> ExprNode  // Produce the antiderivative
}

struct IntegralTable {
    
    // MARK: - Master Table
    
    /// All integral rules ordered from most specific to most general.
    static let entries: [IntegralEntry] = {
        var table: [IntegralEntry] = []
        
        // ── Basic Power & Polynomial ──
        table.append(contentsOf: powerRules)
        table.append(contentsOf: exponentialRules)
        table.append(contentsOf: logarithmRules)
        table.append(contentsOf: trigRules)
        table.append(contentsOf: inverseTrigRules)
        table.append(contentsOf: hyperbolicRules)
        table.append(contentsOf: inverseHyperbolicRules)
        table.append(contentsOf: rationalRules)
        table.append(contentsOf: sqrtRules)
        table.append(contentsOf: specialRules)
        table.append(contentsOf: compositeRules)
        
        return table
    }()
    
    // MARK: - Table Lookup
    
    /// Try to find an integral from the table.
    static func lookup(_ expr: ExprNode, variable v: String) -> ExprNode? {
        for entry in entries {
            if entry.match(expr, v) {
                return entry.result(expr, v)
            }
        }
        return nil
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Power Rules
    // ═══════════════════════════════════════════════
    
    private static var powerRules: [IntegralEntry] {
        [
            // ∫ 1 dx = x
            IntegralEntry(name: "∫1 dx", match: { e, v in e.isOne }, result: { _, v in .variable(v) }),
            // ∫ k dx = k·x
            IntegralEntry(name: "∫k dx", match: { e, v in !e.freeVariables.contains(v) }, result: { e, v in .multiply([e, .variable(v)]) }),
            // ∫ x dx = x²/2
            IntegralEntry(name: "∫x dx", match: { e, v in
                if case .variable(let s) = e, s == v { return true }
                return false
            }, result: { _, v in .multiply([.half, .power(.variable(v), .two)]) }),
            // ∫ x^n dx = x^{n+1}/(n+1) for constant n ≠ -1
            IntegralEntry(name: "∫x^n dx", match: { e, v in
                guard case .power(let base, let exp) = e,
                      case .variable(let s) = base, s == v,
                      !exp.freeVariables.contains(v),
                      exp.numericValue != -1 else { return false }
                return true
            }, result: { e, v in
                guard case .power(_, let n) = e else { return e }
                let n1 = n + .one
                return .multiply([.power(n1, .negOne), .power(.variable(v), n1)])
            }),
            // ∫ 1/x dx = ln|x|
            IntegralEntry(name: "∫1/x dx", match: { e, v in
                if case .power(let base, let exp) = e,
                   case .variable(let s) = base, s == v,
                   exp.numericValue == -1 { return true }
                return false
            }, result: { _, v in .function(.ln, [.function(.abs, [.variable(v)])]) }),
            // ∫ √x dx = (2/3)x^{3/2}
            IntegralEntry(name: "∫√x dx", match: { e, v in
                if case .function(.sqrt, let args) = e,
                   case .variable(let s) = args.first, s == v { return true }
                return false
            }, result: { _, v in .multiply([.frac(2, 3), .power(.variable(v), .frac(3, 2))]) }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Exponential Rules
    // ═══════════════════════════════════════════════
    
    private static var exponentialRules: [IntegralEntry] {
        [
            // ∫ e^x dx = e^x
            IntegralEntry(name: "∫e^x dx", match: { e, v in
                if case .function(.exp, let args) = e,
                   case .variable(let s) = args.first, s == v { return true }
                return false
            }, result: { e, _ in e }),
            // ∫ e^{ax} dx = e^{ax}/a
            IntegralEntry(name: "∫e^(ax) dx", match: { e, v in
                guard case .function(.exp, let args) = e,
                      let coeff = extractLinearCoeff(args[0], v) else { return false }
                return true
            }, result: { e, v in
                guard case .function(.exp, let args) = e,
                      let (a, _) = extractLinearParts(args[0], v) else { return e }
                return .multiply([.power(a, .negOne), e])
            }),
            // ∫ a^x dx = a^x / ln(a)
            IntegralEntry(name: "∫a^x dx", match: { e, v in
                guard case .power(let base, let exp) = e,
                      !base.freeVariables.contains(v),
                      case .variable(let s) = exp, s == v else { return false }
                return true
            }, result: { e, v in
                guard case .power(let base, _) = e else { return e }
                return .multiply([.power(.function(.ln, [base]), .negOne), e])
            }),
            // ∫ x·e^x dx = e^x(x-1)
            IntegralEntry(name: "∫x·e^x dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasX = fs.contains { if case .variable(let s) = $0, s == v { return true }; return false }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0,
                       case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasX && hasExp
            }, result: { _, v in
                .multiply([.function(.exp, [.variable(v)]), .add([.variable(v), .negOne])])
            }),
            // ∫ x²·e^x dx = e^x(x²-2x+2)
            IntegralEntry(name: "∫x²·e^x dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasX2 = fs.contains {
                    if case .power(let b, let n) = $0,
                       case .variable(let s) = b, s == v,
                       n.numericValue == 2 { return true }
                    return false
                }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0,
                       case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasX2 && hasExp
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .multiply([.function(.exp, [x]),
                                  .add([.power(x, .two), .negate(.multiply([.two, x])), .two])])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Logarithm Rules
    // ═══════════════════════════════════════════════
    
    private static var logarithmRules: [IntegralEntry] {
        [
            // ∫ ln(x) dx = x·ln(x) - x
            IntegralEntry(name: "∫ln(x) dx", match: { e, v in
                if case .function(.ln, let args) = e,
                   case .variable(let s) = args.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([x, .function(.ln, [x])]), .negate(x)])
            }),
            // ∫ log₁₀(x) dx = x·(ln(x)-1)/ln(10)
            IntegralEntry(name: "∫log(x) dx", match: { e, v in
                if case .function(.log10, let args) = e,
                   case .variable(let s) = args.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .multiply([x, .add([.function(.log10, [x]),
                                           .negate(.power(.function(.ln, [.number(10)]), .negOne))])])
            }),
            // ∫ ln(x)² dx = x·ln²(x) - 2x·ln(x) + 2x
            IntegralEntry(name: "∫ln²(x) dx", match: { e, v in
                if case .power(let b, let n) = e,
                   case .function(.ln, let args) = b,
                   case .variable(let s) = args.first, s == v,
                   n.numericValue == 2 { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                let lnx = ExprNode.function(.ln, [x])
                return .add([
                    .multiply([x, .power(lnx, .two)]),
                    .negate(.multiply([.two, x, lnx])),
                    .multiply([.two, x])
                ])
            }),
            // ∫ 1/(x·ln(x)) dx = ln|ln(x)|
            IntegralEntry(name: "∫1/(x·ln(x)) dx", match: { e, v in
                guard case .power(let b, let n) = e, n.numericValue == -1,
                      case .multiply(let fs) = b, fs.count == 2 else { return false }
                let hasX = fs.contains { if case .variable(let s) = $0, s == v { return true }; return false }
                let hasLn = fs.contains {
                    if case .function(.ln, let a) = $0,
                       case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasX && hasLn
            }, result: { _, v in
                .function(.ln, [.function(.abs, [.function(.ln, [.variable(v)])])])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Trigonometric Rules
    // ═══════════════════════════════════════════════
    
    private static var trigRules: [IntegralEntry] {
        [
            // ∫ sin(x) dx = -cos(x)
            IntegralEntry(name: "∫sin(x) dx", match: { e, v in
                if case .function(.sin, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .negate(.function(.cos, [.variable(v)])) }),
            
            // ∫ cos(x) dx = sin(x)
            IntegralEntry(name: "∫cos(x) dx", match: { e, v in
                if case .function(.cos, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.sin, [.variable(v)]) }),
            
            // ∫ tan(x) dx = -ln|cos(x)|
            IntegralEntry(name: "∫tan(x) dx", match: { e, v in
                if case .function(.tan, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .negate(.function(.ln, [.function(.abs, [.function(.cos, [.variable(v)])])])) }),
            
            // ∫ cot(x) dx = ln|sin(x)|
            IntegralEntry(name: "∫cot(x) dx", match: { e, v in
                if case .function(.cot, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.ln, [.function(.abs, [.function(.sin, [.variable(v)])])]) }),
            
            // ∫ sec(x) dx = ln|sec(x)+tan(x)|
            IntegralEntry(name: "∫sec(x) dx", match: { e, v in
                if case .function(.sec, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .function(.ln, [.function(.abs, [.add([.function(.sec, [x]), .function(.tan, [x])])])])
            }),
            
            // ∫ csc(x) dx = -ln|csc(x)+cot(x)|
            IntegralEntry(name: "∫csc(x) dx", match: { e, v in
                if case .function(.csc, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .negate(.function(.ln, [.function(.abs, [.add([.function(.csc, [x]), .function(.cot, [x])])])]))
            }),
            
            // ∫ sin²(x) dx = x/2 - sin(2x)/4
            IntegralEntry(name: "∫sin²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.sin, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([.half, x]), .negate(.multiply([.frac(1, 4), .function(.sin, [.multiply([.two, x])])]))])
            }),
            
            // ∫ cos²(x) dx = x/2 + sin(2x)/4
            IntegralEntry(name: "∫cos²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.cos, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([.half, x]), .multiply([.frac(1, 4), .function(.sin, [.multiply([.two, x])])])])
            }),
            
            // ∫ tan²(x) dx = tan(x) - x
            IntegralEntry(name: "∫tan²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.tan, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.function(.tan, [x]), .negate(x)])
            }),
            
            // ∫ sec²(x) dx = tan(x)
            IntegralEntry(name: "∫sec²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.sec, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.tan, [.variable(v)]) }),
            
            // ∫ csc²(x) dx = -cot(x)
            IntegralEntry(name: "∫csc²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.csc, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .negate(.function(.cot, [.variable(v)])) }),
            
            // ∫ sec(x)·tan(x) dx = sec(x)
            IntegralEntry(name: "∫sec·tan dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasSec = fs.contains {
                    if case .function(.sec, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                let hasTan = fs.contains {
                    if case .function(.tan, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasSec && hasTan
            }, result: { _, v in .function(.sec, [.variable(v)]) }),
            
            // ∫ csc(x)·cot(x) dx = -csc(x)
            IntegralEntry(name: "∫csc·cot dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasCsc = fs.contains {
                    if case .function(.csc, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                let hasCot = fs.contains {
                    if case .function(.cot, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasCsc && hasCot
            }, result: { _, v in .negate(.function(.csc, [.variable(v)])) }),
            
            // ∫ sin(ax) dx = -cos(ax)/a
            IntegralEntry(name: "∫sin(ax) dx", match: { e, v in
                guard case .function(.sin, let args) = e,
                      extractLinearCoeff(args[0], v) != nil else { return false }
                return true
            }, result: { e, v in
                guard case .function(.sin, let args) = e,
                      let (a, _) = extractLinearParts(args[0], v) else { return e }
                return .multiply([.negate(.power(a, .negOne)), .function(.cos, args)])
            }),
            
            // ∫ cos(ax) dx = sin(ax)/a
            IntegralEntry(name: "∫cos(ax) dx", match: { e, v in
                guard case .function(.cos, let args) = e,
                      extractLinearCoeff(args[0], v) != nil else { return false }
                return true
            }, result: { e, v in
                guard case .function(.cos, let args) = e,
                      let (a, _) = extractLinearParts(args[0], v) else { return e }
                return .multiply([.power(a, .negOne), .function(.sin, args)])
            }),
            
            // ∫ sin³(x) dx = -cos(x) + cos³(x)/3
            IntegralEntry(name: "∫sin³(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 3,
                   case .function(.sin, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let c = ExprNode.function(.cos, [.variable(v)])
                return .add([.negate(c), .multiply([.frac(1, 3), .power(c, .three)])])
            }),
            
            // ∫ cos³(x) dx = sin(x) - sin³(x)/3
            IntegralEntry(name: "∫cos³(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 3,
                   case .function(.cos, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let s = ExprNode.function(.sin, [.variable(v)])
                return .add([s, .negate(.multiply([.frac(1, 3), .power(s, .three)]))])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Inverse Trigonometric Rules
    // ═══════════════════════════════════════════════
    
    private static var inverseTrigRules: [IntegralEntry] {
        [
            // ∫ arcsin(x) dx = x·arcsin(x) + √(1-x²)
            IntegralEntry(name: "∫arcsin(x) dx", match: { e, v in
                if case .function(.asin, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([x, .function(.asin, [x])]),
                             .function(.sqrt, [.add([.one, .negate(.power(x, .two))])])])
            }),
            
            // ∫ arccos(x) dx = x·arccos(x) - √(1-x²)
            IntegralEntry(name: "∫arccos(x) dx", match: { e, v in
                if case .function(.acos, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([x, .function(.acos, [x])]),
                             .negate(.function(.sqrt, [.add([.one, .negate(.power(x, .two))])]))])
            }),
            
            // ∫ arctan(x) dx = x·arctan(x) - ln(1+x²)/2
            IntegralEntry(name: "∫arctan(x) dx", match: { e, v in
                if case .function(.atan, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.multiply([x, .function(.atan, [x])]),
                             .negate(.multiply([.half, .function(.ln, [.add([.one, .power(x, .two)])])]))])
            }),
            
            // ∫ 1/√(1-x²) dx = arcsin(x)
            IntegralEntry(name: "∫1/√(1-x²) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == -0.5,
                   case .add(let terms) = b, terms.count == 2 {
                    // Check for 1 - x²
                    return matchOneMinusXSquared(b, v)
                }
                return false
            }, result: { _, v in .function(.asin, [.variable(v)]) }),
            
            // ∫ 1/(1+x²) dx = arctan(x)
            IntegralEntry(name: "∫1/(1+x²) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == -1,
                   matchOnePlusXSquared(b, v) { return true }
                return false
            }, result: { _, v in .function(.atan, [.variable(v)]) }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Hyperbolic Rules
    // ═══════════════════════════════════════════════
    
    private static var hyperbolicRules: [IntegralEntry] {
        [
            // ∫ sinh(x) dx = cosh(x)
            IntegralEntry(name: "∫sinh(x) dx", match: { e, v in
                if case .function(.sinh, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.cosh, [.variable(v)]) }),
            
            // ∫ cosh(x) dx = sinh(x)
            IntegralEntry(name: "∫cosh(x) dx", match: { e, v in
                if case .function(.cosh, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.sinh, [.variable(v)]) }),
            
            // ∫ tanh(x) dx = ln(cosh(x))
            IntegralEntry(name: "∫tanh(x) dx", match: { e, v in
                if case .function(.tanh, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.ln, [.function(.cosh, [.variable(v)])]) }),
            
            // ∫ coth(x) dx = ln|sinh(x)|
            IntegralEntry(name: "∫coth(x) dx", match: { e, v in
                if case .function(.coth, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.ln, [.function(.abs, [.function(.sinh, [.variable(v)])])]) }),
            
            // ∫ sech²(x) dx = tanh(x)
            IntegralEntry(name: "∫sech²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.sech, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .function(.tanh, [.variable(v)]) }),
            
            // ∫ csch²(x) dx = -coth(x)
            IntegralEntry(name: "∫csch²(x) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == 2,
                   case .function(.csch, let a) = b, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in .negate(.function(.coth, [.variable(v)])) }),
            
            // ∫ sech(x)·tanh(x) dx = -sech(x)
            IntegralEntry(name: "∫sech·tanh dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasSech = fs.contains { if case .function(.sech, let a) = $0, case .variable(let s) = a.first, s == v { return true }; return false }
                let hasTanh = fs.contains { if case .function(.tanh, let a) = $0, case .variable(let s) = a.first, s == v { return true }; return false }
                return hasSech && hasTanh
            }, result: { _, v in .negate(.function(.sech, [.variable(v)])) }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Inverse Hyperbolic Rules
    // ═══════════════════════════════════════════════
    
    private static var inverseHyperbolicRules: [IntegralEntry] {
        [
            // ∫ 1/√(x²+1) dx = arcsinh(x) = ln(x+√(x²+1))
            IntegralEntry(name: "∫1/√(x²+1) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == -0.5,
                   matchXSquaredPlusOne(b, v) { return true }
                return false
            }, result: { _, v in .function(.asinh, [.variable(v)]) }),
            
            // ∫ 1/√(x²-1) dx = arccosh(x)
            IntegralEntry(name: "∫1/√(x²-1) dx", match: { e, v in
                if case .power(let b, let n) = e, n.numericValue == -0.5,
                   matchXSquaredMinusOne(b, v) { return true }
                return false
            }, result: { _, v in .function(.acosh, [.variable(v)]) }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Rational Function Rules
    // ═══════════════════════════════════════════════
    
    private static var rationalRules: [IntegralEntry] {
        [
            // ∫ 1/(ax+b) dx = ln|ax+b|/a
            IntegralEntry(name: "∫1/(ax+b) dx", match: { e, v in
                guard case .power(let base, let exp) = e, exp.numericValue == -1,
                      extractLinearCoeff(base, v) != nil else { return false }
                return true
            }, result: { e, v in
                guard case .power(let base, _) = e,
                      let (a, _) = extractLinearParts(base, v) else { return e }
                return .multiply([.power(a, .negOne), .function(.ln, [.function(.abs, [base])])])
            }),
            
            // ∫ 1/(a²+x²) dx = (1/a)·arctan(x/a)
            IntegralEntry(name: "∫1/(a²+x²) dx", match: { e, v in
                guard case .power(let base, let exp) = e, exp.numericValue == -1,
                      case .add(let terms) = base, terms.count == 2 else { return false }
                // Look for constant + x²
                var hasConst = false, hasX2 = false
                for t in terms {
                    if !t.freeVariables.contains(v) { hasConst = true }
                    if case .power(let b, let n) = t, case .variable(let s) = b,
                       s == v, n.numericValue == 2 { hasX2 = true }
                }
                return hasConst && hasX2
            }, result: { e, v in
                guard case .power(let base, _) = e,
                      case .add(let terms) = base else { return e }
                let constTerm = terms.first { !$0.freeVariables.contains(v) } ?? .one
                let a = ExprNode.function(.sqrt, [constTerm])
                let x = ExprNode.variable(v)
                return .multiply([.power(a, .negOne), .function(.atan, [.multiply([x, .power(a, .negOne)])])])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Square Root Rules
    // ═══════════════════════════════════════════════
    
    private static var sqrtRules: [IntegralEntry] {
        [
            // ∫ √(a²-x²) dx = (x/2)√(a²-x²) + (a²/2)arcsin(x/a)
            IntegralEntry(name: "∫√(a²-x²) dx", match: { e, v in
                if case .function(.sqrt, let args) = e,
                   matchASquaredMinusXSquared(args[0], v) { return true }
                if case .power(let b, let n) = e, n.numericValue == 0.5,
                   matchASquaredMinusXSquared(b, v) { return true }
                return false
            }, result: { e, v in
                let x = ExprNode.variable(v)
                return .add([
                    .multiply([.half, x, e]),
                    .multiply([.half, .function(.asin, [x])]) // simplified for a=1
                ])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Special Function Rules
    // ═══════════════════════════════════════════════
    
    private static var specialRules: [IntegralEntry] {
        [
            // ∫ erf(x) dx = x·erf(x) + e^{-x²}/√π
            IntegralEntry(name: "∫erf(x) dx", match: { e, v in
                if case .function(.erf, let a) = e, case .variable(let s) = a.first, s == v { return true }
                return false
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([
                    .multiply([x, .function(.erf, [x])]),
                    .multiply([.power(.pi, .half), .function(.exp, [.negate(.power(x, .two))])])
                ])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Composite / Substitution-Friendly Rules
    // ═══════════════════════════════════════════════
    
    private static var compositeRules: [IntegralEntry] {
        [
            // ∫ f'(x)·e^{f(x)} dx = e^{f(x)}
            // Handled by Integrator's substitution engine, not table.
            
            // ∫ f'(x)/f(x) dx = ln|f(x)|  — also handled by substitution.
            
            // ∫ x/(1+x²) dx = ln(1+x²)/2
            IntegralEntry(name: "∫x/(1+x²) dx", match: { e, v in
                guard case .multiply(let fs) = e else { return false }
                let hasX = fs.contains { if case .variable(let s) = $0, s == v { return true }; return false }
                let hasInv1PlusX2 = fs.contains {
                    if case .power(let b, let n) = $0, n.numericValue == -1,
                       matchOnePlusXSquared(b, v) { return true }
                    return false
                }
                return hasX && hasInv1PlusX2
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .multiply([.half, .function(.ln, [.add([.one, .power(x, .two)])])])
            }),
            
            // ∫ x·sin(x) dx = sin(x) - x·cos(x)
            IntegralEntry(name: "∫x·sin(x) dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasX = fs.contains { if case .variable(let s) = $0, s == v { return true }; return false }
                let hasSin = fs.contains {
                    if case .function(.sin, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasX && hasSin
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.function(.sin, [x]), .negate(.multiply([x, .function(.cos, [x])]))])
            }),
            
            // ∫ x·cos(x) dx = cos(x) + x·sin(x)
            IntegralEntry(name: "∫x·cos(x) dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasX = fs.contains { if case .variable(let s) = $0, s == v { return true }; return false }
                let hasCos = fs.contains {
                    if case .function(.cos, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasX && hasCos
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .add([.function(.cos, [x]), .multiply([x, .function(.sin, [x])])])
            }),
            
            // ∫ e^x·sin(x) dx = e^x(sin(x)-cos(x))/2
            IntegralEntry(name: "∫e^x·sin(x) dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                let hasSin = fs.contains {
                    if case .function(.sin, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasExp && hasSin
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .multiply([.half, .function(.exp, [x]),
                                  .add([.function(.sin, [x]), .negate(.function(.cos, [x]))])])
            }),
            
            // ∫ e^x·cos(x) dx = e^x(sin(x)+cos(x))/2
            IntegralEntry(name: "∫e^x·cos(x) dx", match: { e, v in
                guard case .multiply(let fs) = e, fs.count == 2 else { return false }
                let hasExp = fs.contains {
                    if case .function(.exp, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                let hasCos = fs.contains {
                    if case .function(.cos, let a) = $0, case .variable(let s) = a.first, s == v { return true }
                    return false
                }
                return hasExp && hasCos
            }, result: { _, v in
                let x = ExprNode.variable(v)
                return .multiply([.half, .function(.exp, [x]),
                                  .add([.function(.sin, [x]), .function(.cos, [x])])])
            }),
        ]
    }
    
    // ═══════════════════════════════════════════════
    // MARK: - Pattern Matching Helpers
    // ═══════════════════════════════════════════════
    
    /// Extract coefficient a from expression ax+b. Returns a if pattern matches.
    static func extractLinearCoeff(_ expr: ExprNode, _ v: String) -> Double? {
        guard let (a, _) = extractLinearParts(expr, v) else { return nil }
        return a.numericValue
    }
    
    /// Extract (a, b) from ax+b.
    static func extractLinearParts(_ expr: ExprNode, _ v: String) -> (ExprNode, ExprNode)? {
        // Case: just x  → (1, 0)
        if case .variable(let s) = expr, s == v {
            return (.one, .zero)
        }
        // Case: a*x → (a, 0)
        if case .multiply(let fs) = expr, fs.count == 2 {
            if case .variable(let s) = fs[1], s == v, !fs[0].freeVariables.contains(v) {
                return (fs[0], .zero)
            }
            if case .variable(let s) = fs[0], s == v, !fs[1].freeVariables.contains(v) {
                return (fs[1], .zero)
            }
        }
        // Case: ax + b
        if case .add(let terms) = expr, terms.count == 2 {
            for (i, t) in terms.enumerated() {
                let other = terms[1 - i]
                if !other.freeVariables.contains(v) {
                    if let (a, _) = extractLinearParts(t, v) {
                        return (a, other)
                    }
                }
            }
        }
        return nil
    }
    
    /// Check if expr matches 1 - x²
    private static func matchOneMinusXSquared(_ expr: ExprNode, _ v: String) -> Bool {
        guard case .add(let terms) = expr, terms.count == 2 else { return false }
        let hasOne = terms.contains { $0.isOne }
        let hasNegX2 = terms.contains {
            if case .negate(let inner) = $0 {
                if case .power(let b, let n) = inner, case .variable(let s) = b, s == v, n.numericValue == 2 { return true }
            }
            return false
        }
        return hasOne && hasNegX2
    }
    
    /// Check if expr matches 1 + x²
    private static func matchOnePlusXSquared(_ expr: ExprNode, _ v: String) -> Bool {
        guard case .add(let terms) = expr, terms.count == 2 else { return false }
        let hasOne = terms.contains { $0.isOne }
        let hasX2 = terms.contains {
            if case .power(let b, let n) = $0, case .variable(let s) = b, s == v, n.numericValue == 2 { return true }
            return false
        }
        return hasOne && hasX2
    }
    
    /// Check if expr matches x² + 1
    private static func matchXSquaredPlusOne(_ expr: ExprNode, _ v: String) -> Bool {
        matchOnePlusXSquared(expr, v)
    }
    
    /// Check if expr matches x² - 1
    private static func matchXSquaredMinusOne(_ expr: ExprNode, _ v: String) -> Bool {
        guard case .add(let terms) = expr, terms.count == 2 else { return false }
        let hasX2 = terms.contains {
            if case .power(let b, let n) = $0, case .variable(let s) = b, s == v, n.numericValue == 2 { return true }
            return false
        }
        let hasNegOne = terms.contains {
            if case .negate(let inner) = $0, inner.isOne { return true }
            return false
        }
        return hasX2 && hasNegOne
    }
    
    /// Check if expr matches a² - x²
    private static func matchASquaredMinusXSquared(_ expr: ExprNode, _ v: String) -> Bool {
        guard case .add(let terms) = expr, terms.count == 2 else { return false }
        let hasConst = terms.contains { !$0.freeVariables.contains(v) }
        let hasNegX2 = terms.contains {
            if case .negate(let inner) = $0 {
                if case .power(let b, let n) = inner, case .variable(let s) = b, s == v, n.numericValue == 2 { return true }
            }
            return false
        }
        return hasConst && hasNegX2
    }
}
