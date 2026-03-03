// PDESolver.swift
// CalcPrime — Engine/Solvers
// Partial Differential Equations solver.
// Methods: separation of variables, Fourier series, heat/wave/Laplace classification,
// d'Alembert formula, Green's functions, method of characteristics.
// All step-by-step explanations in Spanish.

import Foundation

// MARK: - PDE Classification

/// Classification of second-order linear PDEs.
enum PDEClassification: String {
    case elliptic    = "Elíptica"     // Δu = 0 (Laplace), Poisson
    case parabolic   = "Parabólica"   // Heat equation u_t = α²u_xx
    case hyperbolic  = "Hiperbólica"  // Wave equation u_tt = c²u_xx
    case unknown     = "Desconocida"
}

/// Boundary condition type.
enum BoundaryConditionType: String {
    case dirichlet   = "Dirichlet"    // u = f on boundary
    case neumann     = "Neumann"      // ∂u/∂n = g on boundary
    case robin       = "Robin"        // αu + β ∂u/∂n = g
    case periodic    = "Periódica"
}

/// A boundary condition for a PDE problem.
struct BoundaryCondition {
    let type: BoundaryConditionType
    let location: ExprNode          // e.g., x = 0
    let value: ExprNode             // e.g., u(0, t) = 0
}

/// A PDE problem specification.
struct PDEProblem {
    let equation: ExprNode          // The PDE expression
    let classification: PDEClassification
    let spatialVar: String          // "x"
    let timeVar: String             // "t"
    let functionName: String        // "u"
    let domain: (ExprNode, ExprNode) // spatial domain (0, L)
    let boundaryConditions: [BoundaryCondition]
    let initialCondition: ExprNode? // u(x, 0) = f(x)
    let initialVelocity: ExprNode?  // u_t(x, 0) = g(x) (for wave)
}

/// Solution to a PDE problem.
struct PDESolution {
    let general: ExprNode
    let particular: ExprNode?
    let fourierCoefficients: [(Int, ExprNode)]  // (n, coefficient)
    let steps: [SolutionStep]
}

// MARK: - PDESolver

struct PDESolver {
    
    // MARK: - Classification
    
    /// Classify a 2nd-order linear PDE: Au_xx + 2Bu_xy + Cu_yy + ... = 0
    /// Discriminant Δ = B² - AC: <0 elliptic, =0 parabolic, >0 hyperbolic
    static func classify(A: Double, B: Double, C: Double) -> PDEClassification {
        let disc = B * B - A * C
        if disc < -1e-12 { return .elliptic }
        if disc > 1e-12  { return .hyperbolic }
        return .parabolic
    }
    
    // MARK: - Heat Equation: u_t = α² u_xx
    
    /// Solve the 1D heat equation on [0, L] with homogeneous Dirichlet BCs.
    /// u(0,t) = 0, u(L,t) = 0, u(x,0) = f(x)
    /// Solution: u(x,t) = Σ B_n sin(nπx/L) exp(-α² n²π²t/L²)
    /// B_n = (2/L) ∫₀ᴸ f(x) sin(nπx/L) dx
    static func solveHeatDirichlet(
        alpha: ExprNode,
        length: ExprNode,
        initialCondition: ExprNode,
        spatialVar: String = "x",
        timeVar: String = "t",
        numTerms: Int = 10
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = spatialVar, t = timeVar
        
        steps.append(SolutionStep(
            title: "Ecuación del Calor 1D",
            explanation: "Resolver u_t = α² u_{xx} en [0, L] con condiciones de Dirichlet homogéneas",
            math: "\\frac{\\partial u}{\\partial \(t)} = \\alpha^2 \\frac{\\partial^2 u}{\\partial \(x)^2}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Separación de Variables",
            explanation: "Asumir u(x,t) = X(x)·T(t). Sustituyendo: X·T' = α²·X''·T",
            math: "\\frac{T'}{\\alpha^2 T} = \\frac{X''}{X} = -\\lambda"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Problema de Sturm-Liouville",
            explanation: "Con BCs u(0,t) = u(L,t) = 0 → X(0) = X(L) = 0",
            math: "X'' + \\lambda X = 0, \\quad X(0) = 0, \\quad X(L) = 0"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 3: Valores propios y funciones propias",
            explanation: "λ_n = (nπ/L)², X_n(x) = sin(nπx/L), n = 1, 2, 3, ...",
            math: "\\lambda_n = \\left(\\frac{n\\pi}{L}\\right)^2, \\quad X_n(\(x)) = \\sin\\left(\\frac{n\\pi \(x)}{L}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 4: Ecuación temporal",
            explanation: "T' + α²λ_n T = 0 → T_n(t) = exp(-α²n²π²t/L²)",
            math: "T_n(\(t)) = e^{-\\alpha^2 \\frac{n^2 \\pi^2}{L^2} \(t)}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 5: Solución por superposición",
            explanation: "u(x,t) = Σ B_n sin(nπx/L) exp(-α²n²π²t/L²)",
            math: "u(\(x),\(t)) = \\sum_{n=1}^{\\infty} B_n \\sin\\left(\\frac{n\\pi \(x)}{L}\\right) e^{-\\alpha^2 \\frac{n^2\\pi^2}{L^2} \(t)}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 6: Coeficientes de Fourier",
            explanation: "B_n = (2/L) ∫₀ᴸ f(x) sin(nπx/L) dx",
            math: "B_n = \\frac{2}{L} \\int_0^L f(\(x)) \\sin\\left(\\frac{n\\pi \(x)}{L}\\right) d\(x)"
        ))
        
        // Build the series solution symbolically (first numTerms terms)
        let n = "n"
        let nVar = ExprNode.variable(n)
        let L = length
        let xVar = ExprNode.variable(x)
        let tVar = ExprNode.variable(t)
        let alphaSq = ExprNode.power(alpha, .two)
        
        // Build general term: B_n * sin(nπx/L) * exp(-α²n²π²t/L²)
        let sinArg = ExprNode.multiply([nVar, .pi, xVar, .power(L, .negOne)])
        let expArg = ExprNode.negate(ExprNode.multiply([
            alphaSq,
            ExprNode.power(nVar, .two),
            ExprNode.power(.pi, .two),
            tVar,
            ExprNode.power(ExprNode.power(L, .two), .negOne)
        ]))
        
        let generalTerm = ExprNode.multiply([
            ExprNode.variable("B_\(n)"),
            .function(.sin, [sinArg]),
            .function(.exp, [expArg])
        ])
        
        let solution = ExprNode.summation(generalTerm, n, .one, .constant(.inf))
        
        return (solution, steps)
    }
    
    // MARK: - Wave Equation: u_tt = c² u_xx
    
    /// Solve the 1D wave equation on [0, L] with homogeneous Dirichlet BCs.
    /// u(0,t) = 0, u(L,t) = 0, u(x,0) = f(x), u_t(x,0) = g(x)
    /// d'Alembert + Fourier approach
    static func solveWaveDirichlet(
        waveSpeed: ExprNode,
        length: ExprNode,
        initialDisplacement: ExprNode,
        initialVelocity: ExprNode,
        spatialVar: String = "x",
        timeVar: String = "t",
        numTerms: Int = 10
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = spatialVar, t = timeVar
        
        steps.append(SolutionStep(
            title: "Ecuación de Onda 1D",
            explanation: "Resolver u_{tt} = c² u_{xx} en [0, L]",
            math: "\\frac{\\partial^2 u}{\\partial \(t)^2} = c^2 \\frac{\\partial^2 u}{\\partial \(x)^2}"
        ))
        
        steps.append(SolutionStep(
            title: "Condiciones iniciales",
            explanation: "u(x,0) = f(x) (desplazamiento), u_t(x,0) = g(x) (velocidad)",
            math: "u(\(x),0) = f(\(x)), \\quad u_t(\(x),0) = g(\(x))"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Separación de Variables",
            explanation: "u(x,t) = X(x)·T(t) → X''/X = T''/(c²T) = -λ",
            math: "\\frac{X''}{X} = \\frac{T''}{c^2 T} = -\\lambda"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Valores propios",
            explanation: "λ_n = (nπ/L)², X_n = sin(nπx/L)",
            math: "\\lambda_n = \\left(\\frac{n\\pi}{L}\\right)^2, \\quad X_n(\(x)) = \\sin\\left(\\frac{n\\pi \(x)}{L}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 3: Ecuación temporal",
            explanation: "T'' + c²λ_n T = 0 → T_n = A_n cos(cnπt/L) + B_n sin(cnπt/L)",
            math: "T_n(\(t)) = A_n \\cos\\left(\\frac{cn\\pi \(t)}{L}\\right) + B_n \\sin\\left(\\frac{cn\\pi \(t)}{L}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 4: Solución general",
            math: "u(\(x),\(t)) = \\sum_{n=1}^{\\infty} \\left[A_n \\cos\\left(\\frac{cn\\pi \(t)}{L}\\right) + B_n \\sin\\left(\\frac{cn\\pi \(t)}{L}\\right)\\right] \\sin\\left(\\frac{n\\pi \(x)}{L}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 5: Coeficientes de Fourier",
            explanation: "A_n = (2/L) ∫₀ᴸ f(x) sin(nπx/L) dx, B_n = (2/(cnπ)) ∫₀ᴸ g(x) sin(nπx/L) dx",
            math: "A_n = \\frac{2}{L}\\int_0^L f(\(x))\\sin\\frac{n\\pi \(x)}{L}d\(x), \\quad B_n = \\frac{2}{cn\\pi}\\int_0^L g(\(x))\\sin\\frac{n\\pi \(x)}{L}d\(x)"
        ))
        
        // Build symbolic series
        let n = "n"
        let nVar = ExprNode.variable(n)
        let L = length
        let c = waveSpeed
        let xVar = ExprNode.variable(x)
        let tVar = ExprNode.variable(t)
        
        let sineX = ExprNode.function(.sin, [ExprNode.multiply([nVar, .pi, xVar, .power(L, .negOne)])])
        let omegaN = ExprNode.multiply([c, nVar, .pi, .power(L, .negOne)])
        let cosT = ExprNode.function(.cos, [ExprNode.multiply([omegaN, tVar])])
        let sinT = ExprNode.function(.sin, [ExprNode.multiply([omegaN, tVar])])
        
        let generalTerm = ExprNode.multiply([
            .add([
                .multiply([.variable("A_\(n)"), cosT]),
                .multiply([.variable("B_\(n)"), sinT])
            ]),
            sineX
        ])
        
        let solution = ExprNode.summation(generalTerm, n, .one, .constant(.inf))
        
        return (solution, steps)
    }
    
    // MARK: - Laplace Equation: Δu = 0
    
    /// Solve Laplace equation on rectangle [0,a]×[0,b] with mixed BCs.
    /// u(0,y) = 0, u(a,y) = 0, u(x,0) = 0, u(x,b) = f(x)
    static func solveLaplaceRectangle(
        width: ExprNode,
        height: ExprNode,
        topBC: ExprNode,
        xVar: String = "x",
        yVar: String = "y"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = xVar, y = yVar
        
        steps.append(SolutionStep(
            title: "Ecuación de Laplace 2D",
            explanation: "Resolver ∇²u = 0 en un rectángulo [0,a]×[0,b]",
            math: "\\frac{\\partial^2 u}{\\partial \(x)^2} + \\frac{\\partial^2 u}{\\partial \(y)^2} = 0"
        ))
        
        steps.append(SolutionStep(
            title: "Condiciones de frontera",
            explanation: "u(0,y) = u(a,y) = 0, u(x,0) = 0, u(x,b) = f(x)",
            math: "u(0,\(y)) = u(a,\(y)) = 0, \\quad u(\(x),0) = 0, \\quad u(\(x),b) = f(\(x))"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Separación de Variables",
            explanation: "u(x,y) = X(x)·Y(y) → X''/X = -Y''/Y = -λ",
            math: "\\frac{X''}{X} = -\\frac{Y''}{Y} = -\\lambda"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Problema en X",
            explanation: "X'' + λX = 0, X(0) = 0, X(a) = 0",
            math: "\\lambda_n = \\left(\\frac{n\\pi}{a}\\right)^2, \\quad X_n(\(x)) = \\sin\\left(\\frac{n\\pi \(x)}{a}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 3: Problema en Y",
            explanation: "Y'' - λ_n Y = 0, Y(0) = 0 → Y_n(y) = sinh(nπy/a)",
            math: "Y_n(\(y)) = \\sinh\\left(\\frac{n\\pi \(y)}{a}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 4: Solución general",
            math: "u(\(x),\(y)) = \\sum_{n=1}^{\\infty} C_n \\sin\\left(\\frac{n\\pi \(x)}{a}\\right) \\sinh\\left(\\frac{n\\pi \(y)}{a}\\right)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 5: Aplicar u(x,b) = f(x)",
            explanation: "C_n = (2/a) ∫₀ᵃ f(x)sin(nπx/a)dx / sinh(nπb/a)",
            math: "C_n = \\frac{2}{a \\sinh\\frac{n\\pi b}{a}} \\int_0^a f(\(x)) \\sin\\frac{n\\pi \(x)}{a} d\(x)"
        ))
        
        let n = "n"
        let nVar = ExprNode.variable(n)
        let a = width
        let xv = ExprNode.variable(x)
        let yv = ExprNode.variable(y)
        
        let sinArg = ExprNode.multiply([nVar, .pi, xv, .power(a, .negOne)])
        let sinhArg = ExprNode.multiply([nVar, .pi, yv, .power(a, .negOne)])
        
        let generalTerm = ExprNode.multiply([
            .variable("C_\(n)"),
            .function(.sin, [sinArg]),
            .function(.sinh, [sinhArg])
        ])
        
        let solution = ExprNode.summation(generalTerm, n, .one, .constant(.inf))
        
        return (solution, steps)
    }
    
    // MARK: - d'Alembert Solution (Infinite String)
    
    /// d'Alembert solution for wave equation on (-∞, ∞):
    /// u(x,t) = [f(x-ct) + f(x+ct)]/2 + (1/2c) ∫_{x-ct}^{x+ct} g(s) ds
    static func dAlembertSolution(
        waveSpeed: ExprNode,
        initialDisplacement: ExprNode,
        initialVelocity: ExprNode,
        spatialVar: String = "x",
        timeVar: String = "t"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = spatialVar, t = timeVar
        let c = waveSpeed
        let xVar = ExprNode.variable(x)
        let tVar = ExprNode.variable(t)
        
        steps.append(SolutionStep(
            title: "Fórmula de d'Alembert",
            explanation: "Para la ecuación de onda u_{tt} = c²u_{xx} en la recta real",
            math: "u_{tt} = c^2 u_{xx}, \\quad -\\infty < \(x) < \\infty"
        ))
        
        steps.append(SolutionStep(
            title: "Solución general",
            math: "u(\(x),\(t)) = \\frac{f(\(x) - c\(t)) + f(\(x) + c\(t))}{2} + \\frac{1}{2c}\\int_{\(x)-c\(t)}^{\(x)+c\(t)} g(s)\\,ds"
        ))
        
        // Symbolic construction
        let xMinusCt = xVar - .multiply([c, tVar])
        let xPlusCt = xVar + .multiply([c, tVar])
        
        let fLeft = initialDisplacement.substitute(x, with: xMinusCt)
        let fRight = initialDisplacement.substitute(x, with: xPlusCt)
        
        let displacementPart = ExprNode.multiply([
            .half,
            .add([fLeft, fRight])
        ])
        
        let integralPart = ExprNode.multiply([
            ExprNode.div(.one, ExprNode.multiply([.two, c])),
            .definiteIntegral(initialVelocity.substitute(x, with: .variable("s")), "s", xMinusCt, xPlusCt)
        ])
        
        let solution = ExprNode.add([displacementPart, integralPart])
        
        steps.append(SolutionStep(
            title: "Resultado",
            math: solution.latex
        ))
        
        return (solution, steps)
    }
    
    // MARK: - Method of Characteristics
    
    /// Solve first-order PDE: a·u_x + b·u_y = c using characteristics.
    /// a, b, c may depend on x, y, u.
    static func solveByCharacteristics(
        a: ExprNode,
        b: ExprNode,
        rhs: ExprNode,
        xVar: String = "x",
        yVar: String = "y",
        functionName: String = "u"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = xVar, y = yVar
        
        steps.append(SolutionStep(
            title: "Método de Características",
            explanation: "Resolver a·u_x + b·u_y = c",
            math: "\(a.latex) \\frac{\\partial \(functionName)}{\\partial \(x)} + \(b.latex) \\frac{\\partial \(functionName)}{\\partial \(y)} = \(rhs.latex)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Ecuaciones características",
            explanation: "dx/a = dy/b = du/c",
            math: "\\frac{d\(x)}{\(a.latex)} = \\frac{d\(y)}{\(b.latex)} = \\frac{d\(functionName)}{\(rhs.latex)}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Integrar las curvas características",
            explanation: "Resolver el sistema de EDOs paramétrico para encontrar invariantes"
        ))
        
        // For constant coefficient case a u_x + b u_y = 0:
        // Characteristics: y - (b/a)x = const
        // Solution: u = F(y - (b/a)x) for arbitrary F
        if rhs.isZero {
            let ratio = Simplifier.simplify(ExprNode.div(b, a))
            let characteristic = Simplifier.simplify(
                ExprNode.variable(y) - ExprNode.multiply([ratio, ExprNode.variable(x)])
            )
            
            steps.append(SolutionStep(
                title: "Paso 3: PDE homogénea — solución general",
                explanation: "u = F(ξ) donde ξ es el invariante de las características",
                math: "\(functionName)(\(x),\(y)) = F\\left(\(characteristic.latex)\\right)"
            ))
            
            let solution = ExprNode.function(.lambertW, [characteristic]) // placeholder for arbitrary function F
            return (solution, steps)
        }
        
        // Non-homogeneous: return symbolic form
        let xi = ExprNode.variable("\\xi")
        let solution = ExprNode.function(.lambertW, [xi]) // placeholder
        
        steps.append(SolutionStep(
            title: "Paso 3: Solución general",
            explanation: "La solución depende de la función arbitraria F aplicada al invariante",
            math: "\(functionName) = F(\\xi_1, \\xi_2)"
        ))
        
        return (solution, steps)
    }
    
    // MARK: - Poisson Equation: Δu = f(x,y)
    
    /// Solve Poisson equation on [0,a]×[0,b] with zero BCs using double Fourier series.
    static func solvePoissonRectangle(
        rhs: ExprNode,
        width: ExprNode,
        height: ExprNode,
        xVar: String = "x",
        yVar: String = "y"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = xVar, y = yVar
        
        steps.append(SolutionStep(
            title: "Ecuación de Poisson",
            explanation: "Resolver ∇²u = f(x,y) en [0,a]×[0,b] con u = 0 en la frontera",
            math: "\\nabla^2 u = f(\(x),\(y))"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Desarrollo en serie doble de Fourier",
            explanation: "Expresar f(x,y) y u(x,y) como doble serie de senos",
            math: "u(\(x),\(y)) = \\sum_{n=1}^\\infty \\sum_{m=1}^\\infty u_{nm} \\sin\\frac{n\\pi \(x)}{a} \\sin\\frac{m\\pi \(y)}{b}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Coeficientes de Fourier de f",
            math: "f_{nm} = \\frac{4}{ab} \\int_0^a \\int_0^b f(\(x),\(y)) \\sin\\frac{n\\pi \(x)}{a} \\sin\\frac{m\\pi \(y)}{b} \\, d\(y)\\, d\(x)"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 3: Sustituir en ∇²u = f",
            explanation: "Cada coeficiente satisface: -(n²π²/a² + m²π²/b²)·u_{nm} = f_{nm}",
            math: "u_{nm} = \\frac{-f_{nm}}{\\left(\\frac{n\\pi}{a}\\right)^2 + \\left(\\frac{m\\pi}{b}\\right)^2}"
        ))
        
        let n = "n", m = "m"
        let nVar = ExprNode.variable(n), mVar = ExprNode.variable(m)
        let a = width, b = height
        let xv = ExprNode.variable(x), yv = ExprNode.variable(y)
        
        let sinX = ExprNode.function(.sin, [.multiply([nVar, .pi, xv, .power(a, .negOne)])])
        let sinY = ExprNode.function(.sin, [.multiply([mVar, .pi, yv, .power(b, .negOne)])])
        
        let innerTerm = ExprNode.multiply([.variable("u_{\(n)\(m)}"), sinX, sinY])
        let innerSum = ExprNode.summation(innerTerm, m, .one, .constant(.inf))
        let solution = ExprNode.summation(innerSum, n, .one, .constant(.inf))
        
        return (solution, steps)
    }
    
    // MARK: - Heat Equation with Neumann BCs
    
    /// Solve heat equation with insulated ends: u_x(0,t) = u_x(L,t) = 0.
    /// Solution: u = A_0/2 + Σ A_n cos(nπx/L) exp(-α²n²π²t/L²)
    static func solveHeatNeumann(
        alpha: ExprNode,
        length: ExprNode,
        initialCondition: ExprNode,
        spatialVar: String = "x",
        timeVar: String = "t"
    ) -> (ExprNode, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let x = spatialVar, t = timeVar
        
        steps.append(SolutionStep(
            title: "Ecuación del Calor con Neumann",
            explanation: "u_t = α²u_{xx}, u_x(0,t) = u_x(L,t) = 0 (extremos aislados)",
            math: "\\frac{\\partial u}{\\partial \(t)} = \\alpha^2 \\frac{\\partial^2 u}{\\partial \(x)^2}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 1: Separación de variables con Neumann",
            explanation: "X'(0) = X'(L) = 0 → cosenos en lugar de senos",
            math: "X_n(\(x)) = \\cos\\left(\\frac{n\\pi \(x)}{L}\\right), \\quad n = 0, 1, 2, \\ldots"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 2: Solución general",
            math: "u(\(x),\(t)) = \\frac{A_0}{2} + \\sum_{n=1}^{\\infty} A_n \\cos\\left(\\frac{n\\pi \(x)}{L}\\right) e^{-\\alpha^2 \\frac{n^2\\pi^2}{L^2}\(t)}"
        ))
        
        steps.append(SolutionStep(
            title: "Paso 3: Coeficientes",
            math: "A_n = \\frac{2}{L}\\int_0^L f(\(x)) \\cos\\left(\\frac{n\\pi \(x)}{L}\\right) d\(x)"
        ))
        
        let n = "n"
        let nVar = ExprNode.variable(n)
        let L = length
        let xv = ExprNode.variable(x)
        let tv = ExprNode.variable(t)
        let alphaSq = ExprNode.power(alpha, .two)
        
        let cosArg = ExprNode.multiply([nVar, .pi, xv, .power(L, .negOne)])
        let expArg = ExprNode.negate(ExprNode.multiply([
            alphaSq, .power(nVar, .two), .power(.pi, .two), tv, .power(.power(L, .two), .negOne)
        ]))
        
        let seriesTerm = ExprNode.multiply([
            .variable("A_\(n)"),
            .function(.cos, [cosArg]),
            .function(.exp, [expArg])
        ])
        
        let series = ExprNode.summation(seriesTerm, n, .one, .constant(.inf))
        let solution = ExprNode.add([
            ExprNode.multiply([.half, .variable("A_0")]),
            series
        ])
        
        return (solution, steps)
    }
    
    // MARK: - Numerical: Finite Differences for Heat Equation
    
    /// Explicit finite difference method for u_t = α²u_xx.
    /// Returns (x_i, t_j, u_ij) grid.
    static func solveHeatNumerical(
        alpha: Double,
        length: Double,
        totalTime: Double,
        nx: Int = 50,
        initialCondition: (Double) -> Double,
        leftBC: (Double) -> Double = { _ in 0 },
        rightBC: (Double) -> Double = { _ in 0 }
    ) -> ([[Double]], [SolutionStep]) {
        let dx = length / Double(nx)
        let dt = 0.4 * dx * dx / (alpha * alpha) // CFL condition: r ≤ 0.5
        let nt = Int(totalTime / dt) + 1
        let r = alpha * alpha * dt / (dx * dx)
        
        var steps: [SolutionStep] = []
        steps.append(SolutionStep(
            title: "Método de Diferencias Finitas Explícito",
            explanation: "Δx = \(String(format: "%.4f", dx)), Δt = \(String(format: "%.6f", dt)), r = α²Δt/Δx² = \(String(format: "%.4f", r))",
            math: "u_i^{j+1} = r \\cdot u_{i-1}^j + (1-2r) \\cdot u_i^j + r \\cdot u_{i+1}^j"
        ))
        
        // Initialize grid
        var u = Array(repeating: 0.0, count: nx + 1)
        for i in 0...nx {
            u[i] = initialCondition(Double(i) * dx)
        }
        
        var results: [[Double]] = []
        // Store initial state: [t, u_0, u_1, ..., u_nx]
        results.append([0.0] + u)
        
        // Time-stepping
        for j in 1...nt {
            let t = Double(j) * dt
            var uNew = u
            
            uNew[0] = leftBC(t)
            uNew[nx] = rightBC(t)
            
            for i in 1..<nx {
                uNew[i] = r * u[i - 1] + (1 - 2 * r) * u[i] + r * u[i + 1]
            }
            
            u = uNew
            
            // Store every 10th time step
            if j % max(1, nt / 50) == 0 || j == nt {
                results.append([t] + u)
            }
        }
        
        steps.append(SolutionStep(
            title: "Resultado numérico",
            explanation: "Solución calculada en \(nt) pasos temporales, \(nx) nodos espaciales"
        ))
        
        return (results, steps)
    }
    
    // MARK: - Numerical: Finite Differences for Wave Equation
    
    /// Explicit finite difference for u_tt = c²u_xx.
    static func solveWaveNumerical(
        waveSpeed: Double,
        length: Double,
        totalTime: Double,
        nx: Int = 50,
        initialDisplacement: (Double) -> Double,
        initialVelocity: (Double) -> Double = { _ in 0 },
        leftBC: (Double) -> Double = { _ in 0 },
        rightBC: (Double) -> Double = { _ in 0 }
    ) -> ([[Double]], [SolutionStep]) {
        let dx = length / Double(nx)
        let dt = 0.9 * dx / waveSpeed // CFL: c*dt/dx ≤ 1
        let nt = Int(totalTime / dt) + 1
        let r = waveSpeed * dt / dx
        let r2 = r * r
        
        var steps: [SolutionStep] = []
        steps.append(SolutionStep(
            title: "Diferencias Finitas para Ecuación de Onda",
            explanation: "Δx = \(String(format: "%.4f", dx)), Δt = \(String(format: "%.6f", dt)), CFL = c·Δt/Δx = \(String(format: "%.4f", r))",
            math: "u_i^{j+1} = 2(1-r^2)u_i^j + r^2(u_{i-1}^j + u_{i+1}^j) - u_i^{j-1}"
        ))
        
        var uPrev = Array(repeating: 0.0, count: nx + 1)
        var uCurr = Array(repeating: 0.0, count: nx + 1)
        
        for i in 0...nx {
            let x = Double(i) * dx
            uPrev[i] = initialDisplacement(x)
        }
        
        // First time step using initial velocity
        for i in 1..<nx {
            let x = Double(i) * dx
            uCurr[i] = uPrev[i] + dt * initialVelocity(x) +
                0.5 * r2 * (uPrev[i - 1] - 2 * uPrev[i] + uPrev[i + 1])
        }
        uCurr[0] = leftBC(dt)
        uCurr[nx] = rightBC(dt)
        
        var results: [[Double]] = [[0.0] + uPrev, [dt] + uCurr]
        
        for j in 2...nt {
            let t = Double(j) * dt
            var uNext = Array(repeating: 0.0, count: nx + 1)
            
            uNext[0] = leftBC(t)
            uNext[nx] = rightBC(t)
            
            for i in 1..<nx {
                uNext[i] = 2 * (1 - r2) * uCurr[i] + r2 * (uCurr[i - 1] + uCurr[i + 1]) - uPrev[i]
            }
            
            uPrev = uCurr
            uCurr = uNext
            
            if j % max(1, nt / 50) == 0 || j == nt {
                results.append([t] + uCurr)
            }
        }
        
        steps.append(SolutionStep(
            title: "Resultado numérico",
            explanation: "Ecuación de onda resuelta en \(nt) pasos temporales"
        ))
        
        return (results, steps)
    }
    
    // MARK: - Fourier Series Computation
    
    /// Compute Fourier sine series coefficients numerically.
    /// B_n = (2/L) ∫₀ᴸ f(x) sin(nπx/L) dx
    static func fourierSineCoefficients(
        f: (Double) -> Double,
        length: Double,
        numTerms: Int = 20,
        numPoints: Int = 1000
    ) -> [Double] {
        let L = length
        let dx = L / Double(numPoints)
        var coeffs: [Double] = []
        
        for n in 1...numTerms {
            var integral = 0.0
            for k in 0..<numPoints {
                let x = (Double(k) + 0.5) * dx
                integral += f(x) * Foundation.sin(Double(n) * .pi * x / L) * dx
            }
            coeffs.append(2.0 / L * integral)
        }
        
        return coeffs
    }
    
    /// Compute Fourier cosine series coefficients numerically.
    /// A_n = (2/L) ∫₀ᴸ f(x) cos(nπx/L) dx
    static func fourierCosineCoefficients(
        f: (Double) -> Double,
        length: Double,
        numTerms: Int = 20,
        numPoints: Int = 1000
    ) -> [Double] {
        let L = length
        let dx = L / Double(numPoints)
        var coeffs: [Double] = []
        
        for n in 0...numTerms {
            var integral = 0.0
            for k in 0..<numPoints {
                let x = (Double(k) + 0.5) * dx
                integral += f(x) * Foundation.cos(Double(n) * .pi * x / L) * dx
            }
            let coeff = (n == 0 ? 1.0 / L : 2.0 / L) * integral
            coeffs.append(coeff)
        }
        
        return coeffs
    }
    
    // MARK: - Sturm-Liouville Summary
    
    /// Generate explanation for a general Sturm-Liouville problem.
    static func sturmLiouvilleExplanation(
        pCoeff: String = "p(x)",
        qCoeff: String = "q(x)",
        weight: String = "r(x)"
    ) -> [SolutionStep] {
        return [
            SolutionStep(
                title: "Problema de Sturm-Liouville",
                explanation: "Forma general: -(p(x)y')' + q(x)y = λr(x)y",
                math: "-\\frac{d}{dx}\\left[\(pCoeff) \\frac{dy}{dx}\\right] + \(qCoeff) y = \\lambda \(weight) y"
            ),
            SolutionStep(
                title: "Propiedades",
                explanation: "1. Los valores propios λ_n son reales y forman una sucesión creciente\n2. Las funciones propias φ_n son ortogonales con peso r(x)\n3. Cualquier función f se puede expandir: f(x) = Σ c_n φ_n(x)"
            ),
            SolutionStep(
                title: "Ortogonalidad",
                math: "\\int_a^b \(weight) \\, \\phi_n(x) \\, \\phi_m(x) \\, dx = 0 \\quad (n \\neq m)"
            ),
            SolutionStep(
                title: "Coeficientes de expansión",
                math: "c_n = \\frac{\\int_a^b \(weight) \\, f(x) \\, \\phi_n(x) \\, dx}{\\int_a^b \(weight) \\, \\phi_n^2(x) \\, dx}"
            )
        ]
    }
}
