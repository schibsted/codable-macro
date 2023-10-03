import Foundation
import Codable

enum Qux: String, Codable, Equatable {
    case one, two
}

@Codable
struct Foo: Equatable {
    let bar: String
    let baz: Int?
    let qux: Qux

    var fus: String { bar }

    init(
        bar: String,
        baz: Int?,
        qux: Qux
    ) {
        self.bar = bar
        self.baz = baz
        self.qux = qux
    }
}

let subjects: [String: Foo] = [
    "vanilla": Foo(bar: "bar", baz: 1, qux: .two),
    "with optional": Foo(bar: "bar", baz: nil, qux: .two)
]

try subjects.forEach { (key, foo) in
    print("Running \(key)")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let json = try encoder.encode(foo)
    print(String(data: json, encoding: .utf8)!)

    let foo2 = try JSONDecoder().decode(Foo.self, from: json)
    assert(foo == foo2, "\(key) failed the equality check")
}


