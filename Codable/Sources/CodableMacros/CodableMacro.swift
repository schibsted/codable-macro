import SwiftCompilerPlugin
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
        [
            try ExtensionDeclSyntax("extension \(type): Codable {}")
        ]
    }
}

extension CodableMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let storedProperties: [PropertyDefinition] = declaration.memberBlock.members
            .compactMap {
                guard 
                    let property = $0.decl.as(VariableDeclSyntax.self),
                    let patternBinding = property.bindings.first,
                    patternBinding.accessorBlock == nil,
                    let name = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                    let typeName = patternBinding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text
                else {
                    return nil
                }

                return PropertyDefinition(name: name, typeName: typeName)
            }

        if storedProperties.isEmpty {
            throw CodableMacroError(message: "Expected at least one stored property")
        }

        return [
            DeclSyntax("""
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                \(raw: storedProperties.map { $0.decodeStatement }.joined())
            }
            """),

            DeclSyntax("""
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                \(raw: storedProperties.map { $0.encodeStatement }.joined())
            }
            """),

            DeclSyntax("""
            enum CodingKeys: String, CodingKey {
                case \(raw: storedProperties.map { $0.codingKey }.joined(separator: ", ") )
            }
            """),

            DeclSyntax("""
            let foo = \"\"\"
                            \(declaration.memberBlock.members)
            \"\"\"
            """)

        ]
    }
}

struct PropertyDefinition {
    let name: String
    let typeName: String

    var codingKey: String { name }

    var decodeStatement: String {
        """
        \(name) = try container.decode(\(typeName).self, forKey: .\(name))
        """
    }

    var encodeStatement: String {
        """
        try container.encode(\(name), forKey: .\(name))
        """
    }
}

struct CodableMacroError: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

@main
struct CodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableMacro.self,
    ]
}
