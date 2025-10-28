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
    package let id: String
    package let parentID: String
    package let childrenID: [String]

    package init(
        id: String,
        parentID: String,
        childrenID: [String],
    ) {
        self.id = id
        self.parentID = parentID
        self.childrenID = childrenID
    }
}
