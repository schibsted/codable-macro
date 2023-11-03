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
        [try ExtensionDeclSyntax("extension \(type): Codable {}")]
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
        
        let hasArrayProperties = storedProperties
            .contains(where: { $0.type.isArray })
        
        if storedProperties.isEmpty {
            throw CodableMacroError(message: "Expected at least one stored property")
        }

        guard let codingKeys = CodingKeysDeclaration(paths: storedProperties.map { $0.codingPath }) else {
            throw CodableMacroError(message: "Failed to generate coding keys")
        }

        return [
            DeclSyntax(decoderWithCodingKeys: codingKeys, properties: storedProperties),
            DeclSyntax(encoderWithCodingKeys: codingKeys, properties: storedProperties),
            try codingKeys.declaration,
            hasArrayProperties ? .failableContainerForArray() : nil
        ]
        .compactMap { $0 }
    }
}

struct PropertyDefinition: CustomDebugStringConvertible {
    let name: String
    let type: TypeDefinition
    let codingPath: CodingPath
    let defaultValue: String?

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
    }

    var decodeStatement: CodeBlockItemSyntax {
        let decodeBlock = if let elementType = type.arrayElementType {
            CodeBlockItemSyntax(stringLiteral: "\(name) = try \(codingPath.codingContainerName)" +
                                ".decode([FailableContainer<\(elementType)>].self, forKey: .\(codingPath.containerkey))" +
                                ".compactMap { $0.wrappedValue }")
        } else {
            CodeBlockItemSyntax(stringLiteral: "\(name) = try \(codingPath.codingContainerName)" +
                                ".decode(\(type.name).self, forKey: .\(codingPath.containerkey))")
        }

        var errorHandlingBlock: CodeBlockItemSyntax? {
            let statement: String? = if let defaultValue {
                "\(name) = \(defaultValue)"
            } else if type.isOptional {
                "\(name) = nil"
            } else if type.isArray {
                "\(name) = []"
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

indirect enum TypeDefinition {
    case optional(wrappedType: TypeDefinition)
    case array(elementType: String)
    case identifier(name: String)

    init?(type: TypeSyntax) {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            self = .identifier(name: identifier.name.text)
        } else if let optional = type.as(OptionalTypeSyntax.self),
                  let wrappedDeclaration = TypeDefinition(type: optional.wrappedType) {
            self = .optional(wrappedType: wrappedDeclaration)
        } else if let array = type.as(ArrayTypeSyntax.self) {
            self = .array(elementType: array.element.trimmedDescription)
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
        case let .optional(wrappedType):
            wrappedType.name
        }
    }

    var isArray: Bool {
        arrayElementType != nil
    }

    var arrayElementType: String? {
        switch self {
        case let .array(elementType):
            elementType
        case let .optional(wrappedType):
            wrappedType.arrayElementType
        case .identifier:
            nil
        }
    }

    var isOptional: Bool {
        switch self {
        case .identifier, .array:
            false
        case .optional:
            true
        }
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

    var sortingKey: String { name ?? "" }

    init?(name: String? = nil, paths: [CodingPath]) {
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

                if let keys = CodingKeysDeclaration(name: caseName, paths: nestedPaths) {
                    nestedKeys.append(keys)
                    cases.append(caseName)
                }
            }

        self.cases = cases.sorted()
        self.nestedKeys = nestedKeys.sorted(by: { $0.sortingKey < $1.sortingKey })
    }

    var typeName: String { "\(name?.uppercasingFirstLetter ?? "")CodingKeys" }

    var declaration: DeclSyntax {
        get throws {
            let caseDeclaration = MemberBlockItemSyntax(
                decl: try EnumCaseDeclSyntax("case \(raw: cases.joined(separator: ", "))")
            )

            let nestedTypeDeclarations = try nestedKeys
                .map { try $0.declaration }
                .map { MemberBlockItemSyntax(decl: $0) }

            let allMembers = ([caseDeclaration] + nestedTypeDeclarations)
                .compactMap { $0?.withTrailingTrivia(.newlines(2)) }

            let declarationCode = DeclSyntax(stringLiteral: 
                "enum \(typeName): String, CodingKey {" +
                "\(MemberBlockItemListSyntax(allMembers).trimmed)" +
                "}")

            return declarationCode
        }
    }

    func containerDeclarations(
        ofKind containerKind: ContainerKind,
        parentContainerVariableName: String? = nil,
        parentContainerTypeName: String? = nil
    ) -> [CodeBlockItemSyntax] {
        let containerVariableName: String
        let containerTypeName: String
        let declarationCode: String

        if let parentContainerVariableName, let parentContainerTypeName, let name {
            containerVariableName = "\(parentContainerVariableName.dropLast("container".count))\(name.uppercasingFirstLetter)Container".lowercasingFirstLetter
            containerTypeName = "\(parentContainerTypeName).\(typeName)"
            declarationCode = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(parentContainerVariableName).nestedContainer(keyedBy: \(containerTypeName).self, forKey: .\(name))"
        } else {
            containerVariableName = "container"
            containerTypeName = typeName
            declarationCode = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(containerKind.coderName).container(keyedBy: \(containerTypeName).self)"
        }

        let containerDeclaration = CodeBlockItemSyntax(stringLiteral: declarationCode)
            .withTrailingTrivia(.newline)

        let nestedContainerDeclarations = nestedKeys
            .map {
                $0.containerDeclarations(
                    ofKind: containerKind,
                    parentContainerVariableName: containerVariableName,
                    parentContainerTypeName: containerTypeName
                )
            }
            .joined()

        return [containerDeclaration] + nestedContainerDeclarations
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

private extension SyntaxProtocol {

    func withLeadingTrivia(_ trivia: Trivia) -> Self {
        var syntax = self
        syntax.leadingTrivia = trivia
        return syntax
    }

    func withTrailingTrivia(_ trivia: Trivia) -> Self {
        var syntax = self
        syntax.trailingTrivia = trivia
        return syntax
    }
}

private extension DeclSyntax {

    static func failableContainerForArray() -> DeclSyntax {
        .init(stringLiteral:
            "private struct FailableContainer<T>: Decodable where T: Decodable { " +
            "var wrappedValue: T?\n\n" +
            "init(from decoder: Decoder) throws {" +
            "wrappedValue = try? decoder.singleValueContainer().decode(T.self) " +
            "}" +
            "}"
        )
    }

    init(decoderWithCodingKeys codingKeys: CodingKeysDeclaration, properties: [PropertyDefinition]) {
        self.init(stringLiteral: 
            "init(from decoder: Decoder) throws { " +
            "\(CodeBlockItemListSyntax(codingKeys.containerDeclarations(ofKind: .decode)).withTrailingTrivia(.newlines(2)))" +
            "\(CodeBlockItemListSyntax(properties.map { $0.decodeStatement }).trimmed)" +
            "}"
        )
    }

    init(encoderWithCodingKeys codingKeys: CodingKeysDeclaration, properties: [PropertyDefinition]) {
        self.init(stringLiteral:
            "func encode(to encoder: Encoder) throws {" +
            "\(CodeBlockItemListSyntax(codingKeys.containerDeclarations(ofKind: .encode)).withTrailingTrivia(.newlines(2)))" +
            "\(CodeBlockItemListSyntax(properties.map { $0.encodeStatement }).trimmed)" +
            "}"
        )
    }
}
