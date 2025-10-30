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
import SourceControl
import Basics

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
        #expect(component.id == rootPackage.identity.description)
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
        #expect(component.id == rootPackage.identity.description)
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
        #expect(component.id == "SwiftPM:SwiftPMDataModel")
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
        #expect(component.id == "swiftly:swiftly")
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
        #expect(component.id == "SwiftPM:\(productName)")
        #expect(component.category == .library)
        
        let packageComponent = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        #expect(packageComponent.name == "SwiftPM")
        #expect(packageComponent.id == "SwiftPM")
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
        let cache = SBOMVersionCache()
        
        let component1 = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, cache: cache)
        #expect(component1.version.revision == expectedRevision)
        
        let cachedVersion = await cache.get(rootPackage.identity)
        #expect(cachedVersion != nil, "Cache should contain version for root package")
        #expect(cachedVersion?.revision == expectedRevision, "Cached version should match expected revision")
        
        let gitPath = spmPath.appending(".git")
        try localFileSystem.removeFileTree(gitPath)
        #expect(!localFileSystem.exists(gitPath), "Git directory should be removed")
        
        let component2 = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, cache: cache)
        #expect(component2.version.revision == expectedRevision, "Should return cached version even without Git")
        #expect(component2.version.revision == component1.version.revision, "Both extractions should return same version")
        
        let resolvedProduct = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })
        let productComponent = try await SBOMModel.extractComponent(product: resolvedProduct, graph: graph, store: store, cache: cache)
        #expect(productComponent.version.revision == expectedRevision, "Product should use cached version from root package")
        
        let cachedVersionAfter = await cache.get(rootPackage.identity)
        #expect(cachedVersionAfter?.revision == expectedRevision, "Cache should still contain same version")
    }
}