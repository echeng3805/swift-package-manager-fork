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

package struct SBOMPerson: Codable, Equatable {
    package let id: String
    package let name: String
    package let email: String?

    package init(
        id: String,
        name: String,
        email: String?
    ) {
        self.id = id
        self.name = name
        self.email = email
    }
}
