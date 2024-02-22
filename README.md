# codable-macro
A Swift macro that can generate Codable implementations.

## Features
- [x] Codable conformance for simple types.
- [x] Optional properties.
- [x] Default values.
- [x] Custom keys (using the `@CodableKey("foo")` attribute).
  - [x] Decoding from nested objects.
- [x] Ignoring certain properties (by marking them with the `@CodableIgnored` attribute).
- [x] Lossy coding.
- [x] Validation on decoding (set `needsValidation` parameter of `@Decodable` or `@Codable` to `true` and provide the `var isValid: Bool { get }` property).

## Presentation

Slides: [Google Drive](https://docs.google.com/presentation/d/1-EQn6Z9Ubsl1t7bsHnAMMdJYyqXugzQoiezBZo7DzX4/edit?usp=share_link).
