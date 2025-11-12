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
                } else if packageIDs.contains(dependency.parentID.value) { // package comp, should have package-to-product deps
                    for child in dependency.childrenID {
                        #expect(child.value.hasPrefix(dependency.parentID.value))
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
        
        // Expected structure:
        // - MyApp package depends on Utils package and App product
        // - Utils package depends on Utils product
        // - App product depends on Utils product
        
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
    
    @Test("productNameToTargetName converts product names correctly")
    func testProductNameToTargetName() {
        // Test with various product names from Swiftly graph
        #expect(SBOMExtractor.productNameToTargetName("swiftly") == "swiftly-product")
        #expect(SBOMExtractor.productNameToTargetName("test-swiftly") == "test-swiftly-product")
        #expect(SBOMExtractor.productNameToTargetName("ArgumentParser") == "ArgumentParser-product")
        #expect(SBOMExtractor.productNameToTargetName("AsyncHTTPClient") == "AsyncHTTPClient-product")
        #expect(SBOMExtractor.productNameToTargetName("OpenAPIRuntime") == "OpenAPIRuntime-product")
        #expect(SBOMExtractor.productNameToTargetName("SystemPackage") == "SystemPackage-product")

        #expect(SBOMExtractor.productNameToTargetName("") == "-product")
        #expect(SBOMExtractor.productNameToTargetName("A") == "A-product")
        #expect(SBOMExtractor.productNameToTargetName("product") == "product-product")
    }
    
    @Test("targetNameToProductName converts target names correctly")
    func testTargetNameToProductName() {
        #expect(SBOMExtractor.targetNameToProductName("swiftly-product") == "swiftly")
        #expect(SBOMExtractor.targetNameToProductName("test-swiftly-product") == "test-swiftly")
        #expect(SBOMExtractor.targetNameToProductName("ArgumentParser-product") == "ArgumentParser")
        #expect(SBOMExtractor.targetNameToProductName("AsyncHTTPClient-product") == "AsyncHTTPClient")
        #expect(SBOMExtractor.targetNameToProductName("OpenAPIRuntime-product") == "OpenAPIRuntime")
        #expect(SBOMExtractor.targetNameToProductName("SystemPackage-product") == "SystemPackage")
        
        #expect(SBOMExtractor.targetNameToProductName("Swiftly") == nil)
        #expect(SBOMExtractor.targetNameToProductName("TestSwiftly") == nil)
        #expect(SBOMExtractor.targetNameToProductName("ArgumentParser") == nil)
        #expect(SBOMExtractor.targetNameToProductName("SwiftlyCore") == nil)
        #expect(SBOMExtractor.targetNameToProductName("MacOSPlatform") == nil)
        
        #expect(SBOMExtractor.targetNameToProductName("-product") == "")
        #expect(SBOMExtractor.targetNameToProductName("") == nil)
        #expect(SBOMExtractor.targetNameToProductName("product") == nil)
        #expect(SBOMExtractor.targetNameToProductName("my-product-product") == "my-product")
    }
    
    @Test("moduleNameToTargetName preserves module names")
    func testModuleNameToTargetName() {
        #expect(SBOMExtractor.moduleNameToTargetName("Swiftly") == "Swiftly")
        #expect(SBOMExtractor.moduleNameToTargetName("TestSwiftly") == "TestSwiftly")
        #expect(SBOMExtractor.moduleNameToTargetName("ArgumentParser") == "ArgumentParser")
        #expect(SBOMExtractor.moduleNameToTargetName("SwiftlyCore") == "SwiftlyCore")
        #expect(SBOMExtractor.moduleNameToTargetName("MacOSPlatform") == "MacOSPlatform")
        #expect(SBOMExtractor.moduleNameToTargetName("LinuxPlatform") == "LinuxPlatform")
        #expect(SBOMExtractor.moduleNameToTargetName("SwiftlyWebsiteAPI") == "SwiftlyWebsiteAPI")
        #expect(SBOMExtractor.moduleNameToTargetName("SwiftlyDownloadAPI") == "SwiftlyDownloadAPI")
        #expect(SBOMExtractor.moduleNameToTargetName("AsyncHTTPClient") == "AsyncHTTPClient")
        #expect(SBOMExtractor.moduleNameToTargetName("OpenAPIRuntime") == "OpenAPIRuntime")
        
        #expect(SBOMExtractor.moduleNameToTargetName("") == "")
        #expect(SBOMExtractor.moduleNameToTargetName("A") == "A")
        #expect(SBOMExtractor.moduleNameToTargetName("module-with-dashes") == "module-with-dashes")
    }
    
    @Test("targetNameToModuleName converts target names correctly")
    func testTargetNameToModuleName() {
        #expect(SBOMExtractor.targetNameToModuleName("Swiftly") == "Swiftly")
        #expect(SBOMExtractor.targetNameToModuleName("TestSwiftly") == "TestSwiftly")
        #expect(SBOMExtractor.targetNameToModuleName("ArgumentParser") == "ArgumentParser")
        #expect(SBOMExtractor.targetNameToModuleName("SwiftlyCore") == "SwiftlyCore")
        #expect(SBOMExtractor.targetNameToModuleName("MacOSPlatform") == "MacOSPlatform")
        #expect(SBOMExtractor.targetNameToModuleName("LinuxPlatform") == "LinuxPlatform")
        #expect(SBOMExtractor.targetNameToModuleName("SwiftlyWebsiteAPI") == "SwiftlyWebsiteAPI")
        #expect(SBOMExtractor.targetNameToModuleName("SwiftlyDownloadAPI") == "SwiftlyDownloadAPI")
        #expect(SBOMExtractor.targetNameToModuleName("AsyncHTTPClient") == "AsyncHTTPClient")
        #expect(SBOMExtractor.targetNameToModuleName("OpenAPIRuntime") == "OpenAPIRuntime")
        
        #expect(SBOMExtractor.targetNameToModuleName("swiftly-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("test-swiftly-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("ArgumentParser-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("AsyncHTTPClient-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("OpenAPIRuntime-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("SystemPackage-product") == nil)
        
        #expect(SBOMExtractor.targetNameToModuleName("") == "")
        #expect(SBOMExtractor.targetNameToModuleName("A") == "A")
        #expect(SBOMExtractor.targetNameToModuleName("-product") == nil)
        #expect(SBOMExtractor.targetNameToModuleName("my-product-product") == nil)
    }
    
    @Test("name mapping functions are inverses for products")
    func testProductNameMappingRoundTrip() {
        let productNames = ["swiftly", "test-swiftly", "ArgumentParser", "AsyncHTTPClient", "OpenAPIRuntime"]
        
        for productName in productNames {
            let targetName = SBOMExtractor.productNameToTargetName(productName)
            let recoveredName = SBOMExtractor.targetNameToProductName(targetName)
            #expect(recoveredName == productName, "Round trip failed for product '\(productName)'")
        }
    }
    
    @Test("name mapping functions are inverses for modules")
    func testModuleNameMappingRoundTrip() {
        let moduleNames = ["Swiftly", "TestSwiftly", "SwiftlyCore", "MacOSPlatform", "ArgumentParser"]
        
        for moduleName in moduleNames {
            let targetName = SBOMExtractor.moduleNameToTargetName(moduleName)
            let recoveredName = SBOMExtractor.targetNameToModuleName(targetName)
            #expect(recoveredName == moduleName, "Round trip failed for module '\(moduleName)'")
        }
    }
    
    @Test("product and module mapping functions are mutually exclusive")
    func testProductAndModuleMappingExclusivity() {
        // Product target names should not be recognized as modules
        let productTargetNames = ["swiftly-product", "ArgumentParser-product", "AsyncHTTPClient-product"]
        for targetName in productTargetNames {
            #expect(SBOMExtractor.targetNameToModuleName(targetName) == nil,
                   "Product target '\(targetName)' should not be recognized as a module")
            #expect(SBOMExtractor.targetNameToProductName(targetName) != nil,
                   "Product target '\(targetName)' should be recognized as a product")
        }
        
        // Module target names should not be recognized as products
        let moduleTargetNames = ["Swiftly", "ArgumentParser", "SwiftlyCore"]
        for targetName in moduleTargetNames {
            #expect(SBOMExtractor.targetNameToProductName(targetName) == nil,
                   "Module target '\(targetName)' should not be recognized as a product")
            #expect(SBOMExtractor.targetNameToModuleName(targetName) != nil,
                   "Module target '\(targetName)' should be recognized as a module")
        }
    }
}
