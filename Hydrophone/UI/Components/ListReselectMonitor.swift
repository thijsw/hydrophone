import AppKit
import SwiftUI

/// Invokes `onReselect` when the user clicks the row of this `List` that is
/// already selected. The selection binding is silent for same-row clicks,
/// and SwiftUI tap gestures on rows swallow the backing table's primary
/// clicks (the Up Next gotcha's sibling — see `04`), so this *observes*
/// instead of intercepting: a local mouse-down monitor hit-tests the
/// enclosing table and passes every event through untouched. Local monitors
/// run before event dispatch, so at inspection time the table's selection
/// hasn't processed the click yet — `clicked == selected` is true only for
/// a re-click, never for a selection change.
///
/// Attach with `.background(ListReselectMonitor { … })` on the `List`.
struct ListReselectMonitor: NSViewRepresentable {
    let onReselect: () -> Void

    func makeNSView(context: Context) -> NSView { Monitor(onReselect: onReselect) }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? Monitor)?.onReselect = onReselect
    }

    private final class Monitor: NSView {
        var onReselect: () -> Void
        private var monitor: Any?

        init(onReselect: @escaping () -> Void) {
            self.onReselect = onReselect
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    MainActor.assumeIsolated { self?.inspect(event) }
                    return event
                }
            }
        }

        private func inspect(_ event: NSEvent) {
            guard event.window === window, let table = nearestTableView() else { return }
            let point = table.convert(event.locationInWindow, from: nil)
            let row = table.row(at: point)
            guard row >= 0, row == table.selectedRow else { return }
            onReselect()
        }
    }
}
