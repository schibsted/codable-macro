// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
        CustomDecodedMacro.self,
        MemberwiseInitializableMacro.self
    ]
}

