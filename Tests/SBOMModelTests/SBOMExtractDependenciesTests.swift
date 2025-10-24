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
import PackageGraph
@testable import SBOMModel
import _InternalTestSupport

struct SBOMExtractDependenciesTests {

    private func verifyDependencies(graph: ModulesGraph) async throws {
        let dependencies = try await SBOMModel.extractDependencies(graph)
        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = await extractComponentID(from: rootPackage)
        let packageIDs = graph.packages.map { $0.identity.description }

        #expect(!dependencies.isEmpty)

        let parentIDs = dependencies.map { $0.parentID }
        #expect(parentIDs.count == Set(parentIDs).count, "Parent IDs should be unique")
        
        for dependency in dependencies {
            #expect(!dependency.id.isEmpty, "Dependency ID should not be empty")
            #expect(!dependency.parentID.isEmpty, "Parent ID should not be empty")
            #expect(!dependency.childrenID.isEmpty, "Children ID should not be empty")

            if dependency.parentID == rootPackageID { // root comp
                #expect(!dependency.childrenID.contains(rootPackageID))
                for child in dependency.childrenID {
                    if child.contains(":") { // own product deps
                        #expect(child.hasPrefix(dependency.parentID))
                    } else { // other dependency packages
                        #expect(packageIDs.contains(child))
                    }
                }
            }
            else if packageIDs.contains(dependency.parentID) { // package comp, should have package-to-product deps
                for child in dependency.childrenID {
                    #expect(child.hasPrefix(dependency.parentID))
                }
            }
            else {  // product comp, should have product-to-product deps
                for child in dependency.childrenID {
                    #expect(child.contains(":"), "child ID should be product")
                }
            }
        }
    }
    
    @Test("extractDependencies with sample SPM ModulesGraph")
    func extractDependenciesFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        try await verifyDependencies(graph: graph)   
    }

    @Test("extractDependencies with sample Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        try await verifyDependencies(graph: graph)
    }
}