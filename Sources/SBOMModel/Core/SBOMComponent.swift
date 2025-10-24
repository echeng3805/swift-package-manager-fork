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

package struct SBOMComponent: Codable, Equatable {
    package enum Category: String, Codable, Equatable {
        case application
        case framework
        case library
        case file
    }

    package enum Scope: String, Codable, Equatable {
        case runtime
        case optional
        case test
    }

    package let category: Category
    package let id: String
    package let purl: String
    package let name: String
    package let version: String
    package let originator: SBOMOriginator
    package let description: String?
    package let scope: Scope?
    package let components: [SBOMComponent]?
    package let licenses: [SBOMLicense]?
    
    package init(
        category: Category,
        id: String,
        purl: String,
        name: String,
        version: String,
        originator: SBOMOriginator,
        description: String? = nil,
        scope: Scope?,
        components: [SBOMComponent]? = nil,
        licenses: [SBOMLicense]? = nil,
    ) {
        self.category = category
        self.id = id
        self.purl = purl
        self.name = name
        self.version = version
        self.originator = originator
        self.description = description
        self.scope = scope
        self.components = components
        self.licenses = licenses
    }
}
