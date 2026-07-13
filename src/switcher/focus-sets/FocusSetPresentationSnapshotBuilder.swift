import Foundation

enum FocusSetPresentationSnapshotBuilder {
    static func make() -> FocusSetPresentationSnapshot {
        precondition(Thread.isMainThread, "Focus Set presentation snapshots require the main thread.")
        let configuration = FocusSetsStore().read()
        return FocusSetPresentationSnapshot(
            configuration: configuration,
            resolver: FocusSetResolver(configuration: configuration))
    }
}
