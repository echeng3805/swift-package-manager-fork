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

import Foundation
@testable import SBOMModel
import Testing
import struct TSCBasic.StringError

struct SBOMExtractSpecTests {
    struct ExtractSpecTestCase {
        let input: Spec
        let expectedType: Spec
        let expectedVersion: String
    }

    static let specTestCases: [ExtractSpecTestCase] = [
        ExtractSpecTestCase(
            input: .cyclonedx,
            expectedType: .cyclonedx1,
            expectedVersion: CDXConstants.cyclonedx1SpecVersion
        ),
        ExtractSpecTestCase(
            input: .cyclonedx1,
            expectedType: .cyclonedx1,
            expectedVersion: CDXConstants.cyclonedx1SpecVersion
        ),
        ExtractSpecTestCase(
            input: .spdx,
            expectedType: .spdx3,
            expectedVersion: SPDXConstants.spdx3SpecVersion
        ),
        ExtractSpecTestCase(
            input: .spdx3,
            expectedType: .spdx3,
            expectedVersion: SPDXConstants.spdx3SpecVersion
        ),
    ]

    @Test("extractSpec good weather", arguments: specTestCases)
    func extractSpecParameterized(testCase: ExtractSpecTestCase) async throws {
        let spec = try await SBOMModel.extractSpec(testCase.input)

        #expect(spec.type == testCase.expectedType)
        #expect(spec.version == testCase.expectedVersion)
    }
}
