import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct CodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableMacro.self, 
        DecodableMacro.self,
        EncodableMacro.self,
        CodableKeyMacro.self,
        CodableIgnoredMacro.self,
        MemberwiseInitializableMacro.self
    ]
}

