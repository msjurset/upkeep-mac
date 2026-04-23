import SwiftUI
import AppKit

/// A small "calendar" icon button that opens a graphical date picker in a popover.
/// Clicking a day in the popover updates the binding and auto-dismisses the popover.
struct CalendarPopoverButton: View {
    @Binding var selection: Date
    var minDate: Date?
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "calendar")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Pick a date")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            GraphicalCalendar(
                selection: $selection,
                minDate: minDate,
                onDaySelected: { isPresented = false }
            )
            .padding(10)
        }
    }
}

/// NSDatePicker wrapper in `.clockAndCalendar` style showing just the calendar grid.
/// Fires `onDaySelected` whenever the user clicks a day (picker commits the change).
struct GraphicalCalendar: NSViewRepresentable {
    @Binding var selection: Date
    var minDate: Date?
    var onDaySelected: () -> Void

    func makeNSView(context: Context) -> NSDatePicker {
        let dp = NSDatePicker()
        dp.datePickerStyle = .clockAndCalendar
        dp.datePickerElements = [.yearMonthDay]
        dp.drawsBackground = false
        dp.isBordered = false
        dp.dateValue = selection
        if let minDate { dp.minDate = minDate }
        dp.target = context.coordinator
        dp.action = #selector(Coordinator.dateChanged(_:))
        return dp
    }

    func updateNSView(_ dp: NSDatePicker, context: Context) {
        if !Calendar.current.isDate(dp.dateValue, inSameDayAs: selection) {
            dp.dateValue = selection
        }
        dp.minDate = minDate
        context.coordinator.onDaySelected = onDaySelected
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, onDaySelected: onDaySelected)
    }

    final class Coordinator: NSObject {
        @Binding var selection: Date
        var onDaySelected: () -> Void

        init(selection: Binding<Date>, onDaySelected: @escaping () -> Void) {
            self._selection = selection
            self.onDaySelected = onDaySelected
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            selection = sender.dateValue
            onDaySelected()
        }
    }
}
