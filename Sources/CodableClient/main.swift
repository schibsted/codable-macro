import Foundation
import Codable

@Codable(needsValidation: true) @MemberwiseInitializable
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

    var someSet: Set<String>

    var dict: [String: Int]

    @CodableIgnored
    var neverMindMe: String = "some value"

    @Codable
    public enum Qux: String, Equatable {
        case one, two
    }

    private var isValid: Bool { optionalArray?.isEmpty != true }
}

@Decodable
struct SomeDecodable {
    let bar: String
}

@Encodable
struct SomeEncodable {
    let bar: String
}

let subjects: [String: Foo] = [
    "vanilla": Foo(bar: "bar", fus: "hello", dah: "world", baz: 1, qux: [.two], array: ["a"], optionalArray: [1, 2], someSet: ["a", "b"], dict: [:]),
    "with optional": Foo(bar: "bar", fus: "hello", dah: "world", baz: nil, qux: [.two], array: [], optionalArray: nil, someSet: [], dict: [:]),
    "invalid": Foo(bar: "bar", fus: "hello", dah: "world", baz: nil, qux: [.two], array: [], optionalArray: [], someSet: [], dict: [:])
]

print("\nENCODING AND DECODING BACK:")

try subjects.forEach { (key, foo) in
    print("\n'\(key)':")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let json = try encoder.encode(foo)
    print(String(data: json, encoding: .utf8)!)

    do {
        let foo2 = try JSONDecoder().decode(Foo.self, from: json)
        assert(foo == foo2, "\(key) failed the equality check")
    } catch {
        print("Failed to decode '\(key)': \(error)")
    }
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
    "optionalArray": [1, 2, 3],
    "someSet": ["a", "a", "a"],
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
