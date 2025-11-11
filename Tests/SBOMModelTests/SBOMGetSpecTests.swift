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

struct SBOMGetSpecTests {
    struct GetSpecTestCase {
        let input: Spec
        let expectedType: Spec
        let expectedVersion: String
    }

    static let specTestCases: [GetSpecTestCase] = [
        GetSpecTestCase(
            input: .cyclonedx,
            expectedType: .cyclonedx1,
            expectedVersion: CycloneDXConstants.cyclonedx1SpecVersion
        ),
        GetSpecTestCase(
            input: .cyclonedx1,
            expectedType: .cyclonedx1,
            expectedVersion: CycloneDXConstants.cyclonedx1SpecVersion
        ),
        GetSpecTestCase(
            input: .spdx,
            expectedType: .spdx3,
            expectedVersion: SPDXConstants.spdx3SpecVersion
        ),
        GetSpecTestCase(
            input: .spdx3,
            expectedType: .spdx3,
            expectedVersion: SPDXConstants.spdx3SpecVersion
        ),
    ]

    @Test("getSpec good weather", arguments: specTestCases)
    func getSpecParameterized(testCase: GetSpecTestCase) async throws {
        let spec = try await SBOMModel.getSpec(from: testCase.input)

        #expect(spec.type == testCase.expectedType)
        #expect(spec.version == testCase.expectedVersion)
    }
}
