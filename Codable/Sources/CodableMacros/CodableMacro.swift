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
        let storedProperties: [(name: String, typeName: String)] = declaration.memberBlock.members
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

                return (name: name, typeName: typeName)
            }

        if storedProperties.isEmpty {
            throw CodableMacroError(message: "Expected at least one stored property")
        }

        return [
            DeclSyntax("""
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                \(raw: 
                    storedProperties
                        .map { "\($0.name) = try container.decode(\($0.typeName).self, forKey: .\($0.name))" }
                        .joined()
                )
            }
            """),

            DeclSyntax("""
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                \(raw: 
                    storedProperties
                        .map { "try container.encode(\($0.name), forKey: .\($0.name))" }
                        .joined()
                )
            }
            """),

            DeclSyntax("""
            enum CodingKeys: String, CodingKey {
                case \(raw: storedProperties.map { $0.name }.joined(separator: ", ") )
            }
            """)
        ]
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
