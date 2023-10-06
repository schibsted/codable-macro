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
        let storedProperties: [PropertyDefinition] = try declaration.memberBlock.members
            .compactMap { try PropertyDefinition(declaration: $0.decl) }

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
        ]
    }
}

struct PropertyDefinition: CustomDebugStringConvertible {
    let name: String
    let typeName: String
    let customCodingKey: String?
    let isOptional: Bool
    let defaultValue: String?

    init?(declaration: DeclSyntax) throws {
        guard
            let property = declaration.as(VariableDeclSyntax.self),
            let patternBinding = property.bindings.first,
            patternBinding.accessorBlock == nil,
            let name = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let typeAnnotation = patternBinding.typeAnnotation
        else {
            return nil
        }

        let type: (name: String, isOptional: Bool)? =
            if let typeName = typeAnnotation.type.as(IdentifierTypeSyntax.self)?.name.text {
                (typeName, false)
            } else if let optionalType = typeAnnotation.type.as(OptionalTypeSyntax.self),
                    let typeName = optionalType.wrappedType.as(IdentifierTypeSyntax.self)?.name.text {
                (typeName, true)
            } else {
                nil
            }

        guard let type else { return nil }

        let propertyAttributes = property.attributes
            .compactMap { $0.as(AttributeSyntax.self) }
        
        let customKey = propertyAttributes
            .first(where: { $0.isCodableKey })
            .flatMap { $0.codableKey }

        self.name = name
        self.typeName = type.name
        self.customCodingKey = customKey
        self.isOptional = type.isOptional
        self.defaultValue = patternBinding.initializer?.value.trimmedDescription
    }

    var codingKey: String {
        if let customCodingKey {
            "\(name) = \(customCodingKey)"
        } else {
            name
        }
    }

    var decodeStatement: String {
        let decodeFunction = isOptional || defaultValue != nil ? "decodeIfPresent" : "decode"

        return """
        \(name) = try container.\(decodeFunction)(\(typeName).self, forKey: .\(name))\(defaultValue.map { " ?? \($0)" } ?? "")
        """
    }

    var encodeStatement: String {
        let encodeFunction = isOptional ? "encodeIfPresent" : "encode"

        return """
        try container.\(encodeFunction)(\(name), forKey: .\(name))
        """
    }

    var debugDescription: String {
        "PropertyDefinition(let \(name): \(typeName)\(isOptional ? "?" : ""))\(defaultValue.map { " = \($0)" } ?? "")"
    }
}

private extension AttributeSyntax {
    var isCodableKey: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.description == CodableKeyMacro.attributeName
    }

    var codableKey: String? {
        arguments?.as(LabeledExprListSyntax.self)?.first?.expression.description
    }
}
