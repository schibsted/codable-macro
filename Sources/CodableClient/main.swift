import Foundation
import Codable

@Codable @MemberwiseInitializable
public struct Foo: Equatable {
    @CodableKey("beer.doo")
    var bar: String

    @CodableKey("beer.fus")
    var fus: String

    @CodableKey("ro.duh.dah")
    var dah: String

    @CodableKey("booz")
    var baz: Int?
    
    @CodableKey("qox")
    var qux: [Qux] = [.one]

    var array: [String] = []

    var optionalArray: [Int]?

    var dict: [String: Int]

    @CodableIgnored
    var neverMindMe: String = "some value"

    @Codable
    public enum Qux: String, Equatable {
        case one, two
    }
}

let subjects: [String: Foo] = [
    "vanilla": Foo(bar: "bar", fus: "hello", dah: "world", baz: 1, qux: [.two], array: ["a"], optionalArray: [1, 2], dict: [:]),
    "with optional": Foo(bar: "bar", fus: "hello", dah: "world", baz: nil, qux: [.two], array: [], optionalArray: [], dict: [:])
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
    "beer" : {
        "doo": "I'm a string",
        "fus": "Me too"
    },
    "ro": {
        "duh": {
            "dah": "Hello world"
        }
    },
    "booz": 1,
    "qox": ["1", "two"],
    "dict": {
        "foo": 42,
        "fii": "not an Int"
    }
}
"""
]

try jsons.forEach { json in
    print("\njson: ", json)
    let foo = try JSONDecoder().decode(Foo.self, from: json.data(using: .utf8)!)
    print("\ndecoded: ", foo)
}
