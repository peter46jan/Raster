public enum ShortcutConflicts {
    /// Id's van commando's waarvan de ingeschakelde sneltoets ook bij een ander commando in dezelfde lijst hoort.
    /// Onvolledige commando's tellen niet mee (ze doen nog niets).
    public static func duplicates(in commands: [Command]) -> Set<String> {
        var byShortcut: [Shortcut: [String]] = [:]
        for command in commands where command.isComplete {
            if let shortcut = command.activeShortcut { byShortcut[shortcut, default: []].append(command.id) }
        }
        return Set(byShortcut.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    /// Conflicten tellen alleen binnen één as: Horizontal en Vertical mogen dezelfde sneltoetsen hebben.
    public static func duplicates(in lists: CommandLists) -> Set<String> {
        duplicates(in: lists.horizontal.commands).union(duplicates(in: lists.vertical.commands))
    }
}
