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

import Basics
import Foundation
import TSCUtility

package func encodeSBOM(from sbom: SBOMDocument, outputPath: AbsolutePath?) async throws {
    let encoded = try await encodeSBOMData(from: sbom)
    if let outputPath {
        try localFileSystem.writeFileContents(outputPath, data: encoded)
    } else {
        print(String(decoding: encoded, as: UTF8.self))
    }
}

package func encodeSBOMData(from sbom: SBOMDocument) async throws -> Data {
    let data: any Encodable
    if sbom.metadata.spec.type.supportsCycloneDX {
        data = try await convertToCDXDocument(from: sbom)
    } else if sbom.metadata.spec.type.supportsSPDX {
        data = try await convertToSPDXGraph(from: sbom)
    } else {
        throw SBOMError.unexpectedSpecType(expected: "cyclonedx or spdx", actual: sbom.metadata.spec.type)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let encoded = try encoder.encode(data)

    try await validateSBOM(from: encoded, spec: sbom.metadata.spec)

    return encoded
}

package func validateSBOM(from encoded: Foundation.Data, spec: SBOMSpec) async throws {
    guard let sbomJSONObject = try (JSONSerialization.jsonObject(with: encoded)) as? [String: Any] else {
        throw SBOMEncoderError.jsonConversionFailed(message: "Could not convert generated SBOM file into JSON object for validation")
    }
    let schema = try SBOMSchema(from: try getSchemaFilename(from: spec.type))
    try schema.validate(json: sbomJSONObject, spec: spec)
}

private func getSchemaFilename(from spec: Spec) throws -> String {
    if spec.supportsCycloneDX {
        return CDXConstants.cyclonedx1SchemaFile
    } else if spec.supportsSPDX {
        return SPDXConstants.spdx3SchemaFile
    } else {
        throw SBOMError.unexpectedSpecType(expected: "cyclonedx or spdx", actual: spec)
    }
}