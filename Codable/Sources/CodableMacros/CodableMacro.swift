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

        guard let codingKeys = CodingKeysDeclaration(paths: storedProperties.map { $0.codingPath }) else {
            throw CodableMacroError(message: "Failed to generate coding keys")
        }

        return [
            DeclSyntax("""
            init(from decoder: Decoder) throws {
                \(raw: codingKeys.containerDeclarations(ofKind: .decode))

                \(raw: storedProperties.map { $0.decodeStatement }.joined(separator: "\n    "))
            }
            """),

            DeclSyntax("""
            func encode(to encoder: Encoder) throws {
                \(raw: codingKeys.containerDeclarations(ofKind: .encode))

                \(raw: storedProperties.map { $0.encodeStatement }.joined(separator: "\n    "))
            }
            """),

            DeclSyntax(stringLiteral: codingKeys.declarationCode),
        ]
    }
}

struct PropertyDefinition: CustomDebugStringConvertible {
    let name: String
    let typeName: String
    let codingPath: CodingPath
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
        
        let pathFragments = propertyAttributes
            .first(where: { $0.isCodableKey })
            .flatMap { $0.codableKey }
            .map { $0.split(separator: ".", omittingEmptySubsequences: true).map { String($0) } }
            ?? [name]

        self.name = name
        self.typeName = type.name
        self.codingPath = CodingPath(components: pathFragments, propertyName: name)
        self.isOptional = type.isOptional
        self.defaultValue = patternBinding.initializer?.value.trimmedDescription
    }

    var decodeStatement: String {
        let decodeFunction = isOptional || defaultValue != nil ? "decodeIfPresent" : "decode"

        return """
        \(name) = try \(codingPath.codingContainerName).\(decodeFunction)(\(typeName).self, forKey: .\(codingPath.containerkey))\(defaultValue.map { " ?? \($0)" } ?? "")
        """
    }

    var encodeStatement: String {
        let encodeFunction = isOptional ? "encodeIfPresent" : "encode"

        return """
        try \(codingPath.codingContainerName).\(encodeFunction)(\(name), forKey: .\(codingPath.containerkey))
        """
    }

    var debugDescription: String {
        "PropertyDefinition(let \(name): \(typeName)\(isOptional ? "?" : ""))\(defaultValue.map { " = \($0)" } ?? "")"
    }
}

struct CodingPath {
    var components: [String]
    var propertyName: String

    var firstComponent: String { components[0] }

    var isTerminal: Bool { components.count == 1 }

    var codingContainerName: String {
        if isTerminal {
            return "container"
        }

        let prefix = components
            .dropLast()
            .map { $0.uppercasingFirstLetter }
            .joined()
            .lowercasingFirstLetter

        return "\(prefix)Container"
    }

    var containerkey: String { propertyName }

    func droppingFirstComponent() -> CodingPath {
        CodingPath(components: Array(components.dropFirst()), propertyName: propertyName)
    }
}

struct CodingKeysDeclaration {
    let name: String?
    let cases: [String]
    let nestedKeys: [CodingKeysDeclaration]
    let nestingLevel: Int

    var sortingKey: String { name ?? "" }

    init?(name: String? = nil, nestingLevel: Int = 0, paths: [CodingPath]) {
        guard !paths.isEmpty else { return nil }

        self.name = name

        var cases: [String] = []
        var nestedKeys: [CodingKeysDeclaration] = []

        Dictionary(grouping: paths, by: { $0.firstComponent })
            .forEach { (caseName: String, codingPaths: [CodingPath]) in
                codingPaths
                    .filter { $0.isTerminal }
                    .forEach {
                        cases.append($0.firstComponent == $0.propertyName ? $0.propertyName : "\($0.propertyName) = \"\($0.firstComponent)\"")
                    }

                let nestedPaths = codingPaths
                    .filter { !$0.isTerminal }
                    .map { $0.droppingFirstComponent() }

                if let keys = CodingKeysDeclaration(name: caseName, nestingLevel: nestingLevel + 1, paths: nestedPaths) {
                    nestedKeys.append(keys)
                    cases.append(caseName)
                }
            }

        self.cases = cases.sorted()
        self.nestedKeys = nestedKeys.sorted(by: { $0.sortingKey < $1.sortingKey })
        self.nestingLevel = nestingLevel
    }

    var indentation: String { String(repeating: "    ", count: nestingLevel) }
    
    var typeName: String { "\(name?.uppercasingFirstLetter ?? "")CodingKeys" }

    var declarationCode: String {
        """
        \(indentation)enum \(typeName): String, CodingKey {
        \(indentation)    case \(cases.joined(separator: ", "))\(nestedKeys.isEmpty ? "" : "\n\n" + nestedKeys.map { $0.declarationCode }.joined(separator: "\n\n"))
        \(indentation)}
        """
    }

    func containerDeclarations(
        ofKind containerKind: ContainerKind,
        parentContainerVariableName: String? = nil,
        parentContainerTypeName: String? = nil
    ) -> String {
        let containerVariableName: String
        let containerTypeName: String
        let decodingContainerDeclaration: String

        if let parentContainerVariableName, let parentContainerTypeName, let name {
            containerVariableName = "\(parentContainerVariableName.dropLast("container".count))\(name.uppercasingFirstLetter)Container".lowercasingFirstLetter
            containerTypeName = "\(parentContainerTypeName).\(typeName)"
            decodingContainerDeclaration = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(parentContainerVariableName).nestedContainer(keyedBy: \(containerTypeName).self, forKey: .\(name))"
        } else {
            containerVariableName = "container"
            containerTypeName = typeName
            decodingContainerDeclaration = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(containerKind.coderName).container(keyedBy: \(containerTypeName).self)"
        }

        let nestedDecodingContainerDeclarations = nestedKeys.map {
            $0.containerDeclarations(
                ofKind: containerKind,
                parentContainerVariableName: containerVariableName,
                parentContainerTypeName: containerTypeName
            )
        }

        return ([decodingContainerDeclaration] + nestedDecodingContainerDeclarations)
            .joined(separator: "\n")
    }
}

struct ContainerKind {
    static let decode = ContainerKind(declarationKeyword: "let", tryPrefix: "try ", coderName: "decoder")
    static let encode = ContainerKind(declarationKeyword: "var", tryPrefix: "", coderName: "encoder")

    let declarationKeyword: String
    let tryPrefix: String
    let coderName: String

    private init(declarationKeyword: String, tryPrefix: String, coderName: String) {
        self.declarationKeyword = declarationKeyword
        self.tryPrefix = tryPrefix
        self.coderName = coderName
    }
}

private extension AttributeSyntax {
    var isCodableKey: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.description == CodableKeyMacro.attributeName
    }

    var codableKey: String? {
        arguments?.as(LabeledExprListSyntax.self)?.first?.expression.description
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

private extension String {

    var uppercasingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }

    var lowercasingFirstLetter: String {
        prefix(1).lowercased() + dropFirst()
    }
}
