// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
