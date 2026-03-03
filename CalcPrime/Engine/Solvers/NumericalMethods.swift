// NumericalMethods.swift
// CalcPrime — Engine/Solvers
// Comprehensive numerical methods library.
// Root finding, numerical integration, interpolation, ODE solvers,
// optimization, curve fitting, finite differences.
// All step-by-step explanations in Spanish.

import Foundation

// MARK: - NumericalMethods

struct NumericalMethods {
    
    // ─────────────────────────────────────────────
    // MARK: - Root Finding
    // ─────────────────────────────────────────────
    
    /// Newton-Raphson method: x_{n+1} = x_n - f(x_n)/f'(x_n)
    static func newtonRaphson(
        f: (Double) -> Double,
        df: (Double) -> Double,
        x0: Double,
        tolerance: Double = 1e-12,
        maxIter: Int = 100
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var x = x0
        
        steps.append(SolutionStep(
            title: "Método de Newton-Raphson",
            explanation: "x₀ = \(fmt(x0)), tolerancia = \(tolerance)",
            math: "x_{n+1} = x_n - \\frac{f(x_n)}{f'(x_n)}"
        ))
        
        for i in 0..<maxIter {
            let fx = f(x)
            let dfx = df(x)
            guard Swift.abs(dfx) > 1e-15 else {
                steps.append(SolutionStep(title: "Error", explanation: "Derivada cercana a cero en iteración \(i)"))
                break
            }
            
            let xNew = x - fx / dfx
            
            if i < 10 {
                steps.append(SolutionStep(
                    title: "Iteración \(i + 1)",
                    math: "x_{\(i + 1)} = \(fmt(x)) - \\frac{\(fmt(fx))}{\(fmt(dfx))} = \(fmt(xNew))"
                ))
            }
            
            if Swift.abs(xNew - x) < tolerance {
                steps.append(SolutionStep(
                    title: "Convergencia alcanzada",
                    explanation: "En \(i + 1) iteraciones, |Δx| = \(String(format: "%.2e", Swift.abs(xNew - x)))"
                ))
                return (xNew, steps)
            }
            
            x = xNew
        }
        
        steps.append(SolutionStep(title: "Resultado", math: "x \\approx \(fmt(x))"))
        return (x, steps)
    }
    
    /// Newton-Raphson using symbolic expressions.
    static func newtonRaphsonSymbolic(
        _ expr: ExprNode,
        variable v: String = "x",
        x0: Double = 1.0,
        tolerance: Double = 1e-12,
        maxIter: Int = 100
    ) -> (Double, [SolutionStep]) {
        let derivative = Simplifier.simplify(Differentiator.differentiate(expr, withRespectTo: v))
        
        return newtonRaphson(
            f: { x in expr.substitute(v, with: .number(x)).numericValue ?? .nan },
            df: { x in derivative.substitute(v, with: .number(x)).numericValue ?? .nan },
            x0: x0,
            tolerance: tolerance,
            maxIter: maxIter
        )
    }
    
    /// Bisection method on [a, b].
    static func bisection(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        tolerance: Double = 1e-12,
        maxIter: Int = 100
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var lo = a, hi = b
        
        steps.append(SolutionStep(
            title: "Método de Bisección",
            explanation: "Intervalo inicial: [\(fmt(a)), \(fmt(b))], tolerancia = \(tolerance)"
        ))
        
        guard f(lo) * f(hi) < 0 else {
            steps.append(SolutionStep(title: "Error", explanation: "f(a) y f(b) tienen el mismo signo"))
            return (.nan, steps)
        }
        
        for i in 0..<maxIter {
            let mid = (lo + hi) / 2
            let fMid = f(mid)
            
            if i < 10 {
                steps.append(SolutionStep(
                    title: "Iteración \(i + 1)",
                    explanation: "[\(fmt(lo)), \(fmt(hi))], mid = \(fmt(mid)), f(mid) = \(fmt(fMid))"
                ))
            }
            
            if Swift.abs(fMid) < tolerance || (hi - lo) / 2 < tolerance {
                steps.append(SolutionStep(
                    title: "Convergencia en \(i + 1) iteraciones",
                    math: "x \\approx \(fmt(mid))"
                ))
                return (mid, steps)
            }
            
            if f(lo) * fMid < 0 { hi = mid }
            else { lo = mid }
        }
        
        let result = (lo + hi) / 2
        steps.append(SolutionStep(title: "Resultado", math: "x \\approx \(fmt(result))"))
        return (result, steps)
    }
    
    /// Secant method.
    static func secant(
        f: (Double) -> Double,
        x0: Double,
        x1: Double,
        tolerance: Double = 1e-12,
        maxIter: Int = 100
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var xPrev = x0, xCurr = x1
        
        steps.append(SolutionStep(
            title: "Método de la Secante",
            explanation: "x₀ = \(fmt(x0)), x₁ = \(fmt(x1))",
            math: "x_{n+1} = x_n - f(x_n) \\frac{x_n - x_{n-1}}{f(x_n) - f(x_{n-1})}"
        ))
        
        for i in 0..<maxIter {
            let fPrev = f(xPrev)
            let fCurr = f(xCurr)
            
            guard Swift.abs(fCurr - fPrev) > 1e-15 else { break }
            
            let xNew = xCurr - fCurr * (xCurr - xPrev) / (fCurr - fPrev)
            
            if i < 10 {
                steps.append(SolutionStep(
                    title: "Iteración \(i + 1)",
                    math: "x_{\(i + 2)} = \(fmt(xNew))"
                ))
            }
            
            if Swift.abs(xNew - xCurr) < tolerance {
                steps.append(SolutionStep(title: "Convergencia en \(i + 1) iteraciones", math: "x \\approx \(fmt(xNew))"))
                return (xNew, steps)
            }
            
            xPrev = xCurr
            xCurr = xNew
        }
        
        return (xCurr, steps)
    }
    
    /// Brent's method (combines bisection, secant, inverse quadratic interpolation).
    static func brent(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        tolerance: Double = 1e-12,
        maxIter: Int = 100
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Método de Brent",
            explanation: "Combina bisección, secante e interpolación cuadrática inversa"
        ))
        
        var lo = a, hi = b
        var fa = f(lo), fb = f(hi)
        
        guard fa * fb < 0 else {
            steps.append(SolutionStep(title: "Error", explanation: "f(a) y f(b) deben tener signos opuestos"))
            return (.nan, steps)
        }
        
        if Swift.abs(fa) < Swift.abs(fb) {
            swap(&lo, &hi); swap(&fa, &fb)
        }
        
        var c = lo, fc = fa
        var d = hi - lo
        var mflag = true
        
        for i in 0..<maxIter {
            if Swift.abs(fb) < tolerance || Swift.abs(hi - lo) < tolerance {
                steps.append(SolutionStep(title: "Convergencia en \(i) iteraciones", math: "x \\approx \(fmt(hi))"))
                return (hi, steps)
            }
            
            var s: Double
            if Swift.abs(fa - fc) > 1e-15 && Swift.abs(fb - fc) > 1e-15 {
                // Inverse quadratic interpolation
                s = lo * fb * fc / ((fa - fb) * (fa - fc))
                  + hi * fa * fc / ((fb - fa) * (fb - fc))
                  + c * fa * fb / ((fc - fa) * (fc - fb))
            } else {
                // Secant
                s = hi - fb * (hi - lo) / (fb - fa)
            }
            
            // Conditions for bisection fallback
            let cond1 = (s < (3 * lo + hi) / 4 || s > hi)
            let cond2 = mflag && Swift.abs(s - hi) >= Swift.abs(hi - c) / 2
            let cond3 = !mflag && Swift.abs(s - hi) >= Swift.abs(c - d) / 2
            
            if cond1 || cond2 || cond3 {
                s = (lo + hi) / 2
                mflag = true
            } else {
                mflag = false
            }
            
            let fs = f(s)
            d = c; c = hi; fc = fb
            
            if fa * fs < 0 { hi = s; fb = fs }
            else { lo = s; fa = fs }
            
            if Swift.abs(fa) < Swift.abs(fb) {
                swap(&lo, &hi); swap(&fa, &fb)
            }
        }
        
        return (hi, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Numerical Integration
    // ─────────────────────────────────────────────
    
    /// Simpson's 1/3 rule.
    static func simpson(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        n: Int = 1000
    ) -> (Double, [SolutionStep]) {
        let N = n % 2 == 0 ? n : n + 1
        let h = (b - a) / Double(N)
        var sum = f(a) + f(b)
        
        for i in 1..<N {
            let x = a + Double(i) * h
            sum += (i % 2 == 0 ? 2 : 4) * f(x)
        }
        
        let result = sum * h / 3
        
        let steps = [
            SolutionStep(
                title: "Regla de Simpson 1/3",
                explanation: "n = \(N) subintervalos, h = \(fmt(h))",
                math: "\\int_{\(fmt(a))}^{\(fmt(b))} f(x)\\,dx \\approx \\frac{h}{3}\\left[f(a) + 4\\sum_{\\text{impar}} f(x_i) + 2\\sum_{\\text{par}} f(x_i) + f(b)\\right]"
            ),
            SolutionStep(title: "Resultado", math: "\\approx \(fmt(result))")
        ]
        
        return (result, steps)
    }
    
    /// Simpson's rule using symbolic expression.
    static func simpsonSymbolic(
        _ expr: ExprNode,
        variable v: String = "x",
        from a: Double,
        to b: Double,
        n: Int = 1000
    ) -> (Double, [SolutionStep]) {
        return simpson(
            f: { x in expr.substitute(v, with: .number(x)).numericValue ?? 0 },
            a: a,
            b: b,
            n: n
        )
    }
    
    /// Gauss-Legendre quadrature (5-point).
    static func gaussLegendre(
        f: (Double) -> Double,
        a: Double,
        b: Double
    ) -> (Double, [SolutionStep]) {
        // 5-point Gauss-Legendre nodes and weights on [-1, 1]
        let nodes: [Double] = [
            -0.9061798459386640, -0.5384693101056831, 0.0,
             0.5384693101056831,  0.9061798459386640
        ]
        let weights: [Double] = [
            0.2369268850561891, 0.4786286704993665, 0.5688888888888889,
            0.4786286704993665, 0.2369268850561891
        ]
        
        // Transform from [-1,1] to [a,b]
        let mid = (b + a) / 2
        let halfLen = (b - a) / 2
        
        var sum = 0.0
        for i in 0..<5 {
            let x = mid + halfLen * nodes[i]
            sum += weights[i] * f(x)
        }
        
        let result = halfLen * sum
        
        let steps = [
            SolutionStep(
                title: "Cuadratura de Gauss-Legendre (5 puntos)",
                math: "\\int_{\(fmt(a))}^{\(fmt(b))} f(x)\\,dx \\approx \(fmt(result))"
            )
        ]
        
        return (result, steps)
    }
    
    /// Adaptive Simpson's integration (automatic error control).
    static func adaptiveSimpson(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        tolerance: Double = 1e-10,
        maxDepth: Int = 50
    ) -> Double {
        return adaptiveSimpsonRecursive(f: f, a: a, b: b, tolerance: tolerance, depth: 0, maxDepth: maxDepth)
    }
    
    private static func adaptiveSimpsonRecursive(
        f: (Double) -> Double,
        a: Double, b: Double,
        tolerance: Double,
        depth: Int, maxDepth: Int
    ) -> Double {
        let mid = (a + b) / 2
        let h = (b - a) / 6
        let fa = f(a), fm = f(mid), fb = f(b)
        let whole = h * (fa + 4 * fm + fb)
        
        let lm = (a + mid) / 2, rm = (mid + b) / 2
        let left = (mid - a) / 6 * (fa + 4 * f(lm) + fm)
        let right = (b - mid) / 6 * (fm + 4 * f(rm) + fb)
        let combined = left + right
        
        if depth >= maxDepth || Swift.abs(combined - whole) < 15 * tolerance {
            return combined + (combined - whole) / 15
        }
        
        return adaptiveSimpsonRecursive(f: f, a: a, b: mid, tolerance: tolerance / 2, depth: depth + 1, maxDepth: maxDepth) +
               adaptiveSimpsonRecursive(f: f, a: mid, b: b, tolerance: tolerance / 2, depth: depth + 1, maxDepth: maxDepth)
    }
    
    /// Romberg integration.
    static func romberg(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        maxOrder: Int = 10,
        tolerance: Double = 1e-12
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var R = Array(repeating: Array(repeating: 0.0, count: maxOrder + 1), count: maxOrder + 1)
        
        steps.append(SolutionStep(
            title: "Integración de Romberg",
            explanation: "Extrapolación de Richardson sobre la regla del trapecio"
        ))
        
        // R[0][0] = trapezoidal with 1 interval
        R[0][0] = (b - a) / 2 * (f(a) + f(b))
        
        for i in 1...maxOrder {
            // Composite trapezoidal with 2^i intervals
            let n = 1 << i
            let h = (b - a) / Double(n)
            var sum = 0.0
            for k in stride(from: 1, to: n, by: 2) {
                sum += f(a + Double(k) * h)
            }
            R[i][0] = R[i - 1][0] / 2 + h * sum
            
            // Richardson extrapolation
            for j in 1...i {
                let factor = Foundation.pow(4.0, Double(j))
                R[i][j] = (factor * R[i][j - 1] - R[i - 1][j - 1]) / (factor - 1)
            }
            
            if i >= 2 && Swift.abs(R[i][i] - R[i - 1][i - 1]) < tolerance {
                steps.append(SolutionStep(
                    title: "Convergencia en orden \(i)",
                    math: "\\int \\approx \(fmt(R[i][i]))"
                ))
                return (R[i][i], steps)
            }
        }
        
        let result = R[maxOrder][maxOrder]
        steps.append(SolutionStep(title: "Resultado", math: "\\int \\approx \(fmt(result))"))
        return (result, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Interpolation
    // ─────────────────────────────────────────────
    
    /// Lagrange interpolation polynomial.
    static func lagrangeInterpolation(
        points: [(Double, Double)],
        at x: Double
    ) -> Double {
        let n = points.count
        var result = 0.0
        
        for i in 0..<n {
            var basis = 1.0
            for j in 0..<n where j != i {
                basis *= (x - points[j].0) / (points[i].0 - points[j].0)
            }
            result += points[i].1 * basis
        }
        
        return result
    }
    
    /// Newton's divided differences interpolation.
    static func newtonInterpolation(
        points: [(Double, Double)]
    ) -> ([Double], [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = points.count
        
        steps.append(SolutionStep(
            title: "Interpolación de Newton",
            explanation: "Diferencias divididas con \(n) puntos"
        ))
        
        // Build divided difference table
        var dd = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { dd[i][0] = points[i].1 }
        
        for j in 1..<n {
            for i in 0..<(n - j) {
                dd[i][j] = (dd[i + 1][j - 1] - dd[i][j - 1]) / (points[i + j].0 - points[i].0)
            }
        }
        
        // Coefficients are dd[0][0], dd[0][1], ..., dd[0][n-1]
        let coeffs = (0..<n).map { dd[0][$0] }
        
        var poly = "\(fmt(coeffs[0]))"
        for k in 1..<n {
            let terms = (0..<k).map { "(x - \(fmt(points[$0].0)))" }.joined(separator: "")
            poly += " + \(fmt(coeffs[k]))\(terms)"
        }
        
        steps.append(SolutionStep(
            title: "Polinomio interpolante",
            math: "P(x) = \(poly)"
        ))
        
        return (coeffs, steps)
    }
    
    /// Cubic spline interpolation (natural boundary conditions).
    static func cubicSpline(
        points: [(Double, Double)]
    ) -> ([(Double, Double, Double, Double)], [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = points.count - 1
        guard n >= 1 else { return ([], steps) }
        
        steps.append(SolutionStep(
            title: "Spline cúbico natural",
            explanation: "\(n + 1) puntos, \(n) intervalos"
        ))
        
        let x = points.map(\.0)
        let y = points.map(\.1)
        var h = Array(repeating: 0.0, count: n)
        for i in 0..<n { h[i] = x[i + 1] - x[i] }
        
        // Solve for second derivatives (natural spline: S''(x_0) = S''(x_n) = 0)
        var A = Array(repeating: Array(repeating: 0.0, count: n + 1), count: n + 1)
        var rhs = Array(repeating: 0.0, count: n + 1)
        
        A[0][0] = 1; A[n][n] = 1
        
        for i in 1..<n {
            A[i][i - 1] = h[i - 1]
            A[i][i] = 2 * (h[i - 1] + h[i])
            A[i][i + 1] = h[i]
            rhs[i] = 3 * ((y[i + 1] - y[i]) / h[i] - (y[i] - y[i - 1]) / h[i - 1])
        }
        
        // Solve tridiagonal system
        let c = LinearAlgebra.solve(A, b: rhs) ?? Array(repeating: 0.0, count: n + 1)
        
        // Compute coefficients for each interval
        var splines: [(Double, Double, Double, Double)] = [] // (a, b, c, d) for a + b(x-xi) + c(x-xi)² + d(x-xi)³
        
        for i in 0..<n {
            let a = y[i]
            let b = (y[i + 1] - y[i]) / h[i] - h[i] * (2 * c[i] + c[i + 1]) / 3
            let d = (c[i + 1] - c[i]) / (3 * h[i])
            splines.append((a, b, c[i], d))
        }
        
        steps.append(SolutionStep(
            title: "Coeficientes del spline",
            explanation: "S_i(x) = a_i + b_i(x-x_i) + c_i(x-x_i)² + d_i(x-x_i)³"
        ))
        
        return (splines, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - ODE Numerical Solvers
    // ─────────────────────────────────────────────
    
    /// Classic 4th-order Runge-Kutta.
    static func rk4(
        dydt: (Double, Double) -> Double,
        y0: Double,
        tStart: Double,
        tEnd: Double,
        h: Double = 0.01
    ) -> [(Double, Double)] {
        var results: [(Double, Double)] = [(tStart, y0)]
        var t = tStart, y = y0
        
        while t < tEnd - 1e-15 {
            let step = Swift.min(h, tEnd - t)
            let k1 = step * dydt(t, y)
            let k2 = step * dydt(t + step / 2, y + k1 / 2)
            let k3 = step * dydt(t + step / 2, y + k2 / 2)
            let k4 = step * dydt(t + step, y + k3)
            
            y += (k1 + 2 * k2 + 2 * k3 + k4) / 6
            t += step
            results.append((t, y))
        }
        
        return results
    }
    
    /// RK4 for systems: y' = f(t, y) where y is a vector.
    static func rk4System(
        f: (Double, [Double]) -> [Double],
        y0: [Double],
        tStart: Double,
        tEnd: Double,
        h: Double = 0.01
    ) -> [(Double, [Double])] {
        let n = y0.count
        var results: [(Double, [Double])] = [(tStart, y0)]
        var t = tStart, y = y0
        
        while t < tEnd - 1e-15 {
            let step = Swift.min(h, tEnd - t)
            
            let k1 = f(t, y).map { $0 * step }
            let y2 = zip(y, k1).map { $0.0 + $0.1 / 2 }
            let k2 = f(t + step / 2, y2).map { $0 * step }
            let y3 = zip(y, k2).map { $0.0 + $0.1 / 2 }
            let k3 = f(t + step / 2, y3).map { $0 * step }
            let y4 = zip(y, k3).map { $0.0 + $0.1 }
            let k4 = f(t + step, y4).map { $0 * step }
            
            for i in 0..<n {
                y[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) / 6
            }
            
            t += step
            results.append((t, y))
        }
        
        return results
    }
    
    /// Runge-Kutta-Fehlberg (RKF45) with adaptive step size.
    static func rkf45(
        dydt: (Double, Double) -> Double,
        y0: Double,
        tStart: Double,
        tEnd: Double,
        tolerance: Double = 1e-6,
        hMin: Double = 1e-10,
        hMax: Double = 0.5
    ) -> [(Double, Double)] {
        var results: [(Double, Double)] = [(tStart, y0)]
        var t = tStart, y = y0
        var h = 0.01
        
        // Fehlberg coefficients
        let a2 = 1.0/4, a3 = 3.0/8, a4 = 12.0/13, a5 = 1.0, a6 = 1.0/2
        let b21 = 1.0/4
        let b31 = 3.0/32, b32 = 9.0/32
        let b41 = 1932.0/2197, b42 = -7200.0/2197, b43 = 7296.0/2197
        let b51 = 439.0/216, b52 = -8.0, b53 = 3680.0/513, b54 = -845.0/4104
        let b61 = -8.0/27, b62 = 2.0, b63 = -3544.0/2565, b64 = 1859.0/4104, b65 = -11.0/40
        
        let c1 = 25.0/216, c3 = 1408.0/2565, c4 = 2197.0/4104, c5 = -1.0/5
        let d1 = 16.0/135, d3 = 6656.0/12825, d4 = 28561.0/56430, d5 = -9.0/50, d6 = 2.0/55
        
        while t < tEnd - 1e-15 {
            h = Swift.min(h, tEnd - t)
            
            let k1 = h * dydt(t, y)
            let k2 = h * dydt(t + a2 * h, y + b21 * k1)
            let k3 = h * dydt(t + a3 * h, y + b31 * k1 + b32 * k2)
            let k4 = h * dydt(t + a4 * h, y + b41 * k1 + b42 * k2 + b43 * k3)
            let k5 = h * dydt(t + a5 * h, y + b51 * k1 + b52 * k2 + b53 * k3 + b54 * k4)
            let k6 = h * dydt(t + a6 * h, y + b61 * k1 + b62 * k2 + b63 * k3 + b64 * k4 + b65 * k5)
            
            let y4 = y + c1 * k1 + c3 * k3 + c4 * k4 + c5 * k5
            let y5 = y + d1 * k1 + d3 * k3 + d4 * k4 + d5 * k5 + d6 * k6
            
            let err = Swift.abs(y5 - y4)
            
            if err <= tolerance || h <= hMin {
                t += h
                y = y5
                results.append((t, y))
            }
            
            // Adjust step size
            if err > 1e-15 {
                let factor = 0.84 * Foundation.pow(tolerance / err, 0.25)
                h *= Swift.max(0.1, Swift.min(4.0, factor))
                h = Swift.max(hMin, Swift.min(hMax, h))
            }
        }
        
        return results
    }
    
    /// Adams-Bashforth 4-step method (explicit multistep).
    static func adamsBashforth4(
        dydt: (Double, Double) -> Double,
        y0: Double,
        tStart: Double,
        tEnd: Double,
        h: Double = 0.01
    ) -> [(Double, Double)] {
        // Bootstrap with RK4 for first 4 points
        let bootstrap = rk4(dydt: dydt, y0: y0, tStart: tStart, tEnd: tStart + 3 * h, h: h)
        guard bootstrap.count >= 4 else { return bootstrap }
        
        var results = bootstrap
        var f = bootstrap.map { dydt($0.0, $0.1) }
        var t = bootstrap.last!.0
        var y = bootstrap.last!.1
        
        while t < tEnd - 1e-15 {
            let step = Swift.min(h, tEnd - t)
            let n = f.count
            
            y += step / 24 * (55 * f[n - 1] - 59 * f[n - 2] + 37 * f[n - 3] - 9 * f[n - 4])
            t += step
            
            f.append(dydt(t, y))
            results.append((t, y))
        }
        
        return results
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Optimization
    // ─────────────────────────────────────────────
    
    /// Golden section search for minimum on [a, b].
    static func goldenSection(
        f: (Double) -> Double,
        a: Double,
        b: Double,
        tolerance: Double = 1e-10,
        maxIter: Int = 200
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let phi = (Foundation.sqrt(5) - 1) / 2  // ≈ 0.618
        
        steps.append(SolutionStep(
            title: "Búsqueda de Sección Áurea",
            explanation: "Encontrar mínimo en [\(fmt(a)), \(fmt(b))]"
        ))
        
        var lo = a, hi = b
        var x1 = hi - phi * (hi - lo)
        var x2 = lo + phi * (hi - lo)
        var f1 = f(x1), f2 = f(x2)
        
        for _ in 0..<maxIter {
            if (hi - lo) < tolerance { break }
            
            if f1 < f2 {
                hi = x2
                x2 = x1; f2 = f1
                x1 = hi - phi * (hi - lo)
                f1 = f(x1)
            } else {
                lo = x1
                x1 = x2; f1 = f2
                x2 = lo + phi * (hi - lo)
                f2 = f(x2)
            }
        }
        
        let result = (lo + hi) / 2
        steps.append(SolutionStep(
            title: "Mínimo encontrado",
            math: "x^* \\approx \(fmt(result)), \\; f(x^*) \\approx \(fmt(f(result)))"
        ))
        
        return (result, steps)
    }
    
    /// Gradient descent (1D).
    static func gradientDescent1D(
        df: (Double) -> Double,
        x0: Double,
        learningRate: Double = 0.01,
        tolerance: Double = 1e-10,
        maxIter: Int = 10000
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var x = x0
        
        steps.append(SolutionStep(
            title: "Descenso de gradiente",
            explanation: "η = \(learningRate), x₀ = \(fmt(x0))"
        ))
        
        for i in 0..<maxIter {
            let grad = df(x)
            let xNew = x - learningRate * grad
            
            if Swift.abs(xNew - x) < tolerance {
                steps.append(SolutionStep(title: "Convergencia en \(i) iteraciones", math: "x^* \\approx \(fmt(xNew))"))
                return (xNew, steps)
            }
            
            x = xNew
        }
        
        return (x, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Curve Fitting
    // ─────────────────────────────────────────────
    
    /// Least squares polynomial fit of degree d.
    static func polyFit(
        points: [(Double, Double)],
        degree: Int
    ) -> ([Double], [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = points.count
        let m = degree + 1
        
        steps.append(SolutionStep(
            title: "Ajuste polinomial por mínimos cuadrados",
            explanation: "Grado \(degree), \(n) puntos de datos"
        ))
        
        // Build Vandermonde matrix
        var A: Matrix = Array(repeating: Array(repeating: 0.0, count: m), count: n)
        var b: Vec = Array(repeating: 0.0, count: n)
        
        for i in 0..<n {
            let x = points[i].0
            b[i] = points[i].1
            for j in 0..<m {
                A[i][j] = Foundation.pow(x, Double(j))
            }
        }
        
        // Normal equations: AᵀA c = Aᵀb
        let AtA = LinearAlgebra.multiply(LinearAlgebra.transpose(A), A)
        let Atb = LinearAlgebra.multiplyVec(LinearAlgebra.transpose(A), b)
        
        guard let coeffs = LinearAlgebra.solve(AtA, b: Atb) else {
            steps.append(SolutionStep(title: "Error", explanation: "Sistema singular"))
            return ([], steps)
        }
        
        let polyStr = coeffs.enumerated().map { i, c in
            i == 0 ? fmt(c) : "\(fmt(c))x^{\(i)}"
        }.joined(separator: " + ")
        
        steps.append(SolutionStep(
            title: "Polinomio de ajuste",
            math: "p(x) = \(polyStr)"
        ))
        
        // R² computation
        let yMean = b.reduce(0, +) / Double(n)
        var ssTot = 0.0, ssRes = 0.0
        for i in 0..<n {
            var predicted = 0.0
            for j in 0..<m { predicted += coeffs[j] * Foundation.pow(points[i].0, Double(j)) }
            ssRes += (points[i].1 - predicted) * (points[i].1 - predicted)
            ssTot += (points[i].1 - yMean) * (points[i].1 - yMean)
        }
        let r2 = 1 - ssRes / Swift.max(ssTot, 1e-15)
        
        steps.append(SolutionStep(
            title: "Coeficiente de determinación",
            math: "R^2 = \(String(format: "%.6f", r2))"
        ))
        
        return (coeffs, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Finite Differences
    // ─────────────────────────────────────────────
    
    /// Numerical derivative using central differences.
    static func numericalDerivative(
        f: (Double) -> Double,
        at x: Double,
        h: Double = 1e-6
    ) -> Double {
        (f(x + h) - f(x - h)) / (2 * h)
    }
    
    /// Second numerical derivative.
    static func numericalSecondDerivative(
        f: (Double) -> Double,
        at x: Double,
        h: Double = 1e-4
    ) -> Double {
        (f(x + h) - 2 * f(x) + f(x - h)) / (h * h)
    }
    
    /// Richardson extrapolation for derivatives.
    static func richardsonDerivative(
        f: (Double) -> Double,
        at x: Double,
        h0: Double = 0.1,
        order: Int = 6
    ) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        var D = Array(repeating: Array(repeating: 0.0, count: order), count: order)
        
        for i in 0..<order {
            let h = h0 / Foundation.pow(2, Double(i))
            D[i][0] = (f(x + h) - f(x - h)) / (2 * h)
        }
        
        for j in 1..<order {
            for i in j..<order {
                let factor = Foundation.pow(4, Double(j))
                D[i][j] = (factor * D[i][j - 1] - D[i - 1][j - 1]) / (factor - 1)
            }
        }
        
        let result = D[order - 1][order - 1]
        steps.append(SolutionStep(
            title: "Extrapolación de Richardson",
            math: "f'(\(fmt(x))) \\approx \(fmt(result))"
        ))
        
        return (result, steps)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────
    
    private static func fmt(_ v: Double) -> String {
        if Swift.abs(v - Double(Int(v))) < 1e-10 && Swift.abs(v) < 1e12 { return "\(Int(v))" }
        return String(format: "%.6g", v)
    }
}
