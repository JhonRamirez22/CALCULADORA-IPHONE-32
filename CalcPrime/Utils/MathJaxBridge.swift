// MathJaxBridge.swift
// CalcPrime — Utils
// WKWebView wrapper for rendering LaTeX via MathJax 3.
// Provides a reusable SwiftUI view component.

import SwiftUI
import WebKit

// MARK: - MathJaxView (UIViewRepresentable)

struct MathJaxView: UIViewRepresentable {
    let latex: String
    let textColor: String     // hex color
    let fontSize: CGFloat
    let backgroundColor: String
    
    init(latex: String,
         textColor: String = "#FFB300",
         fontSize: CGFloat = 22,
         backgroundColor: String = "#0A0A0F") {
        self.latex = latex
        self.textColor = textColor
        self.fontSize = fontSize
        self.backgroundColor = backgroundColor
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(latex: latex)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Adjust height after rendering
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    webView.frame.size.height = height
                }
            }
        }
    }
    
    // MARK: - HTML Generation
    
    private func generateHTML(latex: String) -> String {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "'", with: "\\'")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script>
                MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                        displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                        processEscapes: true
                    },
                    svg: {
                        fontCache: 'global',
                        scale: 1.2
                    },
                    startup: {
                        pageReady: () => {
                            return MathJax.startup.defaultPageReady().then(() => {
                                // Signal rendering complete
                                window.webkit.messageHandlers.mathJaxReady?.postMessage('ready');
                            });
                        }
                    }
                };
            </script>
            <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" async></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background-color: \(backgroundColor);
                    color: \(textColor);
                    font-family: -apple-system, system-ui;
                    font-size: \(fontSize)px;
                    display: flex;
                    align-items: center;
                    justify-content: flex-end;
                    min-height: 40px;
                    padding: 8px 12px;
                    overflow: hidden;
                    direction: ltr;
                }
                #math-container {
                    text-align: right;
                    width: 100%;
                    overflow-x: auto;
                    overflow-y: hidden;
                }
                mjx-container {
                    color: \(textColor) !important;
                }
                mjx-container svg {
                    color: \(textColor) !important;
                    fill: \(textColor) !important;
                }
                /* Scrollbar hide */
                ::-webkit-scrollbar { display: none; }
            </style>
        </head>
        <body>
            <div id="math-container">$$\(escaped)$$</div>
        </body>
        </html>
        """
    }
}

// MARK: - MathJaxInlineView (smaller, for step display)

struct MathJaxInlineView: UIViewRepresentable {
    let latex: String
    let textColor: String
    let fontSize: CGFloat
    
    init(latex: String, textColor: String = "#FFFFFF", fontSize: CGFloat = 16) {
        self.latex = latex
        self.textColor = textColor
        self.fontSize = fontSize
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
                MathJax = { tex: { inlineMath: [['$','$']] }, svg: { fontCache: 'global' } };
            </script>
            <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" async></script>
            <style>
                body { background: transparent; color: \(textColor); font-size: \(fontSize)px;
                       font-family: -apple-system; margin: 4px; padding: 0; }
                mjx-container { color: \(textColor) !important; }
            </style>
        </head>
        <body>$\(escaped)$</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - LaTeX Renderer Helper

struct LaTeXRenderer {
    
    /// Convert a CASResult to display-ready LaTeX.
    static func formatResult(_ result: CASResult) -> String {
        result.latex.isEmpty ? result.output : result.latex
    }
    
    /// Wrap expression in display math mode.
    static func displayMath(_ latex: String) -> String {
        "\\displaystyle \(latex)"
    }
    
    /// Format step-by-step solution as LaTeX.
    static func formatSteps(_ steps: [SolutionStepData]) -> String {
        var lines: [String] = []
        for (i, step) in steps.enumerated() {
            lines.append("\\textbf{Paso \(i + 1):} \\text{ \(step.title)}")
            if !step.math.isEmpty {
                lines.append(step.math)
            }
            if !step.explanation.isEmpty {
                lines.append("\\text{\(step.explanation)}")
            }
            for sub in step.substeps {
                lines.append("\\quad \\bullet \\; \(sub.math)")
            }
        }
        return lines.joined(separator: " \\\\\n")
    }
    
    /// Color a LaTeX segment.
    static func colored(_ latex: String, hex: String) -> String {
        "\\color{\(hex)}{\(latex)}"
    }
}
