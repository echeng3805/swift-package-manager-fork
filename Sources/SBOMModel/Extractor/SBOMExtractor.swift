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

/// Cache for storing root package version from Git (to minimize calls to Git)
package actor SBOMVersionCache {
    private var cache: [PackageIdentity: SBOMComponent.Version] = [:]
    package func get(_ identity: PackageIdentity) -> SBOMComponent.Version? {
        self.cache[identity]
    }

    package func set(_ identity: PackageIdentity, version: SBOMComponent.Version) {
        self.cache[identity] = version
    }
}

package func extractSpec(_ spec: Spec) async throws -> SBOMSpec {
    let concreteSpec = spec.latestSpec
    return SBOMSpec(
        type: concreteSpec.type,
        version: concreteSpec.version
    )
}

package func extractMetadata(_ spec: Spec) async throws -> SBOMMetadata {
    try await SBOMMetadata(
        spec: extractSpec(spec),
        timestamp: Date().ISO8601Format(),
        creators: [
            SBOMTool(
                id: SBOMIdentifier.generate(),
                name: "swift-package-manager",
                version: SwiftVersion.current.displayString,
                licenses: [
                    SBOMLicense(
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

/// Extracts version information from Git for the root package
private func extractComponentVersionFromGit(packagePath: AbsolutePath) async throws -> SBOMComponent.Version {
    let gitRepo = GitRepository(path: packagePath, isWorkingRepo: true)
    
    guard let currentRevision = try? gitRepo.getCurrentRevision() else {
        return SBOMComponent.Version(revision: "unknown")
    }
    
    let remotes = (try? gitRepo.remotes()) ?? []
    let repositoryURL = remotes.first(where: { $0.name == "origin" })?.url ?? remotes.first?.url ?? packagePath
        .pathString
    
    if let currentTag = gitRepo.getCurrentTag() {
        return SBOMComponent.Version(
            revision: gitRepo.hasUncommittedChanges() ? "\(currentTag)-modified" : currentTag,
            commit: SBOMCommit(
                sha: currentRevision.identifier,
                repository: repositoryURL
            )
        )
    }
    
    return SBOMComponent.Version(
        revision: gitRepo.hasUncommittedChanges() ? "\(currentRevision.identifier)-modified" : currentRevision
            .identifier,
        commit: SBOMCommit(
            sha: currentRevision.identifier,
            repository: repositoryURL
        )
    )
}

private func extractComponentVersion(
    from packageIdentity: PackageIdentity,
    graph: ModulesGraph? = nil,
    store resolvedPackagesStore: ResolvedPackagesStore,
    cache: SBOMVersionCache?
) async throws -> SBOMComponent.Version {
    if let cache, let cachedVersion = await cache.get(packageIdentity) {
        return cachedVersion
    }

    // root package (try to get version from git)
    if let graph, let rootPackage = graph.rootPackages.first(where: { $0.identity == packageIdentity }) {
        let version = try await extractComponentVersionFromGit(packagePath: rootPackage.path)
        if let cache {
            await cache.set(packageIdentity, version: version)
        }
        return version
    }

    guard let resolvedPackage = resolvedPackagesStore.resolvedPackages[packageIdentity] else {
        return SBOMComponent.Version(revision: "unknown")
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
    return SBOMComponent.Version(revision: version, commit: SBOMCommit(
        sha: sha,
        repository: resolvedPackage.packageRef.kind.locationString // absolute path, URL string, or package identity
    ))
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
    cache: SBOMVersionCache? = nil
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
    cache: SBOMVersionCache? = nil
) async throws -> SBOMComponent {
    let componentVersion = try await extractComponentVersion(
        from: package.identity,
        graph: graph,
        store: store,
        cache: cache
    )
    let products = try await extractProductsFromPackage(package: package, graph: graph, store: store, cache: cache)
    return try await SBOMComponent(
        category: extractCategory(from: package),
        id: extractComponentID(from: package),
        purl: PURL.from(package: package, version: componentVersion).description,
        name: package.identity.description,
        version: componentVersion,
        originator: SBOMOriginator(commits: componentVersion.commit.map { [$0] }),
        description: package.description,
        scope: extractScope(from: package),
        components: products
    )
}

package func extractComponent(
    product: ResolvedProduct,
    graph: ModulesGraph? = nil,
    store: ResolvedPackagesStore,
    cache: SBOMVersionCache? = nil
) async throws -> SBOMComponent {
    let componentVersion = try await extractComponentVersion(
        from: product.packageIdentity,
        graph: graph,
        store: store,
        cache: cache
    )
    return try await SBOMComponent(
        category: extractCategory(from: product),
        id: extractComponentID(from: product),
        purl: PURL.from(product: product, version: componentVersion).description,
        name: product.name,
        version: componentVersion,
        originator: SBOMOriginator(commits: componentVersion.commit.map { [$0] }),
        description: nil,
        scope: extractScope(from: product)
    )
}

package func extractPrimaryComponent(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil,
    cache: SBOMVersionCache? = nil
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
    spec: Spec,
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil
) async throws -> SBOMDocument {
    let cache = SBOMVersionCache()
    return try await SBOMDocument(
        id: SBOMIdentifier.generate(),
        metadata: extractMetadata(spec),
        primaryComponent: extractPrimaryComponent(graph: graph, store: store, product: product, cache: cache),
        dependencies: extractDependencies(graph: graph, store: store, product: product, cache: cache)
    )
}
