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
import Basics
import Foundation
import PackageModel
@testable import SBOMModel
import SourceControl
import Testing
import class TSCBasic.Process

struct SBOMExtractPrimaryComponentTests {
    @Test("extractPrimaryComponent from sample SwiftPM ModulesGraph")
    func extractPrimaryComponentFromSPMModulesGraph() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier

        #expect(component.category == SBOMComponent.Category.library)
        #expect(component.name == rootPackage.identity.description)
        #expect(component.id.value == rootPackage.identity.description)
        #expect(component.purl == "pkg:swift/github.com/swiftlang/SwiftPM@\(expectedRevision)")
        #expect(component.version.revision == expectedRevision)
        #expect(component.version.commit?.sha == expectedRevision)
        #expect(component.version.commit?.repository == SBOMTestStore.swiftPMURL)
        #expect(component.scope == .runtime)
        #expect(component.description == rootPackage.description)

        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == expectedRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractPrimaryComponent from sample Swiftly ModulesGraph")
    func extractPrimaryComponentFromSwiftlyModulesGraph() async throws {
        let (swiftlyRepo, swiftlyPath) = try SBOMTestRepo.setupSwiftlyTestRepo()
        defer { try? SBOMTestRepo.cleanup(swiftlyPath) }

        let graph = try SBOMTestGraph.createSwiftlyModulesGraph(rootPath: swiftlyPath.pathString)
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try swiftlyRepo.getCurrentRevision().identifier

        #expect(component.category == SBOMComponent.Category.application)
        #expect(component.name == rootPackage.identity.description)
        #expect(component.id.value == rootPackage.identity.description)
        #expect(component.purl == "pkg:swift/github.com/swiftlang/swiftly@v1.0.0")
        #expect(component.version.revision == "v1.0.0")
        #expect(component.version.commit?.sha == expectedRevision)
        #expect(component.version.commit?.repository == SBOMTestStore.swiftlyURL)
        #expect(component.scope == .runtime)
        #expect(component.description == rootPackage.description)
        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == expectedRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftlyURL)
    }

    @Test("extractComponent from product from primary component from sample SwiftPM ModulesGraph")
    func extractComponentFromProductFromSPMModulesGraph() async throws {
        let (gitRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let resolvedProduct = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })
        let actualRevision = try gitRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(product: resolvedProduct, graph: graph, store: store)

        #expect(component.category == SBOMComponent.Category.library)
        #expect(component.name == "SwiftPMDataModel")
        #expect(component.id.value == "SwiftPM:SwiftPMDataModel")
        #expect(component.version.revision == actualRevision)
        #expect(component.scope == .runtime)
        #expect(component.purl.contains("pkg:swift/github.com/swiftlang/SwiftPM:SwiftPMDataModel@\(actualRevision)"))
        #expect(component.description == nil)
        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == actualRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractComponent from product from primary component from sample Swiftly ModulesGraph")
    func extractComponentFromProductFromSwiftlyModulesGraph() async throws {
        let (swiftlyRepo, swiftlyPath) = try SBOMTestRepo.setupSwiftlyTestRepo()
        defer { try? SBOMTestRepo.cleanup(swiftlyPath) }

        let graph = try SBOMTestGraph.createSwiftlyModulesGraph(rootPath: swiftlyPath.pathString)
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let resolvedProduct = try #require(rootPackage.products.first)
        let actualRevision = try swiftlyRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(product: resolvedProduct, graph: graph, store: store)

        #expect(component.category == SBOMComponent.Category.application)
        #expect(component.name == "swiftly")
        #expect(component.id.value == "swiftly:swiftly")
        #expect(component.version.revision == "v1.0.0")
        #expect(component.scope == .runtime)
        #expect(component.purl.contains("pkg:swift/github.com/swiftlang/swiftly:swiftly@v1.0.0"))
        #expect(component.description == nil)

        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == actualRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftlyURL)
    }

    @Test("extractPrimaryComponent with product filter")
    func extractPrimaryComponentWithProductFilter() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMDataModel"
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, product: productName)

        #expect(component.name == productName)
        #expect(component.id.value == "SwiftPM:\(productName)")
        #expect(component.category == .library)

        let packageComponent = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        #expect(packageComponent.name == "SwiftPM")
        #expect(packageComponent.id.value == "SwiftPM")
        #expect(component.category == .library)

        #expect(component.id != packageComponent.id)
    }

    @Test("SBOMVersionCache caches version information across multiple extractions")
    func versionCacheStoresAndReusesVersions() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier
        let cache = SBOMGitCache()

        let component1 = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, cache: cache)
        #expect(component1.version.revision == expectedRevision)

        let cachedVersion = await cache.get(rootPackage.identity)
        #expect(cachedVersion != nil, "Cache should contain version for root package")
        #expect(cachedVersion?.version.revision == expectedRevision, "Cached version should match expected revision")

        let gitPath = spmPath.appending(".git")
        try localFileSystem.removeFileTree(gitPath)
        #expect(!localFileSystem.exists(gitPath), "Git directory should be removed")

        let component2 = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, cache: cache)
        #expect(component2.version.revision == expectedRevision, "Should return cached version even without Git")
        #expect(
            component2.version.revision == component1.version.revision,
            "Both extractions should return same version"
        )

        let resolvedProduct = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })
        let productComponent = try await SBOMModel.extractComponent(
            product: resolvedProduct,
            graph: graph,
            store: store,
            cache: cache
        )
        #expect(
            productComponent.version.revision == expectedRevision,
            "Product should use cached version from root package"
        )

        let cachedVersionAfter = await cache.get(rootPackage.identity)
        #expect(cachedVersionAfter?.version.revision == expectedRevision, "Cache should still contain same version")
    }

    @Test("extractComponent from package includes all products as nested components")
    func extractComponentFromPackageIncludesAllProducts() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        #expect(component.components != nil, "Package component should have nested product components")
        let nestedComponents = try #require(component.components)
        #expect(nestedComponents.count == rootPackage.products.count, "Should have one component per product")

        for product in rootPackage.products {
            let productComponent = nestedComponents.first { $0.name == product.name }
            #expect(productComponent != nil, "Should have component for product \(product.name)")
            #expect(productComponent?.id.value == "SwiftPM:\(product.name)")
        }
    }

    @Test("extractComponent from package with executable product has application category")
    func extractComponentFromPackageWithExecutableHasApplicationCategory() async throws {
        let (_, swiftlyPath) = try SBOMTestRepo.setupSwiftlyTestRepo()
        defer { try? SBOMTestRepo.cleanup(swiftlyPath) }

        let graph = try SBOMTestGraph.createSwiftlyModulesGraph(rootPath: swiftlyPath.pathString)
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        #expect(component.category == .application, "Package with executable should be application category")
        #expect(component.name == "swiftly")
        #expect(component.id.value == "swiftly")
    }

    @Test("extractComponent from dependency package uses store version")
    func extractComponentFromDependencyPackageUsesStoreVersion() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        let dependencyPackage = try #require(graph.packages.first { $0.identity.description == "swift-system" })

        let component = try await SBOMModel.extractComponent(package: dependencyPackage, graph: graph, store: store)

        #expect(component.name == "swift-system")
        #expect(component.id.value == "swift-system")
        #expect(component.category == .library)
        #expect(component.version.revision == "1.3.2")
        let expectedSHA = SBOMTestStore.generateMockRevision(for: "swift-system")
        #expect(component.version.commit?.sha == expectedSHA)
        #expect(component.version.commit?.repository == "https://github.com/apple/swift-system.git")
    }

    @Test("extractComponent from product without graph uses store version")
    func extractComponentFromProductWithoutGraphUsesStoreVersion() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        let dependencyPackage = try #require(graph.packages.first { $0.identity.description == "swift-collections" })
        let product = try #require(dependencyPackage.products.first { $0.name == "OrderedCollections" })

        let component = try await SBOMModel.extractComponent(product: product, graph: nil, store: store)

        #expect(component.name == "OrderedCollections")
        #expect(component.id.value == "swift-collections:OrderedCollections")
        #expect(component.category == .library)
        #expect(component.version.revision == "1.1.4")
        #expect(component.description == nil, "Products should not have description")
    }

    @Test("extractComponent from package sets correct PURL")
    func extractComponentFromPackageSetsCorrectPURL() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        #expect(component.purl.hasPrefix("pkg:swift/github.com/swiftlang/SwiftPM@"))
        #expect(component.purl.contains("github.com/swiftlang/SwiftPM"))
    }

    @Test("extractComponent from product sets correct PURL with subpath")
    func extractComponentFromProductSetsCorrectPURLWithSubpath() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first { $0.name == "SwiftPMPackageCollections" })

        let component = try await SBOMModel.extractComponent(product: product, graph: graph, store: store)

        #expect(component.purl.contains("pkg:swift/github.com/swiftlang/SwiftPM:SwiftPMPackageCollections@"))
        #expect(component.purl.contains(":SwiftPMPackageCollections@"))
    }

    @Test("extractComponent from package includes originator with commit info")
    func extractComponentFromPackageIncludesOriginatorWithCommitInfo() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        #expect(component.originator.commits != nil)
        let commits = try #require(component.originator.commits)
        #expect(commits.count == 1)
        #expect(commits.first?.sha == expectedRevision)
        #expect(commits.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractComponent from product includes originator with commit info")
    func extractComponentFromProductIncludesOriginatorWithCommitInfo() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(product: product, graph: graph, store: store)

        #expect(component.originator.commits != nil)
        let commits = try #require(component.originator.commits)
        #expect(commits.count == 1)
        #expect(commits.first?.sha == expectedRevision)
        #expect(commits.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractComponent from package preserves package description")
    func extractComponentFromPackagePreservesDescription() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        #expect(component.description == rootPackage.description)
    }

    @Test("extractComponent from product has nil description")
    func extractComponentFromProductHasNilDescription() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first)

        let component = try await SBOMModel.extractComponent(product: product, graph: graph, store: store)

        #expect(component.description == nil, "Products should not have description")
    }

    @Test("extractComponent from package extracts all products with correct properties")
    func extractComponentFromPackageExtractsAllProductsWithCorrectProperties() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier

        let packageComponent = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        let productComponents = try #require(packageComponent.components)
        #expect(productComponents.count == rootPackage.products.count)

        for (_, product) in rootPackage.products.enumerated() {
            let productComponent = try #require(productComponents.first { $0.name == product.name })
            #expect(productComponent.id.value == "SwiftPM:\(product.name)")
            let expectedCategory: SBOMComponent.Category = product.type == .executable ? .application : .library
            #expect(productComponent.category == expectedCategory)
            #expect(productComponent.version.revision == expectedRevision)
            #expect(productComponent.version.commit?.sha == expectedRevision)
            #expect(productComponent.scope == .runtime)
            #expect(productComponent.description == nil)
            #expect(productComponent.purl.contains(":\(product.name)@"))
        }
    }

    @Test("extractComponent from package with multiple product types extracts all correctly")
    func extractComponentFromPackageWithMultipleProductTypesExtractsAllCorrectly() async throws {
        let (_, swiftlyPath) = try SBOMTestRepo.setupSwiftlyTestRepo()
        defer { try? SBOMTestRepo.cleanup(swiftlyPath) }

        let graph = try SBOMTestGraph.createSwiftlyModulesGraph(rootPath: swiftlyPath.pathString)
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let packageComponent = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        let productComponents = try #require(packageComponent.components)
        #expect(productComponents.count == rootPackage.products.count)

        let executableProduct = try #require(rootPackage.products.first { $0.type == .executable })
        let executableComponent = try #require(productComponents.first { $0.name == executableProduct.name })
        #expect(executableComponent.category == .application)
        #expect(executableComponent.id.value == "swiftly:swiftly")
    }

    @Test("extractComponent from dependency package extracts products with store versions")
    func extractComponentFromDependencyPackageExtractsProductsWithStoreVersions() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        let dependencyPackage = try #require(graph.packages.first { $0.identity.description == "swift-collections" })

        let packageComponent = try await SBOMModel.extractComponent(package: dependencyPackage, graph: graph, store: store)

        let productComponents = try #require(packageComponent.components)
        #expect(productComponents.count == dependencyPackage.products.count)

        let expectedVersion = "1.1.4"
        let expectedSHA = SBOMTestStore.generateMockRevision(for: "swift-collections")
        for productComponent in productComponents {
            #expect(productComponent.version.revision == expectedVersion)
            #expect(productComponent.version.commit?.sha == expectedSHA)
        }

        let orderedCollections = try #require(productComponents.first { $0.name == "OrderedCollections" })
        #expect(orderedCollections.id.value == "swift-collections:OrderedCollections")
        #expect(orderedCollections.category == .library)
    }

    @Test("extractComponent from package with no products has empty components array")
    func extractComponentFromPackageWithNoProductsHasEmptyComponentsArray() async throws {
        // Create a simple package with no products for testing
        let packageIdentity = PackageIdentity.plain("TestPackage")
        let module = SBOMTestGraph.createSwiftModule(name: "TestModule")
        let package = SBOMTestGraph.createPackage(
            identity: packageIdentity,
            displayName: "TestPackage",
            path: "/TestPackage",
            modules: [module],
            products: []
        )
        let resolvedModule = SBOMTestGraph.createResolvedModule(
            packageIdentity: packageIdentity,
            module: module
        )
        let resolvedPackage = SBOMTestGraph.createResolvedPackage(
            package: package,
            modules: IdentifiableSet([resolvedModule]),
            products: []
        )

        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let component = try await SBOMModel.extractComponent(package: resolvedPackage, graph: nil, store: store)

        #expect(component.components != nil)
        #expect(component.components?.isEmpty == true, "Package with no products should have empty components array")
    }

    @Test("extractComponent from package preserves product order")
    func extractComponentFromPackagePreservesProductOrder() async throws {
        let (_, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)

        let packageComponent = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        let productComponents = try #require(packageComponent.components)
        let productNames = productComponents.map(\.name)
        let expectedProductNames = rootPackage.products.map(\.name)

        #expect(productNames == expectedProductNames, "Product components should maintain the same order as package products")
    }

    @Test("extractComponent uses origin remote for version commit")
    func extractComponentUsesOriginRemoteForVersionCommit() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        // Add a second remote to verify origin is preferred
        try await Process.checkNonZeroExit(
            args: "git",
            "-C",
            spmPath.pathString,
            "remote",
            "add",
            "upstream",
            "https://github.com/apple/swift-package-manager.git"
        )

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try spmRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        // Verify the version commit uses the origin remote, not upstream
        #expect(component.version.commit?.repository == SBOMTestStore.swiftPMURL)
        #expect(component.version.commit?.sha == expectedRevision)

        // Verify originator still contains all remotes
        #expect(component.originator.commits != nil)
        let commits = try #require(component.originator.commits)
        #expect(commits.count == 2, "Should have commits for both origin and upstream remotes")
        
        let originCommit = commits.first { $0.repository == SBOMTestStore.swiftPMURL }
        let upstreamCommit = commits.first { $0.repository == "https://github.com/apple/swift-package-manager.git" }
        #expect(originCommit != nil, "Should have commit for origin remote")
        #expect(upstreamCommit != nil, "Should have commit for upstream remote")
    }

    @Test("extractComponent falls back to first remote when no origin exists")
    func extractComponentFallsBackToFirstRemoteWhenNoOriginExists() async throws {
        let uniqueID = UUID().uuidString
        let path = AbsolutePath("/tmp/SwiftPM-no-origin-\(uniqueID)")
        defer { try? SBOMTestRepo.cleanup(path) }

        try localFileSystem.createDirectory(path, recursive: true)
        initGitRepo(path, addFile: true)

        // Add a remote with a different name (not "origin")
        let customRemoteURL = "https://github.com/custom/repo.git"
        try await Process.checkNonZeroExit(
            args: "git",
            "-C",
            path.pathString,
            "remote",
            "add",
            "custom",
            customRemoteURL
        )

        let gitRepo = GitRepository(path: path)
        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: path.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try gitRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)

        // Should fall back to the first (and only) remote
        #expect(component.version.commit?.repository == customRemoteURL)
        #expect(component.version.commit?.sha == expectedRevision)

        // Verify originator contains the custom remote
        #expect(component.originator.commits != nil)
        let commits = try #require(component.originator.commits)
        #expect(commits.count == 1)
        #expect(commits.first?.repository == customRemoteURL)
    }

    @Test("extractComponent handles repository with no remotes")
    func extractComponentHandlesRepositoryWithNoRemotes() async throws {
        let uniqueID = UUID().uuidString
        let path = AbsolutePath("/tmp/SwiftPM-no-remotes-\(uniqueID)")
        defer { try? SBOMTestRepo.cleanup(path) }

        try localFileSystem.createDirectory(path, recursive: true)
        initGitRepo(path, addFile: true)

        // Don't add any remotes
        let gitRepo = GitRepository(path: path)
        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: path.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let expectedRevision = try gitRepo.getCurrentRevision().identifier

        let component = try await SBOMModel.extractComponent(package: rootPackage, graph: graph, store: store)
        #expect(component.version.commit == nil)
        #expect(component.version.revision == expectedRevision)
        #expect(component.originator.commits == nil)
    }
}
