import SwiftUI

// Reusable visual building blocks for the Profile form. Each component owns its
// own layout but accepts a Binding so ProfileView remains the source of truth.

struct ProfileLabeledTextField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .words
    var keyboardType: UIKeyboardType = .default
    var multiline: Bool = false
    var multilineRange: ClosedRange<Int> = 3...6

    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.62))

            field
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .padding(13)
                .background(.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var field: some View {
        if multiline {
            let tf = TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(multilineRange)
            if let focus {
                tf.focused(focus)
            } else {
                tf
            }
        } else {
            let tf = TextField(placeholder, text: $text)
            if let focus {
                tf.focused(focus)
            } else {
                tf
            }
        }
    }
}

struct ProfileSliderRow: View {
    let icon: String
    let label: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(valueText)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.mint)
            }
            Slider(value: $value, in: range, step: step)
                .tint(AppTheme.mint)
        }
    }
}

struct ProfileMenuPicker<Value: Hashable, Content: View>: View {
    let label: LocalizedStringKey
    @Binding var selection: Value
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.62))
            Picker(label, selection: $selection, content: content)
                .pickerStyle(.menu)
                .tint(AppTheme.mint)
        }
    }
}
