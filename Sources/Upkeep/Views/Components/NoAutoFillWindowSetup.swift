import AppKit
import Quartz
import SwiftUI

/// Once-and-for-all suppression of the empty rounded-rectangle popup
/// that appears the first time any field-editor or menu surface
/// initializes in a window on macOS 15+. On macOS 26 a new variant
/// ("SPRoundedWindow") re-appears even with layers 0–5 in place; the
/// layer-6 reaper here orders it out by class-name match.
///
/// The interception happens via NSWindowDelegate's
/// `windowWillReturnFieldEditor(_:to:)` — when that returns non-nil,
/// AppKit uses it in place of its own default editor. SwiftUI assigns
/// its own internal delegate to the windows it creates, so we wrap
/// that delegate via a forwarding NSObject (`responds(to:)` +
/// `forwardingTarget(for:)`) and only add this single method on top.
/// Everything SwiftUI's delegate did before still happens; we just
/// inject one extra hook.

/// The pre-configured field editor returned by every wrapped window.
/// One per app — NSText/NSTextView field editors are designed to be
/// shared; AppKit checks that the returned editor isn't already in
/// use elsewhere and falls back to its own pool when it is, so a
/// shared instance plus the same disabled flags is the canonical
/// shape.
@MainActor
private let sharedNoAutoFillFieldEditor: NSTextView = {
    let editor = NSTextView()
    editor.isFieldEditor = true
    configureNoAutoFill(editor)
    return editor
}()

@MainActor
private func configureNoAutoFill(_ editor: NSTextView) {
    editor.isAutomaticTextCompletionEnabled = false
    editor.isAutomaticSpellingCorrectionEnabled = false
    editor.isAutomaticTextReplacementEnabled = false
    editor.isContinuousSpellCheckingEnabled = false
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.isAutomaticDataDetectionEnabled = false
    editor.isAutomaticLinkDetectionEnabled = false
    if #available(macOS 14.0, *) {
        editor.inlinePredictionType = .no
    }
    if #available(macOS 15.0, *) {
        editor.writingToolsBehavior = .none
        editor.allowedWritingToolsResultOptions = []
    }
}

/// Forwarding NSObject that wraps an existing NSWindowDelegate and
/// adds `windowWillReturnFieldEditor`. All other delegate calls are
/// forwarded transparently so SwiftUI's window machinery (drag, key
/// equivalents, restoration, etc.) keeps working.
final class FieldEditorInterceptor: NSObject, NSWindowDelegate {
    weak var wrapped: NSObject?

    /// Cache of `responds(to:)` answers for forwarded selectors. AppKit
    /// asks the window delegate about the same selectors many times per
    /// focus traversal; without caching, each call forwards through to
    /// SwiftUI's wrapped delegate and the cumulative cost on macOS 26 is
    /// ~1s of latency per focus change. Caching reduces post-warmup cost
    /// to a dictionary lookup.
    private var respondsCache: [Selector: Bool] = [:]

    init(wrapping wrapped: NSObject?) {
        self.wrapped = wrapped
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        guard let aSelector else { return false }
        if let cached = respondsCache[aSelector] { return cached }
        let result = super.responds(to: aSelector) || (wrapped?.responds(to: aSelector) ?? false)
        respondsCache[aSelector] = result
        return result
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let wrapped, wrapped.responds(to: aSelector) else { return nil }
        return wrapped
    }

    @MainActor
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        // Re-apply flags every time AppKit asks for the editor — some
        // of these are reset between editor uses, and Sequoia in
        // particular re-enables `inlinePredictionType` on reuse.
        configureNoAutoFill(sharedNoAutoFillFieldEditor)
        return sharedNoAutoFillFieldEditor
    }
}

/// Strong references to installed interceptors, keyed by window
/// identity. Without this the wrapped objects would dealloc as soon
/// as `installFieldEditorInterceptor` returns since NSWindow.delegate
/// is a weak reference.
@MainActor
private var installedInterceptors: [ObjectIdentifier: FieldEditorInterceptor] = [:]

/// Heuristic class-name fragments that identify AppKit predictive /
/// Writing-Tools / inline-suggestion panels. Match is substring
/// `contains`-based since Apple namespaces these with private
/// underscore-prefixed classes and the exact names vary by macOS
/// version. False positives would orderOut some other AppKit panel
/// but the fragments are specific enough — "InlinePrediction",
/// "WritingTools", "InlineSuggestion", "PredictionPanel" — that no
/// legitimate panel in our app would match.
@MainActor
private let predictivePanelFragments: [String] = [
    "InlinePrediction",
    "InlineSuggestion",
    "PredictionPanel",
    "WritingTools",
    "TextCompletion",
    // macOS 26's empty-rounded autofill popup. Animates from
    // ~312×237 to ~332×265 right after a layout change (cold
    // launch or content-area re-layout). This is the system
    // predictive surface that none of the documented per-editor
    // flags suppress.
    "SPRoundedWindow",
]

@MainActor
private let reaperLogPath: String = {
    let dir = NSHomeDirectory() + "/.upkeep"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let path = dir + "/reaper.log"
    try? "".write(toFile: path, atomically: true, encoding: .utf8)
    return path
}()

@MainActor
private func reapLog(_ s: String) {
    let line = s + "\n"
    if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: reaperLogPath)) {
        h.seekToEndOfFile()
        h.write(Data(line.utf8))
        try? h.close()
    } else {
        try? line.write(toFile: reaperLogPath, atomically: true, encoding: .utf8)
    }
}

/// Order-out any visible panel whose class name matches a known
/// predictive-text fragment. Cheap to call (NSApp.windows is small)
/// and idempotent so multiple triggers per second are fine.
@MainActor
func reapPredictivePanels() {
    for window in NSApp.windows where window.isVisible {
        let name = NSStringFromClass(type(of: window))
        if predictivePanelFragments.contains(where: { name.contains($0) }) {
            reapLog("[reaper] KILLED \(name) frame=\(window.frame)")
            window.orderOut(nil)
        }
    }
}

/// Install (or replace) the interceptor on a window. Idempotent —
/// safe to call repeatedly when SwiftUI re-assigns the delegate.
@MainActor
func installFieldEditorInterceptor(on window: NSWindow) {
    let key = ObjectIdentifier(window)
    let currentDelegate = window.delegate as? NSObject
    if let existing = installedInterceptors[key],
       window.delegate === existing {
        return
    }
    let interceptor = FieldEditorInterceptor(wrapping: currentDelegate)
    installedInterceptors[key] = interceptor
    window.delegate = interceptor
}

/// AppDelegate that installs the field-editor interceptor on every
/// NSWindow the app creates and runs the layer-6 predictive-panel
/// reaper for macOS 26's SPRoundedWindow popup.
final class UpkeepAppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []
    private var eventMonitor: Any?

    override init() {
        // Layer 0 — fires the instant
        // `@NSApplicationDelegateAdaptor(UpkeepAppDelegate.self)`
        // instantiates this delegate, which SwiftUI does very early
        // in the App lifecycle — before applicationWillFinishLaunching,
        // before any window has been laid out.
        //
        // Force-set the prediction-subsystem defaults in our app's
        // persistent domain. set() writes to our app's persistent
        // domain which AppKit reads with higher priority than
        // NSGlobalDomain, so our values win.
        let prefs = UserDefaults.standard
        for key in [
            "NSAutomaticTextCompletionEnabled",
            "NSAutomaticInlinePredictionEnabled",
            "WebAutomaticTextReplacementEnabled",
            "NSAllowsCharacterPickerTouchBarItem",
            "NSAutomaticSpellingCorrectionEnabled",
            "NSAutomaticTextReplacementEnabled",
            "NSAutomaticQuoteSubstitutionEnabled",
            "NSAutomaticDashSubstitutionEnabled",
            "NSAutomaticDataDetectionEnabled",
            "NSAutomaticLinkDetectionEnabled",
        ] {
            prefs.set(false, forKey: key)
        }
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Earliest reliable hook — NSApp exists and any windows
        // SwiftUI has prepared are visible in NSApp.windows.
        for window in NSApp.windows {
            installFieldEditorInterceptor(on: window)
        }

        let didToken = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                installFieldEditorInterceptor(on: window)
            }
        }
        observers.append(didToken)

        // Any window that's added later (sheets, popovers that get
        // promoted) gets wrapped at order-in time.
        let updateToken = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                installFieldEditorInterceptor(on: window)
            }
        }
        observers.append(updateToken)

        // Belt-and-suspenders: before any user interaction reaches a
        // text field, re-sweep every window. Sweeping on .leftMouseDown
        // and .keyDown is cheap (idempotent installs) and guarantees
        // coverage on macOS 26 where the earlier hooks lose the race
        // against SwiftUI's own focus-on-attach. Fan out reaper sweeps
        // at multiple deferred ticks so we catch the popup whether it
        // appears in the same runloop turn or a few hops later.
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .keyDown]
        ) { event in
            MainActor.assumeIsolated {
                for window in NSApp.windows {
                    installFieldEditorInterceptor(on: window)
                }
                reapPredictivePanels()
                for delay in [0.05, 0.15, 0.35, 0.7] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        reapPredictivePanels()
                    }
                }
            }
            return event
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Re-sweep in case any windows came up between
        // applicationWillFinishLaunching and now.
        for window in NSApp.windows {
            installFieldEditorInterceptor(on: window)
        }
        // Touch QLPreviewPanel singleton early so its one-time
        // creation happens during launch — when interceptors are
        // fully wired — rather than the first time the user hits
        // spacebar.
        if let panel = QLPreviewPanel.shared() {
            installFieldEditorInterceptor(on: panel)
        }
        // Cold-launch flash fix. The reaper otherwise only triggers
        // off events / occlusion changes / key changes — at cold
        // launch none of those fire reliably BEFORE the popup paints
        // its first frame. Fan a series of timer-based reaper sweeps
        // across the first few seconds of life so any predictive panel
        // spawned during initial layout gets ordered-out within one
        // runloop turn of instantiation — usually before it draws.
        reapPredictivePanels()
        for delay in [0.05, 0.15, 0.3, 0.6, 1.2, 2.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                reapPredictivePanels()
            }
        }
        // Layer 6 — predictive-panel reaper. Even with layer 0-5 in
        // place, AppKit on macOS 26 sometimes instantiates a
        // predictive-text / Writing-Tools panel during window
        // relayout. Hook occlusion + key changes and sweep
        // NSApp.windows for known predictive panel class names.
        let occlusionToken = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                reapPredictivePanels()
            }
        }
        observers.append(occlusionToken)
        let keyToken = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                reapPredictivePanels()
            }
        }
        observers.append(keyToken)
    }

    deinit {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
