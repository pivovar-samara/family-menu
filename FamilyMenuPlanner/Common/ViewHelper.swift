//
//  ViewHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.12.24.
//

import SwiftUI

// MARK: - UI Constants
/// Centralized UI constants for consistent spacing, sizing, and styling across the app
struct UIConstants {
    // MARK: - Spacing
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 16
    
    // MARK: - Corner Radius
    static let cardCornerRadius: CGFloat = 16
    static let chipCornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 12
    
    // MARK: - Chip Styling
    static let chipHorizontalPadding: CGFloat = 12
    static let chipVerticalPadding: CGFloat = 6
    
    // MARK: - Shadows & Borders
    static let cardShadowRadius: CGFloat = 8
    static let cardBorderWidth: CGFloat = 1
    static let buttonShadowRadius: CGFloat = 4
    
    // MARK: - Button Sizing
    static let buttonHorizontalPadding: CGFloat = 24
    static let buttonVerticalPadding: CGFloat = 14

    // MARK: - Layout
    static let maxContentWidth: CGFloat = 700
    static let minCardWidth: CGFloat = 320
}

// MARK: - Button State Style
/// Unified button state management for consistent styling across buttons and chips
enum ButtonStateStyle {
    case primary
    case secondary
    case chip
    case chipTint(Color)
    case warning
    case error
    case success
    case info
    
    /// Returns the appropriate colors for a button state
    /// - Parameters:
    ///   - isPressed: Whether the button is currently pressed
    ///   - isDisabled: Whether the button is disabled
    ///   - isSelected: Whether the button is selected
    /// - Returns: Tuple containing (background, foreground, border) colors
    func colors(isPressed: Bool = false, isDisabled: Bool = false, isSelected: Bool = false) -> (background: Color, foreground: Color, border: Color) {
        let state: ButtonState = {
            if isDisabled { return .disabled }
            if isSelected { return .selected }
            if isPressed { return .pressed }
            return .default
        }()
        
        switch self {
        case .primary:
            return primaryColors(for: state)
        case .secondary:
            return secondaryColors(for: state)
        case .chip:
            return chipColors(for: state)
        case .chipTint(let tint):
            return chipTintColors(for: state, tint: tint)
        case .warning:
            return warningColors(for: state)
        case .error:
            return errorColors(for: state)
        case .success:
            return successColors(for: state)
        case .info:
            return infoColors(for: state)
        }
    }
    
    private enum ButtonState {
        case `default`
        case pressed
        case disabled
        case selected
    }
    
    private func primaryColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        switch state {
        case .default:
            return (Color.ButtonState.primaryDefault, Color.ButtonState.textSelected, Color.ButtonState.borderSelected)
        case .pressed:
            return (Color.ButtonState.primaryPressed, Color.ButtonState.textSelected, Color.ButtonState.borderSelected)
        case .disabled:
            return (Color.ButtonState.primaryDisabled, Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (Color.ButtonState.primarySelected, Color.ButtonState.textSelected, Color.ButtonState.borderSelected)
        }
    }
    
    private func secondaryColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        switch state {
        case .default:
            return (Color.ButtonState.secondaryDefault, Color.accent, Color.ButtonState.borderDefault)
        case .pressed:
            return (Color.ButtonState.secondaryPressed, Color.accent, Color.ButtonState.borderPressed)
        case .disabled:
            return (Color.ButtonState.secondaryDisabled, Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (Color.ButtonState.secondarySelected, Color.accent, Color.ButtonState.borderSelected)
        }
    }
    
    private func chipColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        switch state {
        case .default:
            return (Color.ButtonState.chipDefault, Color.ButtonState.textDefault, Color.ButtonState.borderDefault)
        case .pressed:
            return (Color.ButtonState.chipPressed, Color.ButtonState.textPressed, Color.ButtonState.borderPressed)
        case .disabled:
            return (Color.ButtonState.chipDisabled, Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (Color.ButtonState.chipSelected, Color.ButtonState.textSelected, Color.ButtonState.borderSelected)
        }
    }
    
    private func chipTintColors(for state: ButtonState, tint: Color) -> (background: Color, foreground: Color, border: Color) {
        switch state {
        case .default:
            return (tint.opacity(0.12), tint, tint.opacity(0.2))
        case .pressed:
            return (tint.opacity(0.18), tint, tint.opacity(0.3))
        case .disabled:
            return (Color.gray.opacity(0.08), Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (tint, Color.white, Color.clear)
        }
    }
    
    private func warningColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        let baseColor = Color.appWarning
        switch state {
        case .default:
            return (baseColor, Color.white, Color.clear)
        case .pressed:
            return (baseColor.opacity(0.8), Color.white, Color.clear)
        case .disabled:
            return (Color.gray.opacity(0.1), Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (baseColor, Color.white, Color.clear)
        }
    }
    
    private func errorColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        let baseColor = Color.appError
        switch state {
        case .default:
            return (baseColor, Color.white, Color.clear)
        case .pressed:
            return (baseColor.opacity(0.8), Color.white, Color.clear)
        case .disabled:
            return (Color.gray.opacity(0.1), Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (baseColor, Color.white, Color.clear)
        }
    }
    
    private func successColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        let baseColor = Color.appSuccess
        switch state {
        case .default:
            return (baseColor, Color.white, Color.clear)
        case .pressed:
            return (baseColor.opacity(0.8), Color.white, Color.clear)
        case .disabled:
            return (Color.gray.opacity(0.1), Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (baseColor, Color.white, Color.clear)
        }
    }
    
    private func infoColors(for state: ButtonState) -> (background: Color, foreground: Color, border: Color) {
        let baseColor = Color.appInfo
        switch state {
        case .default:
            return (baseColor, Color.white, Color.clear)
        case .pressed:
            return (baseColor.opacity(0.8), Color.white, Color.clear)
        case .disabled:
            return (Color.gray.opacity(0.1), Color.ButtonState.textDisabled, Color.ButtonState.borderDisabled)
        case .selected:
            return (baseColor, Color.white, Color.clear)
        }
    }
}

// MARK: - Centering Helpers
extension View {
    /// Centers the view horizontally within its container and constrains its maximum width
    /// - Parameter width: The maximum content width to apply (default: UIConstants.maxContentWidth)
    /// - Returns: A horizontally centered view constrained to the specified width
    func centeredMaxWidth(_ width: CGFloat = UIConstants.maxContentWidth) -> some View {
        HStack {
            Spacer(minLength: 0)
            self.frame(maxWidth: width)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - UI Components

/// Modifier for consistent card styling across the app
struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = UIConstants.cardCornerRadius
    var background: Color = Color.appSecondaryBackground
    var shadowColor: Color = .black.opacity(0.06)
    var shadowRadius: CGFloat = UIConstants.cardShadowRadius
    var borderColor: Color = Color.appBorder
    var borderWidth: CGFloat = UIConstants.cardBorderWidth
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

extension View {
    /// Applies card styling to a view with customizable parameters
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the card (default: 16)
    ///   - background: Background color (default: Secondary background)
    ///   - shadowColor: Shadow color (default: black with 6% opacity)
    ///   - shadowRadius: Shadow radius (default: 8)
    ///   - borderColor: Border color (default: gray with 10% opacity)
    ///   - borderWidth: Border width (default: 1)
    ///   - padding: Internal padding (default: 0)
    /// - Returns: A view with card styling applied
    func appCardStyle(
        cornerRadius: CGFloat = UIConstants.cardCornerRadius,
        background: Color = Color.appSecondaryBackground,
        shadowColor: Color = .black.opacity(0.06),
        shadowRadius: CGFloat = UIConstants.cardShadowRadius,
        borderColor: Color = Color.appBorder,
        borderWidth: CGFloat = UIConstants.cardBorderWidth,
        padding: CGFloat = 0
    ) -> some View {
        self.modifier(AppCardModifier(
            cornerRadius: cornerRadius,
            background: background,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            borderColor: borderColor,
            borderWidth: borderWidth,
            padding: padding
        ))
    }
}

/// Reusable chip/tag component for displaying categories, units, and other metadata. Supports tinted chips via ButtonStateStyle.chipTint(_:). Accepts an optional tint parameter.
struct ChipView: View {
    // Content
    let text: String
    var icon: String? = nil

    // New unified styling API
    var buttonStateStyle: ButtonStateStyle = .chip
    var isEnabled: Bool = true
    var isSelected: Bool = false
    var tint: Color? = nil

    // Layout
    var font: Font = .caption.weight(.medium)
    var horizontalPadding: CGFloat = UIConstants.chipHorizontalPadding
    var verticalPadding: CGFloat = UIConstants.chipVerticalPadding
    var cornerRadius: CGFloat = UIConstants.chipCornerRadius
    var onTap: (() -> Void)? = nil

    // MARK: - Initializers
    /// Modern initializer using the unified ButtonStateStyle API
    init(
        text: String,
        icon: String? = nil,
        buttonStateStyle: ButtonStateStyle = .chip,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        tint: Color? = nil,
        font: Font = .caption.weight(.medium),
        horizontalPadding: CGFloat = UIConstants.chipHorizontalPadding,
        verticalPadding: CGFloat = UIConstants.chipVerticalPadding,
        cornerRadius: CGFloat = UIConstants.chipCornerRadius,
        onTap: (() -> Void)? = nil
    ) {
        // Content
        self.text = text
        self.icon = icon
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        // If a tint is provided and style is default chip, promote to chipTint
        if let tint {
            if case .chip = buttonStateStyle {
                self.buttonStateStyle = .chipTint(tint)
            } else {
                self.buttonStateStyle = buttonStateStyle
            }
        } else {
            self.buttonStateStyle = buttonStateStyle
        }
        // Layout
        self.font = font
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.cornerRadius = cornerRadius
        // Tint
        self.tint = tint
        // Action
        self.onTap = onTap
    }

    var body: some View {
        let colors = buttonStateStyle.colors(
            isPressed: false, // Chips don't have pressed state in this implementation
            isDisabled: !isEnabled,
            isSelected: isSelected
        )
        
        let bg = colors.background
        let fg = colors.foreground
        let border = colors.border
        
        let content = HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
                .lineLimit(1)
                .allowsTightening(false)
                .truncationMode(.tail)
        }
        .font(font)
        .foregroundColor(fg)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border, lineWidth: 1)
                )
        )
        .opacity(isEnabled ? 1.0 : 0.6)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))

        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    content
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!isEnabled)
            } else {
                content
            }
        }
    }
}

// MARK: - Button Styles

/// Primary button style for main actions
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let colors = ButtonStateStyle.primary.colors(
            isPressed: configuration.isPressed,
            isDisabled: false // Button styles don't have access to disabled state
        )
        
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(colors.foreground)
            .padding(.horizontal, UIConstants.buttonHorizontalPadding)
            .padding(.vertical, UIConstants.buttonVerticalPadding)
            .background(colors.background)
            .cornerRadius(UIConstants.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.buttonCornerRadius)
                    .stroke(colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: UIConstants.buttonShadowRadius)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style for alternative actions
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let colors = ButtonStateStyle.secondary.colors(
            isPressed: configuration.isPressed,
            isDisabled: false // Button styles don't have access to disabled state
        )
        
        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(colors.foreground)
            .padding(.horizontal, UIConstants.buttonHorizontalPadding)
            .padding(.vertical, UIConstants.buttonVerticalPadding)
            .background(colors.background)
            .cornerRadius(UIConstants.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.buttonCornerRadius)
                    .stroke(colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Scale button style for interactive elements that need press feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Utility Components

/// Empty state modifier for consistent empty state styling
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
        .listRowBackground(Color.appBackground)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - ViewHelper Class for Shared Utilities
/// Static utility class providing shared helper functions
/// Note: This class cannot be instantiated - use static methods only
class ViewHelper {
    private init() {} // Prevent instantiation - use static methods only

    /// Creates a toolbar button with consistent styling
    static func createToolbarButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: systemImage)
        }
        .foregroundColor(Color.accent)
        .tint(Color.accent)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    /// Applies empty state styling to a view
    static func emptyState<V: View>(_ view: V, message: String) -> some View {
        view.modifier(EmptyStateModifier(message: message))
    }

    /// Applies consistent list styling across the app
    static func applyStyle<V: View>(_ list: V) -> some View {
        list.listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }
}

// MARK: - Ingredient Validation Helpers
extension ViewHelper {
    /// Checks if an ingredient quantity seems unusually large based on its unit
    /// - Parameter ingredient: The ingredient to validate
    /// - Returns: True if the quantity is unusually large for the given unit
    static func hasUnusualQuantity(_ ingredient: IngredientDetail) -> Bool {
        return DataValidationHelper.hasUnusualQuantity(ingredient)
    }
    
    /// Formats ingredient quantity for display (removes decimal if whole number)
    /// - Parameter quantity: The quantity to format
    /// - Returns: A formatted string representation of the quantity
    static func formatQuantity(_ quantity: Double) -> String {
        return DataValidationHelper.formatQuantity(quantity)
    }
    
    /// Normalizes decimal separator in string for Double parsing
    /// Converts comma to period so both "1,5" and "1.5" can be parsed correctly
    /// - Parameter input: The input string to normalize
    /// - Returns: A normalized string with period as decimal separator
    static func normalizeDecimalString(_ input: String) -> String {
        return DataValidationHelper.normalizeDecimalString(input)
    }
}

// MARK: - Meal Type Styling Helpers (Legacy - Use StylingHelper instead)
extension ViewHelper {
    /// Returns the appropriate icon for a meal type
    /// - Parameter mealType: The meal type object
    /// - Returns: SF Symbol name for the meal type icon
    /// @deprecated Use StylingHelper.mealTypeIcon(for:) instead
    static func mealTypeIcon(for mealType: MealType) -> String {
        return StylingHelper.mealTypeIcon(for: mealType)
    }
    
    /// Returns the appropriate color for a meal type
    /// - Parameter mealType: The meal type object
    /// - Returns: Color for the meal type
    /// @deprecated Use StylingHelper.mealTypeColor(for:) instead
    static func mealTypeColor(for mealType: MealType) -> Color {
        return StylingHelper.mealTypeColor(for: mealType)
    }
    
    /// Returns the appropriate icon for a meal type string
    /// - Parameter mealTypeName: The meal type name string
    /// - Returns: SF Symbol name for the meal type icon
    /// @deprecated Use StylingHelper.mealTypeIcon(for:) instead
    static func mealTypeIcon(for mealTypeName: String) -> String {
        return StylingHelper.mealTypeIcon(for: mealTypeName)
    }
    
    /// Returns the appropriate color for a meal type string
    /// - Parameter mealTypeName: The meal type name string
    /// - Returns: Color for the meal type
    /// @deprecated Use StylingHelper.mealTypeColor(for:) instead
    static func mealTypeColor(for mealTypeName: String) -> Color {
        return StylingHelper.mealTypeColor(for: mealTypeName)
    }
}

extension View {
    /// Applies consistent list styling across the app as a view modifier
    func applyStyle() -> some View {
        self.listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }
}

// MARK: - Reusable View Modifiers

/// Reusable sorting toolbar modifier for list views
struct SortingToolbarModifier<SortOptionType: SortOption>: ViewModifier {
    @Binding var showingSortOptions: Bool
    let sortOptions: [SortOptionType]
    let onSortOptionSelected: (SortOptionType) -> Void
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let dialogTitle: String
    
    init(
        showingSortOptions: Binding<Bool>,
        sortOptions: [SortOptionType],
        onSortOptionSelected: @escaping (SortOptionType) -> Void,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        dialogTitle: String
    ) {
        self._showingSortOptions = showingSortOptions
        self.sortOptions = sortOptions
        self.onSortOptionSelected = onSortOptionSelected
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.dialogTitle = dialogTitle
    }
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSortOptions = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color.accent)
                }
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel)
                .confirmationDialog(dialogTitle, isPresented: $showingSortOptions, titleVisibility: .visible) {
                    ForEach(sortOptions, id: \.self) { option in
                        Button(option.displayName) {
                            onSortOptionSelected(option)
                        }
                        .accessibilityIdentifier(option.accessibilityIdentifier)
                    }
                    Button("Cancel".localized(), role: .cancel) {}
                        .accessibilityIdentifier("sort_cancel_button")
                }
            }
        }
    }
}

/// Reusable sheet modifier for adding new items
struct AddSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let content: () -> AnyView
    
    init<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.content = { AnyView(content()) }
    }
    
    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            isPresented = false
        }) {
            NavigationStack {
                self.content()
            }
        }
    }
}

/// Reusable sheet modifier for editing items
struct EditSheetModifier<Item: Identifiable>: ViewModifier {
    @Binding var selectedItem: Item?
    let onDismiss: () -> Void
    let content: (Item) -> AnyView
    
    init<Content: View>(
        selectedItem: Binding<Item?>,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._selectedItem = selectedItem
        self.onDismiss = onDismiss
        self.content = { item in AnyView(content(item)) }
    }
    
    func body(content: Content) -> some View {
        content.sheet(item: $selectedItem, onDismiss: onDismiss) { item in
            NavigationStack {
                self.content(item)
            }
        }
    }
}

/// Reusable alert modifier
struct AlertModifier: ViewModifier {
    @Binding var currentAlert: AlertItem?
    let onDismiss: () -> Void
    
    init(currentAlert: Binding<AlertItem?>, onDismiss: @escaping () -> Void) {
        self._currentAlert = currentAlert
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content.alert(item: $currentAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK".localized())) {
                    alert.action?()
                }
            )
        }
    }
}

// MARK: - Sort Option Protocol
protocol SortOption: CaseIterable, Hashable {
    var displayName: String { get }
    var accessibilityIdentifier: String { get }
}

// MARK: - Sort Option Extensions
extension SortOption {
    /// Default implementation for accessibility identifier
    var accessibilityIdentifier: String {
        return "sort_option_\(displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
}


// MARK: - Feedback Footer View

/// A reusable footer view to show at the bottom of lists/menus that opens the feedback form.
struct FeedbackFooterView: View {
    @State private var isPresenting = false

    var body: some View {
        VStack(spacing: UIConstants.sectionSpacing) {
            Button(action: { isPresenting = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                    Text("Have a feedback? Write us".localized())
                }
                .font(.footnote.weight(.semibold))
            }
            .buttonStyle(ScaleButtonStyle())
            .foregroundColor(Color.accent)
            .accessibilityIdentifier("feedback_footer_button")

            Text("We’d love to hear from you.".localized())
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, UIConstants.sectionSpacing)
        .listRowBackground(Color.appBackground)
        .listRowSeparator(.hidden)
        .background(Color.appBackground)
        .sheet(isPresented: $isPresenting) {
            NavigationStack {
                FeedbackFormView()
            }
        }
    }
}

extension ViewHelper {
    /// Returns a reusable feedback footer view that opens the in-app feedback form.
    static func feedbackFooterView() -> some View {
        FeedbackFooterView()
    }
}
