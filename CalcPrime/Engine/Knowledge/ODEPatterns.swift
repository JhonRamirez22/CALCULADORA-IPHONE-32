// ODEPatterns.swift
// CalcPrime — Engine/Knowledge
// Pattern-matching database for ODE classification and solution selection.
// Used by ODESolver to identify ODE type before applying solution methods.

import Foundation

// MARK: - ODE Classification

enum ODEType: String, CaseIterable {
    case separable           = "Separable"
    case linear1stOrder      = "Lineal de primer orden"
    case exact               = "Exacta"
    case bernoulli           = "Bernoulli"
    case homogeneous         = "Homogénea"
    case riccati             = "Riccati"
    case clairaut            = "Clairaut"
    case linear2ndConst      = "Lineal 2do orden coeficientes constantes"
    case cauchyEuler         = "Cauchy-Euler"
    case reducibleOrder      = "Reducible de orden"
    case linearHigherOrder   = "Lineal de orden superior"
    case system              = "Sistema de EDOs"
    case undeterminedCoeff   = "Coeficientes indeterminados"
    case variationOfParams   = "Variación de parámetros"
    case powerSeries         = "Series de potencias"
    case laplace             = "Transformada de Laplace"
    case numerical           = "Método numérico"
    case unknown             = "Tipo desconocido"
    
    var description: String {
        switch self {
        case .separable: return "dy/dx = f(x)·g(y) — Las variables se pueden separar"
        case .linear1stOrder: return "dy/dx + P(x)·y = Q(x) — Lineal de primer orden"
        case .exact: return "M(x,y)dx + N(x,y)dy = 0 donde ∂M/∂y = ∂N/∂x"
        case .bernoulli: return "dy/dx + P(x)·y = Q(x)·y^n — Ecuación de Bernoulli"
        case .homogeneous: return "dy/dx = F(y/x) — Ecuación homogénea"
        case .riccati: return "dy/dx = P(x) + Q(x)·y + R(x)·y² — Ecuación de Riccati"
        case .clairaut: return "y = x·y' + f(y') — Ecuación de Clairaut"
        case .linear2ndConst: return "ay'' + by' + cy = f(x) — Coeficientes constantes"
        case .cauchyEuler: return "x²y'' + bxy' + cy = f(x) — Cauchy-Euler"
        case .reducibleOrder: return "Se puede reducir el orden con sustitución"
        case .linearHigherOrder: return "Ecuación lineal de orden n > 2"
        case .system: return "Sistema de ecuaciones diferenciales"
        case .undeterminedCoeff: return "Método de coeficientes indeterminados"
        case .variationOfParams: return "Método de variación de parámetros"
        case .powerSeries: return "Solución por series de potencias"
        case .laplace: return "Solución por transformada de Laplace"
        case .numerical: return "Solución numérica (Runge-Kutta, etc.)"
        case .unknown: return "No se pudo clasificar la ecuación"
        }
    }
    
    var methods: [String] {
        switch self {
        case .separable: return ["Separación de variables", "Integración directa"]
        case .linear1stOrder: return ["Factor integrante μ(x) = e^{∫P(x)dx}", "Método directo"]
        case .exact: return ["∂F/∂x = M, ∂F/∂y = N → F(x,y) = C", "Factor integrante si no es exacta"]
        case .bernoulli: return ["Sustitución v = y^{1-n}", "Reducción a lineal"]
        case .homogeneous: return ["Sustitución v = y/x", "Reducción a separable"]
        case .riccati: return ["Conocida una solución particular y₁", "Sustitución y = y₁ + 1/v"]
        case .clairaut: return ["Familia general y = Cx + f(C)", "Envolvente (solución singular)"]
        case .linear2ndConst: return ["Ecuación característica", "Coeficientes indeterminados", "Variación de parámetros"]
        case .cauchyEuler: return ["Sustitución x = e^t", "Ecuación indicial"]
        case .reducibleOrder: return ["v = y'", "v = y'/y"]
        case .linearHigherOrder: return ["Ecuación característica", "Wronskiano"]
        case .system: return ["Valores propios", "Diagonalización", "Exponencial de matrices"]
        case .undeterminedCoeff: return ["Proponer solución particular por forma de f(x)"]
        case .variationOfParams: return ["yp = u₁y₁ + u₂y₂ con Wronskiano"]
        case .powerSeries: return ["y = Σ aₙxⁿ, sustituir y resolver recurrencia"]
        case .laplace: return ["L{y} → resolver en s → L⁻¹"]
        case .numerical: return ["Euler", "RK4", "RKF45", "Adams-Bashforth"]
        case .unknown: return ["Intentar métodos numéricos"]
        }
    }
}

// MARK: - ODE Pattern

struct ODEPattern {
    let type: ODEType
    let order: Int
    let matcher: (ExprNode, String, String) -> Bool  // (equation, yVar, xVar) -> matches?
    let extractor: (ExprNode, String, String) -> [String: ExprNode]?  // Extract components
}

// MARK: - ODEPatterns Database

struct ODEPatterns {
    
    /// Classify an ODE equation.
    static func classify(_ equation: ExprNode, function y: String, variable x: String) -> ODEType {
        for pattern in patterns {
            if pattern.matcher(equation, y, x) {
                return pattern.type
            }
        }
        return .unknown
    }
    
    /// Get the order of the ODE (highest derivative).
    static func order(of equation: ExprNode, function y: String, variable x: String) -> Int {
        var maxOrder = 0
        findMaxDerivativeOrder(equation, y: y, x: x, currentMax: &maxOrder)
        return maxOrder
    }
    
    /// Get recommended solution methods for the classified type.
    static func recommendedMethods(for type: ODEType) -> [String] {
        type.methods
    }
    
    /// Get Spanish explanation of the ODE type.
    static func explanation(for type: ODEType) -> String {
        type.description
    }
    
    /// Try to extract standard form components.
    static func extractComponents(_ equation: ExprNode, function y: String, variable x: String) -> [String: ExprNode]? {
        for pattern in patterns {
            if pattern.matcher(equation, y, x) {
                return pattern.extractor(equation, y, x)
            }
        }
        return nil
    }
    
    // MARK: - Pattern Database
    
    private static let patterns: [ODEPattern] = [
        
        // ─── Separable: dy/dx = f(x)·g(y) ───
        ODEPattern(
            type: .separable,
            order: 1,
            matcher: { eq, y, x in
                // Check if RHS is a product of function of x only and function of y only
                guard let rhs = extractRHS(eq, y, x) else { return false }
                return isSeparable(rhs, y: y, x: x)
            },
            extractor: { eq, y, x in
                guard let rhs = extractRHS(eq, y, x) else { return nil }
                return ["rhs": rhs]
            }
        ),
        
        // ─── Linear 1st Order: y' + P(x)·y = Q(x) ───
        ODEPattern(
            type: .linear1stOrder,
            order: 1,
            matcher: { eq, y, x in
                return isLinear1st(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                return extractLinear1st(eq, y: y, x: x)
            }
        ),
        
        // ─── Exact: M dx + N dy = 0 ───
        ODEPattern(
            type: .exact,
            order: 1,
            matcher: { eq, y, x in
                return isExact(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                return extractExact(eq, y: y, x: x)
            }
        ),
        
        // ─── Bernoulli: y' + P(x)·y = Q(x)·y^n ───
        ODEPattern(
            type: .bernoulli,
            order: 1,
            matcher: { eq, y, x in
                return isBernoulli(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                return extractBernoulli(eq, y: y, x: x)
            }
        ),
        
        // ─── Homogeneous: dy/dx = F(y/x) ───
        ODEPattern(
            type: .homogeneous,
            order: 1,
            matcher: { eq, y, x in
                return isHomogeneous(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                guard let rhs = extractRHS(eq, y, x) else { return nil }
                return ["rhs": rhs]
            }
        ),
        
        // ─── Linear 2nd order constant coefficients ───
        ODEPattern(
            type: .linear2ndConst,
            order: 2,
            matcher: { eq, y, x in
                return isLinear2ndConst(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                return extractLinear2ndConst(eq, y: y, x: x)
            }
        ),
        
        // ─── Cauchy-Euler: x²y'' + bxy' + cy = f(x) ───
        ODEPattern(
            type: .cauchyEuler,
            order: 2,
            matcher: { eq, y, x in
                return isCauchyEuler(eq, y: y, x: x)
            },
            extractor: { eq, y, x in
                return extractCauchyEuler(eq, y: y, x: x)
            }
        ),
    ]
    
    // MARK: - Helper: Find Max Derivative Order
    
    private static func findMaxDerivativeOrder(_ expr: ExprNode, y: String, x: String, currentMax: inout Int) {
        switch expr {
        case .derivative(let f, let v, let order):
            if v == x {
                // Check if f involves y
                if case .variable(let s) = f, s == y { currentMax = Swift.max(currentMax, order) }
                else if case .function(_, _) = f { currentMax = Swift.max(currentMax, order) }
            }
            findMaxDerivativeOrder(f, y: y, x: x, currentMax: &currentMax)
        case .add(let terms):
            for t in terms { findMaxDerivativeOrder(t, y: y, x: x, currentMax: &currentMax) }
        case .multiply(let factors):
            for f in factors { findMaxDerivativeOrder(f, y: y, x: x, currentMax: &currentMax) }
        case .power(let base, let exp):
            findMaxDerivativeOrder(base, y: y, x: x, currentMax: &currentMax)
            findMaxDerivativeOrder(exp, y: y, x: x, currentMax: &currentMax)
        case .negate(let inner):
            findMaxDerivativeOrder(inner, y: y, x: x, currentMax: &currentMax)
        case .function(_, let args):
            for a in args { findMaxDerivativeOrder(a, y: y, x: x, currentMax: &currentMax) }
        default:
            break
        }
    }
    
    // MARK: - Pattern Checkers
    
    /// Extract RHS from y' = RHS or y' - RHS = 0
    private static func extractRHS(_ eq: ExprNode, _ y: String, _ x: String) -> ExprNode? {
        // If equation form: derivative(...) = RHS
        if case .equation(let lhs, let rhs) = eq {
            if containsDerivative(lhs, y: y, x: x) {
                return rhs
            }
        }
        return nil
    }
    
    /// Check if expression contains derivative of y w.r.t. x
    private static func containsDerivative(_ expr: ExprNode, y: String, x: String) -> Bool {
        switch expr {
        case .derivative(let f, let v, _):
            if case .variable(let s) = f, s == y, v == x { return true }
            return containsDerivative(f, y: y, x: x)
        case .add(let terms):
            return terms.contains { containsDerivative($0, y: y, x: x) }
        case .multiply(let factors):
            return factors.contains { containsDerivative($0, y: y, x: x) }
        case .negate(let inner):
            return containsDerivative(inner, y: y, x: x)
        default:
            return false
        }
    }
    
    /// Check if RHS is separable: f(x)·g(y)
    private static func isSeparable(_ rhs: ExprNode, y: String, x: String) -> Bool {
        let vars = rhs.freeVariables
        // If only x or only y, it's trivially separable
        if !vars.contains(y) || !vars.contains(x) { return true }
        // If product form, check factors
        if case .multiply(let factors) = rhs {
            let xFactors = factors.filter { !$0.freeVariables.contains(y) }
            let yFactors = factors.filter { !$0.freeVariables.contains(x) }
            if xFactors.count + yFactors.count == factors.count { return true }
        }
        return false
    }
    
    /// Check if ODE is linear 1st order
    private static func isLinear1st(_ eq: ExprNode, y: String, x: String) -> Bool {
        // y' + P(x)y = Q(x): y appears linearly, no y·y' terms
        guard case .equation(let lhs, _) = eq else { return false }
        return containsDerivative(lhs, y: y, x: x) && !containsNonlinearY(lhs, y: y)
    }
    
    private static func extractLinear1st(_ eq: ExprNode, y: String, x: String) -> [String: ExprNode]? {
        // Simplified extraction
        guard case .equation(_, let rhs) = eq else { return nil }
        return ["Q": rhs]
    }
    
    /// Check for nonlinear y terms (y², y·y', etc.)
    private static func containsNonlinearY(_ expr: ExprNode, y: String) -> Bool {
        if case .power(let b, let n) = expr, case .variable(let s) = b, s == y,
           let nv = n.numericValue, nv != 1 { return true }
        if case .multiply(let fs) = expr {
            let yCount = fs.filter { if case .variable(let s) = $0, s == y { return true }; return false }.count
            if yCount > 1 { return true }
        }
        if case .add(let terms) = expr { return terms.contains { containsNonlinearY($0, y: y) } }
        if case .multiply(let fs) = expr { return fs.contains { containsNonlinearY($0, y: y) } }
        return false
    }
    
    /// Check if exact
    private static func isExact(_ eq: ExprNode, y: String, x: String) -> Bool {
        // Would need M and N extraction and partial derivative check
        // Simplified: return false, ODESolver handles this
        return false
    }
    
    private static func extractExact(_ eq: ExprNode, y: String, x: String) -> [String: ExprNode]? { nil }
    
    /// Check if Bernoulli
    private static func isBernoulli(_ eq: ExprNode, y: String, x: String) -> Bool {
        // y' + P(x)y = Q(x)y^n with n ≠ 0, 1
        guard case .equation(_, let rhs) = eq else { return false }
        // Check if RHS has y^n factor
        if case .multiply(let fs) = rhs {
            return fs.contains {
                if case .power(let b, let n) = $0, case .variable(let s) = b, s == y,
                   let nv = n.numericValue, nv != 0, nv != 1 { return true }
                return false
            }
        }
        return false
    }
    
    private static func extractBernoulli(_ eq: ExprNode, y: String, x: String) -> [String: ExprNode]? {
        guard case .equation(_, let rhs) = eq else { return nil }
        if case .multiply(let fs) = rhs {
            let yPower = fs.first {
                if case .power(let b, _) = $0, case .variable(let s) = b, s == y { return true }
                return false
            }
            if case .power(_, let n) = yPower {
                return ["n": n]
            }
        }
        return nil
    }
    
    /// Check if homogeneous
    private static func isHomogeneous(_ eq: ExprNode, y: String, x: String) -> Bool {
        guard let rhs = extractRHS(eq, y, x) else { return false }
        let vars = rhs.freeVariables
        return vars.contains(y) && vars.contains(x) // Simplified check
    }
    
    /// Check if 2nd order linear constant coefficients
    private static func isLinear2ndConst(_ eq: ExprNode, y: String, x: String) -> Bool {
        var maxOrd = 0
        findMaxDerivativeOrder(eq, y: y, x: x, currentMax: &maxOrd)
        return maxOrd == 2
    }
    
    private static func extractLinear2ndConst(_ eq: ExprNode, y: String, x: String) -> [String: ExprNode]? {
        guard case .equation(_, let rhs) = eq else { return nil }
        return ["f": rhs]
    }
    
    /// Check if Cauchy-Euler
    private static func isCauchyEuler(_ eq: ExprNode, y: String, x: String) -> Bool {
        // x²y'' + bxy' + cy = f(x): Look for x² multiplying y''
        // Simplified check
        return false
    }
    
    private static func extractCauchyEuler(_ eq: ExprNode, y: String, x: String) -> [String: ExprNode]? { nil }
    
    // MARK: - Common ODE Forms Database
    
    struct KnownODE {
        let name: String
        let equation: String
        let solution: String
        let latex: String
    }
    
    /// Database of commonly encountered ODEs with known solutions.
    static let knownODEs: [KnownODE] = [
        KnownODE(name: "Crecimiento exponencial",
                 equation: "y' = ky",
                 solution: "y = Ce^{kx}",
                 latex: "y = Ce^{kx}"),
        KnownODE(name: "Decaimiento exponencial",
                 equation: "y' = -ky",
                 solution: "y = Ce^{-kx}",
                 latex: "y = Ce^{-kx}"),
        KnownODE(name: "Crecimiento logístico",
                 equation: "y' = ky(1-y/L)",
                 solution: "y = L/(1+Ce^{-kx})",
                 latex: "y = \\frac{L}{1+Ce^{-kx}}"),
        KnownODE(name: "Oscilador armónico simple",
                 equation: "y'' + ω²y = 0",
                 solution: "y = C₁cos(ωx) + C₂sin(ωx)",
                 latex: "y = C_1\\cos(\\omega x) + C_2\\sin(\\omega x)"),
        KnownODE(name: "Oscilador amortiguado",
                 equation: "y'' + 2γy' + ω²y = 0",
                 solution: "Depende de γ vs ω (sub/sobre/críticamente amortiguado)",
                 latex: "y'' + 2\\gamma y' + \\omega^2 y = 0"),
        KnownODE(name: "Ecuación de Airy",
                 equation: "y'' - xy = 0",
                 solution: "y = C₁Ai(x) + C₂Bi(x)",
                 latex: "y = C_1 \\text{Ai}(x) + C_2 \\text{Bi}(x)"),
        KnownODE(name: "Ecuación de Bessel",
                 equation: "x²y'' + xy' + (x²-n²)y = 0",
                 solution: "y = C₁Jₙ(x) + C₂Yₙ(x)",
                 latex: "y = C_1 J_n(x) + C_2 Y_n(x)"),
        KnownODE(name: "Ecuación de Legendre",
                 equation: "(1-x²)y'' - 2xy' + n(n+1)y = 0",
                 solution: "y = C₁Pₙ(x) + C₂Qₙ(x)",
                 latex: "y = C_1 P_n(x) + C_2 Q_n(x)"),
        KnownODE(name: "Ecuación de Hermite",
                 equation: "y'' - 2xy' + 2ny = 0",
                 solution: "y = Hₙ(x) (polinomios de Hermite)",
                 latex: "y = H_n(x)"),
        KnownODE(name: "Ecuación de Laguerre",
                 equation: "xy'' + (1-x)y' + ny = 0",
                 solution: "y = Lₙ(x) (polinomios de Laguerre)",
                 latex: "y = L_n(x)"),
        KnownODE(name: "Ecuación de Chebyshev",
                 equation: "(1-x²)y'' - xy' + n²y = 0",
                 solution: "y = C₁Tₙ(x) + C₂Uₙ(x)",
                 latex: "y = C_1 T_n(x) + C_2 U_n(x)"),
        KnownODE(name: "Ecuación de Euler-Cauchy (2do orden)",
                 equation: "x²y'' + bxy' + cy = 0",
                 solution: "y = x^r (ecuación indicial r²+(b-1)r+c=0)",
                 latex: "y = x^r"),
    ]
}
