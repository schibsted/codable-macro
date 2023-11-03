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
                var array1: [String]
                var optionalArray: [String]?
                var array2: Array<String>
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
