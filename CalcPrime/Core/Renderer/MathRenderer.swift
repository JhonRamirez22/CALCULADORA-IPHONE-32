// MathRenderer.swift
// CalcPrime — MathDF iOS
// WKWebView-based MathJax 3 renderer for LaTeX expressions.
// Supports light/dark themes, inline/display mode, configurable font size.

import SwiftUI
import WebKit

// MARK: - MathJaxView (UIViewRepresentable)

struct MathJaxView: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat = 20
    var displayMode: Bool = true
    var textColor: String = "#1A1A1A"
    var backgroundColor: String = "#FFFFFF"
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        loadMathJax(webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentLatex != latex ||
           context.coordinator.currentColor != textColor {
            context.coordinator.currentLatex = latex
            context.coordinator.currentColor = textColor
            updateContent(webView: webView)
        }
    }
    
    private func loadMathJax(webView: WKWebView) {
        let mode = displayMode ? "\\displaystyle " : ""
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <script>
        window.MathJax = {
            tex: {
                inlineMath: [['$','$']],
                displayMath: [['$$','$$']],
                packages: {'[+]': ['ams','noerrors','noundefined']}
            },
            svg: { fontCache: 'global' },
            options: { enableMenu: false },
            startup: {
                ready: function() {
                    MathJax.startup.defaultReady();
                    MathJax.startup.promise.then(function() {
                        adjustSize();
                    });
                }
            }
        };
        function adjustSize() {
            var el = document.getElementById('math');
            if (el) {
                var h = el.scrollHeight + 8;
                window.webkit.messageHandlers.sizeChange && 
                window.webkit.messageHandlers.sizeChange.postMessage(h);
            }
        }
        function updateMath(tex, color) {
            var el = document.getElementById('math');
            el.innerHTML = '$$' + tex + '$$';
            el.style.color = color;
            if (window.MathJax && MathJax.typesetPromise) {
                MathJax.typesetPromise([el]).then(adjustSize);
            }
        }
        </script>
        <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" async></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                background: \(backgroundColor);
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
                overflow: hidden;
                padding: 4px 8px;
            }
            #math {
                font-size: \(fontSize)px;
                color: \(textColor);
                text-align: center;
                max-width: 100%;
                overflow-x: auto;
                -webkit-overflow-scrolling: touch;
            }
            mjx-container { max-width: 100% !important; }
        </style>
        </head><body>
        <div id="math">$$\(mode)\(escaped)$$</div>
        </body></html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func updateContent(webView: WKWebView) {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        let mode = displayMode ? "\\\\displaystyle " : ""
        let js = "updateMath('\(mode)\(escaped)', '\(textColor)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var currentLatex: String = ""
        var currentColor: String = ""
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    }
}

// MARK: - Math Text (SwiftUI convenience)

/// Inline math text that renders LaTeX with MathJax.
struct MathText: View {
    let latex: String
    var fontSize: CGFloat = 18
    var height: CGFloat = 50
    var textColor: String = "#1A1A1A"
    var bgColor: String = "transparent"
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        MathJaxView(
            latex: latex,
            fontSize: fontSize,
            displayMode: true,
            textColor: colorScheme == .dark ? "#E0E0E0" : textColor,
            backgroundColor: colorScheme == .dark ? "#1C1C1E" : bgColor
        )
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Math Preview (real-time input preview)

struct MathPreview: View {
    let latex: String
    let validation: ValidationState
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Preview:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            if latex.isEmpty {
                Text("Escribe una expresión...")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            } else {
                MathJaxView(
                    latex: latex,
                    fontSize: 16,
                    displayMode: false,
                    textColor: validation == .valid
                        ? (colorScheme == .dark ? "#66BB6A" : "#2E7D32")
                        : (colorScheme == .dark ? "#EF5350" : "#C62828"),
                    backgroundColor: "transparent"
                )
                .frame(height: 32)
            }
            
            Spacer()
            
            // Validation indicator
            switch validation {
            case .empty:
                EmptyView()
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MathDFColors.validGreen)
                    .font(.system(size: 16))
            case .invalid(let msg):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(MathDFColors.errorRed)
                    .font(.system(size: 16))
                    .help(msg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
