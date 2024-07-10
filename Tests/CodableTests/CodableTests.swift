import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CodableMacros

final class CodableTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Codable": CodableMacro.self,
        "Decodable": DecodableMacro.self,
        "Encodable": EncodableMacro.self,
        "CodableKey": CodableKeyMacro.self,
        "CodableIgnored": CodableIgnoredMacro.self
    ]

    func testCodableMacro_withSimpleType() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: String
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_withPublicType_generatedDeclarationsArePublic() throws {
        assertMacroExpansion(
            """
            @Codable
            public struct Foo {
                public var bar: String
            }
            """,
            expandedSource: """

            public struct Foo {
                public var bar: String

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)
                }

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenPropertyHasDefaultValue_setToDefaultValueIfDecodingFails() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: String = "something"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String = "something"

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        bar = try container.decode(String.self, forKey: .bar)
                    } catch {
                        bar = "something"
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenPropertyIsOptional_setToNilIfDecodingFails() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: String?
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String?

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        bar = try container.decode(String.self, forKey: .bar)
                    } catch {
                        bar = nil
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encodeIfPresent(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenPropertyIsOptionalAndHasDefaultValue_setToDefaultValueIfDecodingFails() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: String? = "something"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String? = "something"

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        bar = try container.decode(String.self, forKey: .bar)
                    } catch {
                        bar = "something"
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encodeIfPresent(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenPropertyTypeHasGenerics() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: Array<String>?
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Array<String>?

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        bar = try container.decode(Array<String>.self, forKey: .bar)
                    } catch {
                        bar = nil
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encodeIfPresent(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_withArrayProperty_generatesHelperContainerType() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: [String]
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: [String]

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode([FailableContainer<String>].self, forKey: .bar).compactMap {
                        $0.wrappedValue
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }

                private struct FailableContainer<T>: Decodable where T: Decodable {
                    var wrappedValue: T?

                    init(from decoder: Decoder) throws {
                        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
                    }
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_withDictionaryProperty_generatesHelperContainerType() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: [String: String]
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: [String: String]

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode([String: FailableContainer<String>].self, forKey: .bar).compactMapValues {
                        $0.wrappedValue
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }

                private struct FailableContainer<T>: Decodable where T: Decodable {
                    var wrappedValue: T?

                    init(from decoder: Decoder) throws {
                        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
                    }
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_withCustomCodingKey_generatesCorrectCodingKeys() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                @CodableKey("baz")
                var bar: String
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar = "baz"
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenPropertyIsExplicitlyIgnored_isExcludedFromGeneratedCode() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                var bar: String

                @CodableIgnored
                var baz: Int = 42
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String
                var baz: Int = 42

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenImmutablePropertyHasDefaultValue_isExcludedFromGeneratedCode() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                let bar: String
                let baz: Int = 42
            }
            """,
            expandedSource: """

            struct Foo {
                let bar: String
                let baz: Int = 42

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenDecodingFromNestedContainer_generatesNestedCodingKeys() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
                @CodableKey("baz.qux")
                var bar: String
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        let bazContainer = try container.nestedContainer(keyedBy: CodingKeys.BazCodingKeys.self, forKey: .baz)
                        bar = try bazContainer.decode(String.self, forKey: .bar)
                    } catch {
                        throw error
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    var bazContainer = container.nestedContainer(keyedBy: CodingKeys.BazCodingKeys.self, forKey: .baz)

                    try bazContainer.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case baz

                    enum BazCodingKeys: String, CodingKey {
                        case bar = "qux"
                    }
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenAppliedToEnum() throws {
        assertMacroExpansion(
            """
            @Codable
            enum Foo {
                case bar
            }
            """,
            expandedSource: """

            enum Foo {
                case bar
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenAppliedToEmptyType() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Foo {
            }
            """,
            expandedSource: """

            struct Foo {
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }

    func testCodableMacro_whenValidationNeeded_includesValidationCode() throws {
        assertMacroExpansion(
            """
            @Codable(needsValidation: true)
            struct Foo {
                let bar: String

                var isValid: Bool { !bar.isEmpty }
            }
            """,
            expandedSource: """

            struct Foo {
                let bar: String

                var isValid: Bool { !bar.isEmpty }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)

                    if !self.isValid {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Validation failed"))
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(bar, forKey: .bar)
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }


    func testCodableMacro_whenAppliedToActor_throwsError() throws {
        assertMacroExpansion(
            """
            @Codable
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

    func testCodableMacro_whenAppliedToProtocol_throwsError() throws {
        assertMacroExpansion(
            """
            @Codable
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

    func testCodableMacro_whenCombinedWithAnotherCodableMacro_throwsError() throws {
        assertMacroExpansion(
            """
            @Codable @Encodable
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
                DiagnosticSpec(message: CodableMacroError.moreThanOneCodableMacroApplied.description, line: 1, column: 10)
            ],
            macros: testMacros
        )
    }

    func testCodableMacro_withNonTrivialType() throws {
        assertMacroExpansion(
            """
            @Codable
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

                    do {
                        let beerContainer = try container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                        bar = try beerContainer.decode(String.self, forKey: .bar)
                    } catch {
                        throw error
                    }

                    do {
                        let beerContainer = try container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                        fus = try beerContainer.decode(String.self, forKey: .fus)
                    } catch {
                        throw error
                    }

                    do {
                        let roContainer = try container.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.self, forKey: .ro)
                        let roDuhContainer = try roContainer.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.DuhCodingKeys.self, forKey: .duh)
                        dah = try roDuhContainer.decode(String.self, forKey: .dah)
                    } catch {
                        throw error
                    }

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

                private struct FailableContainer<T>: Decodable where T: Decodable {
                    var wrappedValue: T?

                    init(from decoder: Decoder) throws {
                        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
                    }
                }
            }

            extension Foo: Codable {
            }
            """,
            macros: testMacros
        )
    }
}
