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

struct SBOMExtractMetadataTests {
    struct ExtractMetadataTestCase {
        let input: Spec
        let expectedSpecType: Spec
        let expectedSpecVersion: String
    }

    static let metadataTestCases: [ExtractMetadataTestCase] = [
        ExtractMetadataTestCase(
            input: .cyclonedx,
            expectedSpecType: .cyclonedx1,
            expectedSpecVersion: CycloneDXConstants.cyclonedx1SpecVersion
        ),
        ExtractMetadataTestCase(
            input: .cyclonedx1,
            expectedSpecType: .cyclonedx1,
            expectedSpecVersion: CycloneDXConstants.cyclonedx1SpecVersion
        ),
        ExtractMetadataTestCase(
            input: .spdx,
            expectedSpecType: .spdx3,
            expectedSpecVersion: SPDXConstants.spdx3SpecVersion
        ),
        ExtractMetadataTestCase(
            input: .spdx3,
            expectedSpecType: .spdx3,
            expectedSpecVersion: SPDXConstants.spdx3SpecVersion
        ),
    ]

    @Test("extractMetadata good weather", arguments: metadataTestCases)
    func extractMetadataParameterized(testCase: ExtractMetadataTestCase) async throws {
        let metadata = try await SBOMModel.extractMetadata(testCase.input)

        #expect(metadata.spec.type == testCase.expectedSpecType)
        #expect(metadata.spec.version == testCase.expectedSpecVersion)

        let timestamp = try #require(metadata.timestamp)
        #expect(!timestamp.isEmpty)

        let formatter = ISO8601DateFormatter()
        _ = try #require(formatter.date(from: timestamp))

        let creators = try #require(metadata.creators)
        #expect(creators.count == 1)
        let creator = creators[0]
        #expect(!creator.id.value.isEmpty)
        #expect(creator.name == "swift-package-manager")
        #expect(!creator.version.isEmpty)

        let licenses = try #require(creator.licenses)
        #expect(licenses.count == 1)
        let license = licenses[0]
        #expect(license.name == "Apache-2.0")
        #expect(license.url == "http://swift.org/LICENSE.txt")
    }
}
