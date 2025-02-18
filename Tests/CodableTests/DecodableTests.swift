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
        "CodableIgnored": CodableIgnoredMacro.self,
        "CustomDecoded": CustomDecodedMacro.self,
        "MemberwiseInitializable": MemberwiseInitializableMacro.self
    ]

    func testDecodableMacro_withNonTrivialType() throws {
        assertMacroExpansion(
            """
            @Decodable
            public struct Foo: Equatable {
                @CodableKey("beer.doo") public var bar: Swift.String
                @CodableKey("beer.fus") public var fus: Swift.String
                @CodableKey("ro.duh.dah") public var dah: Swift.String
                @CodableKey("booz") public var baz: Int?
                @CodableKey("qox") public var qux: [Qux] = [.one]

                public var array: [Swift.String] = []
                public var optionalArray: [Int]?
                public var dict: [Swift.String: Int]

                @CodableIgnored public var neverMindMe: Swift.String = "some value"
                public let immutable: Int = 0
                public static var booleanValue = false
            }
            """,
            expandedSource: """

            public struct Foo: Equatable {
                public var bar: Swift.String
                public var fus: Swift.String
                public var dah: Swift.String
                public var baz: Int?
                public var qux: [Qux] = [.one]

                public var array: [Swift.String] = []
                public var optionalArray: [Int]?
                public var dict: [Swift.String: Int]

                public var neverMindMe: Swift.String = "some value"
                public let immutable: Int = 0
                public static var booleanValue = false

                public init(
                    bar: Swift.String,
                    fus: Swift.String,
                    dah: Swift.String,
                    baz: Int? = nil,
                    qux: Array<Qux> = [.one],
                    array: Array<Swift.String> = [],
                    optionalArray: Array<Int>? = nil,
                    dict: Dictionary<Swift.String, Int>,
                    neverMindMe: Swift.String = "some value"
                ) {
                    self.bar = bar
                    self.fus = fus
                    self.dah = dah
                    self.baz = baz
                    self.qux = qux
                    self.array = array
                    self.optionalArray = optionalArray
                    self.dict = dict
                    self.neverMindMe = neverMindMe
                }
            
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        let beerContainer = try container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                        bar = try beerContainer.decode(Swift.String.self, forKey: .bar)
                    } catch {
                        throw error
                    }

                    do {
                        let beerContainer = try container.nestedContainer(keyedBy: CodingKeys.BeerCodingKeys.self, forKey: .beer)
                        fus = try beerContainer.decode(Swift.String.self, forKey: .fus)
                    } catch {
                        throw error
                    }

                    do {
                        let roContainer = try container.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.self, forKey: .ro)
                        let roDuhContainer = try roContainer.nestedContainer(keyedBy: CodingKeys.RoCodingKeys.DuhCodingKeys.self, forKey: .duh)
                        dah = try roDuhContainer.decode(Swift.String.self, forKey: .dah)
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
                        array = try container.decode([FailableContainer<Swift.String>].self, forKey: .array).compactMap {
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

                    dict = try container.decode([Swift.String: FailableContainer<Int>].self, forKey: .dict).compactMapValues {
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

    func testDecodableMacro_whenPropertyTypeIsNested() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Outer<O> {
                @Decodable
                struct Inner {
                    @Decodable
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

                init(
                    thing: Outer<Void>.Inner.Innermost<Void>
                ) {
                    self.thing = thing
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    thing = try container.decode(Outer<Void>.Inner.Innermost<Void>.self, forKey: .thing)
                }

                enum CodingKeys: String, CodingKey {
                    case thing
                }
            }

            extension Outer.Inner.Innermost: Decodable {
            }

            extension Outer.Inner: Decodable {
            }

            extension Outer: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenDecodingArray() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                var bar: [String]
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: [String]

                init(
                    bar: Array<String>
                ) {
                    self.bar = bar
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode([FailableContainer<String>].self, forKey: .bar).compactMap {
                        $0.wrappedValue
                    }
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

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenDecodingSet() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                var bar: Set<String>
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Set<String>

                init(
                    bar: Set<String>
                ) {
                    self.bar = bar
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = Set(try container.decode([FailableContainer<String>].self, forKey: .bar).compactMap {
                            $0.wrappedValue
                        })
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

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenDecodingDictionary() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                var bar: [String: Int]
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: [String: Int]

                init(
                    bar: Dictionary<String, Int>
                ) {
                    self.bar = bar
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode([String: FailableContainer<Int>].self, forKey: .bar).compactMapValues {
                        $0.wrappedValue
                    }
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

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenValidationNeeded_includesValidationCode() throws {
        assertMacroExpansion(
            """
            @Decodable(needsValidation: true)
            struct Foo {
                let bar: String

                var isValid: Bool { !bar.isEmpty }
            }
            """,
            expandedSource: """

            struct Foo {
                let bar: String

                var isValid: Bool { !bar.isEmpty }

                init(
                    bar: String
                ) {
                    self.bar = bar
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(String.self, forKey: .bar)

                    if !self.isValid {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Validation failed"))
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case bar
                }
            }

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenCustomDecodedApplied_callsCustomDecodingFunction() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                @CustomDecoded let specialProperty: String

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }
            }
            """,
            expandedSource: """

            struct Foo {
                let specialProperty: String

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }

                init(
                    specialProperty: String
                ) {
                    self.specialProperty = specialProperty
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    specialProperty = try Self.decodeSpecialProperty(from: decoder)
                }

                enum CodingKeys: String, CodingKey {
                    case specialProperty
                }
            }
            
            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenCustomDecodedAppliedToImplicitlyIgnoredProperty_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                @CustomDecoded let specialProperty: String = ""

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }
            }
            """,
            expandedSource: """

            struct Foo {
                let specialProperty: String = ""

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }
            }
            
            extension Foo: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.customDecodingNotApplicableToExcludedProperty(propertyName: "specialProperty").description, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }


    func testDecodableMacro_whenCustomDecodedAppliedToExplicitlyIgnoredProperty_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                @CustomDecoded @CodableIgnored let specialProperty: String

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }
            }
            """,
            expandedSource: """

            struct Foo {
                let specialProperty: String

                static func decodeSpecialProperty(from decoder: Decoder) throws -> Bool { "custom decoded value" }
            }

            extension Foo: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.customDecodingNotApplicableToExcludedProperty(propertyName: "specialProperty").description, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testDecodableMacro_whenPropertyTypeIsOmitted_throwsError() throws {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                var bar = false
            }
            """,
            expandedSource: """

            struct Foo {
                var bar = false
            }

            extension Foo: Decodable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: CodableMacroError.propertyTypeNotSpecified(propertyName: "bar").description, line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testDecodableMacro_whenPropertyIsStatic_isIgnored() throws {
        assertMacroExpansion(
            """
            @Decodable
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
    
    func testDecodableMacro_whenPropertyHasSameNameAsComponentOfCustomCodingKey() {
        assertMacroExpansion(
            """
            @Decodable
            struct Foo {
                var bar: Bar
                @CodableKey("bar.baz") var baz: Baz
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Bar
                var baz: Baz

                init(
                    bar: Bar,
                    baz: Baz
                ) {
                    self.bar = bar
                    self.baz = baz
                }
            
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    bar = try container.decode(Bar.self, forKey: .bar)

                    do {
                        let barContainer = try container.nestedContainer(keyedBy: CodingKeys.BarCodingKeys.self, forKey: .bar)
                        baz = try barContainer.decode(Baz.self, forKey: .baz)
                    } catch {
                        throw error
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case bar

                    enum BarCodingKeys: String, CodingKey {
                        case baz
                    }
                }
            }

            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenHasMemberwiseInitializableMacro_generatesMemberwiseIntializerOnce() throws {
        assertMacroExpansion(
            """
            @Decodable
            @MemberwiseInitializable
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
            
                enum CodingKeys: String, CodingKey {
                    case bar
                }
            
                init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            
            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }

    func testDecodableMacro_whenHasMemberwiseInitializableMacroWithAccessLevel_generatesMemberwiseIntializerOnce() throws {
        assertMacroExpansion(
            """
            @Decodable
            @MemberwiseInitializable(.private)
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
            
                enum CodingKeys: String, CodingKey {
                    case bar
                }
            
                private init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            
            extension Foo: Decodable {
            }
            """,
            macros: testMacros
        )
    }
}
