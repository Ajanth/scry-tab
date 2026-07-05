import Foundation

/// Pure decision for a single click on an override segmented control / radio button / switch.
/// `OverrideClickResolver.decide` is callable in tests with no AppKit / Preferences / UserDefaults
/// dependencies, so we can pin the override state-machine semantics against regressions.
enum OverrideClickDecision: Equatable {
    /// The click landed on the currently displayed value while no state change was needed.
    case skip
    /// The click selected the global value while an override was set.
    case remove
    /// The click selected a non-global value.
    case write(value: String)
}

enum OverrideClickResolver {
    /// Override-control state machine:
    ///   - Override is either SET or UNSET. The displayed value follows the override when SET,
    ///     and follows the global value when UNSET.
    ///   - Selecting the global value removes an existing override (`.remove`).
    ///   - Clicking the displayed non-global override is a no-op (`.skip`).
    ///   - Selecting any other non-global value writes the override (`.write`).
    static func decide(
        newIndex: Int,
        hasOverride: Bool,
        storedOverrideValue: String?,
        globalIndex: Int,
        valueAtIndex: (Int) -> String
    ) -> OverrideClickDecision {
        let displayedIndex: Int
        if hasOverride {
            displayedIndex = Int(storedOverrideValue ?? "") ?? -1
        } else {
            displayedIndex = globalIndex
        }
        if hasOverride && newIndex == globalIndex {
            return .remove
        }
        if newIndex == displayedIndex {
            return .skip
        }
        return .write(value: valueAtIndex(newIndex))
    }
}
