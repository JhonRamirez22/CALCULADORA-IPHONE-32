// Token.swift
// CalcPrime — Engine/Core
// Lexical tokens for the mathematical expression parser.
// Ref: Compilers: Principles, Techniques, and Tools (Aho et al.)

import Foundation

// MARK: - Token

/// Represents a single lexical token produced by the tokenizer.
enum Token: Equatable {
    // Literals
    case number(Double)
    case integer(Int)
    case variable(String)
    case functionName(String)
    
    // Operators
    case plus           // +
    case minus          // -
    case star           // *
    case slash          // /
    case caret          // ^
    case percent        // % (mod)
    case bang           // ! (factorial)
    case equals         // =
    case comma          // ,
    case semicolon      // ;
    
    // Brackets
    case lparen         // (
    case rparen         // )
    case lbracket       // [
    case rbracket       // ]
    case lbrace         // {
    case rbrace         // }
    case pipe           // | (abs)
    
    // Comparison operators
    case less           // <
    case lessEqual      // <=
    case greater        // >
    case greaterEqual   // >=
    case assign         // :=
    case colon          // :
    case cross          // × (cross product)
    case dot            // · (dot product, kept separate from star)
    
    // Calculus tokens
    case integral       // ∫
    case derivative     // d/dx parsed as compound
    case differential(String)  // dx, dt, dy — the differential variable
    case partial        // ∂
    case sum            // Σ
    case product        // Π (product)
    case limitToken     // lim
    case arrow          // → or ->
    case infinity       // ∞
    case constant(String) // __const_pi, __const_e, etc.
    
    // Special
    case underscore     // _ (subscript)
    case to             // keyword "to" in ranges
    case eof
    
    var isOperator: Bool {
        switch self {
        case .plus, .minus, .star, .slash, .caret, .percent, .bang, .equals,
             .less, .lessEqual, .greater, .greaterEqual, .cross, .dot:
            return true
        default: return false
        }
    }
}

// MARK: - Tokenizer

/// Converts a raw input string into a sequence of `Token`s.
/// Handles Unicode math symbols, implicit multiplication detection,
/// scientific notation, and special notation (d/dx, ∫, Σ, etc.)
struct Tokenizer {
    private let input: [Character]
    private var pos: Int = 0
    
    init(_ string: String) {
        // Normalize Unicode math symbols (keep ·/× for semantic tokens)
        let normalized = string
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "τ", with: "tau")
            .replacingOccurrences(of: "φ", with: "phi")
            .replacingOccurrences(of: "γ", with: "euler_gamma")
            .replacingOccurrences(of: "²", with: "^2")
            .replacingOccurrences(of: "³", with: "^3")
            .replacingOccurrences(of: "⁴", with: "^4")
            .replacingOccurrences(of: "⁵", with: "^5")
            .replacingOccurrences(of: "⁻¹", with: "^(-1)")
            .replacingOccurrences(of: "√", with: "sqrt")
            .replacingOccurrences(of: "∛", with: "cbrt")
        self.input = Array(normalized)
    }
    
    // Alternate init for Parser compatibility
    init(input: String) {
        self.init(input)
    }
    
    /// Produce all tokens from the input.
    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while pos < input.count {
            let ch = input[pos]
            
            // Skip whitespace
            if ch.isWhitespace {
                pos += 1
                continue
            }
            
            // Numbers: integers and decimals, scientific notation
            if ch.isNumber || (ch == "." && pos + 1 < input.count && input[pos + 1].isNumber) {
                let numToken = try readNumber()
                // Insert implicit multiplication if needed
                if let last = tokens.last, needsImplicitMul(last, before: numToken) {
                    tokens.append(.star)
                }
                tokens.append(numToken)
                continue
            }
            
            // Integral symbol
            if ch == "∫" || (ch == "\\u{222B}") {
                tokens.append(.integral)
                pos += 1
                continue
            }
            
            // Partial ∂
            if ch == "∂" {
                tokens.append(.partial)
                pos += 1
                continue
            }
            
            // Sigma Σ
            if ch == "Σ" || ch == "∑" {
                tokens.append(.sum)
                pos += 1
                continue
            }
            
            // Product Π
            if ch == "Π" || ch == "∏" {
                tokens.append(.product)
                pos += 1
                continue
            }
            
            // Infinity ∞
            if ch == "∞" {
                tokens.append(.infinity)
                pos += 1
                continue
            }
            
            // Arrow →
            if ch == "→" {
                tokens.append(.arrow)
                pos += 1
                continue
            }
            if ch == "-" && pos + 1 < input.count && input[pos + 1] == ">" {
                tokens.append(.arrow)
                pos += 2
                continue
            }
            
            // Letters: variables, functions, keywords
            if ch.isLetter || ch == "_" {
                let word = readWord()
                let tok = classifyWord(word)
                // Insert implicit multiplication: 3x, )x, x(, etc.
                if let last = tokens.last, needsImplicitMul(last, before: tok) {
                    tokens.append(.star)
                }
                tokens.append(tok)
                continue
            }
            
            // Operators and punctuation
            let tok: Token
            switch ch {
            case "+": tok = .plus
            case "-": tok = .minus
            case "*": tok = .star
            case "×": tok = .cross
            case "·": tok = .dot
            case "/": tok = .slash
            case "^": tok = .caret
            case "%": tok = .percent
            case "!": tok = .bang
            case "=": tok = .equals
            case "<":
                if pos + 1 < input.count && input[pos + 1] == "=" {
                    pos += 1
                    tok = .lessEqual
                } else {
                    tok = .less
                }
            case ">":
                if pos + 1 < input.count && input[pos + 1] == "=" {
                    pos += 1
                    tok = .greaterEqual
                } else {
                    tok = .greater
                }
            case ":":
                if pos + 1 < input.count && input[pos + 1] == "=" {
                    pos += 1
                    tok = .assign
                } else {
                    tok = .colon
                }
            case ",": tok = .comma
            case ";": tok = .semicolon
            case "(":
                // Insert implicit mul: 2(, x(, )(
                if let last = tokens.last, needsImplicitMul(last, before: .lparen) {
                    tokens.append(.star)
                }
                tok = .lparen
            case ")": tok = .rparen
            case "[":
                if let last = tokens.last, needsImplicitMul(last, before: .lbracket) {
                    tokens.append(.star)
                }
                tok = .lbracket
            case "]": tok = .rbracket
            case "{": tok = .lbrace
            case "}": tok = .rbrace
            case "|": tok = .pipe
            case "_": tok = .underscore
            default:
                throw TokenError.unexpectedCharacter(ch, pos)
            }
            tokens.append(tok)
            pos += 1
        }
        
        tokens.append(.eof)
        return tokens
    }
    
    // MARK: - Number Reading
    
    private mutating func readNumber() throws -> Token {
        let start = pos
        var hasDecimal = false
        var isScientific = false
        
        // Integer part
        while pos < input.count && input[pos].isNumber {
            pos += 1
        }
        
        // Decimal part
        if pos < input.count && input[pos] == "." {
            hasDecimal = true
            pos += 1
            while pos < input.count && input[pos].isNumber {
                pos += 1
            }
        }
        
        // Scientific notation: 1.5e-3, 2E10
        if pos < input.count && (input[pos] == "e" || input[pos] == "E") {
            // Check it's not just the variable 'e'
            let nextPos = pos + 1
            if nextPos < input.count && (input[nextPos].isNumber || input[nextPos] == "+" || input[nextPos] == "-") {
                isScientific = true
                pos += 1
                if pos < input.count && (input[pos] == "+" || input[pos] == "-") {
                    pos += 1
                }
                while pos < input.count && input[pos].isNumber {
                    pos += 1
                }
            }
        }
        
        let str = String(input[start..<pos])
        guard let value = Double(str) else {
            throw TokenError.invalidNumber(str, start)
        }
        
        // Return integer token if it's an exact integer
        if !hasDecimal && !isScientific && value == Double(Int(value)) && Swift.abs(value) < 1e15 {
            return .integer(Int(value))
        }
        return .number(value)
    }
    
    // MARK: - Word Reading
    
    private mutating func readWord() -> String {
        let start = pos
        while pos < input.count && (input[pos].isLetter || input[pos].isNumber || input[pos] == "_") {
            pos += 1
        }
        return String(input[start..<pos])
    }
    
    // MARK: - Word Classification
    
    private func classifyWord(_ word: String) -> Token {
        // Keywords
        switch word.lowercased() {
        case "inf", "infinity": return .infinity
        case "to": return .to
        case "lim", "limit": return .limitToken
        case "sum": return .sum
        case "prod": return .product
        default: break
        }
        
        // Differential notation: dx, dy, dt, dz, dr, du, dv, dw, dθ
        if word.count == 2 && word.hasPrefix("d") && word.last!.isLetter {
            let varName = String(word.dropFirst())
            return .differential(varName)
        }
        
        // Well-known functions
        let functions: Set<String> = [
            "sin", "cos", "tan", "csc", "sec", "cot",
            "asin", "acos", "atan", "acsc", "asec", "acot",
            "arcsin", "arccos", "arctan", "arccsc", "arcsec", "arccot",
            "sinh", "cosh", "tanh", "csch", "sech", "coth",
            "asinh", "acosh", "atanh", "acsch", "asech", "acoth",
            "arcsinh", "arccosh", "arctanh",
            "exp", "ln", "log", "log2", "log10",
            "sqrt", "cbrt", "abs", "sign", "sgn",
            "floor", "ceil", "round",
            "gamma", "lgamma", "beta", "digamma",
            "erf", "erfc", "erfi",
            "Si", "Ci", "li", "Ei",
            "besselJ", "besselY", "besselI", "besselK",
            "Ai", "Bi",
            "legendreP", "hermiteH", "laguerreL", "chebyshevT", "chebyshevU",
            "lambertW", "zeta",
            "real", "imag", "conj", "arg",
            "max", "min", "gcd", "lcm", "mod",
            "factorial", "binomial", "nCr", "nPr",
            "det", "trace", "rank", "inv", "transpose",
            "laplace", "ilaplace", "fourier", "ifourier", "ztransform",
            "diff", "integrate", "limit",
            "solve", "simplify", "expand", "factor", "collect",
        ]
        
        // Canonical names
        let canonical: [String: String] = [
            "arcsin": "asin", "arccos": "acos", "arctan": "atan",
            "arccsc": "acsc", "arcsec": "asec", "arccot": "acot",
            "arcsinh": "asinh", "arccosh": "acosh", "arctanh": "atanh",
            "sgn": "sign", "ln": "ln", "log": "log",
        ]
        
        let lower = word.lowercased()
        if functions.contains(lower) || functions.contains(word) {
            let name = canonical[lower] ?? (functions.contains(lower) ? lower : word)
            return .functionName(name)
        }
        
        // Constants
        switch word {
        case "pi":           return .constant("__const_pi")
        case "tau":          return .constant("__const_tau")
        case "e":            return .constant("__const_e")
        case "i":            return .constant("__const_i")
        case "phi":          return .constant("__const_phi")
        case "euler_gamma":  return .constant("__const_euler_gamma")
        case "true":         return .integer(1)
        case "false":        return .integer(0)
        default: break
        }
        
        // If next char is '(' it's probably a function
        if pos < input.count && input[pos] == "(" {
            return .functionName(word)
        }
        
        return .variable(word)
    }
    
    // MARK: - Implicit Multiplication
    
    /// Determines if implicit multiplication should be inserted between two adjacent tokens.
    /// E.g. 2x → 2*x,  x(y) → x*(y),  )(  → )*(,  2sin(x) → 2*sin(x)
    private func needsImplicitMul(_ left: Token, before right: Token) -> Bool {
        let leftIsValue: Bool = {
            switch left {
            case .number, .integer, .variable, .constant, .rparen, .rbracket, .bang, .infinity:
                return true
            default: return false
            }
        }()
        
        let rightIsValue: Bool = {
            switch right {
            case .number(.._), .integer, .variable, .constant, .lparen, .lbracket, .functionName, .pipe, .integral, .sum, .product:
                return true
            default: return false
            }
        }()
        
        return leftIsValue && rightIsValue
    }
}

// MARK: - Token Error

enum TokenError: LocalizedError {
    case unexpectedCharacter(Character, Int)
    case invalidNumber(String, Int)
    case unterminatedString(Int)
    
    var errorDescription: String? {
        switch self {
        case .unexpectedCharacter(let ch, let pos):
            return "Carácter inesperado '\(ch)' en posición \(pos)"
        case .invalidNumber(let s, let pos):
            return "Número inválido '\(s)' en posición \(pos)"
        case .unterminatedString(let pos):
            return "Cadena sin terminar en posición \(pos)"
        }
    }
}
