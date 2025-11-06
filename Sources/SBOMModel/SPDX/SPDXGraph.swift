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

package struct SPDXGraphElement: Encodable {
    private let value: any Encodable

    package init(_ value: some Encodable) {
        self.value = value
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    package func getValue<T>() -> T? {
        self.value as? T
    }
}

package struct SPDXGraph: Encodable {
    package let context: String
    package let graph: [SPDXGraphElement]

    package init(
        context: String,
        graph: [SPDXGraphElement]
    ) {
        self.context = context
        self.graph = graph
    }

    package init(
        context: String,
        graph: [any SPDXObject]
    ) {
        self.context = context
        self.graph = graph.map { SPDXGraphElement($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case context = "@context"
        case graph = "@graph"
    }
}
