import Foundation

struct CodingPath {
    let propertyName: String
    let firstComponent: String
    let remainingComponents: [String]
    let isTerminal: Bool

    var codingContainerName: String {
        if isTerminal {
            return "container"
        }

        let prefix = ([firstComponent] + remainingComponents.dropLast())
            .map { $0.uppercasingFirstLetter }
            .joined()
            .lowercasingFirstLetter

        return "\(prefix)Container"
    }

    var containerkey: String { propertyName }

    init?(components: [String], propertyName: String) {
        guard let firstComponent = components.first else {
            return nil
        }

        self.propertyName = propertyName
        self.firstComponent = firstComponent
        self.remainingComponents = Array(components.dropFirst())
        self.isTerminal = remainingComponents.isEmpty
    }

    func droppingFirstComponent() -> CodingPath? {
        CodingPath(components: remainingComponents, propertyName: propertyName)
    }
}
