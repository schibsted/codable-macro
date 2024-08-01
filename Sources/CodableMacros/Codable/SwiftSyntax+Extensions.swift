import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

extension VariableDeclSyntax {
    var isImmutable: Bool {
        bindingSpecifier.trimmedDescription == "let"
    }

    var isStatic: Bool {
        modifiers.contains(where: { $0.trimmedDescription == "static" })
    }
}

extension AttributeListSyntax {
    var containsMultipleCodableMacros: Bool {
        let codableMacros: Set<String> = ["@Codable", "@Decodable", "@Encodable"]

        return self
            .filter { codableMacros.contains($0.trimmedDescription) }
            .count > 1
    }
}

extension AttributeSyntax {
    var isCodableIgnored: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.trimmedDescription == CodableIgnoredMacro.attributeName
    }

    var isCustomDecoded: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.trimmedDescription == CustomDecodedMacro.attributeName
    }

    var isCodableKey: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.trimmedDescription == CodableKeyMacro.attributeName
    }

    var codableKey: String? {
        arguments?.as(LabeledExprListSyntax.self)?.first?.expression.description
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

extension SyntaxProtocol {

    func withLeadingTrivia(_ trivia: Trivia) -> Self {
        var syntax = self
        syntax.leadingTrivia = trivia
        return syntax
    }

    func withTrailingTrivia(_ trivia: Trivia) -> Self {
        var syntax = self
        syntax.trailingTrivia = trivia
        return syntax
    }
}

extension DeclGroupSyntax {
    var isPublic: Bool {
        modifiers
            .contains(where: { ["public", "open"].contains($0.trimmedDescription) })
    }
}

extension String {

    var uppercasingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }

    var lowercasingFirstLetter: String {
        prefix(1).lowercased() + dropFirst()
    }
}
