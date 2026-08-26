import SwiftUI

// A pushed sound list modelled on the Clock app's alarm sound picker: a leading
// checkmark on the current choice, and an immediate audition when a row is
// tapped.
struct AlarmSoundPickerView: View {
    @Binding var selection: AlarmSoundOption

    @State private var preview = AlarmSoundPreviewPlayer()

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                toneList
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    private var toneList: some View {
        VStack(spacing: 0) {
            ForEach(Array(AlarmSoundOption.allCases.enumerated()), id: \.element) { index, option in
                row(for: option)

                if index < AlarmSoundOption.allCases.count - 1 {
                    Divider().padding(.leading, Layout.separatorInset)
                }
            }
        }
        .background(WPStyles.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(for option: AlarmSoundOption) -> some View {
        let isSelected = selection == option
        let isPlaying = preview.playingOption == option

        return Button {
            select(option)
        } label: {
            HStack(spacing: Layout.checkmarkSpacing) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WPStyles.primaryOrange)
                    .frame(width: Layout.checkmarkWidth, alignment: .leading)
                    .opacity(isSelected ? 1 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.body)
                        .foregroundStyle(WPStyles.primaryText)

                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(WPStyles.tertiaryText)
                    }
                }

                Spacer(minLength: 8)

                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.footnote)
                        .foregroundStyle(WPStyles.tertiaryText)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func select(_ option: AlarmSoundOption) {
        selection = option
        preview.play(option)
    }

    private enum Layout {
        static let checkmarkWidth: CGFloat = 20
        static let checkmarkSpacing: CGFloat = 12
        // Keeps separators aligned with the row titles rather than the checkmark.
        static let separatorInset: CGFloat = 16 + checkmarkWidth + checkmarkSpacing
    }
}
