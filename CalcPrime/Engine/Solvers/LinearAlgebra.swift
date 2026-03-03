// LinearAlgebra.swift
// CalcPrime — Engine/Solvers
// Complete linear algebra engine: determinant, inverse, eigenvalues, eigenvectors,
// SVD, QR, LU, Cholesky, rank, null space, row echelon, RREF, trace,
// cross product, dot product, norms, Gram-Schmidt.
// All step-by-step explanations in Spanish.

import Foundation

// MARK: - Matrix Type Alias

/// A matrix is represented as [[Double]] (rows × cols).
typealias Matrix = [[Double]]
typealias Vec = [Double]

// MARK: - LinearAlgebra

struct LinearAlgebra {
    
    // MARK: - Basic Operations
    
    /// Matrix addition.
    static func add(_ A: Matrix, _ B: Matrix) -> Matrix {
        let rows = A.count
        guard rows > 0, rows == B.count, A[0].count == B[0].count else { return A }
        return (0..<rows).map { i in zip(A[i], B[i]).map(+) }
    }
    
    /// Matrix subtraction.
    static func subtract(_ A: Matrix, _ B: Matrix) -> Matrix {
        let rows = A.count
        guard rows > 0, rows == B.count, A[0].count == B[0].count else { return A }
        return (0..<rows).map { i in zip(A[i], B[i]).map(-) }
    }
    
    /// Scalar multiplication.
    static func scale(_ A: Matrix, by s: Double) -> Matrix {
        A.map { row in row.map { $0 * s } }
    }
    
    /// Matrix multiplication.
    static func multiply(_ A: Matrix, _ B: Matrix) -> Matrix {
        let m = A.count
        guard m > 0 else { return [] }
        let n = A[0].count
        let p = B[0].count
        guard n == B.count else { return [] }
        
        var C = Array(repeating: Array(repeating: 0.0, count: p), count: m)
        for i in 0..<m {
            for j in 0..<p {
                var sum = 0.0
                for k in 0..<n { sum += A[i][k] * B[k][j] }
                C[i][j] = sum
            }
        }
        return C
    }
    
    /// Matrix-vector multiplication.
    static func multiplyVec(_ A: Matrix, _ v: Vec) -> Vec {
        A.map { row in zip(row, v).map(*).reduce(0, +) }
    }
    
    /// Transpose.
    static func transpose(_ A: Matrix) -> Matrix {
        guard !A.isEmpty, !A[0].isEmpty else { return A }
        let m = A.count, n = A[0].count
        var T = Array(repeating: Array(repeating: 0.0, count: m), count: n)
        for i in 0..<m { for j in 0..<n { T[j][i] = A[i][j] } }
        return T
    }
    
    /// Identity matrix.
    static func identity(_ n: Int) -> Matrix {
        var I = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { I[i][i] = 1 }
        return I
    }
    
    /// Trace.
    static func trace(_ A: Matrix) -> Double {
        let n = Swift.min(A.count, A.isEmpty ? 0 : A[0].count)
        var sum = 0.0
        for i in 0..<n { sum += A[i][i] }
        return sum
    }
    
    // MARK: - Determinant
    
    /// Compute determinant using LU decomposition.
    static func determinant(_ A: Matrix) -> Double {
        let n = A.count
        guard n > 0, n == A[0].count else { return 0 }
        
        if n == 1 { return A[0][0] }
        if n == 2 { return A[0][0] * A[1][1] - A[0][1] * A[1][0] }
        if n == 3 {
            return A[0][0] * (A[1][1] * A[2][2] - A[1][2] * A[2][1])
                 - A[0][1] * (A[1][0] * A[2][2] - A[1][2] * A[2][0])
                 + A[0][2] * (A[1][0] * A[2][1] - A[1][1] * A[2][0])
        }
        
        // LU decomposition
        let (_, U, _, sign) = luDecomposition(A)
        var det = Double(sign)
        for i in 0..<n { det *= U[i][i] }
        return det
    }
    
    /// Determinant with steps.
    static func determinantWithSteps(_ A: Matrix) -> (Double, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = A.count
        
        steps.append(SolutionStep(
            title: "Calcular determinante",
            explanation: "Matriz \(n)×\(n)",
            math: matrixToLatex(A)
        ))
        
        let det = determinant(A)
        
        if n == 2 {
            steps.append(SolutionStep(
                title: "Fórmula para 2×2",
                math: "\\det = a_{11}a_{22} - a_{12}a_{21} = \(fmt(A[0][0]))·\(fmt(A[1][1])) - \(fmt(A[0][1]))·\(fmt(A[1][0]))"
            ))
        } else if n == 3 {
            steps.append(SolutionStep(
                title: "Regla de Sarrus / Cofactores",
                explanation: "Expandir por la primera fila"
            ))
        } else {
            steps.append(SolutionStep(
                title: "Descomposición LU",
                explanation: "det(A) = det(L)·det(U) = producto de la diagonal de U (con signo por permutaciones)"
            ))
        }
        
        steps.append(SolutionStep(
            title: "Resultado",
            math: "\\det(A) = \(fmt(det))"
        ))
        
        return (det, steps)
    }
    
    // MARK: - LU Decomposition (with partial pivoting)
    
    /// Returns (L, U, P, sign) where PA = LU.
    static func luDecomposition(_ A: Matrix) -> (Matrix, Matrix, Matrix, Int) {
        let n = A.count
        var U = A
        var L = identity(n)
        var P = identity(n)
        var sign = 1
        
        for k in 0..<n {
            // Partial pivoting
            var maxVal = Swift.abs(U[k][k])
            var maxRow = k
            for i in (k + 1)..<n {
                if Swift.abs(U[i][k]) > maxVal {
                    maxVal = Swift.abs(U[i][k])
                    maxRow = i
                }
            }
            
            if maxRow != k {
                U.swapAt(k, maxRow)
                P.swapAt(k, maxRow)
                sign = -sign
                // Swap L below diagonal
                for j in 0..<k {
                    let tmp = L[k][j]
                    L[k][j] = L[maxRow][j]
                    L[maxRow][j] = tmp
                }
            }
            
            guard Swift.abs(U[k][k]) > 1e-15 else { continue }
            
            for i in (k + 1)..<n {
                let factor = U[i][k] / U[k][k]
                L[i][k] = factor
                for j in k..<n {
                    U[i][j] -= factor * U[k][j]
                }
            }
        }
        
        return (L, U, P, sign)
    }
    
    /// LU decomposition with steps.
    static func luWithSteps(_ A: Matrix) -> (Matrix, Matrix, Matrix, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Descomposición LU",
            explanation: "PA = LU con pivoteo parcial",
            math: matrixToLatex(A)
        ))
        
        let (L, U, P, _) = luDecomposition(A)
        
        steps.append(SolutionStep(
            title: "Matriz L (triangular inferior)",
            math: matrixToLatex(L)
        ))
        steps.append(SolutionStep(
            title: "Matriz U (triangular superior)",
            math: matrixToLatex(U)
        ))
        steps.append(SolutionStep(
            title: "Matriz de permutación P",
            math: matrixToLatex(P)
        ))
        
        return (L, U, P, steps)
    }
    
    // MARK: - Inverse
    
    /// Compute inverse using Gauss-Jordan elimination.
    static func inverse(_ A: Matrix) -> Matrix? {
        let n = A.count
        guard n > 0, n == A[0].count else { return nil }
        
        // Augmented matrix [A | I]
        var aug = Array(repeating: Array(repeating: 0.0, count: 2 * n), count: n)
        for i in 0..<n {
            for j in 0..<n { aug[i][j] = A[i][j] }
            aug[i][n + i] = 1
        }
        
        // Forward elimination
        for k in 0..<n {
            // Pivot
            var maxRow = k
            for i in (k + 1)..<n {
                if Swift.abs(aug[i][k]) > Swift.abs(aug[maxRow][k]) { maxRow = i }
            }
            aug.swapAt(k, maxRow)
            
            guard Swift.abs(aug[k][k]) > 1e-15 else { return nil } // Singular
            
            let pivot = aug[k][k]
            for j in 0..<(2 * n) { aug[k][j] /= pivot }
            
            for i in 0..<n where i != k {
                let factor = aug[i][k]
                for j in 0..<(2 * n) { aug[i][j] -= factor * aug[k][j] }
            }
        }
        
        // Extract inverse
        return (0..<n).map { i in Array(aug[i][n..<(2 * n)]) }
    }
    
    /// Inverse with steps.
    static func inverseWithSteps(_ A: Matrix) -> (Matrix?, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = A.count
        
        steps.append(SolutionStep(
            title: "Calcular A⁻¹",
            explanation: "Eliminación de Gauss-Jordan sobre [A | I]",
            math: matrixToLatex(A)
        ))
        
        let det = determinant(A)
        steps.append(SolutionStep(
            title: "Verificar invertibilidad",
            explanation: "det(A) = \(fmt(det))",
            math: Swift.abs(det) < 1e-15 ? "\\text{Singular — no tiene inversa}" : "\\det(A) \\neq 0 \\Rightarrow \\text{invertible}"
        ))
        
        guard let inv = inverse(A) else {
            steps.append(SolutionStep(title: "Resultado", explanation: "La matriz es singular, no existe inversa"))
            return (nil, steps)
        }
        
        steps.append(SolutionStep(
            title: "A⁻¹ =",
            math: matrixToLatex(inv)
        ))
        
        // Verify
        let product = multiply(A, inv)
        steps.append(SolutionStep(
            title: "Verificación: A·A⁻¹ = I",
            math: matrixToLatex(product.map { $0.map { Swift.abs($0) < 1e-10 ? 0 : $0 } })
        ))
        
        return (inv, steps)
    }
    
    // MARK: - Row Echelon Form / RREF
    
    /// Reduce to row echelon form.
    static func rowEchelonForm(_ A: Matrix) -> Matrix {
        var M = A
        let m = M.count
        guard m > 0 else { return M }
        let n = M[0].count
        
        var pivotRow = 0
        for col in 0..<n {
            guard pivotRow < m else { break }
            
            // Find pivot
            var maxRow = pivotRow
            for i in (pivotRow + 1)..<m {
                if Swift.abs(M[i][col]) > Swift.abs(M[maxRow][col]) { maxRow = i }
            }
            
            guard Swift.abs(M[maxRow][col]) > 1e-15 else { continue }
            
            M.swapAt(pivotRow, maxRow)
            
            let pivot = M[pivotRow][col]
            for j in col..<n { M[pivotRow][j] /= pivot }
            
            for i in (pivotRow + 1)..<m {
                let factor = M[i][col]
                for j in col..<n { M[i][j] -= factor * M[pivotRow][j] }
            }
            
            pivotRow += 1
        }
        
        return M
    }
    
    /// Reduced row echelon form (RREF).
    static func rref(_ A: Matrix) -> Matrix {
        var M = A
        let m = M.count
        guard m > 0 else { return M }
        let n = M[0].count
        
        var pivotRow = 0
        for col in 0..<n {
            guard pivotRow < m else { break }
            
            var maxRow = pivotRow
            for i in (pivotRow + 1)..<m {
                if Swift.abs(M[i][col]) > Swift.abs(M[maxRow][col]) { maxRow = i }
            }
            
            guard Swift.abs(M[maxRow][col]) > 1e-15 else { continue }
            
            M.swapAt(pivotRow, maxRow)
            
            let pivot = M[pivotRow][col]
            for j in 0..<n { M[pivotRow][j] /= pivot }
            
            // Eliminate all rows (not just below)
            for i in 0..<m where i != pivotRow {
                let factor = M[i][col]
                for j in 0..<n { M[i][j] -= factor * M[pivotRow][j] }
            }
            
            pivotRow += 1
        }
        
        return M
    }
    
    /// RREF with steps.
    static func rrefWithSteps(_ A: Matrix) -> (Matrix, [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Forma Escalonada Reducida (RREF)",
            math: matrixToLatex(A)
        ))
        
        let result = rref(A)
        
        steps.append(SolutionStep(
            title: "RREF",
            math: matrixToLatex(result.map { $0.map { Swift.abs($0) < 1e-10 ? 0 : $0 } })
        ))
        
        return (result, steps)
    }
    
    // MARK: - Rank
    
    /// Compute rank via RREF.
    static func rank(_ A: Matrix) -> Int {
        let R = rref(A)
        return R.filter { row in row.contains(where: { Swift.abs($0) > 1e-10 }) }.count
    }
    
    // MARK: - Null Space
    
    /// Find a basis for the null space of A.
    static func nullSpace(_ A: Matrix) -> [Vec] {
        let m = A.count
        guard m > 0 else { return [] }
        let n = A[0].count
        let R = rref(A)
        
        // Find pivot columns
        var pivotCols: [Int] = []
        var pivotRow = 0
        for col in 0..<n {
            guard pivotRow < m else { break }
            if Swift.abs(R[pivotRow][col]) > 1e-10 {
                pivotCols.append(col)
                pivotRow += 1
            }
        }
        
        let freeCols = (0..<n).filter { !pivotCols.contains($0) }
        
        var basis: [Vec] = []
        for fc in freeCols {
            var vec = Array(repeating: 0.0, count: n)
            vec[fc] = 1
            for (pIdx, pc) in pivotCols.enumerated() {
                if pIdx < R.count {
                    vec[pc] = -R[pIdx][fc]
                }
            }
            basis.append(vec)
        }
        
        return basis
    }
    
    // MARK: - Eigenvalues (QR Algorithm)
    
    /// Compute eigenvalues using the QR algorithm (iterative).
    static func eigenvalues(_ A: Matrix, maxIterations: Int = 200, tolerance: Double = 1e-10) -> [Double] {
        let n = A.count
        guard n > 0, n == A[0].count else { return [] }
        
        if n == 1 { return [A[0][0]] }
        
        if n == 2 {
            // Direct formula
            let tr = A[0][0] + A[1][1]
            let det = A[0][0] * A[1][1] - A[0][1] * A[1][0]
            let disc = tr * tr - 4 * det
            if disc >= 0 {
                return [(tr + Foundation.sqrt(disc)) / 2, (tr - Foundation.sqrt(disc)) / 2]
            } else {
                // Complex eigenvalues — return real parts
                return [tr / 2, tr / 2]
            }
        }
        
        // QR iteration with shifts
        var M = A
        for _ in 0..<maxIterations {
            // Wilkinson shift
            let shift = M[n - 1][n - 1]
            let shifted = subtract(M, scale(identity(n), by: shift))
            let (Q, R) = qrDecomposition(shifted)
            M = add(multiply(R, Q), scale(identity(n), by: shift))
            
            // Check convergence
            var offDiag = 0.0
            for i in 0..<n {
                for j in 0..<n where i != j {
                    offDiag += M[i][j] * M[i][j]
                }
            }
            if offDiag < tolerance { break }
        }
        
        return (0..<n).map { M[$0][$0] }
    }
    
    /// Eigenvalues with steps.
    static func eigenvaluesWithSteps(_ A: Matrix) -> ([Double], [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = A.count
        
        steps.append(SolutionStep(
            title: "Calcular valores propios",
            explanation: "Resolver det(A - λI) = 0",
            math: matrixToLatex(A)
        ))
        
        if n == 2 {
            let tr = A[0][0] + A[1][1]
            let det = A[0][0] * A[1][1] - A[0][1] * A[1][0]
            steps.append(SolutionStep(
                title: "Polinomio característico",
                math: "\\lambda^2 - \(fmt(tr))\\lambda + \(fmt(det)) = 0"
            ))
            steps.append(SolutionStep(
                title: "Traza y determinante",
                explanation: "tr(A) = \(fmt(tr)), det(A) = \(fmt(det))"
            ))
        } else {
            steps.append(SolutionStep(
                title: "Método: Algoritmo QR",
                explanation: "Iteración QR con desplazamiento de Wilkinson para matrices \(n)×\(n)"
            ))
        }
        
        let evals = eigenvalues(A)
        
        let evStr = evals.map { fmt($0) }.joined(separator: ", \\; ")
        steps.append(SolutionStep(
            title: "Valores propios",
            math: "\\lambda = \\left\\{ \(evStr) \\right\\}"
        ))
        
        return (evals, steps)
    }
    
    // MARK: - Eigenvectors
    
    /// Compute eigenvectors for each eigenvalue.
    static func eigenvectors(_ A: Matrix) -> [(Double, Vec)] {
        let evals = eigenvalues(A)
        let n = A.count
        var result: [(Double, Vec)] = []
        
        for lambda in evals {
            // Solve (A - λI)v = 0
            let shifted = subtract(A, scale(identity(n), by: lambda))
            let ns = nullSpace(shifted)
            if let v = ns.first {
                // Normalize
                let norm = Foundation.sqrt(v.map { $0 * $0 }.reduce(0, +))
                let normalized = norm > 1e-15 ? v.map { $0 / norm } : v
                result.append((lambda, normalized))
            } else {
                // Fallback: approximate
                result.append((lambda, Array(repeating: 0, count: n)))
            }
        }
        
        return result
    }
    
    /// Eigenvectors with steps.
    static func eigenvectorsWithSteps(_ A: Matrix) -> ([(Double, Vec)], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Calcular vectores propios",
            explanation: "Para cada λ, resolver (A - λI)v = 0",
            math: matrixToLatex(A)
        ))
        
        let pairs = eigenvectors(A)
        
        for (lambda, vec) in pairs {
            let vecStr = vec.map { fmt($0) }.joined(separator: " \\\\ ")
            steps.append(SolutionStep(
                title: "λ = \(fmt(lambda))",
                math: "\\mathbf{v} = \\begin{pmatrix} \(vecStr) \\end{pmatrix}"
            ))
        }
        
        return (pairs, steps)
    }
    
    // MARK: - QR Decomposition (Gram-Schmidt)
    
    /// Classical Gram-Schmidt QR decomposition.
    static func qrDecomposition(_ A: Matrix) -> (Matrix, Matrix) {
        let m = A.count
        guard m > 0 else { return ([], []) }
        let n = A[0].count
        let At = transpose(A) // columns of A = rows of At
        let k = Swift.min(m, n)
        
        var Q: [Vec] = Array(repeating: Array(repeating: 0, count: m), count: k)
        var R = Array(repeating: Array(repeating: 0.0, count: n), count: k)
        
        for j in 0..<k {
            var v = (0..<m).map { A[$0][j] }
            
            for i in 0..<j {
                let dot = zip(Q[i], v).map(*).reduce(0, +)
                R[i][j] = dot
                for idx in 0..<m { v[idx] -= dot * Q[i][idx] }
            }
            
            let norm = Foundation.sqrt(v.map { $0 * $0 }.reduce(0, +))
            R[j][j] = norm
            
            if norm > 1e-15 {
                Q[j] = v.map { $0 / norm }
            } else {
                Q[j] = v
            }
        }
        
        // Q is stored as rows = orthonormal vectors → need to make it m×k
        let Qmat = transpose(Q) // now m×k
        return (Qmat, R)
    }
    
    // MARK: - Cholesky Decomposition
    
    /// Cholesky decomposition A = LLᵀ for symmetric positive definite A.
    static func cholesky(_ A: Matrix) -> Matrix? {
        let n = A.count
        var L = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0...i {
                var sum = 0.0
                for k in 0..<j { sum += L[i][k] * L[j][k] }
                
                if i == j {
                    let val = A[i][i] - sum
                    guard val > 0 else { return nil } // Not positive definite
                    L[i][j] = Foundation.sqrt(val)
                } else {
                    guard Swift.abs(L[j][j]) > 1e-15 else { return nil }
                    L[i][j] = (A[i][j] - sum) / L[j][j]
                }
            }
        }
        
        return L
    }
    
    // MARK: - SVD (Simplified for small matrices)
    
    /// Compute singular values (eigenvalues of AᵀA).
    static func singularValues(_ A: Matrix) -> [Double] {
        let AtA = multiply(transpose(A), A)
        let evals = eigenvalues(AtA)
        return evals.map { Foundation.sqrt(Swift.max(0, $0)) }.sorted(by: >)
    }
    
    /// Simplified SVD returning singular values and steps.
    static func svdWithSteps(_ A: Matrix) -> ([Double], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Descomposición en Valores Singulares (SVD)",
            explanation: "A = UΣVᵀ. Los valores singulares son √(eigenvalores de AᵀA)",
            math: matrixToLatex(A)
        ))
        
        let AtA = multiply(transpose(A), A)
        steps.append(SolutionStep(
            title: "Paso 1: Calcular AᵀA",
            math: matrixToLatex(AtA)
        ))
        
        let sigmas = singularValues(A)
        let sigmaStr = sigmas.map { fmt($0) }.joined(separator: ", \\; ")
        steps.append(SolutionStep(
            title: "Valores singulares",
            math: "\\sigma = \\left\\{ \(sigmaStr) \\right\\}"
        ))
        
        return (sigmas, steps)
    }
    
    // MARK: - Solve Linear System Ax = b
    
    /// Solve Ax = b using LU decomposition.
    static func solve(_ A: Matrix, b: Vec) -> Vec? {
        let n = A.count
        guard n > 0, n == A[0].count, n == b.count else { return nil }
        
        let (L, U, P, _) = luDecomposition(A)
        let Pb = multiplyVec(P, b)
        
        // Forward substitution: Ly = Pb
        var y = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for j in 0..<i { sum += L[i][j] * y[j] }
            y[i] = Pb[i] - sum
        }
        
        // Back substitution: Ux = y
        var x = Array(repeating: 0.0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            guard Swift.abs(U[i][i]) > 1e-15 else { return nil }
            var sum = 0.0
            for j in (i + 1)..<n { sum += U[i][j] * x[j] }
            x[i] = (y[i] - sum) / U[i][i]
        }
        
        return x
    }
    
    /// Solve with steps.
    static func solveWithSteps(_ A: Matrix, b: Vec) -> (Vec?, [SolutionStep]) {
        var steps: [SolutionStep] = []
        let n = A.count
        
        steps.append(SolutionStep(
            title: "Resolver sistema Ax = b",
            explanation: "Sistema de \(n) ecuaciones con \(n) incógnitas"
        ))
        
        steps.append(SolutionStep(
            title: "Matriz aumentada [A|b]",
            math: augmentedLatex(A, b)
        ))
        
        guard let x = solve(A, b: b) else {
            steps.append(SolutionStep(
                title: "Sin solución",
                explanation: "El sistema es singular o incompatible"
            ))
            return (nil, steps)
        }
        
        steps.append(SolutionStep(
            title: "Descomposición LU",
            explanation: "PA = LU → Ly = Pb, Ux = y"
        ))
        
        let solStr = x.enumerated().map { "x_{\($0.offset + 1)} = \(fmt($0.element))" }.joined(separator: ", \\; ")
        steps.append(SolutionStep(
            title: "Solución",
            math: solStr
        ))
        
        return (x, steps)
    }
    
    // MARK: - Dot Product
    
    static func dot(_ u: Vec, _ v: Vec) -> Double {
        zip(u, v).map(*).reduce(0, +)
    }
    
    // MARK: - Cross Product (3D)
    
    static func cross(_ u: Vec, _ v: Vec) -> Vec {
        guard u.count == 3, v.count == 3 else { return [] }
        return [
            u[1] * v[2] - u[2] * v[1],
            u[2] * v[0] - u[0] * v[2],
            u[0] * v[1] - u[1] * v[0]
        ]
    }
    
    // MARK: - Norms
    
    /// Vector L2 norm.
    static func norm(_ v: Vec) -> Double {
        Foundation.sqrt(v.map { $0 * $0 }.reduce(0, +))
    }
    
    /// Vector L1 norm.
    static func norm1(_ v: Vec) -> Double {
        v.map(Swift.abs).reduce(0, +)
    }
    
    /// Vector L∞ norm.
    static func normInf(_ v: Vec) -> Double {
        v.map(Swift.abs).max() ?? 0
    }
    
    /// Matrix Frobenius norm.
    static func frobeniusNorm(_ A: Matrix) -> Double {
        Foundation.sqrt(A.flatMap { $0 }.map { $0 * $0 }.reduce(0, +))
    }
    
    // MARK: - Gram-Schmidt Orthogonalization
    
    /// Classical Gram-Schmidt on a set of column vectors.
    static func gramSchmidt(_ vectors: [Vec]) -> [Vec] {
        var ortho: [Vec] = []
        
        for v in vectors {
            var u = v
            for q in ortho {
                let proj = dot(v, q) / dot(q, q)
                for i in 0..<u.count { u[i] -= proj * q[i] }
            }
            let n = norm(u)
            if n > 1e-15 {
                ortho.append(u.map { $0 / n })
            }
        }
        
        return ortho
    }
    
    /// Gram-Schmidt with steps.
    static func gramSchmidtWithSteps(_ vectors: [Vec]) -> ([Vec], [SolutionStep]) {
        var steps: [SolutionStep] = []
        
        steps.append(SolutionStep(
            title: "Ortogonalización de Gram-Schmidt",
            explanation: "Convertir \(vectors.count) vectores en una base ortonormal"
        ))
        
        let result = gramSchmidt(vectors)
        
        for (i, v) in result.enumerated() {
            let vStr = v.map { fmt($0) }.joined(separator: " \\\\ ")
            steps.append(SolutionStep(
                title: "q_{\(i + 1)}",
                math: "\\mathbf{q}_{\(i + 1)} = \\begin{pmatrix} \(vStr) \\end{pmatrix}"
            ))
        }
        
        return (result, steps)
    }
    
    // MARK: - Condition Number
    
    /// Condition number (ratio of largest to smallest singular value).
    static func conditionNumber(_ A: Matrix) -> Double {
        let svs = singularValues(A)
        guard let maxS = svs.first, let minS = svs.last, minS > 1e-15 else { return .infinity }
        return maxS / minS
    }
    
    // MARK: - Matrix Power
    
    /// Compute A^n (integer power).
    static func power(_ A: Matrix, _ n: Int) -> Matrix {
        let size = A.count
        guard size > 0 else { return A }
        
        if n == 0 { return identity(size) }
        if n == 1 { return A }
        if n < 0 {
            guard let inv = inverse(A) else { return A }
            return power(inv, -n)
        }
        
        // Binary exponentiation
        if n % 2 == 0 {
            let half = power(A, n / 2)
            return multiply(half, half)
        } else {
            return multiply(A, power(A, n - 1))
        }
    }
    
    // MARK: - Matrix Exponential (Padé approximation)
    
    /// Matrix exponential e^A using scaling and squaring + Padé[6/6].
    static func matrixExponential(_ A: Matrix) -> Matrix {
        let n = A.count
        guard n > 0 else { return A }
        
        // Scale
        let normA = frobeniusNorm(A)
        let s = Swift.max(0, Int(Foundation.ceil(Foundation.log2(normA / 5.4))))
        let scaledA = scale(A, by: Foundation.pow(2.0, Double(-s)))
        
        // Padé[6/6] approximation
        let b: [Double] = [1, 1.0/2, 1.0/9, 1.0/72, 1.0/1008, 1.0/30240, 1.0/1209600]
        
        let I = identity(n)
        var N = scale(I, by: b[0])
        var D = scale(I, by: b[0])
        var Ak = I
        
        for k in 1...6 {
            Ak = multiply(Ak, scaledA)
            N = add(N, scale(Ak, by: b[k]))
            D = add(D, scale(Ak, by: (k % 2 == 0 ? 1 : -1) * b[k]))
        }
        
        guard var result = inverse(D).map({ multiply($0, N) }) else { return I }
        
        // Squaring
        for _ in 0..<s {
            result = multiply(result, result)
        }
        
        return result
    }
    
    // MARK: - Symbolic Matrix Operations on ExprNode
    
    /// Convert ExprNode.matrix to Double matrix for numerical computation.
    static func toNumericMatrix(_ node: ExprNode) -> Matrix? {
        guard case .matrix(let rows) = node else { return nil }
        var result: Matrix = []
        for row in rows {
            var numRow: [Double] = []
            for elem in row {
                guard let val = elem.numericValue else { return nil }
                numRow.append(val)
            }
            result.append(numRow)
        }
        return result
    }
    
    /// Convert Double matrix to ExprNode.matrix.
    static func toExprMatrix(_ M: Matrix) -> ExprNode {
        .matrix(M.map { $0.map { cleanNum($0) } })
    }
    
    /// Convert vector to ExprNode.vector.
    static func toExprVector(_ v: Vec) -> ExprNode {
        .vector(v.map { cleanNum($0) })
    }
    
    // MARK: - LaTeX Helpers
    
    static func matrixToLatex(_ M: Matrix) -> String {
        let rows = M.map { row in row.map { fmt($0) }.joined(separator: " & ") }
        return "\\begin{pmatrix} \(rows.joined(separator: " \\\\ ")) \\end{pmatrix}"
    }
    
    private static func augmentedLatex(_ A: Matrix, _ b: Vec) -> String {
        let rows = A.enumerated().map { i, row in
            let aStr = row.map { fmt($0) }.joined(separator: " & ")
            return "\(aStr) & \(fmt(b[i]))"
        }
        return "\\left(\\begin{array}{ccc|c} \(rows.joined(separator: " \\\\ ")) \\end{array}\\right)"
    }
    
    private static func fmt(_ v: Double) -> String {
        if Swift.abs(v - Double(Int(v))) < 1e-10 && Swift.abs(v) < 1e12 { return "\(Int(v))" }
        return String(format: "%.4g", v)
    }
    
    private static func cleanNum(_ v: Double) -> ExprNode {
        if Swift.abs(v - Double(Int(v))) < 1e-10 && Swift.abs(v) < 1e12 {
            return .number(Double(Int(v)))
        }
        return .number(v)
    }
}
