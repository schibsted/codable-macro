import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CodableMacros

final class DecodableTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Codable": CodableMacro.self,
        "Decodable": DecodableMacro.self,
        "Encodable": EncodableMacro.self,
        "CodableKey": CodableKeyMacro.self,
        "CodableIgnored": CodableIgnoredMacro.self
    ]

    func testDecodableMacro_withNonTrivialType() throws {
        assertMacroExpansion(
            """
            @Decodable
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

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let beerContainer = try container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                    let roContainer = try container.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.self, forKey: .ro)
                    let roDuhContainer = try roContainer.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.DuhCodingKeys.self, forKey: .duh)

                    bar = try beerContainer.decode(String.self, forKey: .bar)
                    fus = try beerContainer.decode(String.self, forKey: .fus)
                    dah = try roDuhContainer.decode(String.self, forKey: .dah)

                    do {
                        baz = try container.decode(Int.self, forKey: .baz)
                    } catch {
                        baz = nil
                    }

                    do {
                        qux = try container.decode([FailableContainer<Qux>].self, forKey: .qux).compactMap {
                            $0.wrappedValue
                        }
                    } catch {
                        qux = [.one]
                    }

                    do {
                        array = try container.decode([FailableContainer<String>].self, forKey: .array).compactMap {
                            $0.wrappedValue
                        }
                    } catch {
                        array = []
                    }

                    do {
                        optionalArray = try container.decode([FailableContainer<Int>].self, forKey: .optionalArray).compactMap {
                            $0.wrappedValue
                        }
                    } catch {
                        optionalArray = nil
                    }
                    dict = try container.decode([String: FailableContainer<Int>].self, forKey: .dict).compactMapValues {
                        $0.wrappedValue
                    }
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

                private struct FailableContainer<T>: Decodable where T: Decodable {
                    var wrappedValue: T?

                    init(from decoder: Decoder) throws {
                        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
                    }
                }
            }

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenAppliedToEnum() throws {
        assertMacroExpansion(
            """
            @Decodable
            enum Foo {
                case bar
            }
            """,
            expandedSource: """

            enum Foo {
                case bar
            }

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }


    func testDecodableMacro_whenAppliedToEmptyType() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
            }
            """,
            expandedSource: """

            struct Foo {
            }

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenAppliedToActor_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable
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

    func testDecodableMacro_whenAppliedToProtocol_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable
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

    func testDecodableMacro_whenCombinedWithAnotherCodableMacro_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable @Encodable
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
