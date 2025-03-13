// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct EncodableMacro {}

extension EncodableMacro: ExtensionMacro {

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

        return [try ExtensionDeclSyntax("extension \(type): Encodable {}")]
    }
}

extension EncodableMacro: MemberMacro {

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

        guard let rootCodingContainer = CodingContainer(paths: storedProperties.map { $0.codingPath }) else {
            fatalError("Failed to generate coding keys")
        }

        return [
            DeclSyntax(encoderWithCodingContainer: rootCodingContainer, properties: storedProperties, isPublic: declaration.isPublic),
            try rootCodingContainer.codingKeysDeclaration
        ]
    }
}

extension DeclSyntax {
    init(encoderWithCodingContainer codingContainer: CodingContainer, properties: [PropertyDefinition], isPublic: Bool) {
        let containerDeclarations = codingContainer
            .allCodingContainers()
            .map { $0.containerDeclaration(ofKind: .encode) }

        self.init(stringLiteral:
            "\(isPublic ? "public " : "")func encode(to encoder: Encoder) throws {" +
            "\(CodeBlockItemListSyntax(containerDeclarations).withTrailingTrivia(.newlines(2)))" +
            "\(CodeBlockItemListSyntax(properties.map { $0.encodeStatement }).trimmed)" +
            "}"
        )
    }
}
