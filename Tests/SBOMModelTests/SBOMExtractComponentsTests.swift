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
import Basics
import PackageModel
import PackageGraph
@testable import SBOMModel
import _InternalTestSupport

struct SBOMExtractComponentsTests {
    
    struct TestExpectations {
        let totalComponentCount: Int
        let expectedPackageIds: Set<String>
        let rootPackagePrefix: String
        let expectedRootProductCount: Int
        let expectedRootProductNames: Set<String>
        let expectedDependencyProductCount: Int
    }
    
    private static let spmExpectations = TestExpectations(
        totalComponentCount: 42,
        expectedPackageIds: Set([
            "SwiftPM", "swift-system", "swift-collections", "swift-argument-parser",
            "swift-llbuild", "swift-tools-support-core", "swift-driver",
            "swift-crypto", "swift-certificates"
        ]),
        rootPackagePrefix: "SwiftPM:",
        expectedRootProductCount: 10,
        expectedRootProductNames: Set([
            "PackageCollectionsModel", "SwiftPM-auto", "PackageDescription",
            "PackagePlugin", "XCBuildSupport", "SwiftPMDataModel-auto", "SwiftPMPackageCollections",
            "AppleProductTypes", "SwiftPM", "SwiftPMDataModel"
        ]),
        expectedDependencyProductCount: 32
    )
    
    private static let swiftlyExpectations = TestExpectations(
        totalComponentCount: 17,
        expectedPackageIds: Set([
            "swiftly", "swift-argument-parser", "async-http-client",
            "swift-openapi-async-http-client", "swift-nio", "swift-tools-support-core",
            "swift-openapi-runtime", "swift-system"
        ]),
        rootPackagePrefix: "swiftly:",
        expectedRootProductCount: 2,
        expectedRootProductNames: Set(["swiftly", "test-swiftly"]),
        expectedDependencyProductCount: 15
    )
    
    private func verifyComponents(
        components: [SBOMComponent],
        graph: ModulesGraph,
        expectations: TestExpectations
    ) {
        #expect(components.count == expectations.totalComponentCount)

        let graphPackages = Set(graph.packages.map { $0.identity.description })
        let packageComponents = components.filter { !$0.id.contains(":") }
        let packageComponentIds = Set(packageComponents.map { $0.id })
        #expect(packageComponentIds == graphPackages, "All packages from graph should be converted to components")

        let componentPackageIds = Set(components.compactMap { component in
            component.id.components(separatedBy: ":").first
        })
        #expect(componentPackageIds == expectations.expectedPackageIds, "Package IDs did not match")

        let rootProducts = components.filter { $0.id.hasPrefix(expectations.rootPackagePrefix) }
        #expect(rootProducts.count == expectations.expectedRootProductCount)
        let rootProductNames = Set(rootProducts.map { $0.name })
        #expect(rootProductNames == expectations.expectedRootProductNames)

        let dependencyProducts = components.filter { !$0.id.hasPrefix(expectations.rootPackagePrefix) }
        #expect(dependencyProducts.count == expectations.expectedDependencyProductCount)

        for component in components {
            #expect(!component.id.isEmpty, "Component ID should not be empty")
            #expect(!component.name.isEmpty, "Component name should not be empty")
            #expect(!component.purl.isEmpty, "Component PURL should not be empty")
            #expect(!component.version.isEmpty, "Component version should not be empty")
            #expect(component.category == .application || component.category == .library, "Component category should be application or library")
            #expect(component.scope == .runtime || component.scope == .test, "Component scope should be runtime or test")
        }
    }
    
    @Test("extractComponents with sample SPM ModulesGraph")
    func extractComponentsFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractComponents(graph, store: store)
        
        verifyComponents(components: components, graph: graph, expectations: Self.spmExpectations)
    }

    @Test("extractComponents with sample Swiftly ModulesGraph")
    func extractComponentsFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let components = try await SBOMModel.extractComponents(graph, store: store)
        
        verifyComponents(components: components, graph: graph, expectations: Self.swiftlyExpectations)
    }
    
    @Test("extractComponents fails with empty root packages")
    func extractComponentsFailsWithEmptyRootPackages() async throws {
        let emptyGraph = try ModulesGraph(
            rootPackages: [],
            rootDependencies: [],
            packages: IdentifiableSet([]),
            dependencies: [],
            binaryArtifacts: [:]
        )
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        await #expect(throws: StringError.self) {
            _ = try await SBOMModel.extractComponents(emptyGraph, store: store)
        }
    }
}