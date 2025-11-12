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

package func getSpec(from spec: Spec) async -> SBOMSpec {
    let concreteSpec = spec.latestSpec
    return SBOMSpec(
        type: concreteSpec.type,
        version: concreteSpec.version
    )
}

package func getSpecs(from specs: [Spec]) async -> [SBOMSpec] {
    var result: Set<SBOMSpec> = Set<SBOMSpec>()
    for spec in specs {
        result.insert(await getSpec(from: spec))
    }
    return Array(result)
}

package func writeSBOMs(from sbom: SBOMDocument, specs: [Spec], outputDir: AbsolutePath) async throws {
    try localFileSystem.createDirectory(outputDir, recursive: true)
    let specs = await getSpecs(from: specs)
    for spec in specs {
        try await encodeSBOM(from: sbom, spec: spec, outputDir: outputDir)
    }
}


package func encodeSBOM(from sbom: SBOMDocument, spec: SBOMSpec, outputDir: AbsolutePath?) async throws {
    let encoded = try await encodeSBOMData(from: sbom, spec: spec)
    if let outputDir {
        let filename = "\(spec.type)-\(spec.version)-\(sbom.primaryComponent.name)-\(sbom.primaryComponent.version.revision).json"
        let outputPath = outputDir.appending(component: filename)
        try localFileSystem.writeFileContents(outputPath, data: encoded)
    }
}

package func encodeSBOMData(from sbom: SBOMDocument, spec: SBOMSpec) async throws -> Data {
    let data: any Encodable
    switch spec.type {
    case .cyclonedx, .cyclonedx1:
        data = try await convertToCycloneDXDocument(from: sbom, spec: spec)
    case .spdx, .spdx3:
        data = try await convertToSPDXGraph(from: sbom, spec: spec)
    // case .cyclonedx, .cyclonedx2:
    //     data = try await convertToCycloneDX2Document(from: sbom, spec: spec)
    // case .spdx, .spdx4:
    //     data = try await convertToSPDX4Graph(from: sbom, spec: spec)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let encoded = try encoder.encode(data)

    try await validateSBOM(from: encoded, spec: spec)

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
    switch spec {
    case .cyclonedx, .cyclonedx1:
        return CycloneDXConstants.cyclonedx1SchemaFile
    case .spdx, .spdx3:
        return SPDXConstants.spdx3SchemaFile
    // case .cyclonedx, .cyclonedx2:
    //     return CycloneDXConstants.cyclonedx2SchemaFile
    // case .spdx, .spdx4:
    //     return SPDXConstants.spdx4SchemaFile
    }
}