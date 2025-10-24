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
    
    package init<T: Encodable>(_ value: T) {
        self.value = value
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    package func getValue<T>() -> T? {
        return value as? T
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
        graph: [Any]
    ) {
        self.context = context
        self.graph = graph.compactMap { element in
            if let encodableElement = element as? any Encodable {
                return SPDXGraphElement(encodableElement)
            }
            return nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case context = "@context"
        case graph = "@graph"
    }
}