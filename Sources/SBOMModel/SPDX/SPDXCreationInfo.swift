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

package struct SPDXCreationInfo: Codable, Equatable {
    package let id: String
    package let type: SPDXType
    package let specVersion: String?
    package let createdBy: [String]
    package let created: String

    package init(
        id: String,
        type: SPDXType,
        specVersion: String? = nil,
        createdBy: [String],
        created: String,
    ) {
        self.id = id
        self.type = type
        self.specVersion = specVersion
        self.createdBy = createdBy
        self.created = created
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case type
        case specVersion
        case createdBy
        case created
    }
}