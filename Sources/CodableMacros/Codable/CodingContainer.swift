import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

final class CodingContainer {
    let name: String?
    let cases: [String]
    let nestedContainers: [CodingContainer]
    weak var parent: CodingContainer?

    var sortingKey: String { name ?? "" }

    init?(name: String? = nil, paths: [CodingPath]) {
        guard !paths.isEmpty else { return nil }

        self.name = name

        var cases: [String] = []
        var nestedContainers: [CodingContainer] = []

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

                if let keys = CodingContainer(name: caseName, paths: nestedPaths) {
                    nestedContainers.append(keys)
                    if !cases.contains(caseName) {
                        cases.append(caseName)
                    }
                }
            }

        self.cases = cases.sorted()
        self.nestedContainers = nestedContainers.sorted(by: { $0.sortingKey < $1.sortingKey })

        nestedContainers.forEach { $0.parent = self }
    }

    var typeName: String {
        "\(name?.uppercasingFirstLetter ?? "")CodingKeys"
    }

    var fullyQualifiedTypeName: String {
        [parent?.fullyQualifiedTypeName, typeName]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    var containerVariableName: String {
        if let parent, let name {
            "\(parent.containerVariableName.dropLast("container".count))\(name.uppercasingFirstLetter)Container".lowercasingFirstLetter
        } else {
            "container"
        }
    }

    var codingKeysDeclaration: DeclSyntax {
        get throws {
            let caseDeclaration = MemberBlockItemSyntax(
                decl: try EnumCaseDeclSyntax("case \(raw: cases.joined(separator: ", "))")
            )

            let nestedTypeDeclarations = try nestedContainers
                .map { try $0.codingKeysDeclaration }
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

    func containerDeclaration(ofKind containerKind: ContainerKind) -> CodeBlockItemSyntax {
        let declarationCode: String

        if let parent, let name {
            declarationCode = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(parent.containerVariableName).nestedContainer(keyedBy: \(fullyQualifiedTypeName).self, forKey: .\(name))"
        } else {
            declarationCode = "\(containerKind.declarationKeyword) \(containerVariableName) = \(containerKind.tryPrefix)\(containerKind.coderName).container(keyedBy: \(fullyQualifiedTypeName).self)"
        }

        return CodeBlockItemSyntax(stringLiteral: declarationCode)
            .withTrailingTrivia(.newline)
    }

    func nestedCodingContainers(along codingPath: CodingPath) -> [CodingContainer] {
        if let nestedContainer = nestedContainers.first(where: { $0.name == codingPath.firstComponent }) {
            [nestedContainer] + nestedContainer.nestedCodingContainers(along: codingPath.droppingFirstComponent())
        } else {
            []
        }
    }

    func allCodingContainers() -> [CodingContainer] {
        [self] + nestedContainers
            .map { $0.allCodingContainers() }
            .joined()
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
