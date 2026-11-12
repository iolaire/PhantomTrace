import Testing

extension Tag {
    /// Adapter tests that run a real, harmless system tool or call a real system API (never a user's data).
    @Tag static var live: Self
    /// Local-only end-to-end tests that attach a throwaway disk image. Skipped when `CI` is set.
    @Tag static var integration: Self
}
