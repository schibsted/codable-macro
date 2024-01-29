import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

indirect enum TypeDefinition: CustomStringConvertible {
    case optional(wrappedType: TypeDefinition)
    case array(elementType: String)
    case dictionary(keyType: String, valueType: String)
    case identifier(name: String)

    init?(type: TypeSyntax) {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            let name = [identifier.name.text, identifier.genericArgumentClause?.trimmedDescription]
                .compactMap { $0 }
                .joined()
            self = .identifier(name: name)
        } else if let optional = type.as(OptionalTypeSyntax.self),
                  let wrappedDeclaration = TypeDefinition(type: optional.wrappedType) {
            self = .optional(wrappedType: wrappedDeclaration)
        } else if let array = type.as(ArrayTypeSyntax.self) {
            self = .array(elementType: array.element.trimmedDescription)
        } else if let dictionary = type.as(DictionaryTypeSyntax.self) {
            self = .dictionary(
                keyType: dictionary.key.trimmedDescription,
                valueType: dictionary.value.trimmedDescription
            )
        } else {
            return nil
        }
    }

    var name: String {
        switch self {
        case let .identifier(name):
            name
        case let .array(elementType):
            "[\(elementType)]"
        case .dictionary(let keyType, let elementType):
            "[\(keyType): \(elementType)]"
        case let .optional(wrappedType):
            wrappedType.name
        }
    }

    var isArray: Bool {
        arrayElementType != nil
    }

    var isDictionary: Bool {
        dictionaryElementType != nil
    }

    var arrayElementType: String? {
        switch self {
        case let .array(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.arrayElementType
        case .identifier, .dictionary:
            nil
        }
    }

    var dictionaryElementType: (key: String, value: String)? {
        switch self {
        case let .dictionary(keyType, elementType):
            (keyType, elementType)
        case let .optional(wrappedType):
            wrappedType.dictionaryElementType
        case .identifier, .array:
            nil
        }
    }

    var isOptional: Bool {
        switch self {
        case .identifier, .array, .dictionary:
            false
        case .optional:
            true
        }
    }

    var description: String {
        switch self {
        case let .identifier(name):
            name
        case let .optional(wrappedType):
            "\(wrappedType.description)?"
        case let .array(elementType):
            "[\(elementType.description)]"
        case .dictionary(let keyType, let elementType):
            "[\(keyType.description): \(elementType.description)]"
        }
    }
}

