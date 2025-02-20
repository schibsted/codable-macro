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

        let storedProperties = try declaration.memberBlock.members
            .compactMap { try PropertyDefinition(declaration: $0.decl) }
            .filter { !$0.isExcludedFromCodable }

        if storedProperties.isEmpty {
            return []
        }

        let shouldIncludeFailableContainer = storedProperties
            .contains(where: { $0.type.isCollection })

        guard let rootCodingContainer = CodingContainer(paths: storedProperties.map { $0.codingPath }) else {
            fatalError("Failed to generate coding keys")
        }

        var memberwiseInitializableMacroDeclaration = [DeclSyntax]()
        if !declaration.attributes.containsMemberwiseInitializableMacro {
            var nodeWithoutArguments = node
            nodeWithoutArguments.arguments = nil
            
            memberwiseInitializableMacroDeclaration = try MemberwiseInitializableMacro.expansion(of: nodeWithoutArguments, providingMembersOf: declaration, in: context)
        }
        
        return memberwiseInitializableMacroDeclaration + [
            DeclSyntax(decoderWithCodingContainer: rootCodingContainer, properties: storedProperties, isPublic: declaration.isPublic, needsValidation: node.needsValidation),
            try rootCodingContainer.codingKeysDeclaration,
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

    init(decoderWithCodingContainer codingContainer: CodingContainer, properties: [PropertyDefinition], isPublic: Bool, needsValidation: Bool) {
        let rootCodingContainerDeclaration = if properties.contains(where: { !$0.needsCustomDecoding }) {
            "\(codingContainer.containerDeclaration(ofKind: .decode).withLeadingTrivia(.newline).withTrailingTrivia(.newline))"
        } else {
            ""
        }

        let propertyDecodeStatements = properties
            .map { $0.decodeStatement(rootCodingContainer: codingContainer) }
        
        let propertyDecodeBlock = CodeBlockItemListSyntax(propertyDecodeStatements)
            .withLeadingTrivia(.newline)
            .withTrailingTrivia(.newline)

        let validationBlock = needsValidation
            ? "\(CodeBlockItemSyntax.validationBlock.withLeadingTrivia(.newline).withTrailingTrivia(.newline))"
            : ""

        self.init(stringLiteral:
            "\(isPublic ? "public " : "")init(from decoder: Decoder) throws { " +
            "\(rootCodingContainerDeclaration)" +
            "\(propertyDecodeBlock)" +
            "\(validationBlock)" +
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
