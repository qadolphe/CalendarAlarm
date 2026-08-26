import SwiftUI

struct FeedbackView: View {
    @Bindable var appState: AppState

    @State private var category = FeedbackCategory.experience
    @State private var message = ""
    @State private var submissionState = SubmissionState.idle
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        ZStack {
            Color.clear.withAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    categoryPicker
                    messageEditor
                    status
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(FeedbackCategory.allCases) { option in
                let isSelected = category == option

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        category = option
                        resetSubmissionState()
                    }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? WPStyles.primaryText : WPStyles.secondaryText.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? WPStyles.surfaceRaised : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(isSelected ? WPStyles.primaryOrange.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(WPStyles.surface)
        )
        .disabled(isSubmitting)
    }

    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text(category.prompt)
                    .font(.body)
                    .foregroundStyle(WPStyles.tertiaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $message)
                .font(.body)
                .foregroundStyle(WPStyles.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .focused($isMessageFocused)
                .accessibilityLabel("Feedback")
                .onChange(of: message) { _, newValue in
                    if newValue.count > AppFeedback.maximumMessageLength {
                        message = String(newValue.prefix(AppFeedback.maximumMessageLength))
                    }
                    resetSubmissionState()
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WPStyles.surface)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isMessageFocused = true
        }
        .disabled(isSubmitting)
    }

    @ViewBuilder
    private var status: some View {
        switch submissionState {
        case .sent:
            statusRow("Feedback sent.", icon: "checkmark.circle.fill", tint: WPStyles.successGreen)
        case .failed:
            statusRow("Couldn't send. Try again.", icon: "exclamationmark.circle.fill", tint: WPStyles.primaryOrange)
        case .idle, .submitting:
            EmptyView()
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.black)
                }
                Text(isSubmitting ? "Sending…" : "Submit Feedback")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit || isSubmitting ? 1 : 0.45)
    }

    private func statusRow(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WPStyles.primaryText)
            Spacer()
        }
        .padding(14)
        .background(WPStyles.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hasValidMessage: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        hasValidMessage && submissionState != .submitting && submissionState != .sent
    }

    private var isSubmitting: Bool {
        submissionState == .submitting
    }

    private func submit() {
        isMessageFocused = false
        submissionState = .submitting

        Task {
            do {
                try await appState.submitFeedback(category: category, message: message)
                submissionState = .sent
            } catch is CancellationError {
                submissionState = .idle
            } catch {
                submissionState = .failed
            }
        }
    }

    private func resetSubmissionState() {
        guard submissionState != .submitting else { return }
        submissionState = .idle
    }
}

private enum SubmissionState: Equatable {
    case idle
    case submitting
    case sent
    case failed
}

private extension FeedbackCategory {
    var title: String {
        switch self {
        case .experience: "Experience"
        case .suggestion: "Suggestion"
        case .issue: "Issue"
        }
    }

    var prompt: String {
        switch self {
        case .experience: "How has EarlyOtter been for you?"
        case .suggestion: "What would make EarlyOtter better?"
        case .issue: "What went wrong?"
        }
    }
}
