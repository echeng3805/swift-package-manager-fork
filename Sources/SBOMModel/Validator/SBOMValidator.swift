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
import struct TSCBasic.StringError
import TSCUtility

package func validateSBOM(from encoded: Foundation.Data, spec: SBOMSpec) async throws {
    guard let sbomJSONObject = try (JSONSerialization.jsonObject(with: encoded)) as? [String: Any] else {
        throw StringError("Could not convert generated SBOM file into JSON object for validation")
    }
    let schema = try SBOMSchema(from: getSchemaFilename(from: spec.type))
    try schema.validate(sbomJSONObject)
}

private func getSchemaFilename(from spec: Spec) -> String {
    switch spec {
    case .cyclonedx, .cyclonedx1:
        CDXConstants.cyclonedx1SchemaFile
    case .spdx, .spdx3:
        SPDXConstants.spdx3SchemaFile
    }
}
