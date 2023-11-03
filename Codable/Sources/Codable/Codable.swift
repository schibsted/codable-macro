// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(extension, conformances: Codable)
@attached(member, names: named(init(from:)), named(encode(to:)), named(CodingKeys), named(FailableContainer))
public macro Codable() = #externalMacro(module: "CodableMacros", type: "CodableMacro")

@attached(peer)
public macro CodableKey(_ key: String) = #externalMacro(module: "CodableMacros", type: "CodableKeyMacro")
