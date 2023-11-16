import Foundation
import Codable

enum Qux: String, Codable, Equatable {
    case one, two
}

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
    var qux: [Qux] = [.one]

    var array: [String]

    var optionalArray: [Int]?

    @CodableKey("dict")
    var dict: [String: Int]
}

extension Foo {

    init(
        bar: String,
        fus: String,
        dah: String,
        baz: Int?,
        qux: [Qux],
        array: [String],
        optionalArray: [Int],
        dict: [String: Int]
    ) {
        self.bar = bar
        self.fus = fus
        self.dah = dah
        self.baz = baz
        self.qux = qux
        self.array = array
        self.optionalArray = optionalArray
        self.dict = dict
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
        "foo": 42
    }
}
"""
]

try jsons.forEach { json in
    print("\njson: ", json)
    let foo = try JSONDecoder().decode(Foo.self, from: json.data(using: .utf8)!)
    print("\ndecoded: ", foo)
}
