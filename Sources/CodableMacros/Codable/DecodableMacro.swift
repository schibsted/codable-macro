import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct DecodableMacro {}

extension DecodableMacro: ExtensionMacro {

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

        return [try ExtensionDeclSyntax("extension \(type): Decodable {}")]
    }
}

extension DecodableMacro: MemberMacro {

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
            .contains(where: { $0.type.isArray || $0.type.isDictionary })

        guard let codingKeys = CodingKeysDeclaration(paths: storedProperties.map { $0.codingPath }) else {
            fatalError("Failed to generate coding keys")
        }

        return [
            DeclSyntax(decoderWithCodingKeys: codingKeys, properties: storedProperties, isPublic: declaration.isPublic, needsValidation: node.needsValidation),
            try codingKeys.declaration,
            shouldIncludeFailableContainer ? .failableContainer() : nil
        ]
        .compactMap { $0 }
    }
}

extension DeclSyntax {

    static func failableContainer() -> DeclSyntax {
        .init(stringLiteral:
            "private struct FailableContainer<T>: Decodable where T: Decodable { " +
            "var wrappedValue: T?\n\n" +
            "init(from decoder: Decoder) throws {" +
            "wrappedValue = try? decoder.singleValueContainer().decode(T.self) " +
            "}" +
            "}"
        )
    }

    init(decoderWithCodingKeys codingKeys: CodingKeysDeclaration, properties: [PropertyDefinition], isPublic: Bool, needsValidation: Bool) {
        self.init(stringLiteral:
            "\(isPublic ? "public " : "")init(from decoder: Decoder) throws { " +
            "\(CodeBlockItemListSyntax(codingKeys.containerDeclarations(ofKind: .decode)).withLeadingTrivia(.newline).withTrailingTrivia([]))" +
            "\(CodeBlockItemListSyntax(properties.map { $0.decodeStatement }).withLeadingTrivia(.newlines(2)).withTrailingTrivia(.newline))" +
            "\(needsValidation ? "\(CodeBlockItemSyntax.validationBlock.withLeadingTrivia(.newline).withTrailingTrivia(.newline))" : "")" +
            "}"
        )
    }
}

extension AttributeSyntax {
    var needsValidation: Bool {
        guard 
            case .argumentList(let argumentList) = arguments,
            let needsValidationArgument = argumentList.first(where: { $0.label?.trimmedDescription == "needsValidation" }) 
        else {
            return false
        }

        let value = needsValidationArgument.expression.trimmedDescription

        guard ["true", "false"].contains(value) else {
            fatalError("Expected 'needsValidation' to be either 'true' or 'false'")
        }

        return value == "true"
    }
}

private extension CodeBlockItemSyntax {
    static var validationBlock: Self {
        .init(stringLiteral:
            "if !self.isValid {" +
            "throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: \"Validation failed\"))" +
            "}"
        )
    }
}
