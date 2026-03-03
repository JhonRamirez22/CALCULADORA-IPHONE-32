// Parser.swift
// CalcPrime — Engine/Core
// Recursive-descent parser: Token stream → ExprNode AST
// Grammar:
//   expr     → term (('+' | '-') term)*
//   term     → unary (('*' | '/' | implicit) unary)*
//   unary    → ('-' | '+') unary | power
//   power    → postfix ('^' postfix)?
//   postfix  → primary ('!' | '°')*
//   primary  → number | variable | constant | function | '(' expr ')' | '[' ... ']'
//              | calculus (integral, derivative, limit, sum, product)
//              | matrix '[[' ... ']]'
//
// Handles implicit multiplication, Unicode, differentials, integrals.

import Foundation

// MARK: - ParseError

enum ParseError: Error, LocalizedError {
    case unexpectedToken(Token, String)
    case unexpectedEnd(String)
    case invalidExpression(String)
    case invalidMatrix(String)
    
    var errorDescription: String? {
        switch self {
        case .unexpectedToken(let tok, let ctx): return "Token inesperado \(tok) en \(ctx)"
        case .unexpectedEnd(let ctx): return "Fin inesperado en \(ctx)"
        case .invalidExpression(let msg): return "Expresión inválida: \(msg)"
        case .invalidMatrix(let msg): return "Matriz inválida: \(msg)"
        }
    }
}

// MARK: - Parser

struct Parser {
    private var tokens: [Token]
    private var pos: Int = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    // MARK: - Public
    
    /// Parse a full expression from a string.
    static func parse(_ input: String) throws -> ExprNode {
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()
        var parser = Parser(tokens: tokens)
        let expr = try parser.parseExpression()
        // Allow trailing eof
        if parser.current != .eof && parser.pos < parser.tokens.count {
            throw ParseError.unexpectedToken(parser.current, "se esperaba fin de expresión")
        }
        return expr
    }
    
    // MARK: - Token Navigation
    
    private var current: Token {
        pos < tokens.count ? tokens[pos] : .eof
    }
    
    private var peek: Token {
        pos + 1 < tokens.count ? tokens[pos + 1] : .eof
    }
    
    @discardableResult
    private mutating func advance() -> Token {
        let tok = current
        pos += 1
        return tok
    }
    
    private mutating func expect(_ expected: Token, context: String = "") throws {
        guard current == expected else {
            throw ParseError.unexpectedToken(current, "se esperaba \(expected) \(context)")
        }
        advance()
    }
    
    private func match(_ tok: Token) -> Bool {
        current == tok
    }
    
    private mutating func consumeIf(_ tok: Token) -> Bool {
        if current == tok { advance(); return true }
        return false
    }
    
    // MARK: - Expression (lowest precedence)
    
    /// expr → assignment | equation | comparison
    mutating func parseExpression() throws -> ExprNode {
        let lhs = try parseAdditive()
        
        // Assignment: x := expr
        if case .variable(let name) = lhs, match(.assign) {
            advance()
            let rhs = try parseAdditive()
            return .assignment(name, rhs)
        }
        
        // Equation: expr = expr
        if match(.equals) {
            advance()
            let rhs = try parseAdditive()
            return .equation(lhs, rhs)
        }
        
        // Inequality: expr < expr, expr <= expr, etc.
        switch current {
        case .less:
            advance()
            let rhs = try parseAdditive()
            return .inequality(lhs, "<", rhs)
        case .lessEqual:
            advance()
            let rhs = try parseAdditive()
            return .inequality(lhs, "<=", rhs)
        case .greater:
            advance()
            let rhs = try parseAdditive()
            return .inequality(lhs, ">", rhs)
        case .greaterEqual:
            advance()
            let rhs = try parseAdditive()
            return .inequality(lhs, ">=", rhs)
        default:
            break
        }
        
        return lhs
    }
    
    // MARK: - Additive: term ((+|-) term)*
    
    private mutating func parseAdditive() throws -> ExprNode {
        var terms: [ExprNode] = [try parseTerm()]
        
        while true {
            if match(.plus) {
                advance()
                terms.append(try parseTerm())
            } else if match(.minus) {
                advance()
                let t = try parseTerm()
                terms.append(.negate(t))
            } else {
                break
            }
        }
        
        return terms.count == 1 ? terms[0] : .add(terms)
    }
    
    // MARK: - Term: unary ((*|/|implicit) unary)*
    
    private mutating func parseTerm() throws -> ExprNode {
        var factors: [ExprNode] = [try parseUnary()]
        
        while true {
            if match(.star) || match(.cross) || match(.dot) {
                advance()
                factors.append(try parseUnary())
            } else if match(.slash) {
                advance()
                let divisor = try parseUnary()
                factors.append(.power(divisor, .negOne))
            } else if isImplicitMultiplication() {
                factors.append(try parseUnary())
            } else {
                break
            }
        }
        
        return factors.count == 1 ? factors[0] : .multiply(factors)
    }
    
    /// Determine if the next token triggers implicit multiplication.
    private func isImplicitMultiplication() -> Bool {
        switch current {
        case .number, .integer:
            return false
        case .variable, .functionName, .constant:
            return true
        case .lparen, .lbracket:
            return true
        case .integral, .partial:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Unary: (-|+) unary | power
    
    private mutating func parseUnary() throws -> ExprNode {
        if match(.minus) {
            advance()
            let operand = try parseUnary()
            // Fold: -number → number(-v)
            if case .number(let v) = operand { return .number(-v) }
            if case .rational(let p, let q) = operand { return .rational(-p, q) }
            return .negate(operand)
        }
        if match(.plus) {
            advance()
            return try parseUnary()
        }
        return try parsePower()
    }
    
    // MARK: - Power: postfix ('^' unary)?
    
    private mutating func parsePower() throws -> ExprNode {
        var base = try parsePostfix()
        if match(.caret) {
            advance()
            let exp = try parseUnary() // right-associative
            base = .power(base, exp)
        }
        return base
    }
    
    // MARK: - Postfix: primary ('!' | '°')*
    
    private mutating func parsePostfix() throws -> ExprNode {
        var node = try parsePrimary()
        while match(.bang) {
            advance()
            node = .function(.factorial, [node])
        }
        return node
    }
    
    // MARK: - Primary
    
    private mutating func parsePrimary() throws -> ExprNode {
        switch current {
        // ── Numbers ─────────────────────────────────────────
        case .number(let v):
            advance()
            return .number(v)
        case .integer(let n):
            advance()
            return .number(Double(n))
            
        // ── Constants ───────────────────────────────────────
        case .constant(let name):
            advance()
            switch name {
            case "__const_pi": return .constant(.pi)
            case "__const_e":  return .constant(.e)
            case "__const_i":  return .constant(.i)
            case "__const_phi": return .constant(.phi)
            case "__const_euler_gamma": return .constant(.euler)
            case "__const_inf": return .constant(.inf)
            default: return .variable(name)
            }
            
        // ── Variable ────────────────────────────────────────
        case .variable(let name):
            advance()
            return .variable(name)
            
        // ── Function ────────────────────────────────────────
        case .functionName(let name):
            return try parseFunction(name)
            
        // ── Parenthesized ───────────────────────────────────
        case .lparen:
            advance()
            let expr = try parseExpression()
            try expect(.rparen, context: "en sub-expresión con paréntesis")
            return expr
            
        // ── Absolute value: |expr| ──────────────────────────
        case .pipe:
            advance()
            let expr = try parseExpression()
            try expect(.pipe, context: "en valor absoluto")
            return .function(.abs, [expr])
            
        // ── Integral ────────────────────────────────────────
        case .integral:
            return try parseIntegral()
            
        // ── Partial derivative ──────────────────────────────
        case .partial:
            return try parsePartialDerivative()
            
        // ── d/dx notation ───────────────────────────────────
        case .differential(let v):
            return try parseDifferential(v)
            
        // ── Summation ───────────────────────────────────────
        case .sum:
            return try parseSummation()
            
        // ── Product ─────────────────────────────────────────
        case .product:
            return try parseProduct()
            
        // ── Limit ───────────────────────────────────────────
        case .limitToken:
            return try parseLimit()
            
        // ── Infinity ────────────────────────────────────────
        case .infinity:
            advance()
            return .constant(.inf)
            
        // ── Matrix [[...]] or vector [...] ──────────────────
        case .lbracket:
            return try parseMatrixOrVector()
            
        // ── Left brace { piecewise } ────────────────────────
        case .lbrace:
            return try parsePiecewise()
            
        case .eof:
            throw ParseError.unexpectedEnd("se esperaba expresión")
            
        default:
            throw ParseError.unexpectedToken(current, "se esperaba expresión")
        }
    }
    
    // MARK: - Function Parsing
    
    private mutating func parseFunction(_ name: String) throws -> ExprNode {
        advance() // consume functionName
        
        // Map name → MathFunc
        guard let fn = mapFunctionName(name) else {
            // Unknown function: treat as generic
            if match(.lparen) {
                advance()
                let args = try parseArgList()
                try expect(.rparen, context: "en argumentos de función")
                // Try to build a function call anyway
                return .function(.abs, args) // fallback
            }
            return .variable(name) // treat as variable
        }
        
        // Expect (args)
        guard match(.lparen) else {
            // Function without parens: sin x (single token)
            let arg = try parseUnary()
            return .function(fn, [arg])
        }
        
        advance() // consume (
        let args = try parseArgList()
        try expect(.rparen, context: "en argumentos de \(name)")
        
        return .function(fn, args)
    }
    
    private mutating func parseArgList() throws -> [ExprNode] {
        if match(.rparen) { return [] }
        var args: [ExprNode] = [try parseExpression()]
        while match(.comma) {
            advance()
            args.append(try parseExpression())
        }
        return args
    }
    
    private func mapFunctionName(_ name: String) -> MathFunc? {
        // Canonical names (Tokenizer already normalizes)
        let map: [String: MathFunc] = [
            "sin": .sin, "cos": .cos, "tan": .tan,
            "csc": .csc, "sec": .sec, "cot": .cot,
            "asin": .asin, "acos": .acos, "atan": .atan,
            "acsc": .acsc, "asec": .asec, "acot": .acot,
            "sinh": .sinh, "cosh": .cosh, "tanh": .tanh,
            "csch": .csch, "sech": .sech, "coth": .coth,
            "asinh": .asinh, "acosh": .acosh, "atanh": .atanh,
            "acsch": .acsch, "asech": .asech, "acoth": .acoth,
            "exp": .exp, "ln": .ln, "log": .log, "log2": .log2, "log10": .log10,
            "sqrt": .sqrt, "cbrt": .cbrt,
            "abs": .abs, "sign": .sign, "sgn": .sign,
            "floor": .floor, "ceil": .ceil, "round": .round,
            "gamma": .gamma, "lgamma": .lgamma, "beta": .beta, "digamma": .digamma,
            "erf": .erf, "erfc": .erfc, "erfi": .erfi,
            "Si": .Si, "Ci": .Ci, "li": .li, "Ei": .Ei,
            "besselJ": .besselJ, "besselY": .besselY,
            "besselI": .besselI, "besselK": .besselK,
            "airyAi": .airyAi, "airyBi": .airyBi,
            "legendreP": .legendreP, "legendreQ": .legendreQ,
            "hermiteH": .hermiteH, "laguerreL": .laguerreL,
            "chebyshevT": .chebyshevT, "chebyshevU": .chebyshevU,
            "lambertW": .lambertW, "W": .lambertW,
            "zeta": .zeta,
            "max": .max, "min": .min,
            "gcd": .gcd, "lcm": .lcm, "mod": .mod,
            "factorial": .factorial, "fact": .factorial,
            "binomial": .binomial, "C": .binomial,
            "permutation": .permutation, "P": .permutation,
            "nthRoot": .nthRoot, "root": .nthRoot,
            "logBase": .logBase,
            "real": .real, "imag": .imag, "conj": .conj, "arg": .arg,
            "Re": .real, "Im": .imag,
            "atan2": .atan2,
            "heaviside": .heaviside, "u": .heaviside,
            "delta": .delta, "dirac": .delta,
            "hypergeom": .hypergeom,
            "fresnelS": .fresnelS, "fresnelC": .fresnelC,
            "ellipticK": .ellipticK, "ellipticE": .ellipticE,
            "polyGamma": .polyGamma,
        ]
        return map[name]
    }
    
    // MARK: - Integral Parsing
    // ∫ expr dx  or  ∫_a^b expr dx
    
    private mutating func parseIntegral() throws -> ExprNode {
        advance() // consume ∫
        
        // Check for limits: _lower^upper
        var lower: ExprNode? = nil
        var upper: ExprNode? = nil
        
        if match(.underscore) {
            advance()
            if match(.lparen) {
                advance()
                lower = try parseExpression()
                try expect(.rparen, context: "en límite inferior de integral")
            } else if match(.lbrace) {
                advance()
                lower = try parseExpression()
                try expect(.rbrace, context: "en límite inferior de integral")
            } else {
                lower = try parsePrimary()
            }
        }
        
        if match(.caret) {
            advance()
            if match(.lparen) {
                advance()
                upper = try parseExpression()
                try expect(.rparen, context: "en límite superior de integral")
            } else if match(.lbrace) {
                advance()
                upper = try parseExpression()
                try expect(.rbrace, context: "en límite superior de integral")
            } else {
                upper = try parsePrimary()
            }
        }
        
        // Parse integrand
        let body = try parseExpression()
        
        // Expect dx, dt, etc.
        var varName = "x" // default
        if case .differential(let v) = current {
            advance()
            varName = v
        }
        
        if let lo = lower, let hi = upper {
            return .definiteIntegral(body, varName, lo, hi)
        }
        return .integral(body, varName)
    }
    
    // MARK: - Derivative: d/dx expr  or  d^n/dx^n expr
    
    private mutating func parseDifferential(_ varName: String) throws -> ExprNode {
        advance() // consume d/dx token
        
        // TODO: handle d^n/dx^n notation
        // For now: d/dx(expr) or d/dx expr
        let body: ExprNode
        if match(.lparen) {
            advance()
            body = try parseExpression()
            try expect(.rparen, context: "en derivada")
        } else {
            body = try parseUnary()
        }
        return .derivative(body, varName, 1)
    }
    
    // MARK: - Partial derivative: ∂/∂x expr
    
    private mutating func parsePartialDerivative() throws -> ExprNode {
        advance() // consume ∂
        
        // Expect / ∂ variable
        try expect(.slash, context: "en derivada parcial, se esperaba /")
        guard case .partial = current else {
            throw ParseError.unexpectedToken(current, "se esperaba ∂ en derivada parcial")
        }
        advance()
        
        guard case .variable(let varName) = current else {
            throw ParseError.unexpectedToken(current, "se esperaba variable en derivada parcial")
        }
        advance()
        
        let body: ExprNode
        if match(.lparen) {
            advance()
            body = try parseExpression()
            try expect(.rparen, context: "en derivada parcial")
        } else {
            body = try parseUnary()
        }
        
        return .partialDerivative(body, varName)
    }
    
    // MARK: - Summation: Σ_{i=a}^{b} expr  or  sum(expr, i, a, b)
    
    private mutating func parseSummation() throws -> ExprNode {
        advance() // consume Σ
        
        // Parse _{var=lower}^{upper}
        try expect(.underscore, context: "en sumatorio, se esperaba _")
        
        let (varName, lower) = try parseBoundSpec()
        
        try expect(.caret, context: "en sumatorio, se esperaba ^")
        let upper: ExprNode
        if match(.lbrace) {
            advance()
            upper = try parseExpression()
            try expect(.rbrace, context: "en límite superior de sumatorio")
        } else if match(.lparen) {
            advance()
            upper = try parseExpression()
            try expect(.rparen, context: "en límite superior de sumatorio")
        } else {
            upper = try parsePrimary()
        }
        
        let body = try parseExpression()
        return .summation(body, varName, lower, upper)
    }
    
    // MARK: - Product: Π_{i=a}^{b} expr
    
    private mutating func parseProduct() throws -> ExprNode {
        advance() // consume Π
        
        try expect(.underscore, context: "en productorio, se esperaba _")
        let (varName, lower) = try parseBoundSpec()
        
        try expect(.caret, context: "en productorio, se esperaba ^")
        let upper: ExprNode
        if match(.lbrace) {
            advance()
            upper = try parseExpression()
            try expect(.rbrace, context: "en límite superior de productorio")
        } else if match(.lparen) {
            advance()
            upper = try parseExpression()
            try expect(.rparen, context: "en límite superior de productorio")
        } else {
            upper = try parsePrimary()
        }
        
        let body = try parseExpression()
        return .productOp(body, varName, lower, upper)
    }
    
    // Helper: parse {var=lower} from bound spec
    private mutating func parseBoundSpec() throws -> (String, ExprNode) {
        if match(.lbrace) {
            advance()
            guard case .variable(let v) = current else {
                throw ParseError.unexpectedToken(current, "se esperaba variable en especificación de límite")
            }
            advance()
            try expect(.equals, context: "en especificación de límite, se esperaba =")
            let lower = try parseExpression()
            try expect(.rbrace, context: "en especificación de límite")
            return (v, lower)
        } else if match(.lparen) {
            advance()
            guard case .variable(let v) = current else {
                throw ParseError.unexpectedToken(current, "se esperaba variable en especificación de límite")
            }
            advance()
            try expect(.equals, context: "en especificación de límite, se esperaba =")
            let lower = try parseExpression()
            try expect(.rparen, context: "en especificación de límite")
            return (v, lower)
        } else {
            // No braces: just var=lower
            guard case .variable(let v) = current else {
                throw ParseError.unexpectedToken(current, "se esperaba variable en especificación de límite")
            }
            advance()
            try expect(.equals, context: "se esperaba =")
            let lower = try parsePrimary()
            return (v, lower)
        }
    }
    
    // MARK: - Limit: lim_{x→a} expr
    
    private mutating func parseLimit() throws -> ExprNode {
        advance() // consume lim
        
        try expect(.underscore, context: "en límite, se esperaba _")
        
        // Parse {x→a} or {x→a+} or {x→a-}
        let needBrace = consumeIf(.lbrace)
        let needParen = !needBrace && consumeIf(.lparen)
        
        guard case .variable(let v) = current else {
            throw ParseError.unexpectedToken(current, "se esperaba variable en límite")
        }
        advance()
        
        try expect(.arrow, context: "en límite, se esperaba →")
        
        let point = try parseAdditive()
        
        var dir: LimitDir = .both
        // Check for + or - direction
        if match(.plus) { advance(); dir = .right }
        else if match(.minus) { advance(); dir = .left }
        
        if needBrace { try expect(.rbrace, context: "en límite") }
        if needParen { try expect(.rparen, context: "en límite") }
        
        let body = try parseExpression()
        return .limit(body, v, point, dir)
    }
    
    // MARK: - Matrix/Vector: [[a,b],[c,d]] or [a,b,c]
    
    private mutating func parseMatrixOrVector() throws -> ExprNode {
        advance() // consume [
        
        // Check if matrix: [[
        if match(.lbracket) {
            // Matrix
            var rows: [[ExprNode]] = []
            while match(.lbracket) {
                advance() // consume inner [
                var row: [ExprNode] = [try parseExpression()]
                while match(.comma) {
                    advance()
                    row.append(try parseExpression())
                }
                try expect(.rbracket, context: "en fila de matriz")
                rows.append(row)
                _ = consumeIf(.comma) // optional comma between rows
            }
            try expect(.rbracket, context: "en matriz")
            
            // Validate consistent row lengths
            if let firstLen = rows.first?.count, !rows.allSatisfy({ $0.count == firstLen }) {
                throw ParseError.invalidMatrix("Las filas de la matriz tienen longitudes diferentes")
            }
            
            return .matrix(rows)
        }
        
        // Vector or list
        if match(.rbracket) {
            advance()
            return .vector([])
        }
        
        var elems: [ExprNode] = [try parseExpression()]
        while match(.comma) {
            advance()
            elems.append(try parseExpression())
        }
        try expect(.rbracket, context: "en vector")
        return .vector(elems)
    }
    
    // MARK: - Piecewise: { cond1: val1, cond2: val2 }
    
    private mutating func parsePiecewise() throws -> ExprNode {
        advance() // consume {
        
        var pairs: [(ExprNode, ExprNode)] = []
        while !match(.rbrace) && !match(.eof) {
            let val = try parseExpression()
            // Expect :
            if match(.colon) {
                advance()
                let cond = try parseExpression()
                pairs.append((cond, val))
            } else {
                // Last case (otherwise)
                pairs.append((.number(1), val)) // condition = true
            }
            _ = consumeIf(.comma)
            _ = consumeIf(.semicolon)
        }
        try expect(.rbrace, context: "en función a trozos")
        return .piecewise(pairs)
    }
}
