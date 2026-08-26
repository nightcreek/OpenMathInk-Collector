import Combine
import EMathicaFormulaKeyboardBuiltin
import EMathicaFormulaKeyboardCore
import EMathicaFormulaKeyboardRendering
import EMathicaFormulaKeyboardSwiftUI
import EMathicaMathInputCore
import Foundation

enum CollectorFormulaKeyboardSessionError: LocalizedError {
    case assemblyFailed(String)

    var errorDescription: String? {
        switch self {
        case .assemblyFailed(let message):
            return "共享数学键盘组装失败：\(message)"
        }
    }
}

/// Collector-owned lifetime boundary for the shared scientific keyboard.
///
/// The session owns only prepared keyboard state and the dispatch bridge. Sample
/// storage, PencilKit objects and dataset state remain owned by
/// `CollectorWorkspaceState`.
@MainActor
final class CollectorFormulaKeyboardSession: ObservableObject {
    let preparedKeyboard: FormulaKeyboardPreparedKeyboardSnapshot?
    let viewModel: FormulaKeyboardViewModel?
    let errorDescription: String?

    private let dispatcher: CollectorFormulaKeyboardDispatcher?

    init(workspace: CollectorWorkspaceState) {
        do {
            let assembled = try FormulaKeyboardAssembler.assemble(
                profile: FormulaKeyboardBuiltinProfiles.scientificMath
            )
            let filtered = CollectorFormulaKeyboardCapabilityFilter.filter(assembled)
            let preparedContent = FormulaKeyboardPreparedContentAssembler.assemble(filtered)
            let dispatcher = CollectorFormulaKeyboardDispatcher(
                workspace: workspace,
                defaultPageID: filtered.defaultPageID
            )

            self.preparedKeyboard = filtered
            self.dispatcher = dispatcher
            self.viewModel = FormulaKeyboardViewModel(
                preparedContent: preparedContent,
                dispatcher: dispatcher,
                initialState: FormulaKeyboardRuntimeState(
                    selectedPageID: filtered.defaultPageID
                )
            )
            self.errorDescription = nil
        } catch {
            self.preparedKeyboard = nil
            self.dispatcher = nil
            self.viewModel = nil
            self.errorDescription = CollectorFormulaKeyboardSessionError
                .assemblyFailed(error.localizedDescription)
                .localizedDescription
        }
    }
}

/// Removes every key whose action cannot be executed by the Collector adapter.
///
/// Filtering the immutable prepared snapshot keeps the shared catalog as the
/// capability baseline while guaranteeing that no visible key is a no-op.
enum CollectorFormulaKeyboardCapabilityFilter {
    /// Four dataset-entry keyboards are exposed to the user. The Greek page
    /// is retained as the alternate-script backing page of the single letter
    /// keyboard, not as a fifth selector category.
    static let datasetPageRawValues: Set<String> = [
        "page.scientific.basic",
        "page.scientific.advanced",
        "page.scientific.functions",
        "page.scientific.abc",
        "page.scientific.greek"
    ]

    static func filter(
        _ keyboard: FormulaKeyboardPreparedKeyboardSnapshot
    ) -> FormulaKeyboardPreparedKeyboardSnapshot {
        let datasetPages = keyboard.pages.filter {
            datasetPageRawValues.contains($0.id.rawValue)
        }
        let supportedKeyIDs = Set(
            datasetPages.flatMap { page in
                page.sections.flatMap { section in
                    section.rows.flatMap { row in
                        row.keys
                            .filter { supports($0.action) }
                            .map(\.id)
                    }
                }
            }
        )

        let pages = datasetPages.map { page in
            FormulaKeyboardPreparedPage(
                id: page.id,
                title: page.title,
                sections: page.sections.map { section in
                    FormulaKeyboardPreparedSection(
                        id: section.id,
                        rows: section.rows.map { row in
                            FormulaKeyboardPreparedRow(
                                id: row.id,
                                keys: row.keys.filter { supportedKeyIDs.contains($0.id) }
                            )
                        }
                    )
                }
            )
        }

        let layoutVariants = keyboard.layoutVariants.map { variant in
            FormulaKeyboardPreparedLayoutVariant(
                id: variant.id,
                environment: variant.environment,
                pageLayouts: variant.pageLayouts
                    .filter { datasetPageRawValues.contains($0.pageID.rawValue) }
                    .map { pageLayout in
                    FormulaKeyboardPreparedPageLayout(
                        pageID: pageLayout.pageID,
                        grid: pageLayout.grid,
                        placements: pageLayout.placements.filter {
                            supportedKeyIDs.contains($0.keyID)
                        }
                    )
                }
            )
        }

        return FormulaKeyboardPreparedKeyboardSnapshot(
            keyboardID: keyboard.keyboardID,
            metadata: keyboard.metadata,
            defaultPageID: keyboard.defaultPageID,
            defaultLayoutVariantID: keyboard.defaultLayoutVariantID,
            pages: pages,
            layoutVariants: layoutVariants
        )
    }

    static func supports(_ action: FormulaKeyAction) -> Bool {
        switch action {
        case .editor(.semantic(let semanticID)):
            return CollectorFormulaKeyboardActionMapper.action(for: semanticID) != nil
        case .editor(.navigation(let intent)):
            return CollectorFormulaKeyboardActionMapper.action(for: intent) != nil
        case .editor(.editing(let intent)):
            switch intent {
            case .deleteBackward, .deleteForward, .submit:
                return true
            case .cancel:
                return false
            }
        case .keyboard(let keyboardAction):
            switch keyboardAction {
            case .switchPage, .returnToDefaultPage, .showAlternates, .toggleModifier:
                return true
            case .custom(let customIntent):
                return supports(.init(customIntent: customIntent))
            }
        case .system(.requestFeedback):
            return true
        case .system(.dismissKeyboard):
            return false
        case .custom(let customAction):
            return supports(customAction)
        }
    }

    static func supports(_ action: FormulaKeyboardCustomAction) -> Bool {
        action.namespace == BuiltinSemanticVocabulary.namespace
            && ["editor.clear", "editor.undo", "editor.redo"].contains(action.name)
    }
}

enum CollectorFormulaKeyboardActionMapper {
    private static let numberValues: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9"
    ]

    private static let greekLatex: [String: String] = [
        "alpha": "\\alpha", "beta": "\\beta", "gamma": "\\gamma",
        "delta": "\\delta", "epsilon": "\\epsilon", "zeta": "\\zeta",
        "eta": "\\eta", "theta": "\\theta", "iota": "\\iota",
        "kappa": "\\kappa", "lambda": "\\lambda", "mu": "\\mu",
        "nu": "\\nu", "xi": "\\xi", "omicron": "\\omicron",
        "pi": "\\pi", "rho": "\\rho", "sigma": "\\sigma",
        "lunateSigma": "\\varsigma", "tau": "\\tau", "upsilon": "\\upsilon",
        "phi": "\\phi", "chi": "\\chi", "psi": "\\psi", "omega": "\\omega"
    ]

    private static let uppercaseGreek: [String: String] = [
        "alpha": "Α", "beta": "Β", "gamma": "Γ", "delta": "Δ",
        "epsilon": "Ε", "zeta": "Ζ", "eta": "Η", "theta": "Θ",
        "iota": "Ι", "kappa": "Κ", "lambda": "Λ", "mu": "Μ",
        "nu": "Ν", "xi": "Ξ", "omicron": "Ο", "pi": "Π",
        "rho": "Ρ", "sigma": "Σ", "lunateSigma": "Σ", "tau": "Τ",
        "upsilon": "Υ", "phi": "Φ", "chi": "Χ", "psi": "Ψ", "omega": "Ω"
    ]

    static func action(
        for semanticID: FormulaKeyboardSemanticID,
        activeModifiers: Set<FormulaKeyboardModifier> = []
    ) -> KeyboardAction? {
        guard semanticID.namespace == BuiltinSemanticVocabulary.namespace else {
            return nil
        }

        let uppercase = activeModifiers.contains(.uppercase)
            || activeModifiers.contains(.uppercaseOnce)
            || activeModifiers.contains(.uppercaseLocked)

        switch semanticID.category {
        case .number:
            return numberValues[semanticID.name].map(KeyboardAction.insertCharacter)

        case .variable:
            guard semanticID.name.count == 1 else { return nil }
            let value = uppercase ? semanticID.name.uppercased() : semanticID.name
            return .insertCharacter(value)

        case .constant:
            switch semanticID.name {
            case "pi": return .insertSymbol("\\pi")
            case "e": return .insertCharacter(uppercase ? "E" : "e")
            case "infinity": return .insertSymbol("\\infty")
            case "imaginaryUnit": return .insertCharacter(uppercase ? "I" : "i")
            default: return nil
            }

        case .operator:
            switch semanticID.name {
            case "plus": return .insertOperator("+")
            case "minus": return .insertOperator("-")
            case "multiply": return .insertOperator("*")
            case "divide": return .insertOperator("/")
            case "power": return .insertOperator("^")
            case "factorial": return .insertOperator("!")
            default: return nil
            }

        case .relation:
            switch semanticID.name {
            case "equal": return .insertOperator("=")
            case "lessThan": return .insertOperator("<")
            case "greaterThan": return .insertOperator(">")
            case "lessOrEqual": return .insertSymbol("\\leq")
            case "greaterOrEqual": return .insertSymbol("\\geq")
            case "notEqual": return .insertSymbol("\\neq")
            case "approximatelyEqual": return .insertSymbol("\\approx")
            default: return nil
            }

        case .delimiter:
            switch semanticID.name {
            case "leftParenthesis": return .insertCharacter("(")
            case "rightParenthesis": return .insertCharacter(")")
            case "leftBracket": return .insertCharacter("[")
            case "rightBracket": return .insertCharacter("]")
            case "leftBrace": return .insertCharacter("{")
            case "rightBrace": return .insertCharacter("}")
            case "absoluteValueBar": return .insertCharacter("|")
            default: return nil
            }

        case .punctuation:
            switch semanticID.name {
            case "comma": return .insertCharacter(",")
            case "period": return .insertCharacter(".")
            case "colon": return .insertCharacter(":")
            case "semicolon": return .insertCharacter(";")
            case "space": return .insertCharacter(" ")
            default: return nil
            }

        case .greek:
            if uppercase, let value = uppercaseGreek[semanticID.name] {
                return .insertCharacter(value)
            }
            return greekLatex[semanticID.name].map(KeyboardAction.insertSymbol)

        case .symbol:
            switch semanticID.name {
            case "degree": return .insertSymbol("\\degree")
            case "plusMinus": return .insertSymbol("\\pm")
            case "emptySet": return .insertSymbol("\\varnothing")
            case "cdot": return .insertSymbol("\\cdot")
            case "notIn": return .insertSymbol("\\notin")
            default: return nil
            }

        case .function:
            let supported = [
                "sin", "cos", "tan", "log", "ln", "exp", "simplify",
                "expand", "factor", "solve", "zeros", "evaluate", "approximate"
            ]
            return supported.contains(semanticID.name)
                ? .insertFunction(semanticID.name)
                : nil

        case .structure:
            switch semanticID.name {
            case "fraction": return .insertTemplate(.fraction)
            case "squareRoot": return .insertTemplate(.sqrt)
            case "nthRoot": return .insertTemplate(.nthRoot)
            case "superscript": return .insertTemplate(.superscript)
            case "subscript": return .insertTemplate(.subscriptTemplate)
            case "matrix": return .insertTemplate(.matrix(rows: 2, cols: 2))
            case "piecewise": return .insertTemplate(.piecewise(rows: 2))
            default: return nil
            }

        case .calculus:
            switch semanticID.name {
            case "integral": return .insertTemplate(.integral)
            case "limit": return .insertTemplate(.limit)
            case "summation": return .insertTemplate(.sum)
            case "product": return .insertTemplate(.product)
            // MathInput has no exact structured double-integral or derivative action.
            case "doubleIntegral", "derivative": return nil
            default: return nil
            }

        case .matrix:
            switch semanticID.name {
            case "determinant": return .insertFunction("det")
            case "identity": return .insertCharacter("I")
            // Transpose cannot be represented accurately by the current editor action set.
            case "transpose": return nil
            default: return nil
            }

        case .logic:
            switch semanticID.name {
            case "and": return .insertSymbol("\\land")
            case "or": return .insertSymbol("\\lor")
            case "not": return .insertSymbol("\\lnot")
            case "implies": return .insertSymbol("\\Rightarrow")
            case "iff": return .insertSymbol("\\Leftrightarrow")
            default: return nil
            }

        case .set:
            switch semanticID.name {
            case "union": return .insertSymbol("\\cup")
            case "intersection": return .insertSymbol("\\cap")
            case "elementOf": return .insertSymbol("\\in")
            case "subset": return .insertSymbol("\\subset")
            default: return nil
            }

        case .statistics:
            switch semanticID.name {
            case "mean": return .insertFunction("mean")
            case "median": return .insertFunction("median")
            case "variance": return .insertFunction("var")
            case "standardDeviation": return .insertFunction("std")
            default: return nil
            }

        case .arrow:
            switch semanticID.name {
            case "left": return .insertSymbol("\\leftarrow")
            case "right": return .insertSymbol("\\rightarrow")
            case "leftRight": return .insertSymbol("\\leftrightarrow")
            case "mapsto": return .insertSymbol("\\mapsto")
            default: return nil
            }

        case .editor:
            switch semanticID.name {
            case "deleteBackward": return .deleteBackward
            case "submit": return .submit
            default: return nil
            }

        case .navigation:
            switch semanticID.name {
            case "left": return .moveLeft
            case "right": return .moveRight
            case "up": return .moveUp
            case "down": return .moveDown
            default: return nil
            }
        }
    }

    static func action(for intent: FormulaKeyboardNavigationIntent) -> KeyboardAction? {
        switch intent {
        case .moveLeft: return .moveLeft
        case .moveRight: return .moveRight
        case .moveUp: return .moveUp
        case .moveDown: return .moveDown
        case .tabForward: return .tab
        case .tabBackward: return .shiftTab
        case .moveToLineStart, .moveToLineEnd, .pageUp, .pageDown: return nil
        }
    }
}

final class CollectorFormulaKeyboardDispatcher: @unchecked Sendable, FormulaKeyboardDispatcher {
    private unowned let workspace: CollectorWorkspaceState
    private let defaultPageID: FormulaKeyboardPageIdentifier

    init(
        workspace: CollectorWorkspaceState,
        defaultPageID: FormulaKeyboardPageIdentifier
    ) {
        self.workspace = workspace
        self.defaultPageID = defaultPageID
    }

    nonisolated func dispatch(
        _ action: FormulaKeyAction,
        state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyActionResult {
        MainActor.assumeIsolated {
            dispatchOnMainActor(action, state: state)
        }
    }

    @MainActor
    private func dispatchOnMainActor(
        _ action: FormulaKeyAction,
        state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyActionResult {
        switch action {
        case .editor(let editorAction):
            guard state.isKeyboardEnabled else { return rejected(.keyboardDisabled) }
            return dispatchEditorAction(editorAction, state: state)
        case .keyboard(let keyboardAction):
            guard state.isKeyboardEnabled else { return rejected(.keyboardDisabled) }
            return dispatchKeyboardAction(keyboardAction, state: state)
        case .system(let systemAction):
            return dispatchSystemAction(systemAction)
        case .custom(let customAction):
            guard state.isKeyboardEnabled else { return rejected(.keyboardDisabled) }
            return dispatchCustomAction(customAction)
        }
    }

    @MainActor
    private func dispatchEditorAction(
        _ action: FormulaKeyEditorAction,
        state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyActionResult {
        switch action {
        case .semantic(let semanticID):
            guard let action = CollectorFormulaKeyboardActionMapper.action(
                for: semanticID,
                activeModifiers: state.activeModifiers
            ) else {
                return rejected(.unsupportedAction)
            }
            let result = perform(action)
            guard result.disposition == .performed,
                  state.activeModifiers.contains(.uppercaseOnce) else {
                return result
            }
            return keyboardStateChanged(removingUppercaseOnce(from: state))

        case .navigation(let intent):
            guard let action = CollectorFormulaKeyboardActionMapper.action(for: intent) else {
                return rejected(.unsupportedAction)
            }
            return perform(action)

        case .editing(let intent):
            switch intent {
            case .deleteBackward: return perform(.deleteBackward)
            case .deleteForward: return perform(.deleteForward)
            case .submit:
                workspace.saveCurrentDraft()
                return performed()
            case .cancel:
                return rejected(.unsupportedAction)
            }
        }
    }

    @MainActor
    private func dispatchKeyboardAction(
        _ action: FormulaKeyboardAction,
        state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyActionResult {
        switch action {
        case .switchPage(let pageID):
            guard state.selectedPageID != pageID
                    || state.activeAlternatePresentationID != nil else {
                return noChange()
            }
            return keyboardStateChanged(
                snapshot(
                    from: state,
                    selectedPageID: pageID,
                    alternateID: nil,
                    preservesAlternateID: false
                )
            )

        case .returnToDefaultPage:
            guard state.selectedPageID != defaultPageID
                    || state.activeAlternatePresentationID != nil else {
                return noChange()
            }
            return keyboardStateChanged(
                snapshot(
                    from: state,
                    selectedPageID: defaultPageID,
                    alternateID: nil,
                    preservesAlternateID: false
                )
            )

        case .showAlternates(let keyID):
            let alternateID = try! FormulaKeyboardIdentifier(rawValue: keyID.rawValue)
            guard state.activeAlternatePresentationID != alternateID else {
                return noChange()
            }
            return keyboardStateChanged(
                snapshot(
                    from: state,
                    alternateID: alternateID,
                    preservesAlternateID: false
                )
            )

        case .toggleModifier(let modifier):
            var modifiers = state.activeModifiers
            if modifier == .uppercase {
                if modifiers.contains(.uppercaseLocked) {
                    modifiers.remove(.uppercaseLocked)
                } else if modifiers.contains(.uppercaseOnce) {
                    modifiers.remove(.uppercaseOnce)
                    modifiers.insert(.uppercaseLocked)
                } else {
                    modifiers.insert(.uppercaseOnce)
                }
            } else if modifiers.contains(modifier) {
                modifiers.remove(modifier)
            } else {
                modifiers.insert(modifier)
            }
            return keyboardStateChanged(snapshot(from: state, modifiers: modifiers))

        case .custom(let intent):
            return dispatchCustomAction(.init(customIntent: intent))
        }
    }

    @MainActor
    private func dispatchCustomAction(
        _ action: FormulaKeyboardCustomAction
    ) -> FormulaKeyActionResult {
        guard CollectorFormulaKeyboardCapabilityFilter.supports(action) else {
            return rejected(.unsupportedAction)
        }
        switch action.name {
        case "editor.clear":
            return performWorkspaceMutation { workspace.clearFormulaInput() }
        case "editor.undo":
            return performWorkspaceMutation { workspace.undo() }
        case "editor.redo":
            return performWorkspaceMutation { workspace.redo() }
        default:
            return rejected(.unsupportedAction)
        }
    }

    private func dispatchSystemAction(
        _ action: FormulaKeyboardSystemAction
    ) -> FormulaKeyActionResult {
        switch action {
        case .dismissKeyboard:
            return rejected(.unsupportedAction)
        case .requestFeedback(let kind):
            return feedbackEmitted(kind)
        }
    }

    @MainActor
    private func perform(_ action: KeyboardAction) -> FormulaKeyActionResult {
        performWorkspaceMutation {
            workspace.applyKeyboardAction(action)
        }
    }

    @MainActor
    private func performWorkspaceMutation(
        _ mutation: () -> Void
    ) -> FormulaKeyActionResult {
        let before = CollectorFormulaKeyboardMutationDigest(workspace: workspace)
        mutation()
        let after = CollectorFormulaKeyboardMutationDigest(workspace: workspace)
        return before == after ? noChange() : performed()
    }

    private func snapshot(
        from state: FormulaKeyboardStateSnapshot,
        selectedPageID: FormulaKeyboardPageIdentifier? = nil,
        modifiers: Set<FormulaKeyboardModifier>? = nil,
        alternateID: FormulaKeyboardIdentifier? = nil,
        preservesAlternateID: Bool = true
    ) -> FormulaKeyboardStateSnapshot {
        FormulaKeyboardStateSnapshot(
            selectedPageID: selectedPageID ?? state.selectedPageID,
            activeModifiers: modifiers ?? state.activeModifiers,
            isKeyboardEnabled: state.isKeyboardEnabled,
            activeAlternatePresentationID: preservesAlternateID
                ? state.activeAlternatePresentationID
                : alternateID
        )
    }

    private func removingUppercaseOnce(
        from state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyboardStateSnapshot {
        var modifiers = state.activeModifiers
        modifiers.remove(.uppercaseOnce)
        return snapshot(from: state, modifiers: modifiers)
    }

    private func performed() -> FormulaKeyActionResult {
        try! FormulaKeyActionResult(disposition: .performed)
    }

    private func noChange() -> FormulaKeyActionResult {
        try! FormulaKeyActionResult(disposition: .noChange)
    }

    private func rejected(
        _ reason: FormulaKeyActionRejectionReason
    ) -> FormulaKeyActionResult {
        try! FormulaKeyActionResult(
            disposition: .rejected,
            rejectionReason: reason
        )
    }

    private func keyboardStateChanged(
        _ state: FormulaKeyboardStateSnapshot
    ) -> FormulaKeyActionResult {
        try! FormulaKeyActionResult(
            disposition: .keyboardStateChanged,
            updatedStateSnapshot: state
        )
    }

    private func feedbackEmitted(
        _ feedback: FormulaKeyboardFeedbackKind
    ) -> FormulaKeyActionResult {
        try! FormulaKeyActionResult(
            disposition: .feedbackEmitted,
            feedback: feedback
        )
    }
}

private struct CollectorFormulaKeyboardMutationDigest: Equatable {
    let latex: String
    let sourceText: String
    let computeExpression: String
    let canUndo: Bool
    let canRedo: Bool

    @MainActor
    init(workspace: CollectorWorkspaceState) {
        self.latex = workspace.currentLatex
        self.sourceText = workspace.currentSourceText
        self.computeExpression = workspace.currentComputeExpression
        self.canUndo = workspace.canUndo
        self.canRedo = workspace.canRedo
    }
}
