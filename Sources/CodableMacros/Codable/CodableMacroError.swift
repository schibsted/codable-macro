
import Foundation

enum CodableMacroError: Error, CustomStringConvertible {
    case moreThanOneCodableMacroApplied
    case propertyTypeNotSpecified(propertyName: String)
    case notApplicableToActor
    case notApplicableToProtocol

    var description: String {
        switch self {
        case .moreThanOneCodableMacroApplied:
            "Only one codable macro can be applied at the same time"
        case .propertyTypeNotSpecified(let propertyName):
            "Property '\(propertyName)' must have explicit type"
        case .notApplicableToActor:
            "@Codable cannot be applied to an actor"
        case .notApplicableToProtocol:
            "@Codable cannot be applied to a protocol"
        }
    }
}
