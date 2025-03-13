// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import Foundation

enum CodableMacroError: Error, CustomStringConvertible {
    case moreThanOneCodableMacroApplied
    case propertyTypeNotSpecified(propertyName: String)
    case customDecodingNotApplicableToExcludedProperty(propertyName: String)
    case notApplicableToActor
    case notApplicableToProtocol

    var description: String {
        switch self {
        case .moreThanOneCodableMacroApplied:
            "Only one codable macro can be applied at the same time"
        case .propertyTypeNotSpecified(let propertyName):
            "Property '\(propertyName)' must have explicit type"
        case .customDecodingNotApplicableToExcludedProperty(let propertyName):
            "\(CustomDecodedMacro.attributeName) cannot be applied to '\(propertyName)' because it's not decodable"
        case .notApplicableToActor:
            "@Codable cannot be applied to an actor"
        case .notApplicableToProtocol:
            "@Codable cannot be applied to a protocol"
        }
    }
}
