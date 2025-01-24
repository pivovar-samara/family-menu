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

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: (() -> Void)?
}

