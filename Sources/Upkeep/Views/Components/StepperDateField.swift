import SwiftUI
import AppKit

/// Text+stepper date field that dismisses the auto-calendar overlay (macOS 15+)
/// when the user clicks a day. Wraps `NSDatePicker` in `.textFieldAndStepper` style
/// and resigns first responder on every action, which also closes the overlay.
struct StepperDateField: NSViewRepresentable {
    @Binding var selection: Date
    var minDate: Date?

    func makeNSView(context: Context) -> NSDatePicker {
        let dp = NSDatePicker()
        dp.datePickerStyle = .textFieldAndStepper
        dp.datePickerElements = [.yearMonthDay]
        dp.isBordered = true
        dp.isBezeled = true
        dp.drawsBackground = false
        dp.dateValue = selection
        if let minDate { dp.minDate = minDate }
        dp.target = context.coordinator
        dp.action = #selector(Coordinator.dateChanged(_:))
        dp.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return dp
    }

    func updateNSView(_ dp: NSDatePicker, context: Context) {
        if !Calendar.current.isDate(dp.dateValue, inSameDayAs: selection) {
            dp.dateValue = selection
        }
        dp.minDate = minDate
        context.coordinator.selection = $selection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            selection.wrappedValue = sender.dateValue
            // Resigning first responder dismisses the auto-calendar overlay.
            sender.window?.makeFirstResponder(nil)
        }
    }
}
