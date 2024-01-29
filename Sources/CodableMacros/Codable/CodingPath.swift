import Foundation

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
