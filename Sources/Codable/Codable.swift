// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(extension, conformances: Codable)
@attached(member, names: named(init(from:)), named(encode(to:)), named(CodingKeys), named(FailableContainer))
public macro Codable(needsValidation: Bool = false) = #externalMacro(module: "CodableMacros", type: "CodableMacro")

@attached(extension, conformances: Decodable)
@attached(member, names: named(init(from:)), named(CodingKeys), named(FailableContainer))
public macro Decodable(needsValidation: Bool = false) = #externalMacro(module: "CodableMacros", type: "DecodableMacro")

@attached(extension, conformances: Encodable)
@attached(member, names: named(encode(to:)), named(CodingKeys))
public macro Encodable() = #externalMacro(module: "CodableMacros", type: "EncodableMacro")

@attached(peer)
public macro CodableKey(_ key: String) = #externalMacro(module: "CodableMacros", type: "CodableKeyMacro")

@attached(peer)
public macro CodableIgnored() = #externalMacro(module: "CodableMacros", type: "CodableIgnoredMacro")

@attached(member, names: named(init))
public macro MemberwiseInitializable(_ accessLevel: MemberAccessLevel? = nil) = #externalMacro(module: "CodableMacros", type: "MemberwiseInitializableMacro")

public enum MemberAccessLevel {
    case `public`, `internal`, `fileprivate`, `private`
}
