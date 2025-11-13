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

package struct SBOMRelationship: Codable, Equatable, Hashable {
    // package enum Source: String, Codable, Equatable {
    //     case modules // from ModulesGraph
    //     case build // from build dependency graph
    //     case all // appears in all graphs
    // }

    // package struct Metadata: Codable, Equatable {
    //     let source: Source

    //     package init(
    //         source: Source,
    //     ) {
    //         self.source = source
    //     }
    // }

    package let id: SBOMIdentifier
    package let parentID: SBOMIdentifier
    package let childrenID: [SBOMIdentifier]

    package init(
        id: SBOMIdentifier,
        parentID: SBOMIdentifier,
        childrenID: [SBOMIdentifier]
    ) {
        self.id = id
        self.parentID = parentID
        self.childrenID = childrenID
    }
}
