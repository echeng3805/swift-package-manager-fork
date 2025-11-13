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

import Basics
import Foundation
import PackageCollections
import PackageGraph
import PackageModel
import SourceControl
import TSCUtility

/// Cache for storing root package Git info (to minimize calls to Git)
package actor SBOMGitCache {
    private var cache: [PackageIdentity: SBOMGitInfo] = [:]
    package func get(_ identity: PackageIdentity) -> SBOMGitInfo? {
        self.cache[identity]
    }

    package func set(_ identity: PackageIdentity, gitInfo: SBOMGitInfo) {
        self.cache[identity] = gitInfo
    }
}

/// Cache for storing extracted components (to avoid redundant extraction)
package actor SBOMComponentCache {
    private var packageCache: [PackageIdentity: SBOMComponent] = [:]
    private var productCache: [String: SBOMComponent] = [:] // key: "packageIdentity:productName"
    
    package func getPackage(_ identity: PackageIdentity) -> SBOMComponent? {
        self.packageCache[identity]
    }
    
    package func setPackage(_ identity: PackageIdentity, component: SBOMComponent) {
        self.packageCache[identity] = component
    }
    
    package func getProduct(_ packageIdentity: PackageIdentity, productName: String) -> SBOMComponent? {
        let key = "\(packageIdentity):\(productName)"
        return self.productCache[key]
    }
    
    package func setProduct(_ packageIdentity: PackageIdentity, productName: String, component: SBOMComponent) {
        let key = "\(packageIdentity):\(productName)"
        self.productCache[key] = component
    }
}

package struct SBOMGitInfo {
    package let version: SBOMComponent.Version
    package let originator: SBOMOriginator
    
    package init(version: SBOMComponent.Version, originator: SBOMOriginator) {
        self.version = version
        self.originator = originator
    }
}

/// Extractor for generating SBOM documents
package struct SBOMExtractor {
    let modulesGraph: ModulesGraph
    let dependencyGraph: [String: [String]]?
    let store: ResolvedPackagesStore
    let gitCache: SBOMGitCache
    let componentCache: SBOMComponentCache
    
    package init(
        modulesGraph: ModulesGraph,
        dependencyGraph: [String: [String]]? = nil,
        store: ResolvedPackagesStore
    ) {
        self.modulesGraph = modulesGraph
        self.dependencyGraph = dependencyGraph
        self.store = store
        self.gitCache = SBOMGitCache()
        self.componentCache = SBOMComponentCache()
    }
    
    package init(
        modulesGraph: ModulesGraph,
        dependencyGraph: [String: [String]]? = nil,
        store: ResolvedPackagesStore,
        gitCache: SBOMGitCache,
        componentCache: SBOMComponentCache
    ) {
        self.modulesGraph = modulesGraph
        self.dependencyGraph = dependencyGraph
        self.store = store
        self.gitCache = gitCache
        self.componentCache = componentCache
    }
    
    package func extractMetadata() async throws -> SBOMMetadata {
        return SBOMMetadata(
            timestamp: Date().ISO8601Format(),
            creators: [
                SBOMTool(
                    id: SBOMIdentifier.generate(),
                    name: "swift-package-manager",
                    version: SwiftVersion.current.displayString,
                    licenses: [
                        SBOMLicense( // TODO ev_cheng: better way to get license without network call?
                            name: PackageCollectionsModel.LicenseType.Apache2_0.description,
                            url: "http://swift.org/LICENSE.txt"
                        ),
                    ]
                ),
            ]
        )
    }

    package static func extractCategory(from package: ResolvedPackage) throws -> SBOMComponent.Category {
        let productCategories = package.products.map(\.type)
        if productCategories.contains(.executable) {
            return .application
        }
        return .library
    }

    package static func extractCategory(from product: ResolvedProduct) throws -> SBOMComponent.Category {
        switch product.type {
        case .executable:
            .application
        case .library, .snippet, .plugin, .test, .macro:
            .library
        }
    }

    package static func extractScope(from product: ResolvedProduct) throws -> SBOMComponent.Scope {
        // A product is only .test scope if it's a test product type OR all its modules are test modules
        if product.type == .test {
            return .test
        }
        
        // For non-test products, check if ALL modules are test modules
        guard !product.modules.isEmpty else {
            return .runtime
        }
        
        let allModulesAreTests = product.modules.allSatisfy { $0.type == .test }
        return allModulesAreTests ? .test : .runtime
    }

    package static func extractScope(from package: ResolvedPackage) throws -> SBOMComponent.Scope {
        // A package is only .test scope if ALL products are test products
        guard !package.products.isEmpty else {
            return .runtime
        }
        
        let allProductsAreTests = package.products.allSatisfy { product in
            product.isLinkingXCTest || product.type == .test
        }
        
        return allProductsAreTests ? .test : .runtime
    }
    
    private func extractComponentInfoFromGit(packagePath: AbsolutePath) async throws -> SBOMGitInfo {
        let gitRepo = GitRepository(path: packagePath, isWorkingRepo: true)
        
        let currentRevision = try? gitRepo.getCurrentRevision()
        guard let currentRevision else {
            return SBOMGitInfo(
                version: SBOMComponent.Version(revision: "unknown"),
                originator: SBOMOriginator(commits: nil)
            )
        }
        
        let remotes = (try? gitRepo.remotes()) ?? []
        let hasUncommittedChanges = gitRepo.hasUncommittedChanges()
        let currentTag = gitRepo.getCurrentTag()
        
        let revisionString: String
        if let currentTag {
            revisionString = hasUncommittedChanges ? "\(currentTag)-modified" : currentTag
        } else {
            revisionString = hasUncommittedChanges ? "\(currentRevision.identifier)-modified" : currentRevision.identifier
        }
        
        let primaryRemote = remotes.first(where: { $0.name == "origin" }) ?? remotes.first
        
        let versionCommit: SBOMCommit?
        let commits: [SBOMCommit]?
        
        if let primaryRemote {
            let commit = SBOMCommit(
                sha: currentRevision.identifier,
                repository: primaryRemote.url
            )
            versionCommit = commit
            commits = [commit]
        } else {
            versionCommit = nil
            commits = nil
        }
        
        return SBOMGitInfo(
            version: SBOMComponent.Version(
                revision: revisionString,
                commit: versionCommit
            ),
            originator: SBOMOriginator(commits: commits)
        )
    }

    private func extractComponentVersionAndCommits(from packageIdentity: PackageIdentity) async throws -> SBOMGitInfo {
        if let cachedGitInfo = await gitCache.get(packageIdentity) {
            return cachedGitInfo
        }
        // root package (try to get version and commits from git)
        if let rootPackage = modulesGraph.rootPackages.first(where: { $0.identity == packageIdentity }) {
            let gitInfo = try await extractComponentInfoFromGit(packagePath: rootPackage.path)
            await gitCache.set(packageIdentity, gitInfo: gitInfo)
            return gitInfo
        }
        guard let resolvedPackage = store.resolvedPackages[packageIdentity] else {
            return SBOMGitInfo(
                version: SBOMComponent.Version(revision: "unknown"),
                originator: SBOMOriginator(commits: nil)
            )
        }
        // non-root package (version is from store)
        let version: String
        let sha: String
        switch resolvedPackage.state {
        case .version(let versionValue, let revision):
            version = versionValue.description
            if let revision {
                sha = revision
            } else {
                sha = "unknown"
            }
        case .branch(_, let revision), .revision(let revision):
            version = revision
            sha = revision
        }
        let commit = SBOMCommit(
            sha: sha,
            repository: resolvedPackage.packageRef.kind.locationString // absolute path, URL string, or package identity
        )
        return SBOMGitInfo(
            version: SBOMComponent.Version(revision: version, commit: commit),
            originator: SBOMOriginator(commits: [commit])
        )
    }
    
    package static func extractComponentID(from package: ResolvedPackage) -> SBOMIdentifier {
        SBOMIdentifier(value: package.identity.description)
    }

    package static func extractComponentID(from product: ResolvedProduct) -> SBOMIdentifier {
        SBOMIdentifier(value: "\(product.packageIdentity):\(product.name)")
    }

    private func extractProductsFromPackage(package: ResolvedPackage) async throws -> [SBOMComponent] {
        var productComponents: [SBOMComponent] = []
        for product in package.products {
            let productComponent = try await extractComponent(product: product)
            productComponents.append(productComponent)
        }
        return productComponents
    }

    package func extractComponent(package: ResolvedPackage) async throws -> SBOMComponent {
        if let cached = await componentCache.getPackage(package.identity) {
            return cached
        }
        
        let gitInfo = try await extractComponentVersionAndCommits(from: package.identity)
        let products = try await extractProductsFromPackage(package: package)
        let component = try await SBOMComponent(
            category: Self.extractCategory(from: package),
            id: Self.extractComponentID(from: package),
            purl: PURL.from(package: package, version: gitInfo.version).description,
            name: package.identity.description,
            version: gitInfo.version,
            originator: gitInfo.originator,
            description: package.description,
            scope: Self.extractScope(from: package),
            components: products
        )
        
        await componentCache.setPackage(package.identity, component: component)
        
        return component
    }

    package func extractComponent(product: ResolvedProduct) async throws -> SBOMComponent {
        if let cached = await componentCache.getProduct(product.packageIdentity, productName: product.name) {
            return cached
        }
        
        let gitInfo = try await extractComponentVersionAndCommits(from: product.packageIdentity)
        let component = try await SBOMComponent(
            category: Self.extractCategory(from: product),
            id: Self.extractComponentID(from: product),
            purl: PURL.from(product: product, version: gitInfo.version).description,
            name: product.name,
            version: gitInfo.version,
            originator: gitInfo.originator,
            description: nil,
            scope: Self.extractScope(from: product)
        )
        
        await componentCache.setProduct(product.packageIdentity, productName: product.name, component: component)
        
        return component
    }

    package func extractPrimaryComponent(product: String? = nil) async throws -> SBOMComponent {
        guard let rootPackage = modulesGraph.rootPackages.first else {
            throw SBOMExtractorError.noRootPackage(context: "determine primary component for SBOM")
        }
        // product of root package
        if let productName = product {
            guard let resolvedProduct = rootPackage.products.first(where: { $0.name == productName }) else {
                throw SBOMExtractorError.productNotFound(productName: productName, packageIdentity: rootPackage.identity.description)
            }
            return try await extractComponent(product: resolvedProduct)
        }
        // root package
        return try await extractComponent(package: rootPackage)
    }

    package func extractSBOM(product: String? = nil) async throws -> SBOMDocument {
        return try await SBOMDocument(
            id: SBOMIdentifier.generate(),
            metadata: extractMetadata(),
            primaryComponent: extractPrimaryComponent(product: product),
            dependencies: extractDependencies(product: product)
        )
    }
}
