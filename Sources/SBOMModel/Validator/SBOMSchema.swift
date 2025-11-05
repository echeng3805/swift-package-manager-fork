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

package struct SBOMSchema {
    private let schema: [String: Any]

    package init(from schemaFilename: String) throws {
        guard let schemaURL = Bundle.module.url(forResource: schemaFilename, withExtension: "json") else {
            throw SBOMSchemaError.schemaFileNotFound(
                filename: schemaFilename,
                bundlePath: Bundle.module.bundlePath
            )
        }
        let schemaData = try Data(contentsOf: schemaURL)
        guard let jsonObject = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw SBOMSchemaError.invalidSchemaFormat(message: "Could not parse schema as JSON dictionary")
        }
        self.schema = jsonObject
    }

    package func validate(json jsonObject: Any, spec: SBOMSpec) throws {
        let validator = try createValidator(for: spec)
        try validator.validate(jsonObject)
    }
    
    private func createValidator(for spec: SBOMSpec) throws -> any SBOMValidatorProtocol {
        if spec.type.supportsSPDX {
            return SPDXValidator(schema: schema)
        } else if spec.type.supportsCycloneDX {
            return CDXValidator(schema: schema)
        } else {
            throw SBOMError.unexpectedSpecType(expected: "cyclonedx or spdx", actual: spec.type)
        }
    }
}
