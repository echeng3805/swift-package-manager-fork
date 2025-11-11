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
import PackageGraph
import PackageModel
@testable import SBOMModel
import Testing
import class TSCBasic.Process

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
        totalComponentCount: 22,
        expectedPackageIds: Set([
            "swift-system", "swift-driver", "swift-tools-support-core", "SwiftPM", "swift-collections", "swift-llbuild"
        ]),
        rootPackagePrefix: "SwiftPM:",
        expectedRootProductCount: 10,
        expectedRootProductNames: Set([
            "PackageCollectionsModel", "SwiftPM-auto", "PackageDescription",
            "PackagePlugin", "XCBuildSupport", "SwiftPMDataModel-auto", "SwiftPMPackageCollections",
            "AppleProductTypes", "SwiftPM", "SwiftPMDataModel",
        ]),
        expectedDependencyProductCount: 12
    )

    private static let swiftlyExpectations = TestExpectations(
        totalComponentCount: 17,
        expectedPackageIds: Set([
            "swift-openapi-runtime",
            "swift-openapi-async-http-client",
            "swift-system", "swiftly",
            "swift-argument-parser", "swift-tools-support-core",
            "async-http-client", "swift-nio"
            
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

        let componentPackageIds = Set(components.compactMap { component in
            component.id.value.components(separatedBy: ":").first
        })
        #expect(componentPackageIds == expectations.expectedPackageIds, "Package IDs did not match")

        let rootProducts = components.filter { $0.id.value.hasPrefix(expectations.rootPackagePrefix) }
        #expect(rootProducts.count == expectations.expectedRootProductCount)
        let rootProductNames = Set(rootProducts.map(\.name))
        #expect(rootProductNames == expectations.expectedRootProductNames)

        let dependencyProducts = components.filter { !$0.id.value.hasPrefix(expectations.rootPackagePrefix) }
        #expect(dependencyProducts.count == expectations.expectedDependencyProductCount)

        for component in components {
            #expect(!component.id.value.isEmpty, "Component ID should not be empty")
            #expect(!component.name.isEmpty, "Component name should not be empty")
            #expect(!component.purl.isEmpty, "Component PURL should not be empty")
            #expect(!component.version.revision.isEmpty, "Component version should not be empty")
            #expect(
                component.category == .application || component.category == .library,
                "Component category should be application or library"
            )
            #expect(
                component.scope == .runtime || component.scope == .test,
                "Component scope should be runtime or test"
            )
        }
    }

    @Test("extractComponents with sample SPM ModulesGraph")
    func extractComponentsFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        self.verifyComponents(components: components, graph: graph, expectations: Self.spmExpectations)
    }

    @Test("extractComponents with sample Swiftly ModulesGraph")
    func extractComponentsFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components
        self.verifyComponents(components: components, graph: graph, expectations: Self.swiftlyExpectations)
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
        await #expect(throws: SBOMExtractorError.self) {
            _ = try await SBOMModel.extractDependencies(graph: emptyGraph, store: store).components
        }
    }

    @Test("extractComponents verifies commit extraction for non-main branch dependency")
    func extractComponentsForNonMainBranch() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components

        let swiftLLBuildComponent = components.first { component in
            component.id.value == "swift-llbuild" || component.name == "swift-llbuild"
        }

        let component = try #require(swiftLLBuildComponent, "swift-llbuild component should be found")

        let commits = try #require(
            component.originator.commits,
            "swift-llbuild component should have commit information"
        )
        #expect(!commits.isEmpty, "swift-llbuild should have at least one commit")

        let commit = commits[0]
        #expect(!commit.sha.isEmpty, "Commit SHA should not be empty")
        #expect(commit.repository == "https://github.com/swiftlang/swift-llbuild.git", "Repository URL should match")

        let expectedMockRevision = SBOMTestStore.generateMockRevision(for: "swift-llbuild")
        #expect(commit.sha == expectedMockRevision, "Commit SHA should match the mock revision for swift-llbuild")

        #expect(
            component.version.revision == commit.sha,
            "Component version should match commit SHA for branch-based dependency"
        )
    }

    @Test("extractComponents uses version tag when available for version, but keeps pedigree as commit sha")
    func extractComponentsUsesVersionTagWhenAvailable() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components

        // Find a version-based dependency (swift-argument-parser uses version "1.5.1")
        let swiftSystemComponent = components.first { component in component.id.value == "swift-system" }

        let versionComponent = try #require(swiftSystemComponent, "component should be found")

        let commits = try #require(
            versionComponent.originator.commits,
            "component should have commit information"
        )
        #expect(!commits.isEmpty, "component should have at least one commit")

        let commit = commits[0]
        #expect(!commit.sha.isEmpty, "Commit SHA should not be empty")
        #expect(
            commit.repository == "https://github.com/apple/swift-system.git",
            "Repository URL should match"
        )

        #expect(
            versionComponent.version.revision == "1.3.2",
            "Component version should be the version tag for version-based dependency"
        )
        #expect(
            versionComponent.version.revision != commit.sha,
            "Component version should not be the commit SHA for version-based dependency"
        )
    }

    @Test("extractComponents with product filter")
    func extractComponentsWithProductFilter() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel
            .extractDependencies(graph: graph, store: store, product: "SwiftPMDataModel").components
        let allComponents = try await SBOMModel.extractDependencies(graph: graph, store: store).components

        #expect(components.count < allComponents.count)

        let componentIDs = Set(components.map(\.id.value))
        #expect(components.count > 0)
        #expect(components.count < allComponents.count)

        let expectedComponentIDs: Set<String> = [
            "swift-system:SystemPackage", "swift-system",
            "swift-collections:DequeModule", "SwiftPM:SwiftPMDataModel",
            "swift-collections:OrderedCollections", "swift-tools-support-core",
            "swift-collections", "swift-tools-support-core:SwiftToolsSupport-auto", "SwiftPM"
        ]
        #expect(componentIDs == expectedComponentIDs)

        let componentIDsList = components.map(\.id)
        let uniqueIDs = Set(componentIDsList)
        #expect(componentIDsList.count == uniqueIDs.count)
    }

    @Test("Root package components should not have 'unknown' versions")
    func rootPackageComponentsShouldNotHaveUnknownVersions() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components

        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = rootPackage.identity.description

        let actualRevision = try spmRepo.getCurrentRevision().identifier

        let rootComponents = components.filter { component in
            component.id.value == rootPackageID || component.id.value.hasPrefix("\(rootPackageID):")
        }

        #expect(!rootComponents.isEmpty, "Should have root package components")

        for component in rootComponents {
            #expect(component.version.revision == actualRevision)
            #expect(
                component.originator.commits != nil,
                "Root package component '\(component.id.value)' should have commit information"
            )
            if let commits = component.originator.commits {
                #expect(!commits.isEmpty)
                #expect(commits[0].sha == actualRevision)
            }
        }
    }

    @Test("Root package components should include all remotes in originator")
    func rootPackageComponentsShouldIncludeAllRemotesInOriginator() async throws {
        let (spmRepo, spmPath) = try SBOMTestRepo.setupSPMTestRepo()
        defer { try? SBOMTestRepo.cleanup(spmPath) }

        // Add a second remote to test multiple remotes
        try await Process.checkNonZeroExit(
            args: "git",
            "-C",
            spmPath.pathString,
            "remote",
            "add",
            "upstream",
            "https://github.com/fork/swift-package-manager.git"
        )

        let graph = try SBOMTestGraph.createSPMModulesGraph(rootPath: spmPath.pathString)
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let components = try await SBOMModel.extractDependencies(graph: graph, store: store).components

        let rootPackage = try #require(graph.rootPackages.first)
        let rootPackageID = rootPackage.identity.description

        let actualRevision = try spmRepo.getCurrentRevision().identifier

        let rootComponents = components.filter { component in
            component.id.value == rootPackageID || component.id.value.hasPrefix("\(rootPackageID):")
        }

        #expect(!rootComponents.isEmpty, "Should have root package components")

        for component in rootComponents {
            let commits = try #require(
                component.originator.commits,
                "Root package component '\(component.id.value)' should have commit information"
            )
            
            #expect(commits.count == 2, "Should have commits for both remotes (origin and upstream)")
            
            for commit in commits {
                #expect(commit.sha == actualRevision, "All commits should have the same SHA")
            }
            
            let repositories = Set(commits.map(\.repository))
            #expect(repositories.contains(SBOMTestStore.swiftPMURL), "Should include origin remote")
            #expect(
                repositories.contains("https://github.com/fork/swift-package-manager.git"),
                "Should include upstream remote"
            )
        }
    }
}
