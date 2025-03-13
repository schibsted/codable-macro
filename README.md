# codable-macro
A Swift macro that can generate Codable implementations.

## Motivation

Using `Codable` is the standard approach to serialization in Swift (for a number of reasons). In simple cases, using it
is as simple as conforming the type to the `Codable` and letting the compiler synthesize all the boilerplate.

In real-world projects, however, things are rarely that simple. The JSON data that needs to be deserialized often has a
different structure, different key names, invalid values, etc. `Codable` tries to accommodate these issues (for example,
by supporting custom decoding strategies for keys), but often this is not enough which means having to write massive
amounts of boilerplate code by hand.

Another feature of `Codable` that may cause issues is error handling. By default, decoding errors are propagated all the
 way up, which means a single type deep down the object tree failing to decode causes the entire object tree to fail to 
decode. Generally, this is a reasonable error handling strategy which is consistent with the Swift philosophy of failing
 early, but it is not always optimal. Sometimes potential incompleteness of the decoded data is acceptable and even 
preferrable over breaking features for hundreds of thousands of users, but the only way to make the decoding logic more
robust is to implement it by hand.

## Goal

The goal of this project is to provide an intuitive, easy to use way to generate robust serialization logic.

## Features

### Conform a type to `Codable`

To make a type codable, apply the `@Codable` macro to it: 

```swift
@Codable
public struct Foo {
    let bar: String
}
```

<details>
    <summary>Macro expansion</summary>
      
```swift
@Codable
struct Foo {
    let bar: String
    
    init(
        bar: String
    ) {
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bar = try container.decode(String.self, forKey: .bar)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar
    }
}

extension Foo: Codable {
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "bar": "hello world" }` | `Foo(bar: "hello world")`

**NOTE:** If you only need `Decodable` or `Encodable` conformance, you can use the `@Decodable` or `@Encodable` macros 
instead.

### Optional properties

```swift
@Codable
public struct Foo {
    let bar: String?
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable
struct Foo {
    let bar: String
    
    init(
        bar: String? = nil
    ) {
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            bar = try container.decode(String.self, forKey: .bar)
        } catch {
            bar = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar
    }
}

extension Foo: Codable {
}
```
    
</details>

**NOTE:** If an optional property fails to decode for some reason, the generated decoding logic will fall back to `nil` 
instead of throwing the error. Also, `nil` will be the default value of the corresponding parameter of the generated 
memberwise initializer.

#### Examples

JSON | Decoded value
-|-
`{ "bar": "hello world" }` | `Foo(bar: "hello world")`
`{ "bar": null }` | `Foo(bar: nil)`
`{ "bar": 0 }` | `Foo(bar: nil)`

### Default values

If you would like to specify a default value to use during decoding, you can do it just like you normally would for 
non-codable types:

```swift
@Codable
public struct Foo {
    var bar: String = "some default value"
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable
struct Foo {
    let bar: String
    
    init(
        bar: String = "some default value"
    ) {
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            bar = try container.decode(String.self, forKey: .bar)
        } catch {
            bar = "some default value"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar
    }
}

extension Foo: Codable {
}
```
    
</details>

**NOTE:** Similarly to the way optional properties are handled, if a property with a default value fails to decode for 
some reason, the generated decoding logic will fall back to the default value instead of throwing the error. Also, the 
default value will be used in the generated memberwise initializer.

#### Examples

JSON | Decoded value
-|-
`{ "bar": "hello world" }` | `Foo(bar: "hello world")`
`{ "bar": null }` | `Foo(bar: "some default value")`
`{ "bar": 0 }` | `Foo(bar: "some default value")`

### Lossy decoding of collection types

If an item inside a JSON array fails to decode, it is quietly discarded. This applies to dictionary values as well.

```swift
@Codable
public struct Foo {
    let bar: [String]
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable
public struct Foo {
    let bar: [String]
    
    init(
        bar: Array<String>
    ) {
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bar = try container.decode([FailableContainer<String>].self, forKey: .bar).compactMap {
            $0.wrappedValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar
    }

    private struct FailableContainer<T>: Decodable where T: Decodable {
        var wrappedValue: T?

        init(from decoder: Decoder) throws {
            wrappedValue = try? decoder.singleValueContainer().decode(T.self)
        }
    }        
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "bar": ["hello world"] }` | `Foo(bar: ["hello world"])`
`{ "bar": ["I'm a string", 42] }` | `Foo(bar: ["I'm a string"])`

### Custom coding keys

If the name of a property doesn't match the JSON, you can specify the JSON name using the `@CodableKey("name")` macro. 
If you need to decode a property from a nested object, you can specify the key path to the data using the familiar 
dot-separated key syntax: `@CodableKey("path.to.name")`.

```swift
@Codable
struct Foo {
    @CodableKey("__baz")
    var baz: Int

    @CodableKey("qux.bar")
    var bar: String
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
struct Foo {
    @CodableKey("__baz")
    var baz: Int

    @CodableKey("qux.bar")
    var bar: String
    
    init(
        baz: Int,
        bar: String
    ) {
        self.baz = baz
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        baz = try container.decode(Int.self, forKey: .baz)

        do {
            let quxContainer = try container.nestedContainer(keyedBy: CodingKeys.QuxCodingKeys.self, forKey: .qux)
            bar = try quxContainer.decode(String.self, forKey: .bar)
        } catch {
            throw error
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var quxContainer = container.nestedContainer(keyedBy: CodingKeys.QuxCodingKeys.self, forKey: .qux)

        try container.encode(baz, forKey: .baz)
        try quxContainer.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case baz = "__baz", qux

        enum QuxCodingKeys: String, CodingKey {
            case bar
        }
    }
}

extension Foo: Codable {
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "__baz": 11, "qux": { "bar": "a deeply nested string" } }` | `Foo(baz: 11, bar: "a deeply nested string")`

### Ignore certain properties

If you need to ignore certain properties, apply the  `@CodableIgnored` macro to them.

```swift
@Codable
struct Foo {
    @CodableIgnored
    var uuid: UUID = UUID()
    var bar: String
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable
struct Foo {
    @CodableIgnored
    var uuid: UUID = UUID()
    var bar: String
    
    init(
        uuid: UUID = UUID(),
        bar: String
    ) {
        self.uuid = uuid
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bar = try container.decode(String.self, forKey: .bar)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar
    }
}

extension Foo: Codable {
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "bar": "hello world" }` | `Foo(uuid: 57FCCD12-7DE6-4BE9-9F16-A5B164A47D8F, bar: "hello world")`

### Specify custom decoding logic for certain properties

If simply decoding a property is not enough and you need to transform it in some way, mark it with the `@CustomDecoded` 
macro and provide the custom decoding logic in a static throwing function named `decodeXXX`:

```swift
@Codable
struct Foo {
    var qux: Int

    @CustomDecoded
    var bar: String

    static func decodeBar(from decoder: Decoder) throws -> String {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .bar)
        return "Fancy custom decoded \(value)!"
    }
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable
struct Foo {
    var qux: Int

    @CustomDecoded
    var bar: String

    static func decodeBar(from decoder: Decoder) throws -> String {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .bar)
        return "Fancy custom decoded \(value)!"
    }
    
    init(
        qux: Int,
        bar: String
    ) {
        self.qux = qux
        self.bar = bar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        qux = try container.decode(Int.self, forKey: .qux)
        bar = try Self.decodeBar(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(qux, forKey: .qux)
        try container.encode(bar, forKey: .bar)
    }

    enum CodingKeys: String, CodingKey {
        case bar, qux
    }
}

extension Foo: Codable {
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "qux": 42, "bar": "hello world" }` | `Foo(qux: 42, bar: "Fancy custom decoded hello world!")`

### Custom validation logic

If you need to provide additional validation logic for your codable types, use the `needsValidation` parameter: 
`@Codable(needsValidation: true)` (or `@Codable(needsValidation: true)`) and place your validation logic in the computed
 property named `isValid`:

```swift
@Codable(needsValidation: true)
struct Foo {
    var qux: Int

    var isValid: Bool {
        qux <= 9000
    }
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@Codable(needsValidation: true)
struct Foo {
    var qux: Int

    var isValid: Bool {
        qux <= 9000
    }
    
    init(
        qux: Int
    ) {
        self.qux = qux
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        qux = try container.decode(Int.self, forKey: .qux)

        if !self.isValid {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Validation failed"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(qux, forKey: .qux)
    }

    enum CodingKeys: String, CodingKey {
        case qux
    }        
}

extension Foo: Codable {
}
```
    
</details>

#### Examples

JSON | Decoded value
-|-
`{ "qux": 42 }` | `Foo(qux: 42)`
`{ "qux": 9001 }` | `DecodingError.dataCorrupted(debugDescription: "Validation failed")`


### Generate a memberwise initializer

Applying `@Codable` or `@Decodable` macros to a type generates a memberwise initializer as well, with the same access 
level as the type. You can also generate a memberwise initializer by applying the `@MemberwiseInitializable` macro to 
the type:

```swift
@MemberwiseInitializable
public struct Foo {
    let bar: String
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@MemberwiseInitializable
public struct Foo {
    let bar: String

    public init(
        bar: String
    ) {
        self.bar = bar
    }
}
```

</details>

You can also specify the desired access level:

```swift
@MemberwiseInitializable(.fileprivate)
public struct Foo {
    let bar: String
}
```

<details>
    <summary>Macro expansion</summary>
    
```swift
@MemberwiseInitializable(.fileprivate)
public struct Foo {
    let bar: String

    fileprivate init(
        bar: String
    ) {
        self.bar = bar
    }
}
```

</details>

See **main.swift** for more examples.

## NOTICE

Copyright 2025 Schibsted News Media AB.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

See the License for the specific language governing permissions and limitations under the License.

