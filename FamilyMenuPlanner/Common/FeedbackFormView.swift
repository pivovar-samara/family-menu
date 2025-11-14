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
            Section(header: Text("Subject".localized())) {
                TextField("Enter subject".localized(), text: $subject)
                    .padding(10)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .accessibilityIdentifier("feedback_subject_field")
            }

            Section(header: Text("Message".localized())) {
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
        .trackScreenAppear(name: AnalyticsScreenName.FeedbackForm)
        .applyStyle()
        .background(Color.appBackground)
        .navigationTitle("Send Feedback".localized())
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
            MailComposerView(
                subject: subject,
                body: message,
                recipients: [FeedbackFormView.supportEmail],
                attachment: mailAttachment
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
        .alert("Email Not Available".localized(), isPresented: $showCannotSendAlert) {
            Button("OK".localized(), role: .cancel) { }
        } message: {
            Text("This device isn't set up to send email. Please contact \(FeedbackFormView.supportEmail) manually.".localized())
        }
        .onAppear {
            // Optionally pre-fill attachment so sheet is ready immediately when sending
            prepareAttachmentInBackground()
        }
    }

    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A diagnostics file will be automatically attached to help us resolve issues faster.".localized())
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("No personally identifiable data is included.".localized())
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
        
        showMailSheet = true
        AnalyticsManager.shared.track(name: AnalyticsEventName.feedback_form_send)
    }

    private func prepareAttachmentInBackground() {
        Task.detached(priority: .utility) {
            let result = DiagnosticsHelper.diagnosticsJSONData(logsTailCount: 50)
            await MainActor.run {
                if let result {
                    self.mailAttachment = (data: result.data, mimeType: "application/json", fileName: result.filename)
                } else {
                    self.mailAttachment = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack { FeedbackFormView() }
}
