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

package struct SBOMCommit: Hashable, Codable, Equatable {
    package let sha: String
    package let repository: String
    package let url: String?
    package let authors: [SBOMPerson]?
    package let message: String?

    package init(
        sha: String,
        repository: String,
        url: String? = nil, // url to the commit
        authors: [SBOMPerson]? = nil,
        message: String? = nil
    ) {
        self.sha = sha
        self.repository = repository
        self.url = url
        self.authors = authors
        self.message = message
    }
}
