
import Foundation

struct CodableMacroError: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}
