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

    private func verifyDependencies(graph: ModulesGraph, store: ResolvedPackagesStore) async throws {
        let dependencies = try await #require(SBOMModel.extractDependencies(graph: graph, store: store).dependencies)
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
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        try await verifyDependencies(graph: graph, store: store)   
    }

    @Test("extractDependencies with sample Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        try await verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with product filter")
    func extractDependenciesWithProductFilter() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let productName = "SwiftPMDataModel"
        let dependencies = try await #require(SBOMModel.extractDependencies(graph: graph, store: store, product: productName).dependencies)
        let allDependencies = try await #require(SBOMModel.extractDependencies(graph: graph, store: store).dependencies)
        
        #expect(dependencies.count < allDependencies.count)
        
        // Should contain dependencies starting from the target product
        let dependencyParentIDs = Set(dependencies.map { $0.parentID })
        
        // The target product might not have dependencies, so let's check if it exists in the graph
        let rootPackage = try #require(graph.rootPackages.first)
        let targetProduct = try #require(rootPackage.products.first { $0.name == productName })
        
        // Check if the product has any module dependencies
        var hasModuleDependencies = false
        for module in targetProduct.modules {
            if !module.dependencies.isEmpty {
                hasModuleDependencies = true
                break
            }
        }
        
        if hasModuleDependencies {
            #expect(dependencyParentIDs.contains("SwiftPM:SwiftPMDataModel"))
        } else {
            // If the product has no dependencies, that's also valid
            print("Product \(productName) has no module dependencies")
        }
    }
}