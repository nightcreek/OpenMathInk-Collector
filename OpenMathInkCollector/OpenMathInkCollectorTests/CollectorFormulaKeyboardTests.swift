import EMathicaFormulaKeyboardBuiltin
import EMathicaFormulaKeyboardCore
import EMathicaFormulaKeyboardSwiftUI
import EMathicaMathInputCore
import XCTest
@testable import OpenMathInkCollector

@MainActor
final class CollectorFormulaKeyboardCapabilityTests: XCTestCase {
    func testDatasetKeyboardExposesOnlyFourRequiredCategories() throws {
        let assembled = try FormulaKeyboardAssembler.assemble(
            profile: FormulaKeyboardBuiltinProfiles.scientificMath
        )
        let filtered = CollectorFormulaKeyboardCapabilityFilter.filter(assembled)
        let pageIDs = Set(filtered.pages.map(\.id.rawValue))

        XCTAssertEqual(
            pageIDs,
            CollectorFormulaKeyboardCapabilityFilter.datasetPageRawValues
        )
        XCTAssertFalse(pageIDs.contains("page.scientific.command"))
        XCTAssertFalse(pageIDs.contains("page.scientific.handwriting"))

        let selector = FormulaKeyboardDockSelector(
            pages: filtered.pages,
            state: FormulaKeyboardDockState(
                primaryPageID: filtered.defaultPageID,
                secondaryPageID: try FormulaKeyboardPageIdentifier(
                    rawValue: "page.scientific.functions"
                )
            ),
            moduleVisibility: .basic,
            onSelect: { _, _ in true }
        )

        XCTAssertEqual(selector.categories.count, 4)
        XCTAssertEqual(
            Set(selector.categories.map(\.id)),
            Set(["basic", "symbols", "functions", "variables"])
        )
    }

    func testEveryVisiblePreparedKeyHasAnExecutableAction() throws {
        let assembled = try FormulaKeyboardAssembler.assemble(
            profile: FormulaKeyboardBuiltinProfiles.scientificMath
        )
        let filtered = CollectorFormulaKeyboardCapabilityFilter.filter(assembled)
        let visibility = FormulaKeyboardModuleVisibility.basic

        let visibleKeys = filtered.pages
            .filter { visibility.allows(pageID: $0.id) }
            .flatMap(\.sections)
            .flatMap(\.rows)
            .flatMap(\.keys)

        XCTAssertFalse(visibleKeys.isEmpty)
        for key in visibleKeys {
            XCTAssertTrue(
                CollectorFormulaKeyboardCapabilityFilter.supports(key.action),
                "Visible key \(key.id.rawValue) has no executable Collector mapping"
            )
        }

        let visibleKeyIDs = Set(visibleKeys.map(\.id))
        for variant in filtered.layoutVariants {
            for pageLayout in variant.pageLayouts
                where visibility.allows(pageID: pageLayout.pageID) {
                for placement in pageLayout.placements {
                    XCTAssertTrue(
                        visibleKeyIDs.contains(placement.keyID),
                        "Placement \(placement.keyID.rawValue) survived without a visible key"
                    )
                }
            }
        }
    }

    func testUnsupportedStructuredSemanticsAreFiltered() throws {
        let assembled = try FormulaKeyboardAssembler.assemble(
            profile: FormulaKeyboardBuiltinProfiles.scientificMath
        )
        let filtered = CollectorFormulaKeyboardCapabilityFilter.filter(assembled)
        let semanticIDs = Set(
            filtered.pages
                .flatMap(\.sections)
                .flatMap(\.rows)
                .flatMap(\.keys)
                .map(\.builtinDefinition.semanticID)
        )

        XCTAssertFalse(semanticIDs.contains(BuiltinSemanticVocabulary.calculusDerivative))
        XCTAssertFalse(semanticIDs.contains(BuiltinSemanticVocabulary.matrixTranspose))
        XCTAssertFalse(semanticIDs.contains(BuiltinSemanticVocabulary.calculusDoubleIntegral))
    }

    func testEveryVisibleSemanticInsertionMutatesMathInputState() throws {
        let assembled = try FormulaKeyboardAssembler.assemble(
            profile: FormulaKeyboardBuiltinProfiles.scientificMath
        )
        let filtered = CollectorFormulaKeyboardCapabilityFilter.filter(assembled)
        let visibility = FormulaKeyboardModuleVisibility.basic
        let state = CollectorMathInputState()

        let semanticIDs = filtered.pages
            .filter { visibility.allows(pageID: $0.id) }
            .flatMap(\.sections)
            .flatMap(\.rows)
            .flatMap(\.keys)
            .compactMap { key -> FormulaKeyboardSemanticID? in
                guard case .editor(.semantic(let semanticID)) = key.action,
                      semanticID.category != .editor,
                      semanticID.category != .navigation else {
                    return nil
                }
                return semanticID
            }

        XCTAssertFalse(semanticIDs.isEmpty)
        for semanticID in semanticIDs {
            state.reset()
            let action = try XCTUnwrap(
                CollectorFormulaKeyboardActionMapper.action(for: semanticID),
                "Visible semantic \(semanticID.rawValue) has no MathInput action"
            )
            state.apply(action)
            XCTAssertTrue(
                !state.sourceText.isEmpty || !state.latex.isEmpty,
                "Visible semantic \(semanticID.rawValue) did not mutate MathInput state"
            )
        }
    }

    func testRequiredSemanticFamiliesMapToMathInputActions() {
        let cases: [(FormulaKeyboardSemanticID, KeyboardAction)] = [
            (BuiltinSemanticVocabulary.numberSeven, .insertCharacter("7")),
            (BuiltinSemanticVocabulary.operatorPlus, .insertOperator("+")),
            (BuiltinSemanticVocabulary.greekAlpha, .insertSymbol("\\alpha")),
            (BuiltinSemanticVocabulary.functionSin, .insertFunction("sin")),
            (BuiltinSemanticVocabulary.structureFraction, .insertTemplate(.fraction)),
            (BuiltinSemanticVocabulary.structureSquareRoot, .insertTemplate(.sqrt)),
            (BuiltinSemanticVocabulary.structureNthRoot, .insertTemplate(.nthRoot)),
            (BuiltinSemanticVocabulary.structureSuperscript, .insertTemplate(.superscript)),
            (BuiltinSemanticVocabulary.structureSubscript, .insertTemplate(.subscriptTemplate)),
            (BuiltinSemanticVocabulary.calculusIntegral, .insertTemplate(.integral)),
            (BuiltinSemanticVocabulary.calculusSummation, .insertTemplate(.sum)),
            (BuiltinSemanticVocabulary.structureMatrix, .insertTemplate(.matrix(rows: 2, cols: 2))),
            (BuiltinSemanticVocabulary.structurePiecewise, .insertTemplate(.piecewise(rows: 2)))
        ]

        for (semanticID, expected) in cases {
            XCTAssertEqual(
                CollectorFormulaKeyboardActionMapper.action(for: semanticID),
                expected,
                "Unexpected mapping for \(semanticID.rawValue)"
            )
        }
    }

    func testUppercaseAndUnknownSemanticHandling() throws {
        XCTAssertEqual(
            CollectorFormulaKeyboardActionMapper.action(
                for: BuiltinSemanticVocabulary.variableX,
                activeModifiers: [.uppercaseOnce]
            ),
            .insertCharacter("X")
        )
        XCTAssertEqual(
            CollectorFormulaKeyboardActionMapper.action(
                for: BuiltinSemanticVocabulary.greekOmega,
                activeModifiers: [.uppercaseLocked]
            ),
            .insertCharacter("Ω")
        )

        let unknown = try FormulaKeyboardSemanticID(
            namespace: "collector",
            category: .variable,
            name: "x"
        )
        XCTAssertNil(CollectorFormulaKeyboardActionMapper.action(for: unknown))
    }

    func testDeleteKeyRetainsSharedRepeatBehavior() throws {
        let assembled = try FormulaKeyboardAssembler.assemble(
            profile: FormulaKeyboardBuiltinProfiles.scientificMath
        )
        let deleteKey = assembled.pages
            .flatMap(\.sections)
            .flatMap(\.rows)
            .flatMap(\.keys)
            .first {
                $0.builtinDefinition.semanticID
                    == BuiltinSemanticVocabulary.editorDeleteBackward
            }

        guard let deleteKey else {
            return XCTFail("Shared delete key is missing")
        }
        guard case .repeatWhilePressed = deleteKey.behavior else {
            return XCTFail("Delete key no longer supports long-press repeat")
        }
    }
}

@MainActor
final class CollectorFormulaKeyboardDispatcherTests: XCTestCase {
    func testEditingClearUndoRedoAndReturnRouteThroughWorkspace() async throws {
        let (workspace, root) = try await makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }

        let prepared = CollectorFormulaKeyboardCapabilityFilter.filter(
            try FormulaKeyboardAssembler.assemble(
                profile: FormulaKeyboardBuiltinProfiles.scientificMath
            )
        )
        let dispatcher = CollectorFormulaKeyboardDispatcher(
            workspace: workspace,
            defaultPageID: prepared.defaultPageID
        )
        let state = FormulaKeyboardStateSnapshot(
            selectedPageID: prepared.defaultPageID
        )

        XCTAssertEqual(
            dispatcher.dispatch(
                .editor(.semantic(BuiltinSemanticVocabulary.numberOne)),
                state: state
            ).disposition,
            .performed
        )
        XCTAssertEqual(workspace.currentSourceText, "1")

        let clear = try FormulaKeyboardCustomAction(
            namespace: "builtin",
            name: "editor.clear"
        )
        XCTAssertEqual(
            dispatcher.dispatch(.custom(clear), state: state).disposition,
            .performed
        )
        XCTAssertTrue(workspace.currentSourceText.isEmpty)

        let undo = try FormulaKeyboardCustomAction(
            namespace: "builtin",
            name: "editor.undo"
        )
        XCTAssertEqual(
            dispatcher.dispatch(.custom(undo), state: state).disposition,
            .performed
        )
        XCTAssertEqual(workspace.currentSourceText, "1")

        let redo = try FormulaKeyboardCustomAction(
            namespace: "builtin",
            name: "editor.redo"
        )
        XCTAssertEqual(
            dispatcher.dispatch(.custom(redo), state: state).disposition,
            .performed
        )
        XCTAssertTrue(workspace.currentSourceText.isEmpty)

        XCTAssertEqual(
            dispatcher.dispatch(.editor(.editing(.submit)), state: state).disposition,
            .performed
        )
        XCTAssertEqual(workspace.infoMessage, "草稿已保存")
        XCTAssertEqual(workspace.selectedSample?.status, .draft)
    }

    func testPageSwitchAndUppercaseOneShotUpdateKeyboardState() async throws {
        let (workspace, root) = try await makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }

        let prepared = CollectorFormulaKeyboardCapabilityFilter.filter(
            try FormulaKeyboardAssembler.assemble(
                profile: FormulaKeyboardBuiltinProfiles.scientificMath
            )
        )
        let dispatcher = CollectorFormulaKeyboardDispatcher(
            workspace: workspace,
            defaultPageID: prepared.defaultPageID
        )
        let alternatePage = try XCTUnwrap(
            prepared.pages.first { $0.id != prepared.defaultPageID }?.id
        )
        let initial = FormulaKeyboardStateSnapshot(
            selectedPageID: prepared.defaultPageID
        )

        let pageResult = dispatcher.dispatch(
            .keyboard(.switchPage(alternatePage)),
            state: initial
        )
        XCTAssertEqual(pageResult.updatedStateSnapshot?.selectedPageID, alternatePage)

        let shiftResult = dispatcher.dispatch(
            .keyboard(.toggleModifier(.uppercase)),
            state: initial
        )
        let shifted = try XCTUnwrap(shiftResult.updatedStateSnapshot)
        XCTAssertTrue(shifted.activeModifiers.contains(.uppercaseOnce))

        let letterResult = dispatcher.dispatch(
            .editor(.semantic(BuiltinSemanticVocabulary.variableA)),
            state: shifted
        )
        XCTAssertEqual(workspace.currentSourceText, "A")
        XCTAssertFalse(
            try XCTUnwrap(letterResult.updatedStateSnapshot)
                .activeModifiers
                .contains(.uppercaseOnce)
        )
    }

    private func makeWorkspace() async throws -> (CollectorWorkspaceState, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = CollectorWorkspaceState(store: LocalSampleStore(baseURL: root))

        for _ in 0..<50 where workspace.selectedSampleID == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(workspace.selectedSampleID)
        return (workspace, root)
    }
}
