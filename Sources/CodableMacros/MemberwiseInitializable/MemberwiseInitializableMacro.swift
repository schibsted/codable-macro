import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct MemberwiseInitializableMacro {}

extension MemberwiseInitializableMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard !(declaration is ProtocolDeclSyntax) else {
            throw MemberwiseInitializableMacroError.notApplicableToProtocol
        }

        guard !(declaration is EnumDeclSyntax) else {
            throw MemberwiseInitializableMacroError.notApplicableToEnum
        }

        let storedProperties: [PropertyDefinition] = try declaration.memberBlock.members
            .compactMap { try PropertyDefinition(declaration: $0.decl) }
            .filter { !$0.isImmutableWithDefaultValue }

        if storedProperties.isEmpty {
            throw MemberwiseInitializableMacroError.noStoredProperties
        }

        let accessLevel: String?
        if let arguments = node.arguments {
            guard 
                case .argumentList(let argumentList) = arguments,
                let firstArgument = argumentList.first,
                argumentList.count == 1
            else {
                fatalError("Expected 1 argument")
            }

            guard let level = firstArgument.expression.as(MemberAccessExprSyntax.self)?.declName.trimmedDescription else {
                fatalError("Expected access level")
            }

            accessLevel = level
        } else if let typeAccessLevel = declaration.modifiers.first?.trimmedDescription {
            accessLevel = typeAccessLevel == "open" ? "public" : typeAccessLevel
        } else {
            accessLevel = nil
        }

        return [
        """
        \(raw: accessLevel.map { "\($0) " } ?? "")init(
            \(raw: storedProperties.map { "\($0.name): \($0.type.description)\($0.defaultValue.map { " = \($0)" } ?? "")" }
                .joined(separator: ",\n"))
        ) {
            \(raw: storedProperties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n"))
        }
        """
        ]
    }
}
