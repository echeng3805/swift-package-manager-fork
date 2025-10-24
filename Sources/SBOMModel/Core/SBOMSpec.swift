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

package enum Spec: String, Codable, Equatable, CaseIterable {
    case cyclonedx // most recent CycloneDX version
    case spdx // most recent SPDX version
    case cyclonedx1 // most recent version of CycloneDX v1 (v1.6)
    case spdx3 // most recent version of SPDX 3 (v3.0.1)
    // case cyclonedx2, for future major versions of CycloneDX
    // case spdx4, for future major versions of SPDX
}

package struct SBOMSpec: Codable, Equatable {
    package let type: Spec
    package let version: String

    package init(
        type: Spec,
        version: String,
    ) {
        self.type = type
        self.version = version
    }
}