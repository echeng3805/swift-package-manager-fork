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

package struct CycloneDXAction: Codable, Equatable {
    package let name: String?
    package let email: String?

    package init(
        name: String? = nil,
        email: String? = nil
    ) {
        self.name = name
        self.email = email
    }
}

package struct CycloneDXCommit: Codable, Equatable {
    package let uid: String?
    package let url: String?
    package let author: CycloneDXAction?
    package let message: String?

    package init(
        uid: String? = nil,
        url: String? = nil,
        author: CycloneDXAction? = nil,
        message: String? = nil
    ) {
        self.uid = uid
        self.url = url
        self.author = author
        self.message = message
    }
}

package struct CycloneDXPedigree: Codable, Equatable {
    package let commits: [CycloneDXCommit]?

    package init(commits: [CycloneDXCommit]? = nil) {
        self.commits = commits
    }
}