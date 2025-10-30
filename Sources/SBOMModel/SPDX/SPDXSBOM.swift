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

package struct SPDXSBOM: Codable, Equatable {
    package let id: String
    package let type: SPDXType
    package let creationInfoID: String
    package let profileConformance: [String]
    package let rootElementIDs: [String]

    package init(
        id: String,
        type: SPDXType,
        creationInfoID: String,
        profileConformance: [String],
        rootElementIDs: [String]
    ) {
        self.id = id
        self.type = type
        self.creationInfoID = creationInfoID
        self.profileConformance = profileConformance
        self.rootElementIDs = rootElementIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id = "spdxId"
        case type
        case creationInfoID = "creationInfo"
        case profileConformance
        case rootElementIDs = "rootElement"
    }
}
