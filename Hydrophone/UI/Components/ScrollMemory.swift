import SwiftUI

/// Bridges a persisted scroll id (an `@AppStorage` string; the empty string
/// is the nil sentinel) to the optional binding `.scrollPosition(id:)` wants.
/// Views persist scroll (not `@State`) when opening an album replaces them in
/// the detail column, so Back can land on the same spot.
///
/// Rules shared by every adopter:
/// - ids in `topIDs` read as nil: they're what's reported while the view's
///   header is visible, and restoring to them would scroll the header off —
///   the top stays the top.
/// - `scope` namespaces the stored value as `"scope|id"` for views reused
///   across content (the artist page): another scope's memory reads as nil,
///   so switching content starts at the top and only Back restores.
extension Binding where Value == String {
    func scrollID(scope: String? = nil, topIDs: Set<String> = []) -> Binding<String?> {
        Binding<String?>(
            get: {
                var stored = wrappedValue
                if let scope {
                    let parts = stored.split(separator: "|", maxSplits: 1).map(String.init)
                    guard parts.count == 2, parts[0] == scope else { return nil }
                    stored = parts[1]
                }
                guard !stored.isEmpty, !topIDs.contains(stored) else { return nil }
                return stored
            },
            set: { id in
                switch (id, scope) {
                case (nil, _): wrappedValue = ""
                case let (id?, nil): wrappedValue = id
                case let (id?, scope?): wrappedValue = "\(scope)|\(id)"
                }
            }
        )
    }
}
