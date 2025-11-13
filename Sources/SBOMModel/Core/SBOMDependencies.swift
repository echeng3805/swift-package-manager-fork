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

package enum Entity: String, Codable, Equatable, CaseIterable {
    case all
    case product
    case package

    package var defaultValueDescription: String {
        switch self {
        case .all: "Include all entities in the SBOM"
        case .product: "Only include product information and product dependencies"
        case .package: "Only include package information and package dependencies"
        }
    }
}

package struct SBOMDependencies: Codable, Equatable {
    package let components: [SBOMComponent]
    package let relationships: [SBOMRelationship]?

    package init(
        components: [SBOMComponent],
        relationships: [SBOMRelationship]? = nil
    ) {
        self.components = components
        self.relationships = relationships
    }
}
