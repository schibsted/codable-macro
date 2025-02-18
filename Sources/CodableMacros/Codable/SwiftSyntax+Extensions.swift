import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

extension VariableDeclSyntax {
    var isImmutable: Bool {
        bindingSpecifier.tokenKind == .keyword(.let)
    }

    var isStatic: Bool {
        modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
    }
}

extension AttributeListSyntax {
    var containsMultipleCodableMacros: Bool {
        let codableMacros: Set<String> = ["@Codable", "@Decodable", "@Encodable"]

        return self
            .filter { codableMacros.contains($0.trimmedDescription) }
            .count > 1
    }

    var containsMemberwiseInitializableMacro: Bool {
        self
            .contains { $0.trimmedDescription.hasPrefix("@MemberwiseInitializable") }
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
        let keywords: [TokenKind] = [.keyword(.public), .keyword(.open)]
        return modifiers.contains(where: { keywords.contains($0.name.tokenKind) })
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
