
import Foundation
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

func assertAndCompileMacroExpansion(
    _ originalSource: String,
    expandedSource expectedExpandedSource: String,
    macros: [String : any Macro.Type],
    treatWarningsAsErrors: Bool = true,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let (exitCode, output) = try compileSourceCode(
            expectedExpandedSource,
            treatWarningsAsErrors: treatWarningsAsErrors
        )

        guard exitCode == 0 else {
            XCTFail("Expanded source did not compile, swiftc exit code: \(exitCode), output: \(output ?? "nil")", file: file, line: line)
            return
        }

        assertMacroExpansion(originalSource, expandedSource: expectedExpandedSource, macros: macros, file: file, line: line)
    } catch {
        XCTFail("Failed to invoke the compile command: \(error)", file: file, line: line)
    }
}

private func compileSourceCode(_ sourceCode: String, treatWarningsAsErrors: Bool) throws -> (exitCode: Int32, output: String?) {
    let task = Process()
    let outputPipe = Pipe()

    task.standardOutput = outputPipe
    task.standardError = outputPipe
    task.arguments = ["-c", "echo '\(sourceCode)' | swiftc \(treatWarningsAsErrors ? "-warnings-as-errors" : "") -"]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    try task.run()
    task.waitUntilExit()

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    return (task.terminationStatus, output)
}
