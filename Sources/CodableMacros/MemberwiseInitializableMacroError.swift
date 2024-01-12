
import Foundation

enum MemberwiseInitializableMacroError: Error, CustomStringConvertible {
    case notApplicableToProtocol
    case notApplicableToEnum
    case noStoredProperties

    var description: String {
        switch self {
        case .notApplicableToProtocol:
            "@MemberwiseInitializable cannot be applied to a protocol"
        case .notApplicableToEnum:
            "@MemberwiseInitializable cannot be applied to an enum"
        case .noStoredProperties:
            "Type has no stored properties"
        }
    }
}
