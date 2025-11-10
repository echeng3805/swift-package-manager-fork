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

package struct SBOMRelationship: Codable, Equatable {
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
