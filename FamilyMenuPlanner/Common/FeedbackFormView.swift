import SwiftUI
import MessageUI

struct FeedbackFormView: View {
    static let supportEmail = "plantry.sup@gmail.com"
    
    @Environment(\.dismiss) private var dismiss

    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var showMailSheet: Bool = false
    @State private var showCannotSendAlert: Bool = false
    @State private var mailAttachment: (data: Data, mimeType: String, fileName: String)? = nil

    var body: some View {
        Form {
            Section(header: Text("Subject")) {
                TextField("Enter subject", text: $subject)
                    .padding(10)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .accessibilityIdentifier("feedback_subject_field")
            }

            Section(header: Text("Message")) {
                TextEditor(text: $message)
                    .padding(8)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    .frame(minHeight: 160)
                    .accessibilityIdentifier("feedback_message_editor")
            }

            Section(footer: footerNote) {
                EmptyView()
            }
        }
        .applyStyle()
        .trackScreenAppear(name: AnalyticsScreenName.FeedbackForm)
        .background(Color.appBackground)
        .navigationTitle("Send Feedback")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Send", action: sendTapped)
                    .tint(Color.accent)
                    .disabled(!isValid)
                    .accessibilityIdentifier("feedback_send_button")
            }
            ToolbarItem(placement: .cancellationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .cancel) {
                        AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_cancelled)
                        dismiss()
                    }
                    .tint(Color.accent)
                } else {
                    Button("Cancel".localized()) {
                        AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_cancelled)
                        dismiss()
                    }
                    .foregroundColor(Color.accent)
                }
            }
        }
        .sheet(isPresented: $showMailSheet) {
            if let attachment = mailAttachment {
                MailComposerView(
                    subject: subject,
                    body: message,
                    recipients: [FeedbackFormView.supportEmail],
                    attachment: attachment
                ) { result, error in
                    var loggedResult: String
                    switch result {
                    case .sent: loggedResult = "success"
                    case .failed: loggedResult = "failure"
                    case .cancelled: loggedResult = "cancelled"
                    case .saved: loggedResult = "saved"
                    @unknown default: loggedResult = "unknown"
                    }
                    AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_email_result, properties: [AnalyticsPropertyKey.email_result: loggedResult])
                    // After dismissal, close the form
                    dismiss()
                }
            }
        }
        .alert("Email Not Available", isPresented: $showCannotSendAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This device isn't set up to send email. Please contact \(FeedbackFormView.supportEmail) manually.")
        }
        .onAppear {
            // Optionally pre-fill attachment so sheet is ready immediately when sending
            prepareAttachment()
        }
    }

    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A diagnostics file will be automatically attached to help us resolve issues faster.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("No personally identifiable data is included.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .accessibilityIdentifier("feedback_footer_note")
    }

    private func sendTapped() {
        guard MFMailComposeViewController.canSendMail() else {
            showCannotSendAlert = true
            AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_email_unavailable)
            return
        }
        // Ensure we have fresh diagnostics data
        prepareAttachment()
        showMailSheet = true
        AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_send)
    }

    private func prepareAttachment() {
        if let result = DiagnosticsHelper.diagnosticsJSONData(logsTailCount: 50) {
            mailAttachment = (data: result.data, mimeType: "application/json", fileName: result.filename)
        } else {
            mailAttachment = nil
        }
    }
}

#Preview {
    NavigationStack { FeedbackFormView() }
}
