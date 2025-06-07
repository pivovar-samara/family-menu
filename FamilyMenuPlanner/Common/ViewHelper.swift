//
//  ViewHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.12.24.
//

import SwiftUI

func createToolbarButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button {
        action()
    } label: {
        Label(title, systemImage: systemImage)
    }
    .foregroundColor(Color("AccentColor"))
}

struct EmptyStateModifier: ViewModifier {
    let message: String

    func body(content: Content) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            Spacer()
        }
        .listRowBackground(Color("BackgroundColor"))
        .background(Color("BackgroundColor").ignoresSafeArea())
    }
}

extension View {
    func emptyState(message: String) -> some View {
        self.modifier(EmptyStateModifier(message: message))
    }
    
    /// Prevents CoreGraphics NaN errors by validating frame dimensions
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeWidth = width?.isNaN == false && width?.isInfinite == false ? width : nil
        let safeHeight = height?.isNaN == false && height?.isInfinite == false ? height : nil
        
        return self.frame(
            width: safeWidth,
            height: safeHeight,
            alignment: alignment
        )
    }
}

extension List {
    func applyStyle() -> some View {
        return self
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundColor"))
    }
}
