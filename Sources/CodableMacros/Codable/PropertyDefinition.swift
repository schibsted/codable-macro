import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

struct PropertyDefinition: CustomDebugStringConvertible {
    let name: String
    let type: TypeDefinition
    let codingPath: CodingPath
    let defaultValue: String?
    let isImmutable: Bool
    let isExplicitlyIgnored: Bool

    init?(declaration: DeclSyntax) throws {
        guard
            let property = declaration.as(VariableDeclSyntax.self),
            let patternBinding = property.bindings.first,
            patternBinding.accessorBlock == nil,
            let name = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = patternBinding.typeAnnotation.flatMap({ TypeDefinition(type: $0.type) })
        else {
            return nil
        }

        let propertyAttributes = property.attributes
            .compactMap { $0.as(AttributeSyntax.self) }

        let pathFragments = propertyAttributes
            .first(where: { $0.isCodableKey })
            .flatMap { $0.codableKey }
            .map { $0.split(separator: ".", omittingEmptySubsequences: true).map { String($0) } }
        ?? [name]

        self.name = name
        self.type = type
        self.codingPath = CodingPath(components: pathFragments, propertyName: name)
        self.defaultValue = patternBinding.initializer?.value.trimmedDescription
        self.isImmutable = property.isImmutable
        self.isExplicitlyIgnored = propertyAttributes.contains(where: { $0.isCodableIgnored })
    }

    var isIgnored: Bool {
        isExplicitlyIgnored || // marked with @CodableIgnored
        (isImmutable && defaultValue != nil) // Assigning an immutable property with a default value is a compiler error
    }

    var decodeStatement: CodeBlockItemSyntax {
        let decodeBlock =
            if let arrayElementType = type.arrayElementType {
                CodeBlockItemSyntax(stringLiteral: "\(name) = try \(codingPath.codingContainerName)" +
                                    ".decode([FailableContainer<\(arrayElementType)>].self, forKey: .\(codingPath.containerkey))" +
                                    ".compactMap { $0.wrappedValue }")
            } else if let dictionaryElementType = type.dictionaryElementType {
                CodeBlockItemSyntax(stringLiteral: "\(name) = try \(codingPath.codingContainerName)" +
                                    ".decode([\(dictionaryElementType.key): FailableContainer<\(dictionaryElementType.value)>].self, forKey: .\(codingPath.containerkey))" +
                                    ".compactMapValues { $0.wrappedValue }")
            } else {
                CodeBlockItemSyntax(stringLiteral: "\(name) = try \(codingPath.codingContainerName)" +
                                    ".decode(\(type.name).self, forKey: .\(codingPath.containerkey))")
            }

        var errorHandlingBlock: CodeBlockItemSyntax? {
            let statement: String? = if let defaultValue {
                "\(name) = \(defaultValue)"
            } else if type.isOptional {
                "\(name) = nil"
            } else {
                nil
            }

            return statement
                .map { CodeBlockItemSyntax(stringLiteral: $0) }
        }

        return if let errorHandlingBlock {
            CodeBlockItemSyntax(stringLiteral: "do { \(decodeBlock) } catch { \(errorHandlingBlock) }")
                .withLeadingTrivia(.newline)
                .withTrailingTrivia(.newline)
        } else {
            decodeBlock
                .withTrailingTrivia(.newline)
        }
    }

    var encodeStatement: CodeBlockItemSyntax {
        let encodeFunction = type.isOptional ? "encodeIfPresent" : "encode"

        var encodeStatement = CodeBlockItemSyntax(stringLiteral: "try \(codingPath.codingContainerName)" +
                                                  ".\(encodeFunction)(\(name), forKey: .\(codingPath.containerkey))")
        encodeStatement.trailingTrivia = .newline

        return encodeStatement
    }

    var debugDescription: String {
        "PropertyDefinition(let \(name): \(type.name)\(type.isOptional ? "?" : ""))\(defaultValue.map { " = \($0)" } ?? "")"
    }
}
