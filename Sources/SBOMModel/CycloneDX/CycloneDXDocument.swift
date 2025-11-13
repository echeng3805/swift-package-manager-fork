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

package struct CycloneDXDocument: Codable, Equatable {
    package let schema: String
    package let bomFormat: String
    package let specVersion: String
    package let serialNumber: String
    package let version: Int
    package let metadata: CycloneDXMetadata
    package let components: [CycloneDXComponent]?
    package let dependencies: [CycloneDXDependency]?

    package init(
        schema: String,
        bomFormat: String,
        specVersion: String,
        serialNumber: String,
        version: Int,
        metadata: CycloneDXMetadata,
        components: [CycloneDXComponent]? = nil,
        dependencies: [CycloneDXDependency]? = nil
    ) {
        self.schema = schema
        self.bomFormat = bomFormat
        self.specVersion = specVersion
        self.serialNumber = serialNumber
        self.version = version
        self.metadata = metadata
        self.components = components
        self.dependencies = dependencies
    }

    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case bomFormat
        case specVersion
        case serialNumber
        case version
        case metadata
        case components
        case dependencies
    }
}
