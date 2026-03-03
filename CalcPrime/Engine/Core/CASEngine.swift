// CASEngine.swift
// CalcPrime — Engine/Core
// Central Computer Algebra System orchestrator.
// Routes operations to the appropriate solver (Differentiator, Integrator, Factorizer, etc.)
// and coordinates simplification, expansion, and evaluation.

import Foundation

// MARK: - CASResult

/// The result of a CAS operation.
struct CASResult {
    let input: ExprNode
    let output: ExprNode
    let steps: [SolutionStep]
    let latex: String
    let timeElapsed: TimeInterval
    
    init(input: ExprNode, output: ExprNode, steps: [SolutionStep] = [], timeElapsed: TimeInterval = 0) {
        self.input = input
        self.output = output
        self.steps = steps
        self.latex = output.latex
        self.timeElapsed = timeElapsed
    }
}

// MARK: - SolutionStep

/// A single step in a solution explanation.
struct SolutionStep: Identifiable, Equatable {
    let id = UUID()
    let title: String          // e.g. "Identificar tipo de EDO"
    let explanation: String    // e.g. "La ecuación es de variables separables"
    let math: String           // LaTeX representation
    let substeps: [SolutionStep]
    
    init(title: String, explanation: String = "", math: String = "", substeps: [SolutionStep] = []) {
        self.title = title
        self.explanation = explanation
        self.math = math
        self.substeps = substeps
    }
    
    static func == (lhs: SolutionStep, rhs: SolutionStep) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CASEngine

/// The main CAS engine that orchestrates all mathematical operations.
final class CASEngine {
    
    static let shared = CASEngine()
    
    private init() {}
    
    // MARK: - Parse
    
    /// Parse a string into an AST.
    func parse(_ input: String) throws -> ExprNode {
        try Parser.parse(input)
    }
    
    // MARK: - Simplify
    
    func simplify(_ expr: ExprNode) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let result = Simplifier.simplify(expr)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let steps = [
            SolutionStep(title: "Expresión original", math: expr.latex),
            SolutionStep(title: "Resultado simplificado", math: result.latex)
        ]
        
        return CASResult(input: expr, output: result, steps: steps, timeElapsed: elapsed)
    }
    
    func simplify(_ input: String) throws -> CASResult {
        let expr = try parse(input)
        return simplify(expr)
    }
    
    // MARK: - Expand
    
    func expand(_ expr: ExprNode) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let result = Simplifier.expand(expr)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let steps = [
            SolutionStep(title: "Expresión original", math: expr.latex),
            SolutionStep(title: "Resultado expandido", math: result.latex)
        ]
        
        return CASResult(input: expr, output: result, steps: steps, timeElapsed: elapsed)
    }
    
    // MARK: - Evaluate
    
    func evaluate(_ expr: ExprNode, variables: [String: Double] = [:]) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let simplified = Simplifier.simplify(expr)
        let value = simplified.evaluate(with: variables) ?? Double.nan
        let result = ExprNode.number(value)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        var steps = [SolutionStep(title: "Expresión original", math: expr.latex)]
        if !variables.isEmpty {
            let varsStr = variables.map { "\($0.key) = \($0.value)" }.joined(separator: ", ")
            steps.append(SolutionStep(title: "Sustitución de variables", explanation: varsStr))
        }
        steps.append(SolutionStep(title: "Resultado numérico", math: result.latex))
        
        return CASResult(input: expr, output: result, steps: steps, timeElapsed: elapsed)
    }
    
    func evaluate(_ input: String, variables: [String: Double] = [:]) throws -> CASResult {
        let expr = try parse(input)
        return evaluate(expr, variables: variables)
    }
    
    // MARK: - Differentiate
    
    func differentiate(_ expr: ExprNode, variable: String = "x", order: Int = 1) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        var result = expr
        var steps: [SolutionStep] = [
            SolutionStep(title: "Expresión original", math: "f(\(variable)) = \(expr.latex)")
        ]
        
        for i in 1...order {
            let diff = Differentiator.differentiate(result, withRespectTo: variable)
            let simplified = Simplifier.simplify(diff)
            steps.append(SolutionStep(
                title: i == 1 ? "Primera derivada" : "Derivada de orden \(i)",
                math: "f\(i == 1 ? "'" : "^{(\(i))}")}(\(variable)) = \(simplified.latex)"
            ))
            result = simplified
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return CASResult(input: expr, output: result, steps: steps, timeElapsed: elapsed)
    }
    
    func differentiate(_ input: String, variable: String = "x", order: Int = 1) throws -> CASResult {
        let expr = try parse(input)
        return differentiate(expr, variable: variable, order: order)
    }
    
    // MARK: - Integrate
    
    func integrate(_ expr: ExprNode, variable: String = "x") -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let (result, steps) = Integrator.integrate(expr, withRespectTo: variable)
        let simplified = Simplifier.simplify(result)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        var allSteps = [SolutionStep(title: "Integral", math: "\\int \(expr.latex) \\, d\(variable)")]
        allSteps.append(contentsOf: steps)
        allSteps.append(SolutionStep(title: "Resultado", math: "\(simplified.latex) + C"))
        
        return CASResult(input: expr, output: simplified, steps: allSteps, timeElapsed: elapsed)
    }
    
    func integrateDefinite(_ expr: ExprNode, variable: String = "x", from lower: ExprNode, to upper: ExprNode) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let (antideriv, steps) = Integrator.integrate(expr, withRespectTo: variable)
        let simplified = Simplifier.simplify(antideriv)
        
        // Apply FTC: F(b) - F(a)
        let atUpper = Simplifier.simplify(simplified.substitute(variable, with: upper))
        let atLower = Simplifier.simplify(simplified.substitute(variable, with: lower))
        let result = Simplifier.simplify(atUpper - atLower)
        
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        var allSteps = [SolutionStep(title: "Integral definida", math: "\\int_{\(lower.latex)}^{\(upper.latex)} \(expr.latex) \\, d\(variable)")]
        allSteps.append(contentsOf: steps)
        allSteps.append(SolutionStep(title: "Antiderivada", math: "F(\(variable)) = \(simplified.latex)"))
        allSteps.append(SolutionStep(title: "Teorema Fundamental del Cálculo", math: "F(\(upper.latex)) - F(\(lower.latex)) = \(atUpper.latex) - \(atLower.latex)"))
        allSteps.append(SolutionStep(title: "Resultado", math: result.latex))
        
        return CASResult(input: expr, output: result, steps: allSteps, timeElapsed: elapsed)
    }
    
    // MARK: - Factor
    
    func factor(_ expr: ExprNode) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let (result, steps) = Factorizer.factor(expr)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        var allSteps = [SolutionStep(title: "Expresión original", math: expr.latex)]
        allSteps.append(contentsOf: steps)
        allSteps.append(SolutionStep(title: "Resultado factorizado", math: result.latex))
        
        return CASResult(input: expr, output: result, steps: allSteps, timeElapsed: elapsed)
    }
    
    // MARK: - Solve Equation
    
    func solve(_ equation: ExprNode, variable: String = "x") -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let (solutions, steps) = AlgebraSolver.solve(equation, for: variable)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let resultExpr: ExprNode
        if solutions.isEmpty {
            resultExpr = .undefined("Sin solución")
        } else if solutions.count == 1 {
            resultExpr = solutions[0]
        } else {
            resultExpr = .list(solutions)
        }
        
        var allSteps = [SolutionStep(title: "Ecuación", math: equation.latex)]
        allSteps.append(contentsOf: steps)
        allSteps.append(SolutionStep(title: "Solución(es)", math: resultExpr.latex))
        
        return CASResult(input: equation, output: resultExpr, steps: allSteps, timeElapsed: elapsed)
    }
    
    // MARK: - Solve ODE
    
    func solveODE(_ equation: ExprNode, function: String = "y", variable: String = "x") -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let (result, steps) = ODESolver.solve(equation, function: function, variable: variable)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        var allSteps = [SolutionStep(title: "EDO", math: equation.latex)]
        allSteps.append(contentsOf: steps)
        allSteps.append(SolutionStep(title: "Solución general", math: result.latex))
        
        return CASResult(input: equation, output: result, steps: allSteps, timeElapsed: elapsed)
    }
    
    // MARK: - Collect
    
    func collect(_ expr: ExprNode, variable: String) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let result = Simplifier.collect(expr, variable: variable)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        return CASResult(input: expr, output: result, steps: [
            SolutionStep(title: "Recolectar términos en \(variable)", math: result.latex)
        ], timeElapsed: elapsed)
    }
    
    // MARK: - Trig Simplify
    
    func trigSimplify(_ expr: ExprNode) -> CASResult {
        let start = CFAbsoluteTimeGetCurrent()
        let result = Simplifier.trigSimplify(expr)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        return CASResult(input: expr, output: result, steps: [
            SolutionStep(title: "Simplificación trigonométrica", math: result.latex)
        ], timeElapsed: elapsed)
    }
    
    // MARK: - Process Input (Auto-detect)
    
    /// Parse and auto-detect what operation to perform.
    func process(_ input: String) throws -> CASResult {
        let expr = try parse(input)
        return process(expr)
    }
    
    func process(_ expr: ExprNode) -> CASResult {
        switch expr {
        // Integral detected
        case .integral(let body, let v):
            return integrate(body, variable: v)
        case .definiteIntegral(let body, let v, let lo, let hi):
            return integrateDefinite(body, variable: v, from: lo, to: hi)
            
        // Derivative detected
        case .derivative(let body, let v, let n):
            return differentiate(body, variable: v, order: n)
            
        // Equation detected → solve
        case .equation:
            let mainVar = expr.freeVariables.first ?? "x"
            return solve(expr, variable: mainVar)
            
        // Default → simplify
        default:
            let simplified = simplify(expr)
            // If it's purely numeric, show as evaluation
            if simplified.output.isNumeric {
                return evaluate(expr)
            }
            return simplified
        }
    }
}
