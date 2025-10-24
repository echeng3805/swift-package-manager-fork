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

package struct SPDXRelationship: Codable, Equatable {

    package enum Category: String, Codable, Equatable {
        case describes
        case dependsOn
        case hasOptionalDependency
        case hasTest
        case wasGeneratedFrom
    }

    package let id: String
    package let type: SPDXType
    package let category: Category
    package let creationInfoID: String
    package let parentID: String
    package let childrenID: [String]
    
    package init(
        id: String,
        type: SPDXType,
        category: Category,
        creationInfoID: String,
        parentID: String,
        childrenID: [String],
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.creationInfoID = creationInfoID
        self.parentID = parentID
        self.childrenID = childrenID
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "spdxId"
        case type
        case category = "relationshipType"
        case creationInfoID = "creationInfo"
        case parentID = "from"
        case childrenID = "to"
    }
}
