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
    
    func testMemberwiseInitializableMacro_withDefaultPropertyValues() throws {
        assertMacroExpansion(
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
    
    func testMemberwiseInitializableMacro_withPublicType_generatesPublicInitializer() throws {
        assertMacroExpansion(
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
        assertMacroExpansion(
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
    
    func testMemberwiseInitializableMacro_withAccessLevel_generatesInitializerWithSpecifiedAccessLevel() throws {
        assertMacroExpansion(
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
    
    func testMemberwiseInitializableMacro_withNonTrivialType() throws {
        assertMacroExpansion(
            """
            @MemberwiseInitializable(.private)
            struct Foo {
                var bar: String = ""
                var boo: Int?
                var fus: [String]
                var dah: [String?: Int?]?

                private init(
                    bar: String = "",
                    boo: Int?,
                    fus: [String],
                    dah: [String?: Int?]?
                ) {
                    self.bar = bar
                    self.boo = boo
                    self.fus = fus
                    self.dah = dah
                }
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
                    boo: Int?,
                    fus: [String],
                    dah: [String?: Int?]?
                ) {
                    self.bar = bar
                    self.boo = boo
                    self.fus = fus
                    self.dah = dah
                }

                private init(
                    bar: String = "",
                    boo: Int?,
                    fus: [String],
                    dah: [String?: Int?]?
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
