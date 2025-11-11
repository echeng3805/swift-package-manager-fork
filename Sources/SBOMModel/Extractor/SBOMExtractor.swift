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

package struct SBOMGitInfo {
    package let version: SBOMComponent.Version
    package let originator: SBOMOriginator
    
    package init(version: SBOMComponent.Version, originator: SBOMOriginator) {
        self.version = version
        self.originator = originator
    }
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

package func extractCategory(from package: ResolvedPackage) async throws -> SBOMComponent.Category {
    let productCategories = package.products.map(\.type)
    if productCategories.contains(.executable) {
        return .application
    }
    return .library
}

package func extractCategory(from product: ResolvedProduct) async throws -> SBOMComponent.Category {
    switch product.type {
    case .executable:
        .application
    case .library, .snippet, .plugin, .test, .macro:
        .library
    }
}

package func extractScope(from product: ResolvedProduct) async throws -> SBOMComponent.Scope {
    if product.isLinkingXCTest {
        return .test
    }
    return .runtime
}

package func extractScope(from package: ResolvedPackage) async throws -> SBOMComponent.Scope {
    for product in package.products {
        if product.isLinkingXCTest {
            return .test
        }
    }
    for module in package.modules {
        if module.type == .test {
            return .test
        }
    }
    return .runtime
}

private func extractComponentInfoFromGit(packagePath: AbsolutePath) async throws -> SBOMGitInfo {
    let gitRepo = GitRepository(path: packagePath, isWorkingRepo: true)
    guard let currentRevision = try? gitRepo.getCurrentRevision() else {
        return SBOMGitInfo(
            version: SBOMComponent.Version(revision: "unknown"),
            originator: SBOMOriginator(commits: nil)
        )
    }
    let remotes = (try? gitRepo.remotes()) ?? []
    let hasUncommittedChanges = gitRepo.hasUncommittedChanges()
    
    let revisionString: String
    if let currentTag = gitRepo.getCurrentTag() {
        revisionString = hasUncommittedChanges ? "\(currentTag)-modified" : currentTag
    } else {
        revisionString = hasUncommittedChanges ? "\(currentRevision.identifier)-modified" : currentRevision.identifier
    }
    
    // use the origin remote to avoid listing commits that may not exist in all remotes
    let originRemote = remotes.first(where: { $0.name == "origin" })
    // else fall back to the first remote option
    let primaryRemote = originRemote ?? remotes.first
    
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

private func extractComponentVersionAndCommits(
    from packageIdentity: PackageIdentity,
    graph: ModulesGraph? = nil,
    store resolvedPackagesStore: ResolvedPackagesStore,
    cache: SBOMGitCache?
) async throws -> SBOMGitInfo {
    if let cache, let cachedGitInfo = await cache.get(packageIdentity) {
        return cachedGitInfo
    }
    // root package (try to get version and commits from git)
    if let graph, let rootPackage = graph.rootPackages.first(where: { $0.identity == packageIdentity }) {
        let gitInfo = try await extractComponentInfoFromGit(packagePath: rootPackage.path)
        if let cache {
            await cache.set(packageIdentity, gitInfo: gitInfo)
        }
        return gitInfo
    }
    guard let resolvedPackage = resolvedPackagesStore.resolvedPackages[packageIdentity] else {
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
package func extractComponentID(from package: ResolvedPackage) async -> SBOMIdentifier {
    SBOMIdentifier(value: package.identity.description)
}

package func extractComponentID(from product: ResolvedProduct) async -> SBOMIdentifier {
    SBOMIdentifier(value: "\(product.packageIdentity):\(product.name)")
}

private func extractProductsFromPackage(
    package: ResolvedPackage,
    graph: ModulesGraph? = nil,
    store: ResolvedPackagesStore,
    cache: SBOMGitCache? = nil
) async throws -> [SBOMComponent] {
    var productComponents: [SBOMComponent] = []
    for product in package.products {
        let productComponent = try await extractComponent(product: product, graph: graph, store: store, cache: cache)
        productComponents.append(productComponent)
    }
    return productComponents
}

package func extractComponent(
    package: ResolvedPackage,
    graph: ModulesGraph? = nil,
    store: ResolvedPackagesStore,
    cache: SBOMGitCache? = nil
) async throws -> SBOMComponent {
    let gitInfo = try await extractComponentVersionAndCommits(
        from: package.identity,
        graph: graph,
        store: store,
        cache: cache
    )
    let products = try await extractProductsFromPackage(package: package, graph: graph, store: store, cache: cache)
    return try await SBOMComponent(
        category: extractCategory(from: package),
        id: extractComponentID(from: package),
        purl: PURL.from(package: package, version: gitInfo.version).description,
        name: package.identity.description,
        version: gitInfo.version,
        originator: gitInfo.originator,
        description: package.description,
        scope: extractScope(from: package),
        components: products
    )
}

package func extractComponent(
    product: ResolvedProduct,
    graph: ModulesGraph? = nil,
    store: ResolvedPackagesStore,
    cache: SBOMGitCache? = nil
) async throws -> SBOMComponent {
    let gitInfo = try await extractComponentVersionAndCommits(
        from: product.packageIdentity,
        graph: graph,
        store: store,
        cache: cache
    )
    return try await SBOMComponent(
        category: extractCategory(from: product),
        id: extractComponentID(from: product),
        purl: PURL.from(product: product, version: gitInfo.version).description,
        name: product.name,
        version: gitInfo.version,
        originator: gitInfo.originator,
        description: nil,
        scope: extractScope(from: product)
    )
}

package func extractPrimaryComponent(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil,
    cache: SBOMGitCache? = nil
) async throws -> SBOMComponent {
    guard let rootPackage = graph.rootPackages.first else {
        throw SBOMExtractorError.noRootPackage(context: "determine primary component for SBOM")
    }
    // product of root package
    if let productName = product {
        guard let resolvedProduct = rootPackage.products.first(where: { $0.name == productName }) else {
            throw SBOMExtractorError.productNotFound(productName: productName, packageIdentity: rootPackage.identity.description)
        }
        return try await extractComponent(product: resolvedProduct, graph: graph, store: store, cache: cache)
    }
    // root package
    return try await extractComponent(package: rootPackage, graph: graph, store: store, cache: cache)
}

package func extractSBOM(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil
) async throws -> SBOMDocument {
    let cache = SBOMGitCache()
    return try await SBOMDocument(
        id: SBOMIdentifier.generate(),
        metadata: extractMetadata(),
        primaryComponent: extractPrimaryComponent(graph: graph, store: store, product: product, cache: cache),
        dependencies: extractDependencies(graph: graph, store: store, product: product, cache: cache)
    )
}
