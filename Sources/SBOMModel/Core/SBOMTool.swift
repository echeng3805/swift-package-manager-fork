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

package struct SBOMTool: Codable, Equatable {
    package let id: String
    package let name: String
    package let version: String
    package let licenses: [SBOMLicense]?

    package init(
        id: String,
        name: String,
        version: String,
        licenses: [SBOMLicense]? = nil,
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.licenses = licenses
    }
}
