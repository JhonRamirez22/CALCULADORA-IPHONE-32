// SmartCorrector.swift
// CalcPrime — MathDF iOS
// Autocorrection engine that transforms natural math input into parseable expressions.
// Replicates MathDF's smart input: 2sinx → 2*sin(x), y'3 → y''', etc.

import Foundation

struct SmartCorrector {
    
    // ═══════════════════════════════════════════
    // MARK: - Main Correction Pipeline
    // ═══════════════════════════════════════════
    
    /// Apply all corrections and return the normalized expression.
    static func correct(_ input: String) -> CorrectionResult {
        var text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return CorrectionResult(corrected: "", latex: "", isValid: false, message: nil) }
        
        // Pipeline order matters
        text = normalizeUnicode(text)
        text = applySpanishSynonyms(text)
        text = applyGreekLetters(text)
        text = applyDerivativeNotation(text)
        text = applyFunctionSynonyms(text)
        text = applyImplicitMultiplication(text)
        text = applyParenthesesCorrection(text)
        text = applySubscripts(text)
        text = applyPowerNotation(text)
        text = applyLogNotation(text)
        text = applySqrtNotation(text)
        
        // Validate
        let validation = validate(text)
        let latex = toLatex(text)
        
        return CorrectionResult(
            corrected: text,
            latex: latex,
            isValid: validation.isValid,
            message: validation.message
        )
    }
    
    /// Quick validation without full correction
    static func quickValidate(_ input: String) -> ValidationState {
        let result = correct(input)
        if input.trimmingCharacters(in: .whitespaces).isEmpty { return .empty }
        return result.isValid ? .valid : .invalid(result.message ?? "Expresión inválida")
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Unicode Normalization
    // ═══════════════════════════════════════════
    
    private static func normalizeUnicode(_ s: String) -> String {
        var r = s
        let replacements: [(String, String)] = [
            ("÷", "/"), ("−", "-"), ("×", "*"), ("·", "*"),
            ("²", "^2"), ("³", "^3"), ("⁴", "^4"), ("⁵", "^5"),
            ("⁶", "^6"), ("⁷", "^7"), ("⁸", "^8"), ("⁹", "^9"),
            ("⁰", "^0"), ("¹", "^1"),
            ("⁻¹", "^(-1)"), ("⁻²", "^(-2)"),
            ("₀", "0"), ("₁", "1"), ("₂", "2"), ("₃", "3"),
            ("₄", "4"), ("₅", "5"), ("₆", "6"), ("₇", "7"),
            ("₈", "8"), ("₉", "9"),
            ("√", "sqrt"), ("∛", "cbrt"),
            ("∞", "inf"), ("→", "->"),
            ("≤", "<="), ("≥", ">="), ("≠", "!="),
            ("π", "pi"), ("τ", "tau"),
        ]
        for (from, to) in replacements {
            r = r.replacingOccurrences(of: from, with: to)
        }
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Spanish Synonyms
    // ═══════════════════════════════════════════
    
    private static func applySpanishSynonyms(_ s: String) -> String {
        var r = s
        let synonyms: [(String, String)] = [
            // Trigonometric (Spanish → English)
            ("sen(", "sin("), ("seno(", "sin("),
            ("cos(", "cos("), ("coseno(", "cos("),
            ("tg(", "tan("), ("tang(", "tan("), ("tangente(", "tan("),
            ("ctg(", "cot("), ("cotg(", "cot("),
            ("sec(", "sec("), ("csc(", "csc("), ("cosec(", "csc("),
            // Inverse trig (Spanish)
            ("arcsen(", "arcsin("), ("arcsin(", "asin("),
            ("arcos(", "acos("), ("arccos(", "acos("),
            ("arctg(", "atan("), ("arctan(", "atan("),
            ("arsin(", "asin("), ("arcos(", "acos("), ("artg(", "atan("),
            // Hyperbolic (Spanish)
            ("senh(", "sinh("), ("cosh(", "cosh("),
            ("tgh(", "tanh("), ("tangh(", "tanh("),
            ("ctgh(", "coth("),
            // Inverse hyperbolic
            ("arcsenh(", "asinh("), ("arccosh(", "acosh("), ("arctgh(", "atanh("),
            // Logarithms
            ("lg(", "log10("), ("log(", "log("),
            // Other
            ("raiz(", "sqrt("), ("raíz(", "sqrt("),
            ("modulo(", "abs("), ("módulo(", "abs("),
            ("senx", "sin(x)"), ("cosx", "cos(x)"), ("tgx", "tan(x)"),
        ]
        for (from, to) in synonyms {
            r = r.replacingOccurrences(of: from, with: to)
        }
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Greek Letters
    // ═══════════════════════════════════════════
    
    private static func applyGreekLetters(_ s: String) -> String {
        var r = s
        // Only replace whole words (not inside function names)
        let greeks: [(String, String)] = [
            ("alpha", "α"), ("beta", "β"), ("gamma", "γ"),
            ("delta", "δ"), ("epsilon", "ε"), ("zeta", "ζ"),
            ("eta", "η"), ("theta", "θ"), ("iota", "ι"),
            ("kappa", "κ"), ("lambda", "λ"), ("mu", "μ"),
            ("nu", "ν"), ("xi", "ξ"), ("omicron", "ο"),
            ("rho", "ρ"), ("sigma", "σ"), ("tau", "τ"),
            ("upsilon", "υ"), ("phi", "φ"), ("chi", "χ"),
            ("psi", "ψ"), ("omega", "ω"),
        ]
        for (word, greek) in greeks {
            // Whole-word replacement (avoid replacing inside 'arctan' etc.)
            r = replaceWholeWord(in: r, word: word, with: greek)
        }
        return r
    }
    
    private static func replaceWholeWord(in text: String, word: String, with replacement: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Derivative Notation
    // ═══════════════════════════════════════════
    
    private static func applyDerivativeNotation(_ s: String) -> String {
        var r = s
        
        // y'3 → y''' (prime with order number)
        if let regex = try? NSRegularExpression(pattern: "([a-zA-Z])'+([0-9]+)") {
            let range = NSRange(r.startIndex..., in: r)
            let matches = regex.matches(in: r, range: range)
            for match in matches.reversed() {
                let fullRange = Range(match.range, in: r)!
                let varRange = Range(match.range(at: 1), in: r)!
                let numRange = Range(match.range(at: 2), in: r)!
                let varName = String(r[varRange])
                let existing = r[fullRange].filter { $0 == "'" }.count
                let num = Int(String(r[numRange])) ?? 0
                let totalPrimes = existing + num
                let replacement = varName + String(repeating: "'", count: totalPrimes)
                r.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        // d2y/dx2 → d^2y/dx^2
        if let regex = try? NSRegularExpression(pattern: "d([0-9])([a-zA-Z])/d([a-zA-Z])([0-9])") {
            let range = NSRange(r.startIndex..., in: r)
            let matches = regex.matches(in: r, range: range)
            for match in matches.reversed() {
                let fullRange = Range(match.range, in: r)!
                let order = String(r[Range(match.range(at: 1), in: r)!])
                let fn = String(r[Range(match.range(at: 2), in: r)!])
                let vr = String(r[Range(match.range(at: 3), in: r)!])
                let replacement = "d^\(order)\(fn)/d\(vr)^\(order)"
                r.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        // D[y,x] → dy/dx, D[y,x,2] → d^2y/dx^2
        if let regex = try? NSRegularExpression(pattern: "D\\[([a-zA-Z]),([a-zA-Z])(?:,([0-9]+))?\\]") {
            let range = NSRange(r.startIndex..., in: r)
            let matches = regex.matches(in: r, range: range)
            for match in matches.reversed() {
                let fullRange = Range(match.range, in: r)!
                let fn = String(r[Range(match.range(at: 1), in: r)!])
                let vr = String(r[Range(match.range(at: 2), in: r)!])
                let order: String
                if match.range(at: 3).location != NSNotFound {
                    let n = String(r[Range(match.range(at: 3), in: r)!])
                    order = n == "1" ? "" : "^\(n)"
                } else {
                    order = ""
                }
                let replacement = order.isEmpty ? "d\(fn)/d\(vr)" : "d\(order)\(fn)/d\(vr)\(order)"
                r.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        // Dy, D2y → dy/dx, d^2y/dx^2 (assume x as default variable)
        if let regex = try? NSRegularExpression(pattern: "\\bD([0-9]*)([a-zA-Z])\\b") {
            let range = NSRange(r.startIndex..., in: r)
            let matches = regex.matches(in: r, range: range)
            for match in matches.reversed() {
                let fullRange = Range(match.range, in: r)!
                let numStr = String(r[Range(match.range(at: 1), in: r)!])
                let fn = String(r[Range(match.range(at: 2), in: r)!])
                let order = numStr.isEmpty ? 1 : (Int(numStr) ?? 1)
                let replacement: String
                if order == 1 {
                    replacement = "d\(fn)/dx"
                } else {
                    replacement = "d^\(order)\(fn)/dx^\(order)"
                }
                r.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        // y(n) notation: y(4) → d^4y/dx^4 (only when inside ODE context)
        // Not applied here to avoid conflicts with function calls
        
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Function Synonyms
    // ═══════════════════════════════════════════
    
    private static func applyFunctionSynonyms(_ s: String) -> String {
        var r = s
        // sin^-1(x) → asin(x)
        let inverseFuncs = ["sin", "cos", "tan", "sec", "csc", "cot",
                            "sinh", "cosh", "tanh"]
        for fn in inverseFuncs {
            r = r.replacingOccurrences(of: "\(fn)^-1(", with: "a\(fn)(")
            r = r.replacingOccurrences(of: "\(fn)^(-1)(", with: "a\(fn)(")
        }
        
        // ln^2(x) → (ln(x))^2
        if let regex = try? NSRegularExpression(pattern: "(ln|log|sin|cos|tan|sec|csc|cot)\\^([0-9]+)\\(") {
            let range = NSRange(r.startIndex..., in: r)
            let matches = regex.matches(in: r, range: range)
            for match in matches.reversed() {
                let fullRange = Range(match.range, in: r)!
                let fn = String(r[Range(match.range(at: 1), in: r)!])
                let power = String(r[Range(match.range(at: 2), in: r)!])
                // Find matching paren
                let afterMatch = r.index(fullRange.upperBound, offsetBy: -1)
                if let closeIdx = findMatchingParen(in: r, from: afterMatch) {
                    let inner = String(r[r.index(after: afterMatch)...r.index(before: closeIdx)])
                    let replacement = "(\(fn)(\(inner)))^\(power)"
                    let replaceRange = fullRange.lowerBound...closeIdx
                    r.replaceSubrange(replaceRange, with: replacement)
                }
            }
        }
        
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Implicit Multiplication
    // ═══════════════════════════════════════════
    
    private static func applyImplicitMultiplication(_ s: String) -> String {
        var r = s
        
        let knownFunctions = Set([
            "sin", "cos", "tan", "cot", "sec", "csc",
            "asin", "acos", "atan", "acot", "asec", "acsc",
            "sinh", "cosh", "tanh", "coth", "sech", "csch",
            "asinh", "acosh", "atanh",
            "ln", "log", "log10", "log2", "exp",
            "sqrt", "cbrt", "abs",
            "arcsin", "arccos", "arctan",
            "floor", "ceil", "round",
            "gamma", "beta", "erf", "erfc"
        ])
        
        // 2sinx → 2*sin(x), 3e^x → 3*e^(x)
        // Pattern: digit immediately followed by letter (that starts a function or variable)
        var result = ""
        let chars = Array(r)
        var i = 0
        
        while i < chars.count {
            result.append(chars[i])
            
            if i + 1 < chars.count {
                let cur = chars[i]
                let next = chars[i + 1]
                
                // digit followed by letter (not exponent notation like 3e5)
                if cur.isNumber && next.isLetter && next != "e" {
                    // Check if it's a function name ahead
                    let remaining = String(chars[(i+1)...])
                    let isFunc = knownFunctions.contains(where: { remaining.hasPrefix($0) })
                    if isFunc || next.isLetter {
                        result.append("*")
                    }
                }
                // ) followed by ( → )*(
                else if cur == ")" && next == "(" {
                    result.append("*")
                }
                // ) followed by letter → )*letter
                else if cur == ")" && next.isLetter {
                    result.append("*")
                }
                // letter/digit followed by ( — only insert * if not a function name
                else if (cur.isLetter || cur.isNumber) && next == "(" {
                    let word = extractWordBackward(from: result)
                    if !knownFunctions.contains(word) && !word.isEmpty && word.count == 1 {
                        // Single variable followed by ( → x*(
                        // But not for things like y(x) which is function application
                    }
                }
                // digit immediately after )
                else if cur == ")" && next.isNumber {
                    result.append("*")
                }
            }
            
            i += 1
        }
        
        r = result
        
        // Handle specific patterns:
        // sinx → sin(x), cosx → cos(x), etc.
        for fn in knownFunctions {
            // fnx → fn(x) when followed by single variable letter
            if let regex = try? NSRegularExpression(pattern: "\\b\(fn)([a-z])\\b(?!\\()") {
                let range = NSRange(r.startIndex..., in: r)
                r = regex.stringByReplacingMatches(in: r, range: range,
                                                    withTemplate: "\(fn)($1)")
            }
        }
        
        return r
    }
    
    private static func extractWordBackward(from s: String) -> String {
        var word = ""
        for ch in s.reversed() {
            if ch.isLetter { word.insert(ch, at: word.startIndex) }
            else { break }
        }
        return word
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Parentheses Auto-close
    // ═══════════════════════════════════════════
    
    private static func applyParenthesesCorrection(_ s: String) -> String {
        var open = 0
        for ch in s {
            if ch == "(" { open += 1 }
            if ch == ")" { open -= 1 }
        }
        
        if open > 0 {
            return s + String(repeating: ")", count: open)
        }
        return s
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Subscripts: a123 → a₁₂₃
    // ═══════════════════════════════════════════
    
    private static func applySubscripts(_ s: String) -> String {
        // This is mainly for LaTeX display, internal representation uses a_123
        return s
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Power Notation
    // ═══════════════════════════════════════════
    
    private static func applyPowerNotation(_ s: String) -> String {
        var r = s
        // e^2x → e^(2*x)
        if let regex = try? NSRegularExpression(pattern: "e\\^([0-9]+)([a-zA-Z])(?!\\^|[0-9])") {
            let range = NSRange(r.startIndex..., in: r)
            r = regex.stringByReplacingMatches(in: r, range: range,
                                                withTemplate: "e^($1*$2)")
        }
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Log Notation
    // ═══════════════════════════════════════════
    
    private static func applyLogNotation(_ s: String) -> String {
        var r = s
        // log3(x) → log(3,x), log(a,x) already handled by parser
        if let regex = try? NSRegularExpression(pattern: "log([0-9]+)\\(") {
            let range = NSRange(r.startIndex..., in: r)
            r = regex.stringByReplacingMatches(in: r, range: range,
                                                withTemplate: "log($1,")
        }
        // lnx → ln(x) — already handled by implicit multiplication
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Sqrt Notation
    // ═══════════════════════════════════════════
    
    private static func applySqrtNotation(_ s: String) -> String {
        var r = s
        // sqrt7(x) → nthroot(7,x)
        if let regex = try? NSRegularExpression(pattern: "sqrt([0-9]+)\\(") {
            let range = NSRange(r.startIndex..., in: r)
            r = regex.stringByReplacingMatches(in: r, range: range,
                                                withTemplate: "nthroot($1,")
        }
        // sqrt(n,x) → nthroot(n,x) — pass through to parser
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Validation
    // ═══════════════════════════════════════════
    
    private static func validate(_ text: String) -> (isValid: Bool, message: String?) {
        // Check balanced parentheses
        var depth = 0
        for ch in text {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth -= 1 }
            if depth < 0 { return (false, "Paréntesis de cierre sin apertura") }
        }
        if depth != 0 { return (false, "Paréntesis no cerrado") }
        
        // Check balanced brackets
        depth = 0
        for ch in text {
            if ch == "[" { depth += 1 }
            if ch == "]" { depth -= 1 }
            if depth < 0 { return (false, "Corchete de cierre sin apertura") }
        }
        if depth != 0 { return (false, "Corchete no cerrado") }
        
        // Check empty parentheses
        if text.contains("()") { return (false, "Paréntesis vacíos") }
        
        // Check consecutive operators
        if let regex = try? NSRegularExpression(pattern: "[+\\-*/^]{2,}") {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                // Allow -- (double negative) and -+ etc.
                if let strictRegex = try? NSRegularExpression(pattern: "[+*/^]{2,}") {
                    if strictRegex.firstMatch(in: text, range: range) != nil {
                        return (false, "Operadores consecutivos")
                    }
                }
            }
        }
        
        // Try to parse
        do {
            _ = try Parser.parse(text)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    // ═══════════════════════════════════════════
    // MARK: - LaTeX Conversion
    // ═══════════════════════════════════════════
    
    private static func toLatex(_ text: String) -> String {
        // Try full parse → AST → .latex
        do {
            let node = try Parser.parse(text)
            return node.latex
        } catch {
            // Fallback: simple text replacements
            return simpleFallbackLatex(text)
        }
    }
    
    private static func simpleFallbackLatex(_ text: String) -> String {
        var r = text
        r = r.replacingOccurrences(of: "*", with: " \\cdot ")
        r = r.replacingOccurrences(of: "sqrt(", with: "\\sqrt{")
        r = r.replacingOccurrences(of: "pi", with: "\\pi")
        r = r.replacingOccurrences(of: "inf", with: "\\infty")
        return r
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Helper
    // ═══════════════════════════════════════════
    
    private static func findMatchingParen(in text: String, from idx: String.Index) -> String.Index? {
        guard idx < text.endIndex, text[idx] == "(" else { return nil }
        var depth = 0
        var i = idx
        while i < text.endIndex {
            if text[i] == "(" { depth += 1 }
            if text[i] == ")" { depth -= 1 }
            if depth == 0 { return i }
            i = text.index(after: i)
        }
        return nil
    }
}

// MARK: - Correction Result

struct CorrectionResult {
    let corrected: String
    let latex: String
    let isValid: Bool
    let message: String?
}
