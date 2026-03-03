// ExportHelper.swift
// CalcPrime — Utils
// Export calculations as images, PDF, or text.

import SwiftUI
import UIKit

struct ExportHelper {
    
    // MARK: - Export Formats
    
    enum ExportFormat {
        case plainText
        case latex
        case image
        case pdf
    }
    
    // MARK: - Export Calculation
    
    /// Export a calculation result to the specified format.
    static func export(_ result: CalculationResult, format: ExportFormat) -> Any? {
        switch format {
        case .plainText:
            return exportAsText(result)
        case .latex:
            return exportAsLaTeX(result)
        case .image:
            return nil // Would need async rendering
        case .pdf:
            return exportAsPDF(result)
        }
    }
    
    /// Share via system share sheet.
    static func share(_ items: [Any], from viewController: UIViewController? = nil) {
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            
            // iPad requires sourceView
            if let popover = ac.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
            }
            
            vc.present(ac, animated: true)
        }
    }
    
    // MARK: - Text Export
    
    private static func exportAsText(_ result: CalculationResult) -> String {
        var text = """
        ═══════════════════════════════
        CalcPrime — Resultado
        ═══════════════════════════════
        
        Entrada: \(result.input)
        Resultado: \(result.output)
        Categoría: \(result.category.rawValue)
        Tiempo: \(String(format: "%.4f", result.timeElapsed))s
        """
        
        if !result.steps.isEmpty {
            text += "\n\n───── Pasos ─────\n"
            for (i, step) in result.steps.enumerated() {
                text += "\nPaso \(i + 1): \(step.title)"
                if !step.explanation.isEmpty {
                    text += "\n  \(step.explanation)"
                }
                if !step.math.isEmpty {
                    text += "\n  \(step.math)"
                }
                for sub in step.substeps {
                    text += "\n    • \(sub.math)"
                }
            }
        }
        
        text += "\n\n═══════════════════════════════\n"
        text += "Generado por CalcPrime\n"
        text += "Fecha: \(DateFormatter.localizedString(from: result.timestamp, dateStyle: .medium, timeStyle: .short))"
        
        return text
    }
    
    // MARK: - LaTeX Export
    
    private static func exportAsLaTeX(_ result: CalculationResult) -> String {
        var tex = """
        \\documentclass[12pt]{article}
        \\usepackage{amsmath,amssymb}
        \\usepackage[spanish]{babel}
        \\begin{document}
        
        \\section*{CalcPrime — Resultado}
        
        \\textbf{Entrada:}
        \\[ \(result.latex.isEmpty ? result.input : result.input) \\]
        
        \\textbf{Resultado:}
        \\[ \(result.latex.isEmpty ? result.output : result.latex) \\]
        
        """
        
        if !result.steps.isEmpty {
            tex += "\\subsection*{Solución paso a paso}\n\\begin{enumerate}\n"
            for step in result.steps {
                tex += "  \\item \\textbf{\(step.title)}"
                if !step.explanation.isEmpty {
                    tex += " — \(step.explanation)"
                }
                if !step.math.isEmpty {
                    tex += "\n  \\[ \(step.math) \\]\n"
                }
            }
            tex += "\\end{enumerate}\n"
        }
        
        tex += """
        
        \\vfill
        \\noindent\\textit{Generado por CalcPrime}
        \\end{document}
        """
        
        return tex
    }
    
    // MARK: - PDF Export
    
    private static func exportAsPDF(_ result: CalculationResult) -> Data? {
        let text = exportAsText(result)
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            let textRect = pageRect.insetBy(dx: 50, dy: 50)
            let nsString = text as NSString
            nsString.draw(in: textRect, withAttributes: attrs)
        }
        
        return data
    }
    
    // MARK: - Copy to Clipboard
    
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    static func copyLatexToClipboard(_ result: CalculationResult) {
        let latex = result.latex.isEmpty ? result.output : result.latex
        UIPasteboard.general.string = latex
    }
}
