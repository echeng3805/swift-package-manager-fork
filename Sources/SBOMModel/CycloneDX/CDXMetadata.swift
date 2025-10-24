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

package struct CDXTools: Codable, Equatable {
    package let components: [CDXComponent]
    
    package init(components: [CDXComponent]) {
        self.components = components
    }
}

package struct CDXMetadata: Codable, Equatable {
    package let timestamp: String?
    package let component: CDXComponent
    package let tools: CDXTools?

    package init(
        timestamp: String?,
        component: CDXComponent,
        tools: CDXTools?
    ) {
        self.timestamp = timestamp
        self.component = component
        self.tools = tools
    }
}