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
            graph[dependency.parentID.value] = dependency.childrenID.map(\.value)
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
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)
        let dependencies = try await #require(extractor.extractDependencies(product: product).relationships)
        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = SBOMExtractor.extractComponentID(from: rootPackage).value
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
            #expect(!dependency.id.value.isEmpty, "Dependency ID should not be empty")
            #expect(!dependency.parentID.value.isEmpty, "Parent ID should not be empty")
            #expect(!dependency.childrenID.isEmpty, "Children ID should not be empty")
            
            #expect(!dependency.childrenID.map(\.value).contains(dependency.parentID.value), "parent '\(dependency.parentID.value)' should not depend on itself")
            
            if product != nil {
                // Product-filtered validation
                if packageIDs.contains(dependency.parentID.value) { // package component
                    for child in dependency.childrenID {
                        if child.value.contains(":") { // package-to-product dep (own product)
                            #expect(child.value.hasPrefix(dependency.parentID.value), "Package '\(dependency.parentID.value)' product dependency '\(child.value)' should be its own product")
                        } else { // package-to-package dep
                            #expect(packageIDs.contains(child.value), "Package '\(dependency.parentID.value)' package dependency '\(child.value)' should be a valid package")
                        }
                    }
                } else {
                    // Products should only have product-to-product deps, not point back to packages
                    for child in dependency.childrenID {
                        #expect(child.value.contains(":"), "Product '\(dependency.parentID.value)' should only depend on other products, but found package dependency '\(child.value)'")
                    }
                }
            } else {
                // Full graph validation
                if dependency.parentID.value == rootPackageID { // root comp
                    #expect(!dependency.childrenID.map(\.value).contains(rootPackageID))
                    for child in dependency.childrenID {
                        if child.value.contains(":") { // own product deps
                            #expect(child.value.hasPrefix(dependency.parentID.value))
                        } else { // other dependency packages
                            #expect(packageIDs.contains(child.value))
                        }
                    }
                } else if packageIDs.contains(dependency.parentID.value) { // package comp, can have package-to-product or package-to-package deps
                    for child in dependency.childrenID {
                        if child.value.contains(":") { // own product deps
                            #expect(child.value.hasPrefix(dependency.parentID.value), "Package '\(dependency.parentID.value)' product dependency '\(child.value)' should be its own product")
                        } else { // other dependency packages
                            #expect(packageIDs.contains(child.value), "Package '\(dependency.parentID.value)' package dependency '\(child.value)' should be a valid package")
                        }
                    }
                } else { // product comp, should have product-to-product deps
                    for child in dependency.childrenID {
                        #expect(child.value.contains(":"), "child ID should be product")
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
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with sample Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with product filter SwiftPMPackageCollections")
    func extractDependenciesWithProductFilter() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMPackageCollections"
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with product filter SwiftPMDataModel")
    func extractDependenciesWithProductFilterSwiftPMDataModel() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMDataModel"
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with simple test graph")
    func extractDependenciesFromSimpleGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)
        let dependencies = try await #require(extractor.extractDependencies().relationships)
        
        #expect(dependencies.count == 3, "Simple graph should have exactly 3 dependency relationships")
        
        let myAppPackageDep = try #require(dependencies.first { $0.parentID.value == "MyApp" })
        let utilsPackageDep = try #require(dependencies.first { $0.parentID.value == "Utils" })
        let appProductDep = try #require(dependencies.first { $0.parentID.value == "MyApp:App" })
        
        // Verify MyApp package dependencies
        #expect(myAppPackageDep.childrenID.count == 2, "MyApp package should have 2 dependencies")
        #expect(myAppPackageDep.childrenID.map(\.value).contains("Utils"), "MyApp should depend on Utils package")
        #expect(myAppPackageDep.childrenID.map(\.value).contains("MyApp:App"), "MyApp should depend on its own App product")
        
        // Verify Utils package dependencies
        #expect(utilsPackageDep.childrenID.count == 1, "Utils package should have 1 dependency")
        #expect(utilsPackageDep.childrenID.map(\.value).contains("Utils:Utils"), "Utils should depend on its own Utils product")
        
        // Verify App product dependencies
        #expect(appProductDep.childrenID.count == 1, "App product should have 1 dependency")
        #expect(appProductDep.childrenID.map(\.value).contains("Utils:Utils"), "App product should depend on Utils product")
    }
    
    // MARK: - Name Mapping Tests
    
    @Test("getTargetName(fromProduct:) converts product names correctly")
    func testGetTargetNameFromProduct() {
        // Test with various product names from Swiftly graph
        #expect(SBOMExtractor.getTargetName(fromProduct: "swiftly") == "swiftly-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "test-swiftly") == "test-swiftly-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "ArgumentParser") == "ArgumentParser-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "AsyncHTTPClient") == "AsyncHTTPClient-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "OpenAPIRuntime") == "OpenAPIRuntime-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "SystemPackage") == "SystemPackage-product")

        #expect(SBOMExtractor.getTargetName(fromProduct: "") == "-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "A") == "A-product")
        #expect(SBOMExtractor.getTargetName(fromProduct: "product") == "product-product")
    }
    
    @Test("getProductName(fromTarget:) converts target names correctly")
    func testGetProductNameFromTarget() {
        #expect(SBOMExtractor.getProductName(fromTarget: "swiftly-product") == "swiftly")
        #expect(SBOMExtractor.getProductName(fromTarget: "test-swiftly-product") == "test-swiftly")
        #expect(SBOMExtractor.getProductName(fromTarget: "ArgumentParser-product") == "ArgumentParser")
        #expect(SBOMExtractor.getProductName(fromTarget: "AsyncHTTPClient-product") == "AsyncHTTPClient")
        #expect(SBOMExtractor.getProductName(fromTarget: "OpenAPIRuntime-product") == "OpenAPIRuntime")
        #expect(SBOMExtractor.getProductName(fromTarget: "SystemPackage-product") == "SystemPackage")
        
        #expect(SBOMExtractor.getProductName(fromTarget: "Swiftly") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "TestSwiftly") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "ArgumentParser") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "SwiftlyCore") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "MacOSPlatform") == nil)
        
        #expect(SBOMExtractor.getProductName(fromTarget: "-product") == "")
        #expect(SBOMExtractor.getProductName(fromTarget: "") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "product") == nil)
        #expect(SBOMExtractor.getProductName(fromTarget: "my-product-product") == "my-product")
    }
    
    @Test("getTargetName(fromModule:) preserves module names")
    func testGetTargetNameFromModule() {
        #expect(SBOMExtractor.getTargetName(fromModule: "Swiftly") == "Swiftly")
        #expect(SBOMExtractor.getTargetName(fromModule: "TestSwiftly") == "TestSwiftly")
        #expect(SBOMExtractor.getTargetName(fromModule: "ArgumentParser") == "ArgumentParser")
        #expect(SBOMExtractor.getTargetName(fromModule: "SwiftlyCore") == "SwiftlyCore")
        #expect(SBOMExtractor.getTargetName(fromModule: "MacOSPlatform") == "MacOSPlatform")
        #expect(SBOMExtractor.getTargetName(fromModule: "LinuxPlatform") == "LinuxPlatform")
        #expect(SBOMExtractor.getTargetName(fromModule: "SwiftlyWebsiteAPI") == "SwiftlyWebsiteAPI")
        #expect(SBOMExtractor.getTargetName(fromModule: "SwiftlyDownloadAPI") == "SwiftlyDownloadAPI")
        #expect(SBOMExtractor.getTargetName(fromModule: "AsyncHTTPClient") == "AsyncHTTPClient")
        #expect(SBOMExtractor.getTargetName(fromModule: "OpenAPIRuntime") == "OpenAPIRuntime")
        
        #expect(SBOMExtractor.getTargetName(fromModule: "") == "")
        #expect(SBOMExtractor.getTargetName(fromModule: "A") == "A")
        #expect(SBOMExtractor.getTargetName(fromModule: "module-with-dashes") == "module-with-dashes")
    }
    
    @Test("getModuleName(fromTarget:) converts target names correctly")
    func testGetModuleNameFromTarget() {
        #expect(SBOMExtractor.getModuleName(fromTarget: "Swiftly") == "Swiftly")
        #expect(SBOMExtractor.getModuleName(fromTarget: "TestSwiftly") == "TestSwiftly")
        #expect(SBOMExtractor.getModuleName(fromTarget: "ArgumentParser") == "ArgumentParser")
        #expect(SBOMExtractor.getModuleName(fromTarget: "SwiftlyCore") == "SwiftlyCore")
        #expect(SBOMExtractor.getModuleName(fromTarget: "MacOSPlatform") == "MacOSPlatform")
        #expect(SBOMExtractor.getModuleName(fromTarget: "LinuxPlatform") == "LinuxPlatform")
        #expect(SBOMExtractor.getModuleName(fromTarget: "SwiftlyWebsiteAPI") == "SwiftlyWebsiteAPI")
        #expect(SBOMExtractor.getModuleName(fromTarget: "SwiftlyDownloadAPI") == "SwiftlyDownloadAPI")
        #expect(SBOMExtractor.getModuleName(fromTarget: "AsyncHTTPClient") == "AsyncHTTPClient")
        #expect(SBOMExtractor.getModuleName(fromTarget: "OpenAPIRuntime") == "OpenAPIRuntime")
        
        #expect(SBOMExtractor.getModuleName(fromTarget: "swiftly-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "test-swiftly-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "ArgumentParser-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "AsyncHTTPClient-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "OpenAPIRuntime-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "SystemPackage-product") == nil)
        
        #expect(SBOMExtractor.getModuleName(fromTarget: "") == "")
        #expect(SBOMExtractor.getModuleName(fromTarget: "A") == "A")
        #expect(SBOMExtractor.getModuleName(fromTarget: "-product") == nil)
        #expect(SBOMExtractor.getModuleName(fromTarget: "my-product-product") == nil)
    }
    
    @Test("name mapping functions are inverses for products")
    func testProductNameMappingRoundTrip() {
        let productNames = ["swiftly", "test-swiftly", "ArgumentParser", "AsyncHTTPClient", "OpenAPIRuntime"]
        
        for productName in productNames {
            let targetName = SBOMExtractor.getTargetName(fromProduct: productName)
            let recoveredName = SBOMExtractor.getProductName(fromTarget: targetName)
            #expect(recoveredName == productName, "Round trip failed for product '\(productName)'")
        }
    }
    
    @Test("name mapping functions are inverses for modules")
    func testModuleNameMappingRoundTrip() {
        let moduleNames = ["Swiftly", "TestSwiftly", "SwiftlyCore", "MacOSPlatform", "ArgumentParser"]
        
        for moduleName in moduleNames {
            let targetName = SBOMExtractor.getTargetName(fromModule: moduleName)
            let recoveredName = SBOMExtractor.getModuleName(fromTarget: targetName)
            #expect(recoveredName == moduleName, "Round trip failed for module '\(moduleName)'")
        }
    }
    
    @Test("product and module mapping functions are mutually exclusive")
    func testProductAndModuleMappingExclusivity() {
        // Product target names should not be recognized as modules
        let productTargetNames = ["swiftly-product", "ArgumentParser-product", "AsyncHTTPClient-product"]
        for targetName in productTargetNames {
            #expect(SBOMExtractor.getModuleName(fromTarget: targetName) == nil,
                   "Product target '\(targetName)' should not be recognized as a module")
            #expect(SBOMExtractor.getProductName(fromTarget: targetName) != nil,
                   "Product target '\(targetName)' should be recognized as a product")
        }
        
        // Module target names should not be recognized as products
        let moduleTargetNames = ["Swiftly", "ArgumentParser", "SwiftlyCore"]
        for targetName in moduleTargetNames {
            #expect(SBOMExtractor.getProductName(fromTarget: targetName) == nil,
                   "Module target '\(targetName)' should not be recognized as a product")
            #expect(SBOMExtractor.getModuleName(fromTarget: targetName) != nil,
                   "Module target '\(targetName)' should be recognized as a module")
        }
    }
    
    // MARK: - Build Graph Tests
    
    @Test("extractDependencies with build graph for simple test graph")
    func extractDependenciesFromSimpleGraphWithBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSimpleDependencyGraph()
        
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let dependencies = try await #require(extractor.extractDependencies().relationships)
        
        #expect(!dependencies.isEmpty, "Should have dependencies when using build graph")
        
        try await self.verifyDependencies(graph: graph, store: store)
        
        // Verify specific relationships from build graph
        let myAppPackageDep = try #require(dependencies.first { $0.parentID.value == "MyApp" })
        let utilsPackageDep = try #require(dependencies.first { $0.parentID.value == "Utils" })
        let appProductDep = try #require(dependencies.first { $0.parentID.value == "MyApp:App" })
        
        // Verify MyApp package dependencies
        #expect(myAppPackageDep.childrenID.count == 2, "MyApp package should have 2 dependencies")
        #expect(myAppPackageDep.childrenID.map(\.value).contains("Utils"), "MyApp should depend on Utils package")
        #expect(myAppPackageDep.childrenID.map(\.value).contains("MyApp:App"), "MyApp should depend on its own App product")
        
        // Verify Utils package dependencies
        #expect(utilsPackageDep.childrenID.count == 1, "Utils package should have 1 dependency")
        #expect(utilsPackageDep.childrenID.map(\.value).contains("Utils:Utils"), "Utils should depend on its own Utils product")
        
        // Verify App product dependencies (from build graph)
        #expect(appProductDep.childrenID.count == 1, "App product should have 1 dependency")
        #expect(appProductDep.childrenID.map(\.value).contains("Utils:Utils"), "App product should depend on Utils product")
    }
    
    @Test("extractDependencies with build graph for SPM ModulesGraph")
    func extractDependenciesFromSPMModulesGraphWithBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSPMDependencyGraph()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let _  = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }
    
    @Test("extractDependencies with build graph for Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraphWithBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSwiftlyDependencyGraph()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let _  = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }
    
    @Test("extractDependencies with build graph and product filter for SPM")
    func extractDependenciesWithBuildGraphAndProductFilterSPM() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSPMDependencyGraph()
        let productName = "SwiftPMPackageCollections"
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let _  = try await extractor.extractDependencies(product: productName)
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }
    
    @Test("extractDependencies with build graph and product filter for Swiftly")
    func extractDependenciesWithBuildGraphAndProductFilterSwiftly() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSwiftlyDependencyGraph()
        let productName = "swiftly"
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let _  = try await extractor.extractDependencies(product: productName)
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }
    
    @Test("extractDependencies with empty build graph falls back to ModulesGraph")
    func extractDependenciesWithEmptyBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        // Empty build graph - should fall back to ModulesGraph
        let buildGraph: [String: [String]] = [:]
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        let _  = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }
}
