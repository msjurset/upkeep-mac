import AppKit

/// NSTextField subclass that refuses all autofill and autocompletion.
/// The field editor (NSTextView) must be reconfigured in three places —
/// becomeFirstResponder, textDidBeginEditing, and textShouldBeginEditing —
/// because AppKit re-enables auto-* flags at each lifecycle point. Plus a
/// cell-level pre-focus hook (layer 4) that runs before AppKit attaches
/// the editor — needed on macOS 15 because the inline-prediction popup is
/// scheduled inside super.becomeFirstResponder().
final class NoAutoFillTextField: NSTextField {
    override var allowsCharacterPickerTouchBarItem: Bool {
        get { false }
        set {}
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Structural layer-5 install: AppKit calls this synchronously when
        // the view is attached to a window — before any focus event is
        // possible — so the shared field-editor singleton is wired before
        // becomeFirstResponder fires. Protects every sheet/popover
        // automatically without per-call-site DispatchQueue.main.async
        // races. The interceptor caches responds(to:) results, so the
        // ~1s tab-cycle latency seen with the naive forwarding wrap is
        // gone after warmup.
        if let window {
            installFieldEditorInterceptor(on: window)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            disableAllAutoComplete(editor)
        }
        return result
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        if let editor = currentEditor() as? NSTextView {
            disableAllAutoComplete(editor)
        }
    }

    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        if let editor = textObject as? NSTextView {
            disableAllAutoComplete(editor)
        }
        return super.textShouldBeginEditing(textObject)
    }

    override class var cellClass: AnyClass? {
        get { NoAutoFillTextFieldCell.self }
        set {}
    }

    fileprivate func disableAllAutoComplete(_ editor: NSTextView) {
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
}

/// Cell that disables predictions on the field editor *before* it begins
/// taking input. macOS 15 schedules the inline-prediction popup inside
/// super.becomeFirstResponder(), so the field-level overrides run too
/// late to suppress the initial popup. setUpFieldEditorAttributes is
/// the only point that runs early enough.
final class NoAutoFillTextFieldCell: NSTextFieldCell {
    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let configured = super.setUpFieldEditorAttributes(textObj)
        if let editor = configured as? NSTextView,
           let owner = controlView as? NoAutoFillTextField {
            owner.disableAllAutoComplete(editor)
        }
        return configured
    }
}
