// Copyright 2025 Schibsted News Media AB.
// Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import CodableMacros

final class MemberwiseInitializableTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "MemberwiseInitializable": MemberwiseInitializableMacro.self
    ]

    func testMemberwiseInitializableMacro_withSimpleType() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: String
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String

                init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenPropertyTypeHasGenerics() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: Generic<String>
            }
            
            struct Generic<T> {
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: Generic<String>

                init(
                    bar: Generic<String>
                ) {
                    self.bar = bar
                }
            }

            struct Generic<T> {
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withDefaultPropertyValues() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: String = "default value"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String = "default value"

                init(
                    bar: String = "default value"
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_ifImmutablePropertyHasDefaultValue_isNotIncluded() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            struct Foo {
                var bar: String
                var mutable: String = "something"
                let immutable: String = "something else"
            }
            """,
            expandedSource: """

            struct Foo {
                var bar: String
                var mutable: String = "something"
                let immutable: String = "something else"

                init(
                    bar: String,
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
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            public struct Foo {
                public var bar: String
            }
            """,
            expandedSource: """

            public struct Foo {
                public var bar: String

                public init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withOpenType_generatesPublicInitializer() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            open class Foo {
                public var bar: String
            }
            """,
            expandedSource: """

            open class Foo {
                public var bar: String

                public init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenTypeHasInitialValue_usesItAsDefaultValue() throws {
        assertAndCompileMacroExpansion(
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
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable(.fileprivate)
            public struct Foo {
                public var bar: String
            }
            """,
            expandedSource: """

            public struct Foo {
                public var bar: String

                fileprivate init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenAppliedToFinalType() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            final class Foo {
                let bar: String
            }
            """,
            expandedSource: """

            final class Foo {
                let bar: String

                init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_whenAppliedToFinalPublicType_handlesNonStandardKeywordOrder() throws {
        assertAndCompileMacroExpansion(
            """
            @MemberwiseInitializable
            final public class Foo {
                let bar: String
            }
            """,
            expandedSource: """

            final public class Foo {
                let bar: String

                public init(
                    bar: String
                ) {
                    self.bar = bar
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMemberwiseInitializableMacro_withNonTrivialType() throws {
        assertAndCompileMacroExpansion(
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
                    fus: Array<String>,
                    dah: Dictionary<String?, Int?>? = nil
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
