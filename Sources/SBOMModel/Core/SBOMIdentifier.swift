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

import Foundation

package struct SBOMIdentifier: Codable, Equatable, Hashable {
    package let value: String

    package init(value: String) {
        self.value = value
    }

    package static func generate() -> SBOMIdentifier {
        SBOMIdentifier(value: "urn:uuid:\(UUID().uuidString.lowercased())")
    }
}
