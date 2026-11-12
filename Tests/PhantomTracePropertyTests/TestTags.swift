import Testing

extension Tag {
    /// Property-based tests (500 or more iterations each). Run only these with `swift test --filter Property`.
    @Tag static var property: Self
}
