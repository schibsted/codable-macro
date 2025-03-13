// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

        let storedProperties = try declaration.memberBlock.members
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

        var memberwiseInitializableMacroDeclaration = [DeclSyntax]()
        if !declaration.attributes.containsMemberwiseInitializableMacro {
            var nodeWithoutArguments = node
            nodeWithoutArguments.arguments = nil

            memberwiseInitializableMacroDeclaration = try MemberwiseInitializableMacro.expansion(of: nodeWithoutArguments, providingMembersOf: declaration, in: context)
        }

        return memberwiseInitializableMacroDeclaration + [
            DeclSyntax(decoderWithCodingContainer: codingContainer, properties: storedProperties, isPublic: declaration.isPublic, needsValidation: node.needsValidation),
            DeclSyntax(encoderWithCodingContainer: codingContainer, properties: storedProperties, isPublic: declaration.isPublic),
            try codingContainer.codingKeysDeclaration,
            shouldIncludeFailableContainer ? .failableContainer() : nil
        ]
            .compactMap { $0 }
    }
}
