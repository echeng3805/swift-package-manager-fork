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

package struct CDXAction: Codable, Equatable {
    package let timestamp: String?
    package let name: String?
    package let email: String?

    package init(
        timestamp: String? = nil,
        name: String? = nil,
        email: String? = nil
    ) {
        self.timestamp = timestamp
        self.name = name
        self.email = email
    }
}

package struct CDXCommit: Codable, Equatable {
    package let uid: String?
    package let url: String?
    package let author: CDXAction?
    package let message: String?

    package init(
        uid: String? = nil,
        url: String? = nil,
        author: CDXAction? = nil,
        message: String? = nil
    ) {
        self.uid = uid
        self.url = url
        self.author = author
        self.message = message
    }
}

package struct CDXPedigree: Codable, Equatable {
    package let commits: [CDXCommit]?

    package init(commits: [CDXCommit]? = nil) {
        self.commits = commits
    }
}
