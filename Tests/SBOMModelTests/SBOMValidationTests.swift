//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing
import Foundation
import Basics
@testable import SBOMModel
import _InternalTestSupport
import PackageGraph

struct SBOMValidationTests {

    struct ValidateGraphSBOMTestCase: CustomStringConvertible {
        let graphName: String
        let inputSpec: Spec
        let inputGraph: ModulesGraph
        let inputStore: ResolvedPackagesStore
        let wantError: Bool
        
        var description: String { // don't print the graph because it's large
            return "ValidateGraphSBOMTestCase(graph: \(graphName), spec: \(inputSpec), wantError: \(wantError))"
        }
    }
    
    static func getValidateGraphSBOMTestCases() throws -> [ValidateGraphSBOMTestCase] {
        return [
            ValidateGraphSBOMTestCase(
                graphName: "SwiftPM",
                inputSpec: .cyclonedx,
                inputGraph: try SBOMTestGraph.createSPMModulesGraph(),
                inputStore: try SBOMTestStore.createSPMResolvedPackagesStore(),
                wantError: false,
            ),
            ValidateGraphSBOMTestCase(
                graphName: "SwiftPM",
                inputSpec: .spdx,
                inputGraph: try SBOMTestGraph.createSPMModulesGraph(),
                inputStore: try SBOMTestStore.createSPMResolvedPackagesStore(),
                wantError: false,
            ),
            ValidateGraphSBOMTestCase(
                graphName: "Swiftly",
                inputSpec: .cyclonedx,
                inputGraph: try SBOMTestGraph.createSwiftlyModulesGraph(),
                inputStore: try SBOMTestStore.createSwiftlyResolvedPackagesStore(),
                wantError: false,
            ),
            ValidateGraphSBOMTestCase(
                graphName: "Swiftly",
                inputSpec: .spdx,
                inputGraph: try SBOMTestGraph.createSwiftlyModulesGraph(),
                inputStore: try SBOMTestStore.createSwiftlyResolvedPackagesStore(),
                wantError: false,
            ),
        ]
    }

    @Test("validate SBOM from graphs", arguments: try getValidateGraphSBOMTestCases())
    func validateSBOMFromGraph(testCase: ValidateGraphSBOMTestCase) async throws {
        let document = try await SBOMModel.extractSBOM(spec: testCase.inputSpec, graph: testCase.inputGraph, store: testCase.inputStore)
        let encodedData = try await encodeSBOMData(from: document)

        if testCase.wantError {
            await #expect(throws: StringError.self) {
                try await validateSBOM(from: encodedData, spec: document.metadata.spec)
            }
        } else {
            try await validateSBOM(from: encodedData, spec: document.metadata.spec)
        }
    }

    struct ValidateFileSBOMTestCase {
        let inputFilePath: String
        let inputSBOMSpec: SBOMSpec
        let wantError: Bool
    }

    static func getValidateFileSBOMTestCases() throws -> [ValidateFileSBOMTestCase] {
        return [
            // valid CycloneDX SBOMs
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-cyclonedx-1.7-empty-comps",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: false,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-cyclonedx-1.7-minimal",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: false,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-cyclonedx-1.7-unicode",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: false,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-cyclonedx-1.7-spm",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: false,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-cyclonedx-1.7-versions",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: false,
            ),

            // valid SPDX SBOMs
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-spdx-3.0.1-spm",
                inputSBOMSpec: SBOMSpec(type: .spdx3, version: "3.0.1"),
                wantError: false,
            ),
            // valid SPDX SBOMs
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/valid-spdx-3.0.1-versions",
                inputSBOMSpec: SBOMSpec(type: .spdx3, version: "3.0.1"),
                wantError: false,
            ),
            
            // invalid CycloneDX SBOMs
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/invalid-cyclonedx-1-missing-fields",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: true,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/invalid-cyclonedx-1-small",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: CDXConstants.cyclonedx1SpecVersion),
                wantError: true,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/invalid-cyclonedx-1.7-uppercase-uuid",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: "1.7"),
                wantError: true,
            ),
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/invalid-cyclonedx-1.7-wrong-bomformat",
                inputSBOMSpec: SBOMSpec(type: .cyclonedx1, version: "1.7"),
                wantError: true,
            ),

            // invalid SPDX SBOMs
            ValidateFileSBOMTestCase(
                inputFilePath: "testfiles/invalid-spdx-3-small",
                inputSBOMSpec: SBOMSpec(type: .spdx3, version: SPDXConstants.spdx3SpecVersion),
                wantError: true,
            ),
        ]
    }

    @Test("validate SBOM from files", arguments: try getValidateFileSBOMTestCases())
    func validateSBOMFromFile(testCase: ValidateFileSBOMTestCase) async throws {
       let testBundle = Bundle.module
        guard let fileURL = testBundle.url(forResource: testCase.inputFilePath, withExtension: "json") else {
            throw StringError("Could not find \(testCase.inputFilePath).json test file")
        }
        let encodedData = try Data(contentsOf: fileURL)

        if testCase.wantError {
            await #expect(throws: (any Error).self) {
                try await validateSBOM(from: encodedData, spec: testCase.inputSBOMSpec)
            }
        } else {
            try await validateSBOM(from: encodedData, spec: testCase.inputSBOMSpec)
        }
    }
}