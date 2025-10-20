//
//  AppConfig.swift
//  FamilyMenuPlanner
//
//  Created by Ilia Khokhlov on 02.10.25.
//

import Foundation


enum AppConfig {
    static var amplitudeKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String ?? ""
    }
}
