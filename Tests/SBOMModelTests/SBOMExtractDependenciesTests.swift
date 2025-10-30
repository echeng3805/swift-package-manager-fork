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

import _InternalTestSupport
import Foundation
import PackageGraph
@testable import SBOMModel
import Testing

struct SBOMExtractDependenciesTests {
    private func verifyDependencies(graph: ModulesGraph, store: ResolvedPackagesStore) async throws {
        let dependencies = try await #require(SBOMModel.extractDependencies(graph: graph, store: store).relationships)
        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = await extractComponentID(from: rootPackage)
        let packageIDs = graph.packages.map(\.identity.description)

        #expect(!dependencies.isEmpty)

        let parentIDs = dependencies.map(\.parentID)
        #expect(parentIDs.count == Set(parentIDs).count, "Parent IDs should be unique")

        for dependency in dependencies {
            #expect(!dependency.id.isEmpty, "Dependency ID should not be empty")
            #expect(!dependency.parentID.isEmpty, "Parent ID should not be empty")
            #expect(!dependency.childrenID.isEmpty, "Children ID should not be empty")

            #expect(!dependency.childrenID.contains(dependency.parentID), "parent should not depend on itself")

            if dependency.parentID == rootPackageID { // root comp
                #expect(!dependency.childrenID.contains(rootPackageID))
                for child in dependency.childrenID {
                    if child.contains(":") { // own product deps
                        #expect(child.hasPrefix(dependency.parentID))
                    } else { // other dependency packages
                        #expect(packageIDs.contains(child))
                    }
                }
            } else if packageIDs.contains(dependency.parentID) { // package comp, should have package-to-product deps
                for child in dependency.childrenID {
                    #expect(child.hasPrefix(dependency.parentID))
                }
            } else { // product comp, should have product-to-product deps
                for child in dependency.childrenID {
                    #expect(child.contains(":"), "child ID should be product")
                }
            }
        }
    }

    @Test("extractDependencies with sample SPM ModulesGraph")
    func extractDependenciesFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with sample Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with product filter SwiftPMPackageCollections")
    func extractDependenciesWithProductFilter() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMPackageCollections"
        let dependencies = try await #require(SBOMModel.extractDependencies(
            graph: graph,
            store: store,
            product: productName
        ).relationships)
        #expect(dependencies.count == 2)

        let swiftPMDependency = try #require(dependencies.first(where: { $0.parentID == "SwiftPM" }))
        #expect(Set(swiftPMDependency.childrenID) == Set([
            "SwiftPM:PackageCollectionsModel",
            "SwiftPM:SwiftPMPackageCollections",
        ]))
        let packageCollectionsDependency = try #require(dependencies
            .first(where: { $0.parentID == "SwiftPM:SwiftPMPackageCollections" }))
        #expect(packageCollectionsDependency.childrenID == ["SwiftPM:PackageCollectionsModel"])
    }
}
