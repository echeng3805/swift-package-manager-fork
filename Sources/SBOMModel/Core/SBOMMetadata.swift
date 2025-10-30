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

package struct SBOMMetadata: Codable, Equatable {
    package let spec: SBOMSpec
    package let timestamp: String?
    package let creators: [SBOMTool]?

    package init(
        spec: SBOMSpec,
        timestamp: String?,
        creators: [SBOMTool]? = nil
    ) {
        self.spec = spec
        self.timestamp = timestamp
        self.creators = creators
    }
}
