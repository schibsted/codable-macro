// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(extension, conformances: Codable)
@attached(member, names: named(init(from:)), named(encode(to:)), named(CodingKeys), named(Debug))
public macro Codable() = #externalMacro(module: "CodableMacros", type: "CodableMacro")
