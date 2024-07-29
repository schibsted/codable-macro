import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct CodableMacro {}

extension CodableMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        if declaration is ProtocolDeclSyntax || declaration is ActorDeclSyntax {
            return []
        }

        if declaration.attributes.containsMultipleCodableMacros {
            return []
        }

        return [try ExtensionDeclSyntax("extension \(type): Codable {}")]
    }
}

extension CodableMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard !(declaration is ActorDeclSyntax) else {
            throw CodableMacroError.notApplicableToActor
        }

        guard !(declaration is ProtocolDeclSyntax) else {
            throw CodableMacroError.notApplicableToProtocol
        }
        
        guard !declaration.attributes.containsMultipleCodableMacros else {
            throw CodableMacroError.moreThanOneCodableMacroApplied
        }

        if declaration is EnumDeclSyntax {
            return []
        }

        let storedProperties: [PropertyDefinition] = try declaration.memberBlock.members
            .compactMap { try PropertyDefinition(declaration: $0.decl) }
            .filter { !$0.isExcludedFromCodable }

        if storedProperties.isEmpty {
            return []
        }

        let shouldIncludeFailableContainer = storedProperties
            .contains(where: { $0.type.isCollection })

        guard let codingContainer = CodingContainer(paths: storedProperties.map { $0.codingPath }) else {
            fatalError("Failed to generate coding keys")
        }

        return [
            DeclSyntax(decoderWithCodingContainer: codingContainer, properties: storedProperties, isPublic: declaration.isPublic, needsValidation: node.needsValidation),
            DeclSyntax(encoderWithCodingContainer: codingContainer, properties: storedProperties, isPublic: declaration.isPublic),
            try codingContainer.codingKeysDeclaration,
            shouldIncludeFailableContainer ? .failableContainer() : nil
        ]
        .compactMap { $0 }
    }
}
