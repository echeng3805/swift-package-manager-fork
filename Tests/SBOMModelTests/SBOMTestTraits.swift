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

/// Tests for SBOM extraction with trait-enabled dependencies
/// Based on patterns from WorkspaceTests+Traits.swift and ModulesGraphTests+Traits.swift
struct SBOMTestTraits {
    
    @Test("SBOM extraction with packages that have enabled traits")
    func sbom_whenPackageHasEnabledTraits() async throws {
        // Create a simple package with enabled traits
        let rootIdentity = PackageIdentity.plain("RootPackage")
        
        let rootModule = SBOMTestModulesGraph.createSwiftModule(name: "RootModule")
        let rootProduct = try Product(
            package: rootIdentity,
            name: "RootProduct",
            type: .library(.automatic),
            modules: [rootModule]
        )
        let rootPackage = SBOMTestModulesGraph.createPackage(
            identity: rootIdentity,
            displayName: "RootPackage",
            path: "/RootPackage",
            modules: [rootModule],
            products: [rootProduct]
        )
        let resolvedRootModule = SBOMTestModulesGraph.createResolvedModule(
            packageIdentity: rootIdentity,
            module: rootModule
        )
        let resolvedRootProduct = SBOMTestModulesGraph.createResolvedProduct(
            packageIdentity: rootIdentity,
            product: rootProduct,
            modules: IdentifiableSet([resolvedRootModule])
        )
        let resolvedRoot = SBOMTestModulesGraph.createResolvedPackage(
            package: rootPackage,
            modules: IdentifiableSet([resolvedRootModule]),
            products: [resolvedRootProduct],
            enabledTraits: ["Trait1", "Trait2"]
        )
        
        let graph = try ModulesGraph(
            rootPackages: [resolvedRoot],
            packages: IdentifiableSet([resolvedRoot]),
            dependencies: [],
            binaryArtifacts: [:]
        )
        
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)
        let dependencies = try await extractor.extractDependencies()
        
        // Verify package is included in SBOM
        #expect(dependencies.components.count >= 1)
        #expect(dependencies.components.contains(where: { $0.name == "RootPackage" }))
    }
    
    @Test("SBOM extraction with no enabled traits")
    func sbom_whenNoTraitsEnabled() async throws {
        let rootIdentity = PackageIdentity.plain("RootPackage")
        
        let rootModule = SBOMTestModulesGraph.createSwiftModule(name: "RootModule")
        let rootProduct = try Product(
            package: rootIdentity,
            name: "RootProduct",
            type: .library(.automatic),
            modules: [rootModule]
        )
        let rootPackage = SBOMTestModulesGraph.createPackage(
            identity: rootIdentity,
            displayName: "RootPackage",
            path: "/RootPackage",
            modules: [rootModule],
            products: [rootProduct]
        )
        let resolvedRootModule = SBOMTestModulesGraph.createResolvedModule(
            packageIdentity: rootIdentity,
            module: rootModule
        )
        let resolvedRootProduct = SBOMTestModulesGraph.createResolvedProduct(
            packageIdentity: rootIdentity,
            product: rootProduct,
            modules: IdentifiableSet([resolvedRootModule])
        )
        let resolvedRoot = SBOMTestModulesGraph.createResolvedPackage(
            package: rootPackage,
            modules: IdentifiableSet([resolvedRootModule]),
            products: [resolvedRootProduct],
            enabledTraits: nil
        )
        
        let graph = try ModulesGraph(
            rootPackages: [resolvedRoot],
            packages: IdentifiableSet([resolvedRoot]),
            dependencies: [],
            binaryArtifacts: [:]
        )
        
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)
        let dependencies = try await extractor.extractDependencies()
        
        // Verify package is included in SBOM even without traits
        #expect(dependencies.components.count >= 1)
        #expect(dependencies.components.contains(where: { $0.name == "RootPackage" }))
    }
    
    @Test("SBOM scope extraction respects package traits")
    func sbom_whenScopeExtractionWithTraits() throws {
        let rootIdentity = PackageIdentity.plain("RootPackage")
        
        let rootModule = SBOMTestModulesGraph.createSwiftModule(name: "RootModule")
        let rootProduct = try Product(
            package: rootIdentity,
            name: "RootProduct",
            type: .library(.automatic),
            modules: [rootModule]
        )
        let rootPackage = SBOMTestModulesGraph.createPackage(
            identity: rootIdentity,
            displayName: "RootPackage",
            path: "/RootPackage",
            modules: [rootModule],
            products: [rootProduct]
        )
        let resolvedRootModule = SBOMTestModulesGraph.createResolvedModule(
            packageIdentity: rootIdentity,
            module: rootModule
        )
        let resolvedRootProduct = SBOMTestModulesGraph.createResolvedProduct(
            packageIdentity: rootIdentity,
            product: rootProduct,
            modules: IdentifiableSet([resolvedRootModule])
        )
        let resolvedRoot = SBOMTestModulesGraph.createResolvedPackage(
            package: rootPackage,
            modules: IdentifiableSet([resolvedRootModule]),
            products: [resolvedRootProduct],
            enabledTraits: ["RuntimeTrait"]
        )
        
        // Test scope extraction - traits should not affect scope determination
        let scope = try SBOMExtractor.extractScope(from: resolvedRoot)
        #expect(scope == SBOMComponent.Scope.runtime)
        
        let productScope = try SBOMExtractor.extractScope(from: resolvedRootProduct)
        #expect(productScope == SBOMComponent.Scope.runtime)
    }
    
    @Test("SBOM extraction with package dependencies and traits")
    func sbom_whenPackageDependenciesWithTraits() async throws {
        let rootIdentity = PackageIdentity.plain("RootPackage")
        let depIdentity = PackageIdentity.plain("DependencyPackage")
        
        // Create dependency package with traits
        let depModule = SBOMTestModulesGraph.createSwiftModule(name: "DepModule")
        let depProduct = try Product(
            package: depIdentity,
            name: "DepProduct",
            type: .library(.automatic),
            modules: [depModule]
        )
        let depPackage = SBOMTestModulesGraph.createPackage(
            identity: depIdentity,
            displayName: "DependencyPackage",
            path: "/DependencyPackage",
            modules: [depModule],
            products: [depProduct]
        )
        let resolvedDepModule = SBOMTestModulesGraph.createResolvedModule(
            packageIdentity: depIdentity,
            module: depModule
        )
        let resolvedDepProduct = SBOMTestModulesGraph.createResolvedProduct(
            packageIdentity: depIdentity,
            product: depProduct,
            modules: IdentifiableSet([resolvedDepModule])
        )
        let resolvedDep = SBOMTestModulesGraph.createResolvedPackage(
            package: depPackage,
            modules: IdentifiableSet([resolvedDepModule]),
            products: [resolvedDepProduct],
            enabledTraits: ["DepTrait1"]
        )
        
        // Create root package with dependency and traits
        let rootModule = SBOMTestModulesGraph.createSwiftModule(
            name: "RootModule",
            dependencies: [
                .product(Module.ProductReference(name: "DepProduct", package: depIdentity.description), conditions: [])
            ]
        )
        let rootProduct = try Product(
            package: rootIdentity,
            name: "RootProduct",
            type: .library(.automatic),
            modules: [rootModule]
        )
        let rootPackage = SBOMTestModulesGraph.createPackage(
            identity: rootIdentity,
            displayName: "RootPackage",
            path: "/RootPackage",
            modules: [rootModule],
            products: [rootProduct]
        )
        let resolvedRootModule = SBOMTestModulesGraph.createResolvedModule(
            packageIdentity: rootIdentity,
            module: rootModule,
            dependencies: [.product(resolvedDepProduct, conditions: [])]
        )
        let resolvedRootProduct = SBOMTestModulesGraph.createResolvedProduct(
            packageIdentity: rootIdentity,
            product: rootProduct,
            modules: IdentifiableSet([resolvedRootModule])
        )
        let resolvedRoot = SBOMTestModulesGraph.createResolvedPackage(
            package: rootPackage,
            modules: IdentifiableSet([resolvedRootModule]),
            products: [resolvedRootProduct],
            dependencies: [depIdentity],
            enabledTraits: ["RootTrait1"]
        )
        
        let graph = try ModulesGraph(
            rootPackages: [resolvedRoot],
            packages: IdentifiableSet([resolvedRoot, resolvedDep]),
            dependencies: [],
            binaryArtifacts: [:]
        )
        
        let store = try SBOMTestStore.createSimpleResolvedPackagesStore()
        let extractor = SBOMExtractor(modulesGraph: graph, dependencyGraph: nil, store: store)
        let dependencies = try await extractor.extractDependencies()
        
        // Verify both packages are included
        #expect(dependencies.components.count >= 2)
        #expect(dependencies.components.contains(where: { $0.name == "RootPackage" }))
        #expect(dependencies.components.contains(where: { $0.name == "DependencyPackage" }))
        
        // Verify dependency relationship exists
        #expect(dependencies.relationships?.count ?? 0 >= 1)
    }
}