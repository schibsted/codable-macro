import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

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


