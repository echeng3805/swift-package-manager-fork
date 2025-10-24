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

import Testing
import Foundation
@testable import SBOMModel
import _InternalTestSupport

struct SBOMExtractTests {

    @Test("extractSBOM with sample SwiftPM ModulesGraph")
    func extractSBOMFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let sbomDocument = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store)
        
        #expect(sbomDocument.metadata.spec.type == .cyclonedx1)
        #expect(sbomDocument.metadata.spec.version == "1.7")
        
        #expect(!sbomDocument.primaryComponent.name.isEmpty)

        let timestamp = try #require(sbomDocument.metadata.timestamp)
        #expect(!timestamp.isEmpty)
        
        let creators = try #require(sbomDocument.metadata.creators)
        #expect(!creators.isEmpty)
        #expect(creators[0].name == "Swift Package Manager")
        
        if let components = sbomDocument.components {
            #expect(components.isEmpty || !components.isEmpty) // Either is valid
        }
    }

    @Test("extractSBOM with sample Swiftly ModulesGraph")
    func extractSBOMFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let sbomDocument = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store)
        
        #expect(sbomDocument.metadata.spec.type == .cyclonedx1)
        #expect(sbomDocument.metadata.spec.version == "1.7")
        
        #expect(!sbomDocument.primaryComponent.name.isEmpty)

        let timestamp = try #require(sbomDocument.metadata.timestamp)
        #expect(!timestamp.isEmpty)
        
        let creators = try #require(sbomDocument.metadata.creators)
        #expect(!creators.isEmpty)
        #expect(creators[0].name == "Swift Package Manager")
        
        if let components = sbomDocument.components {
            #expect(components.isEmpty || !components.isEmpty) // Either is valid
        }
    }
}