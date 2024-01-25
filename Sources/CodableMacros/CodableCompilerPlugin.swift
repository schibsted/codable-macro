import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct CodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableMacro.self, CodableKeyMacro.self, CodableIgnoredMacro.self, MemberwiseInitializableMacro.self
    ]
}

