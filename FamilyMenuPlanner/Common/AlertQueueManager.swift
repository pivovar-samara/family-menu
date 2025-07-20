//
//  AlertQueueManager.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import Foundation
import Combine

final class AlertQueueManager: ObservableObject {
    @Published var currentAlert: AlertItem? = nil
    private var alertQueue: [AlertItem] = []

    func enqueue(alert: AlertItem) {
        alertQueue.append(alert)
        showNextAlertIfNeeded()
    }

    private func showNextAlertIfNeeded() {
        guard currentAlert == nil, !alertQueue.isEmpty else { return }
        currentAlert = alertQueue.removeFirst()
    }

    func dismissCurrentAlert() {
        currentAlert = nil
        showNextAlertIfNeeded()
    }
}

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let action: (() -> Void)?
    
    // Note: The `action` closure is intentionally excluded from the equality check
    // because closures are reference types and do not conform to `Equatable`.
    // Equality is determined based on `title` and `message` to detect duplicate alerts.
    static func == (lhs: AlertItem, rhs: AlertItem) -> Bool {
        return lhs.title == rhs.title && lhs.message == rhs.message
    }
}

