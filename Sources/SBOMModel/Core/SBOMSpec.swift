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

package enum Spec: String, Codable, Equatable, CaseIterable, Comparable {
    case cyclonedx
    case spdx
    case cyclonedx1
    case spdx3
    // case cyclonedx2, for future major versions of CycloneDX
    // case spdx4, for future major versions of SPDX

    package var defaultValueDescription: String {
        let (_, version) = self.latestSpec
        switch self {
        case .cyclonedx: return "Most recent major version of CycloneDX supported by SwiftPM (currently: \(version))"
        case .spdx: return "Most recent major version of SPDX supported by SwiftPM (currently: \(version))"
        case .cyclonedx1: return "Most recent minor version of CycloneDX v1 supported by SSwiftPMPM  (currently: \(version))"
        case .spdx3: return "Most recent minor version of SPDX v3 supported by SwiftPM (currently: \(version))"
        }
    }

    package static func < (lhs: Spec, rhs: Spec) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    package var supportsCycloneDX: Bool {
        switch self {
        case .cyclonedx, .cyclonedx1:
            true
        case .spdx, .spdx3:
            false
        }
    }

    package var supportsSPDX: Bool {
        switch self {
        case .spdx, .spdx3:
            true
        case .cyclonedx, .cyclonedx1:
            false
        }
    }

    /// Returns the concrete spec type and version for generic spec cases.
    /// For versioned cases (e.g., .cyclonedx1, .spdx3), returns self.
    /// For generic cases (e.g., .cyclonedx, .spdx), returns the latest supported version.
    package var latestSpec: (type: Spec, version: String) {
        switch self {
        case .cyclonedx:
            return (.cyclonedx1, CycloneDXConstants.cyclonedx1SpecVersion)
        case .spdx:
            return (.spdx3, SPDXConstants.spdx3SpecVersion)
        case .cyclonedx1:
            return (.cyclonedx1, CycloneDXConstants.cyclonedx1SpecVersion)
        case .spdx3:
            return (.spdx3, SPDXConstants.spdx3SpecVersion)
        // When adding new major versions (e.g., .cyclonedx2, .spdx4):
        // 1. Add the new case to the enum
        // 2. Update the .cyclonedx or .spdx case above to return the new version
        // 3. Add a case for the new version that returns itself
        }
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
