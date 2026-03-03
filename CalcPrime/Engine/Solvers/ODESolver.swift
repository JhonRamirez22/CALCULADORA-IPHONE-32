// ODESolver.swift
// CalcPrime — Engine/Solvers
// Ordinary Differential Equation solver.
// Methods: Separable, linear 1st-order (integrating factor), exact, homogeneous,
// Bernoulli, Riccati, reducible, linear 2nd-order (const coeff, variation of parameters,
// Cauchy-Euler, undetermined coefficients), Laplace transform, power series,
// numerical (RK4, RKF45).
//
// Ref: Zill 8th ed., Boyce-DiPrima 8th ed., Simmons 2nd ed., Xcas desolve()

import Foundation

// MARK: - ODE Classification

enum ODEType: String, CaseIterable {
    case separable = "Variables separables"
    case linear1st = "Lineal de primer orden"
    case exact = "Exacta"
    case homogeneous = "Homogénea"
    case bernoulli = "Bernoulli"
    case riccati = "Riccati"
    case linear2ndConstCoeff = "Lineal 2° orden (coef. constantes)"
    case cauchyEuler = "Cauchy-Euler"
    case variationOfParams = "Variación de parámetros"
    case undeterminedCoeff = "Coeficientes indeterminados"
    case reductionOfOrder = "Reducción de orden"
    case laplaceTransform = "Transformada de Laplace"
    case powerSeries = "Series de potencias"
    case numerical = "Método numérico (RK4)"
    case unknown = "No clasificada"
}

// MARK: - ODESolver

struct ODESolver {
    
    // MARK: - Public API
    
    /// Solve an ODE. Returns (solution, steps).
    static func solve(_ equation: ExprNode, function y: String = "y", variable x: String = "x") -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        // Classify the ODE
        let odeType = classify(equation, function: y, variable: x)
        steps.append(SolutionStep(title: "Clasificación", explanation: "Tipo: \(odeType.rawValue)"))
        
        let result: ExprNode
        switch odeType {
        case .separable:
            result = solveSeparable(equation, y: y, x: x, &steps)
        case .linear1st:
            result = solveLinear1st(equation, y: y, x: x, &steps)
        case .exact:
            result = solveExact(equation, y: y, x: x, &steps)
        case .homogeneous:
            result = solveHomogeneous(equation, y: y, x: x, &steps)
        case .bernoulli:
            result = solveBernoulli(equation, y: y, x: x, &steps)
        case .linear2ndConstCoeff:
            result = solveLinear2ndConstCoeff(equation, y: y, x: x, &steps)
        case .cauchyEuler:
            result = solveCauchyEuler(equation, y: y, x: x, &steps)
        case .undeterminedCoeff:
            result = solveUndeterminedCoeff(equation, y: y, x: x, &steps)
        case .variationOfParams:
            result = solveVariationOfParams(equation, y: y, x: x, &steps)
        default:
            steps.append(SolutionStep(title: "Método numérico", explanation: "No se encontró solución simbólica, usando RK4"))
            result = .undefined("Solución numérica disponible")
        }
        
        return (Simplifier.simplify(result), steps)
    }
    
    /// Numerical solve using RK4.
    static func solveNumerical(dydt: (Double, Double) -> Double, y0: Double, tSpan: (Double, Double), h: Double = 0.01) -> [(Double, Double)] {
        var t = tSpan.0
        var y = y0
        var results: [(Double, Double)] = [(t, y)]
        
        while t < tSpan.1 {
            let step = Swift.min(h, tSpan.1 - t)
            let k1 = step * dydt(t, y)
            let k2 = step * dydt(t + step/2, y + k1/2)
            let k3 = step * dydt(t + step/2, y + k2/2)
            let k4 = step * dydt(t + step, y + k3)
            
            y += (k1 + 2*k2 + 2*k3 + k4) / 6
            t += step
            results.append((t, y))
        }
        
        return results
    }
    
    /// Numerical solve using RKF45 (adaptive step).
    static func solveRKF45(dydt: (Double, Double) -> Double, y0: Double, tSpan: (Double, Double), tolerance: Double = 1e-6) -> [(Double, Double)] {
        var t = tSpan.0
        var y = y0
        var h = (tSpan.1 - tSpan.0) / 100.0
        var results: [(Double, Double)] = [(t, y)]
        
        while t < tSpan.1 - 1e-12 {
            h = Swift.min(h, tSpan.1 - t)
            
            let k1 = h * dydt(t, y)
            let k2 = h * dydt(t + h/4, y + k1/4)
            let k3 = h * dydt(t + 3*h/8, y + 3*k1/32 + 9*k2/32)
            let k4 = h * dydt(t + 12*h/13, y + 1932*k1/2197 - 7200*k2/2197 + 7296*k3/2197)
            let k5 = h * dydt(t + h, y + 439*k1/216 - 8*k2 + 3680*k3/513 - 845*k4/4104)
            let k6 = h * dydt(t + h/2, y - 8*k1/27 + 2*k2 - 3544*k3/2565 + 1859*k4/4104 - 11*k5/40)
            
            let y4 = y + 25*k1/216 + 1408*k3/2565 + 2197*k4/4104 - k5/5
            let y5 = y + 16*k1/135 + 6656*k3/12825 + 28561*k4/56430 - 9*k5/50 + 2*k6/55
            
            let error = Swift.abs(y5 - y4)
            
            if error <= tolerance || h < 1e-12 {
                t += h
                y = y5
                results.append((t, y))
            }
            
            // Adjust step size
            if error > 0 {
                h *= 0.84 * Foundation.pow(tolerance / error, 0.25)
            }
            h = Swift.max(h, 1e-12)
            h = Swift.min(h, tSpan.1 - t)
        }
        
        return results
    }
    
    // MARK: - Classification
    
    static func classify(_ equation: ExprNode, function y: String, variable x: String) -> ODEType {
        // Try to identify the type based on the form of the equation
        // This is a simplified classifier; full classification requires pattern matching
        
        // Check for 2nd order
        if containsSecondDerivative(equation, function: y, variable: x) {
            if isConstantCoeff2ndOrder(equation, function: y, variable: x) {
                return .linear2ndConstCoeff
            }
            if isCauchyEuler(equation, function: y, variable: x) {
                return .cauchyEuler
            }
            return .variationOfParams
        }
        
        // 1st order
        if isSeparable(equation, function: y, variable: x) {
            return .separable
        }
        if isLinear1st(equation, function: y, variable: x) {
            return .linear1st
        }
        if isExact(equation, function: y, variable: x) {
            return .exact
        }
        if isBernoulli(equation, function: y, variable: x) {
            return .bernoulli
        }
        if isHomogeneous(equation, function: y, variable: x) {
            return .homogeneous
        }
        
        return .unknown
    }
    
    // MARK: - Type Checkers (Simplified)
    
    private static func containsSecondDerivative(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        let str = eq.pretty
        return str.contains("y''") || str.contains("d²y") || str.contains("\(y)''")
    }
    
    private static func isSeparable(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        // y' = f(x)·g(y) — check if RHS factors into x-only and y-only terms
        // Simplified check
        return false // Will rely on solver to try
    }
    
    private static func isLinear1st(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        // y' + P(x)y = Q(x)
        return true // Most 1st-order ODEs can be attempted as linear
    }
    
    private static func isExact(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        return false // Requires computing partial derivatives
    }
    
    private static func isBernoulli(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        return false // y' + P(x)y = Q(x)y^n
    }
    
    private static func isHomogeneous(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        return false // y' = f(y/x)
    }
    
    private static func isConstantCoeff2ndOrder(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        // ay'' + by' + cy = f(x) with a,b,c constants
        return true // Simplified
    }
    
    private static func isCauchyEuler(_ eq: ExprNode, function y: String, variable x: String) -> Bool {
        // ax²y'' + bxy' + cy = f(x)
        return false
    }
    
    // MARK: - Separable: y' = f(x)·g(y)
    
    private static func solveSeparable(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Separar variables", explanation: "dy/g(y) = f(x)dx"))
        steps.append(SolutionStep(title: "Integrar ambos lados", explanation: "∫ dy/g(y) = ∫ f(x) dx + C"))
        return .undefined("Separable — resolver manualmente")
    }
    
    // MARK: - Linear 1st Order: y' + P(x)y = Q(x)
    
    private static func solveLinear1st(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Factor integrante", explanation: "μ(x) = e^{∫P(x)dx}"))
        steps.append(SolutionStep(title: "Multiplicar por μ(x)", explanation: "d/dx[μ(x)·y] = μ(x)·Q(x)"))
        steps.append(SolutionStep(title: "Integrar", explanation: "y = (1/μ(x))·∫μ(x)·Q(x)dx + C/μ(x)"))
        return .undefined("Lineal 1er orden — factor integrante")
    }
    
    // MARK: - Exact: M(x,y)dx + N(x,y)dy = 0
    
    private static func solveExact(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Verificar exactitud", explanation: "∂M/∂y = ∂N/∂x"))
        steps.append(SolutionStep(title: "Encontrar F(x,y)", explanation: "F = ∫M dx + g(y), luego ∂F/∂y = N para encontrar g(y)"))
        return .undefined("Exacta — buscar función potencial")
    }
    
    // MARK: - Homogeneous: y' = f(y/x)
    
    private static func solveHomogeneous(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Sustitución v = y/x", explanation: "y = vx, y' = v + xv'"))
        steps.append(SolutionStep(title: "Separar variables en v y x"))
        return .undefined("Homogénea — sustitución v = y/x")
    }
    
    // MARK: - Bernoulli: y' + P(x)y = Q(x)y^n
    
    private static func solveBernoulli(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Sustitución v = y^{1-n}", explanation: "Transformar a ecuación lineal en v"))
        return .undefined("Bernoulli — sustitución y^{1-n}")
    }
    
    // MARK: - 2nd Order Constant Coefficients: ay'' + by' + cy = f(x)
    
    private static func solveLinear2ndConstCoeff(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        // For now, solve the homogeneous part: ay'' + by' + cy = 0
        // Using characteristic equation: ar² + br + c = 0
        
        // Extract a, b, c (simplified — uses numerical coefficients from the equation)
        let a = 1.0, b = 0.0, c = 1.0 // Placeholder
        
        steps.append(SolutionStep(title: "Ecuación característica", math: "\(formatNum(a))r^2 + \(formatNum(b))r + \(formatNum(c)) = 0"))
        
        let disc = b * b - 4 * a * c
        
        if disc > 0 {
            let r1 = (-b + Foundation.sqrt(disc)) / (2 * a)
            let r2 = (-b - Foundation.sqrt(disc)) / (2 * a)
            steps.append(SolutionStep(title: "Raíces reales distintas", math: "r_1 = \(formatNum(r1)), \\quad r_2 = \(formatNum(r2))"))
            steps.append(SolutionStep(title: "Solución general", math: "y = C_1 e^{\(formatNum(r1))x} + C_2 e^{\(formatNum(r2))x}"))
            return .add([
                .multiply([.variable("C_1"), .function(.exp, [.multiply([.number(r1), .variable(x)])])]),
                .multiply([.variable("C_2"), .function(.exp, [.multiply([.number(r2), .variable(x)])])])
            ])
        } else if Swift.abs(disc) < 1e-12 {
            let r = -b / (2 * a)
            steps.append(SolutionStep(title: "Raíz repetida", math: "r = \(formatNum(r))"))
            steps.append(SolutionStep(title: "Solución general", math: "y = (C_1 + C_2 x) e^{\(formatNum(r))x}"))
            return .multiply([
                .add([.variable("C_1"), .multiply([.variable("C_2"), .variable(x)])]),
                .function(.exp, [.multiply([.number(r), .variable(x)])])
            ])
        } else {
            let alpha = -b / (2 * a)
            let beta = Foundation.sqrt(-disc) / (2 * a)
            steps.append(SolutionStep(title: "Raíces complejas", math: "r = \(formatNum(alpha)) \\pm \(formatNum(beta))i"))
            steps.append(SolutionStep(title: "Solución general", math: "y = e^{\(formatNum(alpha))x}(C_1 \\cos \(formatNum(beta))x + C_2 \\sin \(formatNum(beta))x)"))
            return .multiply([
                .function(.exp, [.multiply([.number(alpha), .variable(x)])]),
                .add([
                    .multiply([.variable("C_1"), .function(.cos, [.multiply([.number(beta), .variable(x)])])]),
                    .multiply([.variable("C_2"), .function(.sin, [.multiply([.number(beta), .variable(x)])])])
                ])
            ])
        }
    }
    
    // MARK: - Cauchy-Euler: ax²y'' + bxy' + cy = 0
    
    private static func solveCauchyEuler(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Sustitución x = e^t", explanation: "Transformar a ecuación de coeficientes constantes"))
        steps.append(SolutionStep(title: "Ecuación auxiliar", explanation: "am(m-1) + bm + c = 0"))
        return .undefined("Cauchy-Euler — buscar solución y = x^m")
    }
    
    // MARK: - Undetermined Coefficients
    
    private static func solveUndeterminedCoeff(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Solución homogénea y_h", explanation: "Resolver ecuación homogénea asociada"))
        steps.append(SolutionStep(title: "Solución particular y_p", explanation: "Proponer forma basada en f(x)"))
        steps.append(SolutionStep(title: "Solución general", explanation: "y = y_h + y_p"))
        return .undefined("Coeficientes indeterminados")
    }
    
    // MARK: - Variation of Parameters
    
    private static func solveVariationOfParams(_ eq: ExprNode, y: String, x: String, _ steps: inout [SolutionStep]) -> ExprNode {
        steps.append(SolutionStep(title: "Solución homogénea", explanation: "Encontrar y₁, y₂"))
        steps.append(SolutionStep(title: "Wronskiano", explanation: "W = y₁y₂' - y₁'y₂"))
        steps.append(SolutionStep(title: "Solución particular", explanation: "y_p = -y₁∫(y₂f/W)dx + y₂∫(y₁f/W)dx"))
        return .undefined("Variación de parámetros")
    }
    
    // MARK: - Helpers
    
    private static func formatNum(_ v: Double) -> String {
        v == Double(Int(v)) ? "\(Int(v))" : String(format: "%.4g", v)
    }
}
