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

package struct CDXComponent: Codable, Equatable {
    package enum Category: String, Codable, Equatable {
        case application
        case framework
        case library
        case file
    }

    package enum Scope: String, Codable, Equatable {
        case required
        case optional
        case excluded
    }

    package let type: Category
    package let bomRef: String
    package let name: String
    package let version: String
    package let scope: Scope
    package let purl: String
    package let components: [CDXComponent]?
    package let pedigree: CDXPedigree?

    package init(
        type: Category,
        bomRef: String,
        name: String,
        version: String,
        scope: Scope,
        purl: String,
        components: [CDXComponent]? = nil,
        pedigree: CDXPedigree? = nil
    ) {
        self.type = type
        self.bomRef = bomRef
        self.name = name
        self.version = version
        self.scope = scope
        self.purl = purl
        self.components = components
        self.pedigree = pedigree
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case bomRef = "bom-ref"
        case name
        case version
        case scope
        case purl
        case components
        case pedigree
    }
}
