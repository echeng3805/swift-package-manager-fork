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

package struct SPDXExternalIdentifier: Codable, Equatable {
    package enum Category: String, Codable, Equatable {
        case gitoid
    }

    package let identifier: String
    package let identifierLocator: [String]
    package let type: SPDXType
    package let category: Category

    package init(
        identifier: String,
        identifierLocator: [String],
        type: SPDXType,
        category: Category
    ) {
        self.identifier = identifier
        self.identifierLocator = identifierLocator
        self.type = type
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case identifierLocator
        case type
        case category = "externalIdentifierType"
    }
}
