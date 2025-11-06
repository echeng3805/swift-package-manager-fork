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

package struct CycloneDXTools: Codable, Equatable {
    package let components: [CycloneDXComponent]

    package init(components: [CycloneDXComponent]) {
        self.components = components
    }
}

package struct CycloneDXMetadata: Codable, Equatable {
    package let timestamp: String?
    package let component: CycloneDXComponent
    package let tools: CycloneDXTools?

    package init(
        timestamp: String?,
        component: CycloneDXComponent,
        tools: CycloneDXTools?
    ) {
        self.timestamp = timestamp
        self.component = component
        self.tools = tools
    }
}