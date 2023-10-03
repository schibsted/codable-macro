import Foundation
import Codable

enum Qux: String, Codable, Equatable {
    case one, two
}

@Codable
struct Foo: Equatable {
    var bar: String
    var baz: Int?
    var qux: Qux = .one
}

extension Foo {

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

print("\nENCODING AND DECODING BACK:")

try subjects.forEach { (key, foo) in
    print("\n\(key):")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let json = try encoder.encode(foo)
    print(String(data: json, encoding: .utf8)!)

    let foo2 = try JSONDecoder().decode(Foo.self, from: json)
    assert(foo == foo2, "\(key) failed the equality check")
}

print("\nDECODING:")

let jsons = [
"""
{
  "bar" : "bar",
  "baz" : 1,
  "qux" : "two"
}
""",
"""
{
  "bar" : "bar",
  "baz" : 1
}
""",
"""
{
  "bar" : "bar"
}
"""
]

try jsons.forEach { json in
    print("\njson: ", json)
    let foo = try JSONDecoder().decode(Foo.self, from: json.data(using: .utf8)!)
    print("\ndecoded: ", foo)
}
