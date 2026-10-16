extension SnappingState {
    /// Een stand zonder app erachter, voor renders en tests.
    package convenience init(isEnabled: Bool, isRunning: Bool) {
        self.init()
        self.isEnabled = isEnabled
        self.isRunning = isRunning
    }
}
