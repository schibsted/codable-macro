# codable-macro
A Swift macro that can generate Codable implementations.

## Features
- [x] Codable conformance for simple types.
- [x] Optional properties.
- [x] Default values.
- [x] Custom coding keys (using the `@CodableKey("foo")` attribute).
  - [x] Decoding from nested objects (use keypath syntax to specify the coding path, for example `@CodableKey("foo.bar")`).
- [x] Ignore certain properties (by marking them with the `@CodableIgnored` attribute).
- [x] Specify custom decoding logic for certain properties (by marking them with the `@CustomDecoded` attribute and providing the static decoding function).
- [x] Lossy coding: where possible, the generated logic will try to prevent the errors from being propagated up the chain. For example, an array item that fails to decode will be ignored instead of causing the decoding of the entire array to fail.   
- [x] Validation on decoding (set `needsValidation` parameter of `@Decodable` or `@Codable` to `true` and provide the `var isValid: Bool { get }` property). If the validation check fails, the decoding initializer will throw an error.

## Usage
See the examples in **main.swift**.

## Presentation

Slides: [Google Drive](https://docs.google.com/presentation/d/1-EQn6Z9Ubsl1t7bsHnAMMdJYyqXugzQoiezBZo7DzX4/edit?usp=share_link).
