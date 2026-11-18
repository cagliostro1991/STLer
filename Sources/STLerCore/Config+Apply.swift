extension Config {
    /// The file types to render again now that this config replaced `old`: those whose own settings
    /// changed, or every enabled type when folders were added or the scope switched. Types that are
    /// off never apply, and removing a folder starts nothing.
    func typesToApply(after old: Config) -> [FileType] {
        let scopeGrew = scope != old.scope || !Set(scopeFolders).isSubset(of: old.scopeFolders)
        return FileType.allCases.filter { self[$0].enabled && (scopeGrew || self[$0] != old[$0]) }
    }
}
