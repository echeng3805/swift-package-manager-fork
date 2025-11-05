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
    private func detectCycles(in dependencies: [SBOMRelationship]) -> [String] {
        // Build adjacency list
        var graph: [String: [String]] = [:]
        for dependency in dependencies {
            graph[dependency.parentID] = dependency.childrenID
        }
        
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var cycles: [String] = []
        
        func dfs(node: String, path: [String]) {
            if recursionStack.contains(node) {
                // Found a cycle - build the cycle path
                if let cycleStart = path.firstIndex(of: node) {
                    let cyclePath = (path[cycleStart...] + [node]).joined(separator: " -> ")
                    cycles.append(cyclePath)
                }
                return
            }
            if visited.contains(node) {
                return
            }
            visited.insert(node)
            recursionStack.insert(node)
            if let children = graph[node] {
                for child in children {
                    dfs(node: child, path: path + [node])
                }
            }
            recursionStack.remove(node)
        }
        for node in graph.keys {
            if !visited.contains(node) {
                dfs(node: node, path: [])
            }
        }
        return cycles
    }
    
    private func verifyProductDependencies(
        graph: ModulesGraph,
        store: ResolvedPackagesStore,
        product: String? = nil
    ) async throws {
        let dependencies = try await #require(SBOMModel.extractDependencies(
            graph: graph,
            store: store,
            product: product
        ).relationships)
        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = await extractComponentID(from: rootPackage)
        let packageIDs = graph.packages.map(\.identity.description)
        
        if product != nil {
            #expect(!dependencies.isEmpty, "Product SBOM should have dependencies")
        } else {
            #expect(!dependencies.isEmpty)
        }
        
        let parentIDs = dependencies.map(\.parentID)
        #expect(parentIDs.count == Set(parentIDs).count, "Parent IDs should be unique")

        let cycles = detectCycles(in: dependencies)
        #expect(cycles.isEmpty, "Dependency graph should not contain cycles. Found: \(cycles.joined(separator: "; "))")
        
        for dependency in dependencies {
            #expect(!dependency.id.isEmpty, "Dependency ID should not be empty")
            #expect(!dependency.parentID.isEmpty, "Parent ID should not be empty")
            #expect(!dependency.childrenID.isEmpty, "Children ID should not be empty")
            
            #expect(!dependency.childrenID.contains(dependency.parentID), "parent '\(dependency.parentID)' should not depend on itself")
            
            if product != nil {
                // Product-filtered validation
                if packageIDs.contains(dependency.parentID) { // package component
                    for child in dependency.childrenID {
                        if child.contains(":") { // package-to-product dep (own product)
                            #expect(child.hasPrefix(dependency.parentID), "Package '\(dependency.parentID)' product dependency '\(child)' should be its own product")
                        } else { // package-to-package dep
                            #expect(packageIDs.contains(child), "Package '\(dependency.parentID)' package dependency '\(child)' should be a valid package")
                        }
                    }
                } else {
                    // Products should only have product-to-product deps, not point back to packages
                    for child in dependency.childrenID {
                        #expect(child.contains(":"), "Product '\(dependency.parentID)' should only depend on other products, but found package dependency '\(child)'")
                    }
                }
            } else {
                // Full graph validation
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
    }
    
    private func verifyDependencies(graph: ModulesGraph, store: ResolvedPackagesStore) async throws {
        try await verifyProductDependencies(graph: graph, store: store, product: nil)
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
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with product filter SwiftPMDataModel")
    func extractDependenciesWithProductFilterSwiftPMDataModel() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMDataModel"
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with simple test graph")
    func extractDependenciesFromSimpleGraph() async throws {
        let graph = try SBOMTestGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
        let dependencies = try await #require(SBOMModel.extractDependencies(graph: graph, store: store).relationships)
        
        // Expected structure:
        // - MyApp package depends on Utils package and App product
        // - Utils package depends on Utils product
        // - App product depends on Utils product
        
        #expect(dependencies.count == 3, "Simple graph should have exactly 3 dependency relationships")
        
        // Find each dependency relationship
        let myAppPackageDep = try #require(dependencies.first { $0.parentID == "MyApp" })
        let utilsPackageDep = try #require(dependencies.first { $0.parentID == "Utils" })
        let appProductDep = try #require(dependencies.first { $0.parentID == "MyApp:App" })
        
        // Verify MyApp package dependencies
        #expect(myAppPackageDep.childrenID.count == 2, "MyApp package should have 2 dependencies")
        #expect(myAppPackageDep.childrenID.contains("Utils"), "MyApp should depend on Utils package")
        #expect(myAppPackageDep.childrenID.contains("MyApp:App"), "MyApp should depend on its own App product")
        
        // Verify Utils package dependencies
        #expect(utilsPackageDep.childrenID.count == 1, "Utils package should have 1 dependency")
        #expect(utilsPackageDep.childrenID.contains("Utils:Utils"), "Utils should depend on its own Utils product")
        
        // Verify App product dependencies
        #expect(appProductDep.childrenID.count == 1, "App product should have 1 dependency")
        #expect(appProductDep.childrenID.contains("Utils:Utils"), "App product should depend on Utils product")
    }
}
