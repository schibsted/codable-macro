// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CodableMacros

final class EncodableTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Codable": CodableMacro.self,
        "Decodable": DecodableMacro.self,
        "Encodable": EncodableMacro.self,
        "CodableKey": CodableKeyMacro.self,
        "CodableIgnored": CodableIgnoredMacro.self
    ]

    func testEncodableMacro_withNonTrivialType() throws {
        assertAndCompileMacroExpansion(
            """
            @Encodable
            public struct Foo: Equatable {
                @CodableKey("beer.doo") public var bar: String
                @CodableKey("beer.fus") public var fus: String
                @CodableKey("ro.duh.dah") public var dah: String
                @CodableKey("booz") public var baz: Int?
                @CodableKey("qox") public var qux: [Qux] = [.one]

                public var array: [String] = []
                public var optionalArray: [Int]?
                public var dict: [String: Int]

                @CodableIgnored public var neverMindMe: String = "some value"
                public let immutable: Int = 0
                public static var booleanValue = false
            }
            
            public enum Qux: String, Encodable, Equatable {
                case one, two
            }            
            """,
            expandedSource: """

            public struct Foo: Equatable {
                public var bar: String
                public var fus: String
                public var dah: String
                public var baz: Int?
                public var qux: [Qux] = [.one]

                public var array: [String] = []
                public var optionalArray: [Int]?
                public var dict: [String: Int]

                public var neverMindMe: String = "some value"
                public let immutable: Int = 0
                public static var booleanValue = false

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    var beerContainer = container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                    var roContainer = container.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.self, forKey: .ro)
                    var roDuhContainer = roContainer.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.DuhCodingKeys.self, forKey: .duh)

                    try beerContainer.encode(bar, forKey: .bar)
                    try beerContainer.encode(fus, forKey: .fus)
                    try roDuhContainer.encode(dah, forKey: .dah)
                    try container.encodeIfPresent(baz, forKey: .baz)
                    try container.encode(qux, forKey: .qux)
                    try container.encode(array, forKey: .array)
                    try container.encodeIfPresent(optionalArray, forKey: .optionalArray)
                    try container.encode(dict, forKey: .dict)
                }

                enum CodingKeys: String, CodingKey {
                    case array, baz = "booz", beer, dict, optionalArray, qux = "qox", ro

                    enum BeerCodingKeys: String, CodingKey {
                        case bar = "doo", fus
                    }

                    enum RoCodingKeys: String, CodingKey {
                        case duh

                        enum DuhCodingKeys: String, CodingKey {
                            case dah
                        }
                    }
                }
            }

            public enum Qux: String, Encodable, Equatable {
                case one, two
            }            

            extension Foo: Encodable {
            }
            """,
            macros: testMacros
        )
    }

    func testEncodableMacro_whenAppliedToEnum() throws {
        assertAndCompileMacroExpansion(
            """
            @Encodable
            enum Foo {
                case bar
            }
            """,
            expandedSource: """

            enum Foo {
                case bar
            }

            extension Foo: Encodable {
            }
            """,
            macros: testMacros
        )
    }

    func testEncodableMacro_whenAppliedToEmptyType() throws {
        assertAndCompileMacroExpansion(
            """
            @Encodable
            struct Foo {
            }
            """,
            expandedSource: """

            struct Foo {
            }

            extension Foo: Encodable {
            }
            """,
            macros: testMacros
        )
    }

    func testEncodableMacro_whenPropertyIsStatic_isIgnored() throws {
        assertAndCompileMacroExpansion(
            """
            @Encodable
            struct Foo {
                static var foo: Int = 0
                static var bar = false
            }
            """,
            expandedSource: """

            struct Foo {
                static var foo: Int = 0
                static var bar = false
            }

            extension Foo: Encodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenPropertyTypeIsNested() throws {
        assertAndCompileMacroExpansion(
            """
            @Encodable
            struct Outer<O> {
                @Encodable
                struct Inner {
                    @Encodable
                    struct Innermost<I> {
                    }
                }

                let thing: Outer<Void>.Inner.Innermost<Void>
            }
            """,
            expandedSource: """
            struct Outer<O> {
                struct Inner {
                    struct Innermost<I> {
                    }
                }

                let thing: Outer<Void>.Inner.Innermost<Void>

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(thing, forKey: .thing)
                }

                enum CodingKeys: String, CodingKey {
                    case thing
                }
            }

            extension Outer.Inner.Innermost: Encodable {
            }

            extension Outer.Inner: Encodable {
            }

            extension Outer: Encodable {
            }
            """,
            macros: testMacros
        )
    }

    func testEncodableMacro_whenAppliedToActor_throwsError() throws {
        assertMacroExpansion(
            """
            @Encodable
            actor Foo {
            }
            """,
            expandedSource: """

            actor Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.notApplicableToActor.description, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testEncodableMacro_whenAppliedToProtocol_throwsError() throws {
        assertMacroExpansion(
            """
            @Encodable
            protocol Foo {
            }
            """,
            expandedSource: """

            protocol Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.notApplicableToProtocol.description, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testEncodableMacro_whenCombinedWithAnotherCodableMacro_throwsError() throws {
        assertMacroExpansion(
            """
            @Encodable @Decodable
            struct Foo {
                var bar: String
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.moreThanOneCodableMacroApplied.description, line: 1, column: 1),
                DiagnosticSpec(message: CodableMacroError.moreThanOneCodableMacroApplied.description, line: 1, column: 12)
            ],
            macros: testMacros
        )
    }
}
