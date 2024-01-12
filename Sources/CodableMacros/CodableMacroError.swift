
import Foundation

enum CodableMacroError: Error, CustomStringConvertible {
    case notApplicableToActor
    case notApplicableToProtocol

    var description: String {
        switch self {
        case .notApplicableToActor:
            "@Codable cannot be applied to an actor"
        case .notApplicableToProtocol:
            "@Codable cannot be applied to a protocol"
        }
    }
}
