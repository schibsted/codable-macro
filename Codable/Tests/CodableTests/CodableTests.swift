import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(CodableMacros)
import CodableMacros

let testMacros: [String: Macro.Type] = [
    "Codable": CodableMacro.self,
]
#endif

final class CodableTests: XCTestCase {
    func testMacro() throws {
        #if canImport(CodableMacros)
        assertMacroExpansion(
            """
            @Codable
            struct Foo: Equatable {
                @CodableKey("beer.doo")
                var bar: String

                @CodableKey("beer.fus")
                var fus: String

                @CodableKey("ro.duh.dah")
                var dah: String

                @CodableKey("booz")
                var baz: Int?

                @CodableKey("qox")
                var qux: Qux = .one

                var array: [String]

                var optionalArray: [Int]?
            }
            """,
            expandedSource: """
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
