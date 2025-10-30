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

import ArgumentParser

package enum Spec: String, Codable, Equatable, CaseIterable, ExpressibleByArgument, Comparable {
    case cyclonedx
    case spdx
    case cyclonedx1
    case spdx3
    // case cyclonedx2, for future major versions of CycloneDX
    // case spdx4, for future major versions of SPDX

    package var defaultValueDescription: String {
        switch self {
        case .cyclonedx: "Most recent major version of CycloneDX supported by SPM (currently: \(CDXConstants.cyclonedx1SpecVersion))"
        case .spdx: "Most recent major version of SPDX supported by SPM (currently: \(SPDXConstants.spdx3SpecVersion))"
        case .cyclonedx1: "Most recent minor version of CycloneDX v1 supported by SPM  (currently: \(CDXConstants.cyclonedx1SpecVersion))"
        case .spdx3: "Most recent minor version of SPDX v3 supported by SPM (currently: \(SPDXConstants.spdx3SpecVersion))"
        }
    }

    package static func < (lhs: Spec, rhs: Spec) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package struct SBOMSpec: Codable, Equatable {
    package let type: Spec
    package let version: String

    package init(
        type: Spec,
        version: String
    ) {
        self.type = type
        self.version = version
    }
}
