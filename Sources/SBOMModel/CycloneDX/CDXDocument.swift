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

package struct CDXDocument: Codable, Equatable {
    package let schema: String
    package let bomFormat: String
    package let specVersion: String
    package let serialNumber: String
    package let version: Int
    package let metadata: CDXMetadata
    package let components: [CDXComponent]?
    package let dependencies: [CDXDependency]?

    package init(
        schema: String,
        bomFormat: String,
        specVersion: String,
        serialNumber: String,
        version: Int,
        metadata: CDXMetadata,
        components: [CDXComponent]? = nil,
        dependencies: [CDXDependency]? = nil
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
