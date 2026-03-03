# MathDF iOS — Calculadora CAS paso a paso

<p align="center">
  <strong>Inspirada en mathdf.com</strong><br>
  Resuelve integrales, derivadas, ecuaciones, ODEs, límites y más con pasos detallados.
</p>

---

## 🎯 Características

| Módulo | Descripción |
|--------|-------------|
| ∫ **Integrales** | Indefinidas y definidas, 11+ métodos de integración |
| 📐 **Derivadas** | Orden n, regla de la cadena, derivación implícita |
| 🔄 **Ec. Diferenciales** | Separables, lineales, Bernoulli, 2° orden |
| ✖️ **Ecuaciones** | Polinomios hasta grado 4, trascendentes, sistemas |
| 📊 **Límites** | L'Hôpital, límites notables, Taylor |
| 🔢 **Matrices** | Gauss-Jordan, determinantes, autovalores |
| 🌀 **Complejos** | Polar, Argand, De Moivre, raíces n-ésimas |
| 🧮 **Numérico** | Evaluación con precisión configurable |

## 🏗 Arquitectura

```
CalcPrime/
├── App/                  # Entry point + Navigation
│   ├── MathDFApp.swift
│   └── AppRouter.swift
├── Models/               # Data models + AppState
│   ├── Models.swift
│   └── AppState.swift
├── Core/
│   ├── Parser/           # SmartCorrector (2sinx → 2*sin(x))
│   └── Renderer/         # MathJax, Steps, GraphView
├── Components/           # SmartInputField, MathKeyboard, ModuleCard
├── Views/                # Home, History, Settings
├── Modules/              # 8 módulos independientes
│   ├── Integral/
│   ├── ODE/
│   ├── Derivative/
│   ├── Equation/
│   ├── Limit/
│   ├── Matrix/
│   ├── Complex/
│   └── Numeric/
└── Engine/               # Motor CAS completo (23 archivos)
    ├── Core/             # Token, Parser, ExprNode, Simplifier, CASEngine
    ├── Solvers/          # 11 solvers especializados
    └── Knowledge/        # Tablas de integrales, Laplace, ODEs, trig
```

## 🔧 Motor CAS

- **Parser** recursivo descendente con AST completo
- **Simplificador** con 50+ reglas algebraicas
- **ExprNode**: enum indirecto con 30+ casos (.number, .function, .integral, .limit, etc.)
- **LaTeX nativo** generado desde el AST
- **Sin dependencias externas** — 100% Swift puro

## 📱 Stack Técnico

- **Swift 5.9+** / SwiftUI
- **iOS 17+** (NavigationStack, Observable)
- **MathJax 3** via WKWebView para renderizado LaTeX
- **CoreGraphics** para gráficas interactivas (zoom, pan, slider C)
- **Bundle ID**: `com.personal.mathdfios`

## 🚀 Instalación

1. Clona el repositorio
2. Abre `CalcPrime.xcodeproj` en Xcode 15+
3. Selecciona tu iPhone como destino
4. Build & Run (Cmd+R)

## 👤 Autor

**Jhon Ramirez** — [@JhonRamirez22](https://github.com/JhonRamirez22)
