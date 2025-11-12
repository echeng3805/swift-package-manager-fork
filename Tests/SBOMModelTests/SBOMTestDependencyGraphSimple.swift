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
@testable import SBOMModel

extension SBOMTestDependencyGraph {
    /// Creates a simple dependency graph for testing
    /// Structure:
    /// - MyApp (package) -> [Utils (package), MyApp:App (product)]
    /// - Utils (package) -> [Utils:Utils (product)]
    /// - MyApp:App (product) -> [Utils:Utils (product)]
    static func createSimpleDependencyGraph() -> [String: [String]] {
        [
            "MyApp": ["Utils", "MyApp:App"],
            "Utils": ["Utils:Utils"],
            "MyApp:App": ["Utils:Utils"],
            "Utils:Utils": []
        ]
    }
}