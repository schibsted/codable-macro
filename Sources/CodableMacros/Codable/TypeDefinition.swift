import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

indirect enum TypeDefinition: CustomStringConvertible {
    case optional(wrappedType: TypeDefinition)
    case array(elementType: String)
    case set(elementType: String)
    case dictionary(keyType: String, valueType: String)
    case identifier(name: String)

    init?(type: TypeSyntax) {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            let typeName = identifier.name.text

            if let genericArgumentClause = identifier.genericArgumentClause {
                let genericParameterTypes = genericArgumentClause.arguments.map { $0.argument }
                let genericParameterNames = genericArgumentClause.arguments.map { $0.trimmedDescription }
                
                switch typeName {
                case "Array":
                    guard let elementType = genericParameterNames.first else {
                        return nil
                    }
                    
                    self = .array(elementType: elementType)

                case "Set":
                    guard let elementType = genericParameterNames.first else {
                        return nil
                    }

                    self = .set(elementType: elementType)

                case "Dictionary":
                    guard genericParameterNames.count == 2 else {
                        return nil
                    }

                    self = .dictionary(keyType: genericParameterNames[0], valueType: genericParameterNames[1])
                
                case "Optional":
                    guard let wrappedType = genericParameterTypes.first.flatMap({ TypeDefinition(type: $0) }) else {
                        return nil
                    }

                    self = .optional(wrappedType: wrappedType)

                default:
                    self = .identifier(name: "\(typeName)\(genericArgumentClause.trimmedDescription)")
                }
            } else {
                self = .identifier(name: typeName)
            }
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
        case let .set(elementType):
            "Set<\(elementType)>"
        case .dictionary(let keyType, let elementType):
            "[\(keyType): \(elementType)]"
        case let .optional(wrappedType):
            wrappedType.name
        }
    }

    var isCollection: Bool {
        switch self {
        case .array, .set, .dictionary:
            true
        case let .optional(wrappedType):
            wrappedType.isCollection
        default:
            false
        }
    }

    var arrayElementType: String? {
        switch self {
        case let .array(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.arrayElementType
        default:
            nil
        }
    }

    var setElementType: String? {
        switch self {
        case let .set(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.setElementType
        default:
            nil
        }
    }

    var dictionaryElementType: (key: String, value: String)? {
        switch self {
        case let .dictionary(keyType, elementType):
            (keyType, elementType)
        case let .optional(wrappedType):
            wrappedType.dictionaryElementType
        default:
            nil
        }
    }

    var isOptional: Bool {
        switch self {
        case .optional:
            true
        default:
            false
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
        case let .set(elementType):
            "Set<\(elementType.description)>"
        case .dictionary(let keyType, let elementType):
            "[\(keyType.description): \(elementType.description)]"
        }
    }
}
