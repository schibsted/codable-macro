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
            throw CodableMacroError(message: "Unable to apply to a protocol")
        }

        guard !(declaration is EnumDeclSyntax) else {
            throw CodableMacroError(message: "Unable to apply to an enum")
        }

        let storedProperties: [PropertyDefinition] = try declaration.memberBlock.members
            .compactMap { try PropertyDefinition(declaration: $0.decl) }

        if storedProperties.isEmpty {
            throw CodableMacroError(message: "Expected at least one stored property")
        }

        let accessLevel: String?
        if let arguments = node.arguments {
            guard 
                case .argumentList(let argumentList) = arguments,
                let firstArgument = argumentList.first,
                argumentList.count == 1
            else {
                throw CodableMacroError(message: "Expected 1 argument")
            }

            guard let level = firstArgument.expression.as(MemberAccessExprSyntax.self)?.declName.trimmedDescription else {
                throw CodableMacroError(message: "Expected access level")
            }

            accessLevel = level
        } else if let typeAccessLevel = declaration.modifiers.first?.trimmedDescription {
            accessLevel = typeAccessLevel
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
