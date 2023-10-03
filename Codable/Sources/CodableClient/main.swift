import Foundation
import Codable

enum Qux: String, Codable {
    case one, two
}

@Codable
struct Foo {
    let bar: String
    let baz: Int
    let qux: Qux

    var fus: String { bar }

    init() {
        self.bar = "bar"
        self.baz = 1
        self.qux = .two
    }
}

let foo = Foo()

let coder = JSONEncoder()
coder.outputFormatting = .prettyPrinted
let json = try coder.encode(foo)

print(String(data: json, encoding: .utf8)!)
