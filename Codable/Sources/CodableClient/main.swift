import Foundation
import Codable

enum Qux: String, Codable, Equatable {
    case one, two
}

@Codable
struct Foo: Equatable {
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

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let json = try encoder.encode(foo)
print(String(data: json, encoding: .utf8)!)

let foo2 = try JSONDecoder().decode(Foo.self, from: json)
assert(foo == foo2)


