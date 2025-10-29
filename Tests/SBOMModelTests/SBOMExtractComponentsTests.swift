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
            #expect(!component.version.revision.isEmpty, "Component version should not be empty")
            #expect(component.category == .application || component.category == .library, "Component category should be application or library")
            #expect(component.scope == .runtime || component.scope == .test, "Component scope should be runtime or test")
        }
    }
    
    @Test("extractComponents with sample SPM ModulesGraph")
    func extractComponentsFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        verifyComponents(components: components, graph: graph, expectations: Self.spmExpectations)
    }

    @Test("extractComponents with sample Swiftly ModulesGraph")
    func extractComponentsFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
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
            _ = try await SBOMModel.extractDependencies(graph: emptyGraph, store: store).components
        }
    }
    
    @Test("extractComponents verifies commit extraction for non-main branch dependency")
    func extractComponentsForNonMainBranch() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        
        let swiftLLBuildComponent = components.first { component in
            component.id == "swift-llbuild" || component.name == "swift-llbuild"
        }
        
        let component = try #require(swiftLLBuildComponent, "swift-llbuild component should be found")
        
        let commits = try #require(component.originator.commits, "swift-llbuild component should have commit information")
        #expect(!commits.isEmpty, "swift-llbuild should have at least one commit")
        
        let commit = commits[0]
        #expect(!commit.sha.isEmpty, "Commit SHA should not be empty")
        #expect(commit.repository == "https://github.com/swiftlang/swift-llbuild.git", "Repository URL should match")
        
        let expectedMockRevision = String(format: "%040x", abs("swift-llbuild".hash)).prefix(40).padding(toLength: 40, withPad: "0", startingAt: 0)
        #expect(commit.sha == expectedMockRevision, "Commit SHA should match the mock revision for swift-llbuild")
        
        #expect(component.version.revision == commit.sha, "Component version should match commit SHA for branch-based dependency")
    }
    
    @Test("extractComponents uses version tag when available for version, but keeps pedigree as commit sha")
    func extractComponentsUsesVersionTagWhenAvailable() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        
        // Find a version-based dependency (swift-argument-parser uses version "1.5.1")
        let argParserComponent = components.first { component in
            component.id == "swift-argument-parser" || component.name == "swift-argument-parser"
        }
        
        let versionComponent = try #require(argParserComponent, "swift-argument-parser component should be found")
        
        let commits = try #require(versionComponent.originator.commits, "swift-argument-parser component should have commit information")
        #expect(!commits.isEmpty, "swift-argument-parser should have at least one commit")
        
        let commit = commits[0]
        #expect(!commit.sha.isEmpty, "Commit SHA should not be empty")
        #expect(commit.repository == "https://github.com/apple/swift-argument-parser.git", "Repository URL should match")
        
        #expect(versionComponent.version.revision == "1.5.1", "Component version should be the version tag for version-based dependency")
        #expect(versionComponent.version.revision != commit.sha, "Component version should not be the commit SHA for version-based dependency")
    }

    @Test("extractComponents with product filter")
    func extractComponentsWithProductFilter() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store, product: "SwiftPMDataModel").components
        let allComponents = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        
        #expect(components.count < allComponents.count)
        
        let componentIDs = Set(components.map { $0.id })
        #expect(componentIDs.contains("SwiftPM:SwiftPMDataModel"))
        #expect(componentIDs.contains("SwiftPM"))

        // TODO: also check for other stuff
    }
}
