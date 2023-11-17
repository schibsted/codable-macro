import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct CodableKeyMacro {}

extension CodableKeyMacro: PeerMacro {
    static let attributeName = "CodableKey"

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        [] // This macro doesn't generate any code
    }
    
}
