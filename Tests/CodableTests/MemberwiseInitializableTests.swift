import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CodableMacros

final class MemberwiseInitializableTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "MemberwiseInitializable": MemberwiseInitializableMacro.self
    ]

    func testMemberwiseInitializableMacro_withSimpleType() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: Bar
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Bar

                init(
                    bar: Bar
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenPropertyTypeHasGenerics() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: Generic<Bar>
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Generic<Bar>

                init(
                    bar: Generic<Bar>
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withDefaultPropertyValues() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: Bar = "default value"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Bar = "default value"

                init(
                    bar: Bar = "default value"
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_ifImmutablePropertyHasDefaultValue_isNotIncluded() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: Bar
                var mutable: String = "something"
                let immutable: String = "something else"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Bar
                var mutable: String = "something"
                let immutable: String = "something else"

                init(
                    bar: Bar,
                    mutable: String = "something"
                ) {
                    self.bar = bar
                    self.mutable = mutable
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withPublicType_generatesPublicInitializer() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            public struct Foo {
                public var bar: Bar
            }
            """,
            expandedSource: """

            public struct Foo {
                public var bar: Bar

                public init(
                    bar: Bar
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withOpenType_generatesPublicInitializer() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            open class Foo {
                public var bar: Bar
            }
            """,
            expandedSource: """

            open class Foo {
                public var bar: Bar

                public init(
                    bar: Bar
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenTypeHasInitialValue_usesItAsDefaultValue() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable
            class Foo {
                var something: String? = "default value"
                var p1: String?
                var p2: Optional<String>
                var p3: String
            }
            """,
            expandedSource: """

            class Foo {
                var something: String? = "default value"
                var p1: String?
                var p2: Optional<String>
                var p3: String

                init(
                    something: String? = "default value",
                    p1: String? = nil,
                    p2: String? = nil,
                    p3: String
                ) {
                    self.something = something
                    self.p1 = p1
                    self.p2 = p2
                    self.p3 = p3
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withAccessLevel_generatesInitializerWithSpecifiedAccessLevel() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable(.fileprivate)
            public struct Foo {
                public var bar: Bar
            }
            """,
            expandedSource: """

            public struct Foo {
                public var bar: Bar

                fileprivate init(
                    bar: Bar
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withNonTrivialType() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable(.private)
            struct Foo {
                var bar: String = ""
                var boo: Int?
                var fus: [String]
                var dah: [String?: Int?]?
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String = ""
                var boo: Int?
                var fus: [String]
                var dah: [String?: Int?]?

                private init(
                    bar: String = "",
                    boo: Int? = nil,
                    fus: [String],
                    dah: [String?: Int?]? = nil
                ) {
                    self.bar = bar
                    self.boo = boo
                    self.fus = fus
                    self.dah = dah
                }
            }
            """,
            macros: testMacros
        )
    }
}
