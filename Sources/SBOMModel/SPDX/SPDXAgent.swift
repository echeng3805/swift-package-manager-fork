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

package struct SPDXAgent: Codable, Equatable {
    package let id: String
    package let type: SPDXType
    package let name: String
    package let creationInfoID: String

    package init(
        id: String,
        type: SPDXType,
        name: String,
        creationInfoID: String
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.creationInfoID = creationInfoID
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "spdxId"
        case type
        case name
        case creationInfoID = "creationInfo"
    }
}
