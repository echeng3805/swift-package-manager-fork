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

    // MARK: - Helper Methods for Validation


    private func detectCycles(in dependencies: [SBOMRelationship]) -> [String] {
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
    
    private func isProductID(_ id: String) -> Bool {
        id.contains(":")
    }
    
    private func isOwnProduct(childID: String, parentID: String) -> Bool {
        childID.hasPrefix(parentID)
    }
    
    private func validateOwnProductDependency(childID: String, parentID: String) {
        #expect(
            isOwnProduct(childID: childID, parentID: parentID),
            "Package '\(parentID)' product dependency '\(childID)' should depend on '\(parentID)'"
        )
    }
    
    private func validatePackageDependency(childID: String, parentID: String, packageIDs: [String]) {
        #expect(
            packageIDs.contains(childID),
            "Package '\(parentID)' package dependency '\(childID)' should be a valid package"
        )
    }
    
    private func validateProductDependency(childID: String, parentID: String) {
        #expect(
            isProductID(childID),
            "Product '\(parentID)' should only depend on other products, but found package dependency '\(childID)'"
        )
    }
    
    private func validatePackageChildren(
        dependency: SBOMRelationship,
        rootPackageID: String,
        packageIDs: [String],
        filter: Filter = .all
    ) {
        for child in dependency.childrenID {
            if isProductID(child.value) { // package-to-product
                // root-package to root product is allowed when filter == .package or .product
                if filter == .package && rootPackageID != dependency.parentID.value {
                    #expect(!isProductID(child.value), "Package \(dependency.parentID) should only depend on packages when filter is .package'")
                    return
                } else if filter == .product && rootPackageID != dependency.parentID.value { 
                    #expect(!isProductID(child.value), "Package \(dependency.parentID) should only depend on root products and not other products when filter is .product'")
                    return
                }
                validateOwnProductDependency(childID: child.value, parentID: dependency.parentID.value)
            } else { // package-to-package
                validatePackageDependency(childID: child.value, parentID: dependency.parentID.value, packageIDs: packageIDs)
            }
        }
    }
    
    private func validateProductChildren(dependency: SBOMRelationship) {
        for child in dependency.childrenID { // product-to-product
            validateProductDependency(childID: child.value, parentID: dependency.parentID.value)
        }
    }
    
    private func validateRootPackageChildren(
        dependency: SBOMRelationship,
        rootPackageID: String,
        packageIDs: [String],
        filter: Filter = .all
    ) {
        #expect(!dependency.childrenID.map(\.value).contains(rootPackageID))
        validatePackageChildren(dependency: dependency, rootPackageID: rootPackageID, packageIDs: packageIDs, filter: filter)
    }
    
    private func verifyProductDependencies(
        graph: ModulesGraph,
        store: ResolvedPackagesStore,
        dependencyGraph: [String: [String]]? = nil,
        filter: Filter = .all,
        product: String? = nil,
    ) async throws {
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: dependencyGraph, store: store)
        let dependencies = try await #require(extractor.extractDependencies(product: product, filter: filter).relationships)
        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = SBOMExtractor.extractComponentID(from: rootPackage).value
        let packageIDs = graph.packages.map(\.identity.description)

        #expect(!dependencies.isEmpty)

        let parentIDs = dependencies.map(\.parentID)
        #expect(parentIDs.count == Set(parentIDs).count, "Parent IDs should be unique")

        let cycles = self.detectCycles(in: dependencies)
        #expect(cycles.isEmpty, "Dependency graph should not contain cycles. Found: \(cycles.joined(separator: "; "))")

        for dependency in dependencies {
            #expect(!dependency.id.value.isEmpty, "Dependency ID should not be empty")
            #expect(!dependency.parentID.value.isEmpty, "Parent ID should not be empty")
            #expect(!dependency.childrenID.isEmpty, "Children ID should not be empty")

            #expect(
                !dependency.childrenID.map(\.value).contains(dependency.parentID.value),
                "parent '\(dependency.parentID.value)' should not depend on itself"
            )

            if packageIDs.contains(dependency.parentID.value) { // package-to-product or package-to-package
                validatePackageChildren(dependency: dependency, rootPackageID: rootPackageID, packageIDs: packageIDs, filter: filter)
            } else {
                // product-to-product
                validateProductChildren(dependency: dependency)
            }

            if product == nil {
                #expect(!dependency.childrenID.map(\.value).contains(rootPackageID))
            }
        }
    }

    private func verifyDependencies(graph: ModulesGraph, store: ResolvedPackagesStore) async throws {
        try await self.verifyProductDependencies(graph: graph, store: store, product: nil)
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
        #expect(
            myAppPackageDep.childrenID.map(\.value).contains("MyApp:App"),
            "MyApp should depend on its own App product"
        )

        // Verify Utils package dependencies
        #expect(utilsPackageDep.childrenID.count == 1, "Utils package should have 1 dependency")
        #expect(
            utilsPackageDep.childrenID.map(\.value).contains("Utils:Utils"),
            "Utils should depend on its own Utils product"
        )

        // Verify App product dependencies
        #expect(appProductDep.childrenID.count == 1, "App product should have 1 dependency")
        #expect(
            appProductDep.childrenID.map(\.value).contains("Utils:Utils"),
            "App product should depend on Utils product"
        )
    }

    // MARK: - Name Mapping Tests

    @Test("getTargetName(fromProduct:) converts product names correctly")
    func getTargetNameFromProduct() {
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
    func getProductNameFromTarget() {
        #expect(SBOMExtractor.getProductName(fromTarget: "swiftly-product") == "swiftly")
        #expect(SBOMExtractor.getProductName(fromTarget: "test-swiftly-product") == "test-swiftly")
        #expect(SBOMExtractor.getProductName(fromTarget: "ArgumentParser-product") == "ArgumentParser")
        #expect(SBOMExtractor.getProductName(fromTarget: "AsyncHTTPClient-product") == "AsyncHTTPClient")
        #expect(SBOMExtractor.getProductName(fromTarget: "OpenAPIRuntime-product") == "OpenAPIRuntime")
        #expect(SBOMExtractor.getProductName(fromTarget: "SystemPackage-product") == "SystemPackage")
        #expect(SBOMExtractor.getProductName(fromTarget: "SwiftBuild-product") == "SwiftBuild")

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

    @Test("getPackageAndModuleNames(fromTarget:) converts target names correctly")
    func getPackageAndModuleNamesFromTarget() {
        // Test simple module names (no package prefix)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "Swiftly")?.moduleName == "Swiftly")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "Swiftly")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "TestSwiftly")?.moduleName == "TestSwiftly")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "TestSwiftly")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "ArgumentParser")?.moduleName == "ArgumentParser")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "ArgumentParser")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyCore")?.moduleName == "SwiftlyCore")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyCore")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "MacOSPlatform")?.moduleName == "MacOSPlatform")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "MacOSPlatform")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "LinuxPlatform")?.moduleName == "LinuxPlatform")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "LinuxPlatform")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyWebsiteAPI")?
            .moduleName == "SwiftlyWebsiteAPI")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyWebsiteAPI")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyDownloadAPI")?
            .moduleName == "SwiftlyDownloadAPI")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SwiftlyDownloadAPI")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "AsyncHTTPClient")?.moduleName == "AsyncHTTPClient")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "AsyncHTTPClient")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "OpenAPIRuntime")?.moduleName == "OpenAPIRuntime")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "OpenAPIRuntime")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SPMSQLite3")?.moduleName == "SPMSQLite3")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SPMSQLite3")?.packageName == nil)

        // Modules that start with underscores
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_CryptoExtras")?.moduleName == "_CryptoExtras")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_CryptoExtras")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_AsyncFileSystem")?
            .moduleName == "_AsyncFileSystem")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_AsyncFileSystem")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_CertificateInternals")?
            .moduleName == "_CertificateInternals")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "_CertificateInternals")?.packageName == nil)

        // Test product names (should return nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swiftly-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "test-swiftly-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "ArgumentParser-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "AsyncHTTPClient-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "OpenAPIRuntime-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "SystemPackage-product") == nil)

        // Test edge cases
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "")?.moduleName == "")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "A")?.moduleName == "A")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "A")?.packageName == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "-product") == nil)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "my-product-product") == nil)

        // Test package_module format (with underscores)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio_NIOPosix")?.packageName == "swift-nio")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio_NIOPosix")?.moduleName == "NIOPosix")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio-ssl_NIOSSL")?
            .packageName == "swift-nio-ssl")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio-ssl_NIOSSL")?.moduleName == "NIOSSL")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-crypto_Crypto")?
            .packageName == "swift-crypto")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-crypto_Crypto")?.moduleName == "Crypto")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-crypto__CryptoExtras")?
            .packageName == "swift-crypto")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-crypto__CryptoExtras")?
            .moduleName == "_CryptoExtras")

        // Test modules with leading underscores (like _NIOBase64, _NIODataStructures)
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio__NIOBase64")?.packageName == "swift-nio")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio__NIOBase64")?.moduleName == "_NIOBase64")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio__NIODataStructures")?
            .packageName == "swift-nio")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "swift-nio__NIODataStructures")?
            .moduleName == "_NIODataStructures")

        // Test modules with multiple leading underscores
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "package___ModuleName")?.packageName == "package")
        #expect(SBOMExtractor.getPackageAndModuleNames(fromTarget: "package___ModuleName")?
            .moduleName == "__ModuleName")
    }

    @Test("name mapping functions are inverses for products")
    func productNameMappingRoundTrip() {
        let productNames = ["swiftly", "test-swiftly", "ArgumentParser", "AsyncHTTPClient", "OpenAPIRuntime"]

        for productName in productNames {
            let targetName = SBOMExtractor.getTargetName(fromProduct: productName)
            let recoveredName = SBOMExtractor.getProductName(fromTarget: targetName)
            #expect(recoveredName == productName, "Round trip failed for product '\(productName)'")
        }
    }

    @Test("product and module mapping functions are mutually exclusive")
    func productAndModuleMappingExclusivity() {
        // Product target names should not be recognized as modules
        let productTargetNames = ["swiftly-product", "ArgumentParser-product", "AsyncHTTPClient-product"]
        for targetName in productTargetNames {
            #expect(
                SBOMExtractor.getPackageAndModuleNames(fromTarget: targetName) == nil,
                "Product target '\(targetName)' should not be recognized as a module"
            )
            #expect(
                SBOMExtractor.getProductName(fromTarget: targetName) != nil,
                "Product target '\(targetName)' should be recognized as a product"
            )
        }

        // Module target names should not be recognized as products
        let moduleTargetNames = ["Swiftly", "ArgumentParser", "SwiftlyCore"]
        for targetName in moduleTargetNames {
            #expect(
                SBOMExtractor.getProductName(fromTarget: targetName) == nil,
                "Module target '\(targetName)' should not be recognized as a product"
            )
            #expect(
                SBOMExtractor.getPackageAndModuleNames(fromTarget: targetName) != nil,
                "Module target '\(targetName)' should be recognized as a module"
            )
        }
    }

    // MARK: - toProduct and toModule Tests

    @Test("toProduct(fromTarget:) returns correct product for valid product targets")
    func toProductWithValidTargets() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let swiftlyProduct = extractor.toProduct(fromTarget: "swiftly-product")
        #expect(swiftlyProduct?.name == "swiftly", "Product name should be 'swiftly'")

        let testSwiftlyProduct = extractor.toProduct(fromTarget: "test-swiftly-product")
        #expect(testSwiftlyProduct?.name == "test-swiftly", "Product name should be 'test-swiftly'")
    }

    @Test("toProduct(fromTarget:) returns nil for non-product targets")
    func toProductWithNonProductTargets() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        #expect(extractor.toProduct(fromTarget: "Swiftly") == nil, "Module name should not be recognized as product")
        #expect(
            extractor.toProduct(fromTarget: "SwiftlyCore") == nil,
            "Module name should not be recognized as product"
        )
        #expect(
            extractor.toProduct(fromTarget: "_AsyncFileSystem") == nil,
            "Module with underscore should not be recognized as product"
        )
        #expect(extractor.toProduct(fromTarget: "SPMSQLite3") == nil, "Module name should not be recognized as product")

        #expect(
            extractor.toProduct(fromTarget: "swift-nio_NIOPosix") == nil,
            "Package_module format should not be recognized as product"
        )
        #expect(
            extractor.toProduct(fromTarget: "swift-nio__NIOBase64") == nil,
            "Package_module with underscore should not be recognized as product"
        )
    }

    @Test("toProduct(fromTarget:) handles edge cases for product targets")
    func toProductEdgeCases() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let swiftBuildProduct = extractor.toProduct(fromTarget: "SwiftBuild-product")
        #expect(swiftBuildProduct != nil, "SwiftBuild-product should exist in modules graph")

        let swbBuildServiceProduct = extractor.toProduct(fromTarget: "SWBBuildService-product")
        #expect(swbBuildServiceProduct != nil, "SWBBuildService-product should exist in modules graph")
    }

    @Test("toModule(fromTarget:) returns correct module for simple module names")
    func toModuleWithSimpleNames() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let swiftlyModule = extractor.toModule(fromTarget: "Swiftly")
        #expect(swiftlyModule?.name == "Swiftly", "Module name should be 'Swiftly'")

        let swiftlyCoreModule = extractor.toModule(fromTarget: "SwiftlyCore")
        #expect(swiftlyCoreModule?.name == "SwiftlyCore", "Module name should be 'SwiftlyCore'")
    }

    @Test("toModule(fromTarget:) returns correct module for system module")
    func toModuleWithSystemModules() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let spmSQLite3Module = extractor.toModule(fromTarget: "SPMSQLite3")
        #expect(spmSQLite3Module?.name == "SPMSQLite3", "Module name should be 'SPMSQLite3'")
    }

    @Test("toModule(fromTarget:) returns correct module for modules with leading underscores")
    func toModuleWithLeadingUnderscores() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let asyncFileSystemModule = extractor.toModule(fromTarget: "_AsyncFileSystem")
        #expect(asyncFileSystemModule?.name == "_AsyncFileSystem", "Module name should be '_AsyncFileSystem'")

        let certificateInternalsModule = extractor.toModule(fromTarget: "_CertificateInternals")
        #expect(
            certificateInternalsModule?.name == "_CertificateInternals",
            "Module name should be '_CertificateInternals'"
        )

        let cryptoExtrasModule = extractor.toModule(fromTarget: "_CryptoExtras")
        #expect(cryptoExtrasModule?.name == "_CryptoExtras", "Module name should be '_CryptoExtras'")

        let swiftSyntaxCShimsModule = extractor.toModule(fromTarget: "_SwiftSyntaxCShims")
        #expect(swiftSyntaxCShimsModule?.name == "_SwiftSyntaxCShims", "Module name should be '_SwiftSyntaxCShims'")

        let swiftlyGraph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let swiftlyStore = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let swiftlyExtractor = SBOMExtractor(modulesGraph: swiftlyGraph, dependencyGraph: nil, store: swiftlyStore)

        let subprocessCShimsModule = swiftlyExtractor.toModule(fromTarget: "_SubprocessCShims")
        #expect(subprocessCShimsModule?.name == "_SubprocessCShims", "Module name should be '_SubprocessCShims'")
    }

    @Test("toModule(fromTarget:) returns correct module for package_module format")
    func toModuleWithPackageModuleFormat() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        let nioPosixModule = extractor.toModule(fromTarget: "swift-nio_NIOPosix")
        #expect(nioPosixModule?.name == "NIOPosix", "Module name should be 'NIOPosix'")
        #expect(nioPosixModule?.packageIdentity.description == "swift-nio", "Package identity should be 'swift-nio'")

        let nioSSLModule = extractor.toModule(fromTarget: "swift-nio-ssl_NIOSSL")
        #expect(nioSSLModule?.name == "NIOSSL", "Module name should be 'NIOSSL'")
        #expect(
            nioSSLModule?.packageIdentity.description == "swift-nio-ssl",
            "Package identity should be 'swift-nio-ssl'"
        )

        // Test modules with leading underscores in package_module format
        let nioBase64Module = extractor.toModule(fromTarget: "swift-nio__NIOBase64")
        #expect(nioBase64Module?.name == "_NIOBase64", "Module name should be '_NIOBase64'")
        #expect(nioBase64Module?.packageIdentity.description == "swift-nio", "Package identity should be 'swift-nio'")

        let nioDataStructuresModule = extractor.toModule(fromTarget: "swift-nio__NIODataStructures")
        #expect(nioDataStructuresModule?.name == "_NIODataStructures", "Module name should be '_NIODataStructures'")
        #expect(
            nioDataStructuresModule?.packageIdentity.description == "swift-nio",
            "Package identity should be 'swift-nio'"
        )

        let cryptoExtrasModule = extractor.toModule(fromTarget: "swift-crypto__CryptoExtras")
        #expect(cryptoExtrasModule?.name == "_CryptoExtras", "Module name should be '_CryptoExtras'")
        #expect(
            cryptoExtrasModule?.packageIdentity.description == "swift-crypto",
            "Package identity should be 'swift-crypto'"
        )
    }

    @Test("toModule(fromTarget:) returns nil for product targets")
    func toModuleWithProductTargets() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        #expect(
            extractor.toModule(fromTarget: "swiftly-product") == nil,
            "Product target should not be recognized as module"
        )
        #expect(
            extractor.toModule(fromTarget: "test-swiftly-product") == nil,
            "Product target should not be recognized as module"
        )
        #expect(
            extractor.toModule(fromTarget: "SwiftBuild-product") == nil,
            "Product target should not be recognized as module"
        )
        #expect(
            extractor.toModule(fromTarget: "SWBBuildService-product") == nil,
            "Product target should not be recognized as module"
        )
    }

    @Test("toModule(fromTarget:) handles non-existent modules gracefully")
    func toModuleWithNonExistentModules() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        #expect(extractor.toModule(fromTarget: "NonExistentModule") == nil, "Non-existent module should return nil")
        #expect(
            extractor.toModule(fromTarget: "_NonExistentModule") == nil,
            "Non-existent module with underscore should return nil"
        )
        #expect(
            extractor.toModule(fromTarget: "package_NonExistentModule") == nil,
            "Non-existent package_module should return nil"
        )
    }

    @Test("toProduct and toModule are mutually exclusive")
    func toProductAndToModuleMutualExclusivity() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)

        // Product targets should only work with toProduct
        let productTarget = "swiftly-product"
        #expect(extractor.toProduct(fromTarget: productTarget) != nil, "Product target should work with toProduct")
        #expect(extractor.toModule(fromTarget: productTarget) == nil, "Product target should not work with toModule")

        // Module targets should only work with toModule
        let moduleTarget = "Swiftly"
        #expect(extractor.toModule(fromTarget: moduleTarget) != nil, "Module target should work with toModule")
        #expect(extractor.toProduct(fromTarget: moduleTarget) == nil, "Module target should not work with toProduct")

        // Package_module format should only work with toModule
        let packageModuleTarget = "swift-nio_NIOPosix"
        if extractor.toModule(fromTarget: packageModuleTarget) != nil {
            #expect(
                extractor.toProduct(fromTarget: packageModuleTarget) == nil,
                "Package_module format should not work with toProduct"
            )
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

        let myAppPackageDep = try #require(dependencies.first { $0.parentID.value == "MyApp" })
        let utilsPackageDep = try #require(dependencies.first { $0.parentID.value == "Utils" })
        let appProductDep = try #require(dependencies.first { $0.parentID.value == "MyApp:App" })

        #expect(myAppPackageDep.childrenID.count == 2, "MyApp package should have 2 dependencies")
        #expect(myAppPackageDep.childrenID.map(\.value).contains("Utils"), "MyApp should depend on Utils package")
        #expect(
            myAppPackageDep.childrenID.map(\.value).contains("MyApp:App"),
            "MyApp should depend on its own App product"
        )

        #expect(utilsPackageDep.childrenID.count == 1, "Utils package should have 1 dependency")
        #expect(
            utilsPackageDep.childrenID.map(\.value).contains("Utils:Utils"),
            "Utils should depend on its own Utils product"
        )

        #expect(appProductDep.childrenID.count == 1, "App product should have 1 dependency")
        #expect(
            appProductDep.childrenID.map(\.value).contains("Utils:Utils"),
            "App product should depend on Utils product"
        )
    }

    @Test("extractDependencies with build graph for SPM ModulesGraph")
    func extractDependenciesFromSPMModulesGraphWithBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSPMDependencyGraph()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        _ = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with build graph for Swiftly ModulesGraph")
    func extractDependenciesFromSwiftlyModulesGraphWithBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSwiftlyDependencyGraph()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        _ = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    @Test("extractDependencies with build graph and product filter for SPM")
    func extractDependenciesWithBuildGraphAndProductFilterSPM() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSPMDependencyGraph()
        let productName = "SwiftPMPackageCollections"
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        _ = try await extractor.extractDependencies(product: productName)
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with build graph and product filter for Swiftly")
    func extractDependenciesWithBuildGraphAndProductFilterSwiftly() async throws {
        let graph = try SBOMTestModulesGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let buildGraph = SBOMTestDependencyGraph.createSwiftlyDependencyGraph()
        let productName = "swiftly"
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        _ = try await extractor.extractDependencies(product: productName)
        try await self.verifyProductDependencies(graph: graph, store: store, product: productName)
    }

    @Test("extractDependencies with empty build graph falls back to ModulesGraph")
    func extractDependenciesWithEmptyBuildGraph() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        // Empty build graph - should fall back to ModulesGraph
        let buildGraph: [String: [String]] = [:]
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: buildGraph, store: store)
        _ = try await extractor.extractDependencies()
        try await self.verifyDependencies(graph: graph, store: store)
    }

    // MARK: - Filter Tests
    
    @Test("Filter.all tracks all relationships")
    func filterAllTracksAllRelationships() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        try await self.verifyDependencies(graph: graph, store: store)
    }
    
    @Test("Filter.product tracks only product-to-product and cross-boundary relationships when primary component is package")
    func filterProductTracksOnlyProductRelationships() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()        
        try await self.verifyProductDependencies(graph: graph, store: store, filter: .product, product: nil)
        
    }
    
    @Test("Filter.package tracks only package-to-package relationships when primary component is package")
    func filterPackageTracksOnlyPackageRelationships() async throws {
        let graph = try SBOMTestModulesGraph.createSimpleModulesGraph()
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()        
        try await self.verifyProductDependencies(graph: graph, store: store, filter: .package, product: nil)
    }

    @Test("Filter.product tracks only product-to-product when primary component is product")
    func filterProductTracksOnlyProductRelationshipsForProduct() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        try await self.verifyProductDependencies(graph: graph, store: store, filter: .product, product: "SwiftPMDataModel")
        
    }
    
    @Test("Filter.package tracks only package-to-package relationships and cross-boundary relationships when primary component is product")
    func filterPackageTracksOnlyPackageRelationshipsForProduct() async throws {
        let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        try await self.verifyProductDependencies(graph: graph, store: store, filter: .package, product: "SwiftPMDataModel")
    }
}
