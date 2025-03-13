// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

final class TypeDefinition: CustomStringConvertible {
    enum Kind {
        case optional(wrappedType: TypeDefinition)
        case array(elementType: String)
        case set(elementType: String)
        case dictionary(keyType: String, valueType: String)
        case identifier(name: String)
    }

    let kind: Kind
    let baseTypeName: String?

    init?(type: TypeSyntax) {
        if type.is(MemberTypeSyntax.self) || type.is(IdentifierTypeSyntax.self) {
            let (typeName, genericArgumentClause): (String?, GenericArgumentClauseSyntax?) =
                if let identifier = type.as(IdentifierTypeSyntax.self) {
                    (identifier.name.text, identifier.genericArgumentClause)
                } else if let member = type.as(MemberTypeSyntax.self) {
                    (member.name.text, member.genericArgumentClause)
                } else {
                    (nil, nil)
                }

            guard let typeName else { return nil }

            if let genericArgumentClause {
                let genericParameterTypes = genericArgumentClause.arguments.map { $0.argument }
                let genericParameterNames = genericArgumentClause.arguments.map { $0.trimmedDescription }
                
                switch typeName {
                case "Array":
                    guard let elementType = genericParameterNames.first else {
                        return nil
                    }

                    kind = .array(elementType: elementType)

                case "Set":
                    guard let elementType = genericParameterNames.first else {
                        return nil
                    }

                    kind = .set(elementType: elementType)

                case "Dictionary":
                    guard genericParameterNames.count == 2 else {
                        return nil
                    }

                    kind = .dictionary(keyType: genericParameterNames[0], valueType: genericParameterNames[1])

                case "Optional":
                    guard let wrappedType = genericParameterTypes.first.flatMap({ TypeDefinition(type: $0) }) else {
                        return nil
                    }

                    kind = .optional(wrappedType: wrappedType)

                default:
                    kind = .identifier(name: "\(typeName)\(genericArgumentClause.trimmedDescription)")
                }
            } else {
                kind = .identifier(name: typeName)
            }

            baseTypeName = type.as(MemberTypeSyntax.self)?.baseType.trimmedDescription
        } else if let optional = type.as(OptionalTypeSyntax.self),
                  let wrappedDeclaration = TypeDefinition(type: optional.wrappedType) {
            kind = .optional(wrappedType: wrappedDeclaration)
            baseTypeName = nil
        } else if let array = type.as(ArrayTypeSyntax.self) {
            kind = .array(elementType: array.element.trimmedDescription)
            baseTypeName = nil
        } else if let dictionary = type.as(DictionaryTypeSyntax.self) {
            kind = .dictionary(
                keyType: dictionary.key.trimmedDescription,
                valueType: dictionary.value.trimmedDescription
            )
            baseTypeName = nil
        } else {
            return nil
        }
    }

    var decodableTypeName: String {
        let name = switch kind {
        case let .identifier(name):
            name
        case let .array(elementType):
            "Array<\(elementType)>"
        case let .set(elementType):
            "Set<\(elementType)>"
        case .dictionary(let keyType, let elementType):
            "Dictionary<\(keyType): \(elementType)>"
        case let .optional(wrappedType):
            wrappedType.decodableTypeName
        }

        return [baseTypeName, name]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    var isCollection: Bool {
        switch kind {
        case .array, .set, .dictionary:
            true
        case let .optional(wrappedType):
            wrappedType.isCollection
        default:
            false
        }
    }

    var arrayElementType: String? {
        switch kind {
        case let .array(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.arrayElementType
        default:
            nil
        }
    }

    var setElementType: String? {
        switch kind {
        case let .set(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.setElementType
        default:
            nil
        }
    }

    var dictionaryElementType: (key: String, value: String)? {
        switch kind {
        case let .dictionary(keyType, elementType):
            (keyType, elementType)
        case let .optional(wrappedType):
            wrappedType.dictionaryElementType
        default:
            nil
        }
    }

    var isOptional: Bool {
        switch kind {
        case .optional:
            true
        default:
            false
        }
    }

    var description: String {
        let description = switch kind {
        case let .identifier(name):
            name
        case let .optional(wrappedType):
            "\(wrappedType.description)?"
        case let .array(elementType):
            "Array<\(elementType.description)>"
        case let .set(elementType):
            "Set<\(elementType.description)>"
        case .dictionary(let keyType, let elementType):
            "Dictionary<\(keyType.description), \(elementType.description)>"
        }

        return [baseTypeName, description]
            .compactMap { $0 }
            .joined(separator: ".")
    }
}
