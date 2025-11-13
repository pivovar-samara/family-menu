import SwiftUI
import MessageUI

/// A SwiftUI wrapper around MFMailComposeViewController for composing support emails with attachments.
struct MailComposerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MFMailComposeViewController

    let subject: String
    let body: String
    let recipients: [String]
    /// Optional attachment to include with the email.
    /// Provide (data, mimeType, fileName), where mimeType for JSON is "application/json".
    let attachment: (data: Data, mimeType: String, fileName: String)?

    /// Called when the mail composer finishes (sent, cancelled, failed, saved).
    var onFinish: ((MFMailComposeResult, Error?) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let attachment {
            vc.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No dynamic updates needed.
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        init(_ parent: MailComposerView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { [parent] in
                parent.onFinish?(result, error)
            }
        }
    }
}
