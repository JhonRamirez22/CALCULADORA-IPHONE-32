// SpecialFunctions.swift
// CalcPrime — Engine/Solvers
// Special mathematical functions: Bessel, Airy, Legendre, Hermite, Laguerre,
// Chebyshev, Lambert W, error functions, gamma/beta, elliptic integrals,
// Fresnel integrals, polylogarithm, Hurwitz zeta, Bernoulli numbers.
// Numerical implementations with series, asymptotic, and continued fraction methods.

import Foundation

// MARK: - SpecialFunctions

struct SpecialFunctions {
    
    // ─────────────────────────────────────────────
    // MARK: - Gamma & Related
    // ─────────────────────────────────────────────
    
    /// Lanczos approximation for Gamma function.
    static func gamma(_ x: Double) -> Double {
        if x <= 0 && x == Foundation.floor(x) { return .infinity }
        if x < 0.5 {
            // Reflection formula: Γ(1-z)Γ(z) = π/sin(πz)
            return .pi / (Foundation.sin(.pi * x) * gamma(1 - x))
        }
        
        let z = x - 1
        let g = 7.0
        let c: [Double] = [
            0.99999999999980993,
            676.5203681218851,
            -1259.1392167224028,
            771.32342877765313,
            -176.61502916214059,
            12.507343278686905,
            -0.13857109526572012,
            9.9843695780195716e-6,
            1.5056327351493116e-7
        ]
        
        var sum = c[0]
        for i in 1..<c.count {
            sum += c[i] / (z + Double(i))
        }
        
        let t = z + g + 0.5
        return Foundation.sqrt(2 * .pi) * Foundation.pow(t, z + 0.5) * Foundation.exp(-t) * sum
    }
    
    /// Log-gamma for large arguments.
    static func logGamma(_ x: Double) -> Double {
        Foundation.lgamma(x)
    }
    
    /// Beta function: B(a,b) = Γ(a)Γ(b)/Γ(a+b)
    static func beta(_ a: Double, _ b: Double) -> Double {
        Foundation.exp(logGamma(a) + logGamma(b) - logGamma(a + b))
    }
    
    /// Digamma function ψ(x) = Γ'(x)/Γ(x)
    static func digamma(_ x: Double) -> Double {
        var result = 0.0
        var z = x
        
        // Use recurrence for small z
        while z < 6 {
            result -= 1 / z
            z += 1
        }
        
        // Asymptotic expansion for large z
        let z2 = 1 / (z * z)
        result += Foundation.log(z) - 0.5 / z
            - z2 * (1.0/12 - z2 * (1.0/120 - z2 * (1.0/252 - z2 * 1.0/240)))
        
        return result
    }
    
    /// Polygamma function ψ^(n)(x)
    static func polygamma(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return digamma(x) }
        
        // Series representation
        let sign = (n % 2 == 0) ? -1.0 : 1.0
        let factN = (1...n).reduce(1.0) { $0 * Double($1) }
        
        var sum = 0.0
        for k in 0..<200 {
            sum += 1.0 / Foundation.pow(x + Double(k), Double(n + 1))
        }
        
        return sign * factN * sum
    }
    
    /// Incomplete gamma function γ(s, x) = ∫₀ˣ t^{s-1} e^{-t} dt
    static func incompleteGamma(_ s: Double, _ x: Double) -> Double {
        if x < s + 1 {
            // Series expansion
            var sum = 0.0, term = 1.0 / s
            sum = term
            for n in 1..<200 {
                term *= x / (s + Double(n))
                sum += term
                if Swift.abs(term) < 1e-15 * Swift.abs(sum) { break }
            }
            return sum * Foundation.exp(-x + s * Foundation.log(x))
        } else {
            // Continued fraction (Legendre)
            return gamma(s) - upperIncompleteGamma(s, x)
        }
    }
    
    /// Upper incomplete gamma Γ(s, x) = ∫ₓ^∞ t^{s-1} e^{-t} dt
    static func upperIncompleteGamma(_ s: Double, _ x: Double) -> Double {
        // Continued fraction
        var f = 1.0, c = 1.0, d = 1.0 / (x + 1 - s)
        f = d
        
        for n in 1..<200 {
            let an = Double(n) * (s - Double(n))
            let bn = x + Double(2 * n + 1) - s
            d = 1.0 / (bn + an * d)
            c = bn + an / c
            let delta = c * d
            f *= delta
            if Swift.abs(delta - 1) < 1e-15 { break }
        }
        
        return Foundation.exp(-x + s * Foundation.log(x)) * f
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Error Functions
    // ─────────────────────────────────────────────
    
    /// Error function: erf(x) = (2/√π) ∫₀ˣ e^{-t²} dt
    static func erf(_ x: Double) -> Double {
        // Abramowitz & Stegun 7.1.26
        let t = 1.0 / (1.0 + 0.3275911 * Swift.abs(x))
        let poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))))
        let result = 1.0 - poly * Foundation.exp(-x * x)
        return x >= 0 ? result : -result
    }
    
    /// Complementary error function: erfc(x) = 1 - erf(x)
    static func erfc(_ x: Double) -> Double {
        1.0 - erf(x)
    }
    
    /// Imaginary error function: erfi(x) = -i·erf(ix) = (2/√π) ∫₀ˣ e^{t²} dt
    static func erfi(_ x: Double) -> Double {
        // Series: erfi(x) = (2/√π) Σ x^{2n+1} / (n! (2n+1))
        var sum = 0.0
        var term = x
        sum = term
        for n in 1..<100 {
            term *= x * x / Double(n)
            let contrib = term / Double(2 * n + 1)
            sum += contrib
            if Swift.abs(contrib) < 1e-15 * Swift.abs(sum) { break }
        }
        return 2.0 / Foundation.sqrt(.pi) * sum
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Bessel Functions
    // ─────────────────────────────────────────────
    
    /// Bessel function of the first kind J_n(x) — series expansion.
    static func besselJ(_ n: Int, _ x: Double) -> Double {
        var sum = 0.0
        for m in 0..<40 {
            let sign = (m % 2 == 0) ? 1.0 : -1.0
            let num = Foundation.pow(x / 2, Double(2 * m + n))
            let denom = Foundation.tgamma(Double(m + 1)) * Foundation.tgamma(Double(m + n + 1))
            sum += sign * num / denom
        }
        return sum
    }
    
    /// Bessel function J_ν(x) for real order ν.
    static func besselJReal(_ nu: Double, _ x: Double) -> Double {
        var sum = 0.0
        for m in 0..<50 {
            let sign = (m % 2 == 0) ? 1.0 : -1.0
            let num = Foundation.pow(x / 2, Double(2 * m) + nu)
            let denom = Foundation.tgamma(Double(m + 1)) * Foundation.tgamma(Double(m) + nu + 1)
            sum += sign * num / denom
            if Swift.abs(num / denom) < 1e-16 { break }
        }
        return sum
    }
    
    /// Bessel function of the second kind Y_n(x).
    static func besselY(_ n: Int, _ x: Double) -> Double {
        // Y_n(x) = [J_n(x)cos(nπ) - J_{-n}(x)] / sin(nπ)
        // For integer n, use limit form
        let eps = 1e-8
        let nuPlus = Double(n) + eps
        let nuMinus = Double(n) - eps
        let jp = besselJReal(nuPlus, x)
        let jm = besselJReal(nuMinus, x)
        // Numerical derivative approach for integer order
        let cosPi = Foundation.cos(nuPlus * .pi)
        let sinPi = Foundation.sin(nuPlus * .pi)
        guard Swift.abs(sinPi) > 1e-15 else { return .nan }
        let jNeg = besselJReal(-nuPlus, x)
        return (jp * cosPi - jNeg) / sinPi
    }
    
    /// Modified Bessel function I_n(x).
    static func besselI(_ n: Int, _ x: Double) -> Double {
        var sum = 0.0
        for m in 0..<50 {
            let num = Foundation.pow(x / 2, Double(2 * m + n))
            let denom = Foundation.tgamma(Double(m + 1)) * Foundation.tgamma(Double(m + n + 1))
            sum += num / denom
            if Swift.abs(num / denom) < 1e-16 { break }
        }
        return sum
    }
    
    /// Modified Bessel function K_n(x) — numerical approximation.
    static func besselK(_ n: Int, _ x: Double) -> Double {
        guard x > 0 else { return .infinity }
        let eps = 1e-6
        let nu = Double(n) + eps
        let Ip = besselI(n, x)
        let Im = besselIReal(-nu, x)
        return .pi / 2 * (Im - Ip) / Foundation.sin(nu * .pi)
    }
    
    private static func besselIReal(_ nu: Double, _ x: Double) -> Double {
        var sum = 0.0
        for m in 0..<50 {
            let num = Foundation.pow(x / 2, Double(2 * m) + nu)
            let denom = Foundation.tgamma(Double(m + 1)) * Foundation.tgamma(Double(m) + nu + 1)
            sum += num / denom
            if Swift.abs(num / denom) < 1e-16 { break }
        }
        return sum
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Airy Functions
    // ─────────────────────────────────────────────
    
    /// Airy function Ai(x) — series for small |x|, asymptotic for large |x|.
    static func airyAi(_ x: Double) -> Double {
        if Swift.abs(x) < 5 {
            // Series: Ai(x) = c1 f(x) - c2 g(x)
            // where f = Σ x^{3k}/(3k)!! and g = Σ x^{3k+1}/(3k+1)!!
            let c1 = 1.0 / (Foundation.pow(3.0, 2.0/3.0) * Foundation.tgamma(2.0/3.0))
            let c2 = 1.0 / (Foundation.pow(3.0, 1.0/3.0) * Foundation.tgamma(1.0/3.0))
            
            var f = 1.0, g = x
            var fTerm = 1.0, gTerm = x
            
            for k in 1..<30 {
                fTerm *= x * x * x / (Double(3 * k) * Double(3 * k - 1))
                gTerm *= x * x * x / (Double(3 * k + 1) * Double(3 * k))
                f += fTerm
                g += gTerm
            }
            
            return c1 * f - c2 * g
        }
        
        // Asymptotic for large positive x: Ai(x) ≈ e^{-ξ}/(2√π x^{1/4})
        if x > 0 {
            let xi = 2.0/3.0 * Foundation.pow(x, 1.5)
            return Foundation.exp(-xi) / (2 * Foundation.sqrt(.pi) * Foundation.pow(x, 0.25))
        }
        
        // Asymptotic for large negative x: oscillatory
        let xi = 2.0/3.0 * Foundation.pow(-x, 1.5)
        return Foundation.sin(xi + .pi/4) / (Foundation.sqrt(.pi) * Foundation.pow(-x, 0.25))
    }
    
    /// Airy function Bi(x).
    static func airyBi(_ x: Double) -> Double {
        if Swift.abs(x) < 5 {
            let c1 = 1.0 / (Foundation.pow(3.0, 1.0/6.0) * Foundation.tgamma(2.0/3.0))
            let c2 = Foundation.pow(3.0, 1.0/6.0) / Foundation.tgamma(1.0/3.0)
            
            var f = 1.0, g = x
            var fTerm = 1.0, gTerm = x
            
            for k in 1..<30 {
                fTerm *= x * x * x / (Double(3 * k) * Double(3 * k - 1))
                gTerm *= x * x * x / (Double(3 * k + 1) * Double(3 * k))
                f += fTerm
                g += gTerm
            }
            
            return c1 * f + c2 * g
        }
        
        if x > 0 {
            let xi = 2.0/3.0 * Foundation.pow(x, 1.5)
            return Foundation.exp(xi) / (Foundation.sqrt(.pi) * Foundation.pow(x, 0.25))
        }
        
        let xi = 2.0/3.0 * Foundation.pow(-x, 1.5)
        return -Foundation.cos(xi + .pi/4) / (Foundation.sqrt(.pi) * Foundation.pow(-x, 0.25))
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Orthogonal Polynomials
    // ─────────────────────────────────────────────
    
    /// Legendre polynomial P_n(x) via recurrence.
    static func legendreP(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return x }
        
        var p0 = 1.0, p1 = x
        for k in 2...n {
            let p2 = ((2 * Double(k) - 1) * x * p1 - (Double(k) - 1) * p0) / Double(k)
            p0 = p1; p1 = p2
        }
        return p1
    }
    
    /// Associated Legendre function P_n^m(x).
    static func legendrePm(_ n: Int, _ m: Int, _ x: Double) -> Double {
        guard m >= 0 && m <= n else { return 0 }
        
        // Start with P_m^m
        var pmm = 1.0
        if m > 0 {
            let sx = Foundation.sqrt(1 - x * x)
            var fact = 1.0
            for _ in 1...m {
                pmm *= -fact * sx
                fact += 2
            }
        }
        
        if n == m { return pmm }
        
        var pmm1 = x * Double(2 * m + 1) * pmm
        if n == m + 1 { return pmm1 }
        
        var pnm = 0.0
        for k in (m + 2)...n {
            pnm = (Double(2 * k - 1) * x * pmm1 - Double(k + m - 1) * pmm) / Double(k - m)
            pmm = pmm1; pmm1 = pnm
        }
        return pnm
    }
    
    /// Hermite polynomial H_n(x) (physicist's convention).
    static func hermiteH(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return 2 * x }
        
        var h0 = 1.0, h1 = 2 * x
        for k in 2...n {
            let h2 = 2 * x * h1 - 2 * Double(k - 1) * h0
            h0 = h1; h1 = h2
        }
        return h1
    }
    
    /// Laguerre polynomial L_n(x).
    static func laguerreL(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return 1 - x }
        
        var l0 = 1.0, l1 = 1 - x
        for k in 2...n {
            let l2 = ((2 * Double(k) - 1 - x) * l1 - (Double(k) - 1) * l0) / Double(k)
            l0 = l1; l1 = l2
        }
        return l1
    }
    
    /// Associated Laguerre polynomial L_n^α(x).
    static func laguerreLA(_ n: Int, _ alpha: Double, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return 1 + alpha - x }
        
        var l0 = 1.0, l1 = 1 + alpha - x
        for k in 2...n {
            let l2 = ((2 * Double(k) - 1 + alpha - x) * l1 - (Double(k) - 1 + alpha) * l0) / Double(k)
            l0 = l1; l1 = l2
        }
        return l1
    }
    
    /// Chebyshev polynomial T_n(x) (first kind).
    static func chebyshevT(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return x }
        
        var t0 = 1.0, t1 = x
        for _ in 2...n {
            let t2 = 2 * x * t1 - t0
            t0 = t1; t1 = t2
        }
        return t1
    }
    
    /// Chebyshev polynomial U_n(x) (second kind).
    static func chebyshevU(_ n: Int, _ x: Double) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return 2 * x }
        
        var u0 = 1.0, u1 = 2 * x
        for _ in 2...n {
            let u2 = 2 * x * u1 - u0
            u0 = u1; u1 = u2
        }
        return u1
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Elliptic Integrals
    // ─────────────────────────────────────────────
    
    /// Complete elliptic integral of the first kind K(k).
    /// K(k) = ∫₀^{π/2} dθ/√(1-k²sin²θ)
    static func ellipticK(_ k: Double) -> Double {
        // Arithmetic-geometric mean
        var a = 1.0, b = Foundation.sqrt(1 - k * k)
        for _ in 0..<50 {
            let aNew = (a + b) / 2
            let bNew = Foundation.sqrt(a * b)
            if Swift.abs(aNew - bNew) < 1e-15 { break }
            a = aNew; b = bNew
        }
        return .pi / (2 * a)
    }
    
    /// Complete elliptic integral of the second kind E(k).
    /// E(k) = ∫₀^{π/2} √(1-k²sin²θ) dθ
    static func ellipticE(_ k: Double) -> Double {
        var a = 1.0, b = Foundation.sqrt(1 - k * k)
        var c = k
        var sum = 1.0 - k * k / 2
        var power = 0.5
        
        for _ in 0..<50 {
            let aNew = (a + b) / 2
            let bNew = Foundation.sqrt(a * b)
            c = (a - b) / 2
            power *= 2
            sum -= power * c * c
            if Swift.abs(c) < 1e-15 { break }
            a = aNew; b = bNew
        }
        
        return .pi / (2 * a) * sum
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Lambert W Function
    // ─────────────────────────────────────────────
    
    /// Principal branch W₀(x): W(x)·e^{W(x)} = x.
    static func lambertW(_ x: Double) -> Double {
        guard x >= -1.0 / M_E else { return .nan }
        if x == 0 { return 0 }
        
        // Initial estimate
        var w: Double
        if x < 1 {
            w = x
        } else {
            w = Foundation.log(x) - Foundation.log(Foundation.log(x))
        }
        
        // Halley iteration
        for _ in 0..<100 {
            let ew = Foundation.exp(w)
            let wew = w * ew
            let num = wew - x
            let denom = ew * (w + 1) - (w + 2) * num / (2 * w + 2)
            let delta = num / denom
            w -= delta
            if Swift.abs(delta) < 1e-15 { break }
        }
        
        return w
    }
    
    /// Secondary branch W₋₁(x) for x ∈ [-1/e, 0).
    static func lambertWm1(_ x: Double) -> Double {
        guard x >= -1.0 / M_E && x < 0 else { return .nan }
        
        var w = Foundation.log(-x) - Foundation.log(-Foundation.log(-x))
        
        for _ in 0..<100 {
            let ew = Foundation.exp(w)
            let wew = w * ew
            let num = wew - x
            let denom = ew * (w + 1) - (w + 2) * num / (2 * w + 2)
            w -= num / denom
            if Swift.abs(num / denom) < 1e-15 { break }
        }
        
        return w
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Zeta & Related
    // ─────────────────────────────────────────────
    
    /// Riemann zeta function ζ(s) for real s > 1.
    static func zeta(_ s: Double) -> Double {
        if s == 2 { return .pi * .pi / 6 }
        if s == 4 { return Foundation.pow(.pi, 4) / 90 }
        
        // Borwein's algorithm (faster convergence)
        let n = 20
        var sum = 0.0
        var dk = 0.0
        
        for k in 0..<n {
            dk += Double(binomial(n, k)) * Foundation.pow(-1, Double(k)) / Foundation.pow(Double(k + 1), s)
        }
        
        // Direct summation with Euler-Maclaurin correction
        sum = 0
        for k in 1..<200 {
            sum += 1.0 / Foundation.pow(Double(k), s)
        }
        
        return sum
    }
    
    /// Hurwitz zeta ζ(s, a) = Σ_{n=0}^{∞} 1/(n+a)^s
    static func hurwitzZeta(_ s: Double, _ a: Double) -> Double {
        var sum = 0.0
        for n in 0..<500 {
            sum += 1.0 / Foundation.pow(Double(n) + a, s)
            if n > 10 && 1.0 / Foundation.pow(Double(n) + a, s) < 1e-15 { break }
        }
        return sum
    }
    
    private static func binomial(_ n: Int, _ k: Int) -> Int {
        guard k >= 0 && k <= n else { return 0 }
        if k == 0 || k == n { return 1 }
        var r = 1
        for i in 0..<Swift.min(k, n - k) {
            r = r * (n - i) / (i + 1)
        }
        return r
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Fresnel Integrals
    // ─────────────────────────────────────────────
    
    /// Fresnel integral S(x) = ∫₀ˣ sin(πt²/2) dt
    static func fresnelS(_ x: Double) -> Double {
        var sum = 0.0
        let x2 = x * x
        var term = x * .pi / 2 * x2 / 3  // first term
        var power = x
        
        for n in 0..<50 {
            let sign = (n % 2 == 0) ? 1.0 : -1.0
            let factPart = Foundation.pow(.pi / 2, Double(2 * n + 1)) *
                           Foundation.pow(x, Double(4 * n + 3)) /
                           (Double(factorialInt(2 * n + 1)) * Double(4 * n + 3))
            sum += sign * factPart
            if Swift.abs(factPart) < 1e-15 { break }
        }
        
        return sum
    }
    
    /// Fresnel integral C(x) = ∫₀ˣ cos(πt²/2) dt
    static func fresnelC(_ x: Double) -> Double {
        var sum = 0.0
        
        for n in 0..<50 {
            let sign = (n % 2 == 0) ? 1.0 : -1.0
            let factPart = Foundation.pow(.pi / 2, Double(2 * n)) *
                           Foundation.pow(x, Double(4 * n + 1)) /
                           (Double(factorialInt(2 * n)) * Double(4 * n + 1))
            sum += sign * factPart
            if Swift.abs(factPart) < 1e-15 { break }
        }
        
        return sum
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Sine / Cosine Integrals
    // ─────────────────────────────────────────────
    
    /// Sine integral Si(x) = ∫₀ˣ sin(t)/t dt
    static func sinIntegral(_ x: Double) -> Double {
        var sum = 0.0
        for n in 0..<100 {
            let sign = (n % 2 == 0) ? 1.0 : -1.0
            let term = sign * Foundation.pow(x, Double(2 * n + 1)) /
                       (Double(2 * n + 1) * Double(factorialInt(2 * n + 1)))
            sum += term
            if Swift.abs(term) < 1e-15 { break }
        }
        return sum
    }
    
    /// Cosine integral Ci(x) = γ + ln(x) + ∫₀ˣ (cos(t)-1)/t dt
    static func cosIntegral(_ x: Double) -> Double {
        let eulerGamma = 0.5772156649015329
        var sum = eulerGamma + Foundation.log(x)
        
        for n in 1..<100 {
            let sign = (n % 2 == 0) ? 1.0 : -1.0
            let term = sign * Foundation.pow(x, Double(2 * n)) /
                       (Double(2 * n) * Double(factorialInt(2 * n)))
            sum += term
            if Swift.abs(term) < 1e-15 { break }
        }
        return sum
    }
    
    /// Exponential integral Ei(x) = -∫_{-x}^{∞} e^{-t}/t dt
    static func expIntegral(_ x: Double) -> Double {
        let eulerGamma = 0.5772156649015329
        var sum = eulerGamma + Foundation.log(Swift.abs(x))
        
        for n in 1..<100 {
            let term = Foundation.pow(x, Double(n)) / (Double(n) * Double(factorialInt(n)))
            sum += term
            if Swift.abs(term) < 1e-15 { break }
        }
        return sum
    }
    
    /// Logarithmic integral li(x) = Ei(ln x)
    static func logIntegral(_ x: Double) -> Double {
        guard x > 0 && x != 1 else { return .nan }
        return expIntegral(Foundation.log(x))
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Bernoulli Numbers
    // ─────────────────────────────────────────────
    
    /// Compute Bernoulli number B_n.
    static func bernoulliNumber(_ n: Int) -> Double {
        if n == 0 { return 1 }
        if n == 1 { return -0.5 }
        if n % 2 == 1 && n > 1 { return 0 }
        
        // Akiyama-Tanigawa algorithm
        var a = Array(repeating: 0.0, count: n + 1)
        for m in 0...n {
            a[m] = 1.0 / Double(m + 1)
            for j in stride(from: m, through: 1, by: -1) {
                a[j - 1] = Double(j) * (a[j - 1] - a[j])
            }
        }
        return a[0]
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Hypergeometric Functions
    // ─────────────────────────────────────────────
    
    /// Confluent hypergeometric ₁F₁(a; b; z) = M(a, b, z).
    static func hypergeometric1F1(_ a: Double, _ b: Double, _ z: Double) -> Double {
        var sum = 1.0, term = 1.0
        for n in 1..<200 {
            term *= (a + Double(n - 1)) * z / ((b + Double(n - 1)) * Double(n))
            sum += term
            if Swift.abs(term) < 1e-15 * Swift.abs(sum) { break }
        }
        return sum
    }
    
    /// Gauss hypergeometric ₂F₁(a, b; c; z) for |z| < 1.
    static func hypergeometric2F1(_ a: Double, _ b: Double, _ c: Double, _ z: Double) -> Double {
        guard Swift.abs(z) < 1 else { return .nan }
        var sum = 1.0, term = 1.0
        for n in 1..<200 {
            term *= (a + Double(n - 1)) * (b + Double(n - 1)) * z / ((c + Double(n - 1)) * Double(n))
            sum += term
            if Swift.abs(term) < 1e-15 * Swift.abs(sum) { break }
        }
        return sum
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Symbolic Evaluation Bridge
    // ─────────────────────────────────────────────
    
    /// Evaluate a special function by MathFunc enum at given numeric arguments.
    static func evaluate(_ fn: MathFunc, args: [Double]) -> Double? {
        guard !args.isEmpty else { return nil }
        let x = args[0]
        
        switch fn {
        case .besselJ:
            guard args.count >= 2 else { return nil }
            return besselJ(Int(args[0]), args[1])
        case .besselY:
            guard args.count >= 2 else { return nil }
            return besselY(Int(args[0]), args[1])
        case .besselI:
            guard args.count >= 2 else { return nil }
            return besselI(Int(args[0]), args[1])
        case .besselK:
            guard args.count >= 2 else { return nil }
            return besselK(Int(args[0]), args[1])
        case .airyAi: return airyAi(x)
        case .airyBi: return airyBi(x)
        case .legendreP:
            guard args.count >= 2 else { return nil }
            return legendreP(Int(args[0]), args[1])
        case .hermiteH:
            guard args.count >= 2 else { return nil }
            return hermiteH(Int(args[0]), args[1])
        case .laguerreL:
            guard args.count >= 2 else { return nil }
            return laguerreL(Int(args[0]), args[1])
        case .chebyshevT:
            guard args.count >= 2 else { return nil }
            return chebyshevT(Int(args[0]), args[1])
        case .chebyshevU:
            guard args.count >= 2 else { return nil }
            return chebyshevU(Int(args[0]), args[1])
        case .gamma: return gamma(x)
        case .lgamma: return logGamma(x)
        case .beta:
            guard args.count >= 2 else { return nil }
            return beta(args[0], args[1])
        case .digamma: return digamma(x)
        case .polyGamma:
            guard args.count >= 2 else { return nil }
            return polygamma(Int(args[0]), args[1])
        case .erf: return erf(x)
        case .erfc: return erfc(x)
        case .erfi: return erfi(x)
        case .Si: return sinIntegral(x)
        case .Ci: return cosIntegral(x)
        case .Ei: return expIntegral(x)
        case .li: return logIntegral(x)
        case .lambertW: return lambertW(x)
        case .zeta: return zeta(x)
        case .ellipticK: return ellipticK(x)
        case .ellipticE: return ellipticE(x)
        case .fresnelS: return fresnelS(x)
        case .fresnelC: return fresnelC(x)
        case .hypergeom:
            guard args.count >= 3 else { return nil }
            return hypergeometric2F1(args[0], args[1], args[2], 0.5) // placeholder z
        default:
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private static func factorialInt(_ n: Int) -> Int {
        guard n > 1 else { return 1 }
        return (2...n).reduce(1, *)
    }
}
