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

import Foundation
import struct TSCBasic.StringError
import TSCUtility
import Basics
import PackageCollections
import PackageGraph
import PackageModel
import SourceControl

private struct ComponentVersion: Codable, Equatable {
    let version: String
    let commit: SBOMCommit?

    init(
        version: String,
        commit: SBOMCommit? = nil,
    ) {
        self.version = version
        self.commit = commit
    }
}

package func extractSpec(_ spec: Spec) async throws -> SBOMSpec {
    switch spec {
    // cyclonedx and spdx refer to the most recent versions.
    // when there are new major versions available, cyclonedx and spdx should be moved to the same
    // cases as cyclonedx2 and spdx4.
    case .cyclonedx, .cyclonedx1:
        return SBOMSpec(
            type: .cyclonedx1,
            version: CDXConstants.cyclonedx1SpecVersion,
        )
    case .spdx, .spdx3:
        return SBOMSpec(
            type: .spdx3,
            version: SPDXConstants.spdx3SpecVersion,
        )
    }
}

package func extractMetadata(_ spec: Spec) async throws -> SBOMMetadata {
    return SBOMMetadata(
        spec: try await extractSpec(spec),
        timestamp: Date().ISO8601Format(),
        creators: [
            SBOMTool(
                id: generateSBOMID(),
                name: "Swift Package Manager",
                version: SwiftVersion.current.displayString,
                licenses: [
                    SBOMLicense(
                        name: PackageCollectionsModel.LicenseType.Apache2_0.description,
                        url: "http://swift.org/LICENSE.txt",
                    )
                ],
            )
        ]
    )
}

package func extractCategory(from package: ResolvedPackage) async throws -> SBOMComponent.Category {
    let productCategories = package.products.map{ $0.type }
    if productCategories.contains(.executable) {
        return .application
    }
    return .library
}

package func extractCategory(from product: ResolvedProduct) async throws -> SBOMComponent.Category {
    switch product.type {
        case .executable:
            return .application
        default:
            return .library
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

private func extractComponentVersion(from packageIdentity: PackageIdentity, store resolvedPackagesStore: ResolvedPackagesStore) async throws -> ComponentVersion {
    guard let resolvedPackage = resolvedPackagesStore.resolvedPackages[packageIdentity] else {
        return ComponentVersion(version: "unknown", commit: nil)
    }
    
    let version: String
    let sha: String
    
    switch resolvedPackage.state {
    case .version(let versionValue, let revision):
        version = versionValue.description
        if let revision = revision {
            sha = revision
        } else {
            sha = ""
        }
    case .branch(_, let revision), .revision(let revision):
        version = revision
        sha = revision
    }
    
    return ComponentVersion(version: version, commit: SBOMCommit(
        sha: sha,
        repository: resolvedPackage.packageRef.kind.locationString
    ))
}

package func extractComponentID(from package: ResolvedPackage) async -> String {
    return package.identity.description
}

package func extractComponentID(from product: ResolvedProduct) async -> String {
    return "\(product.packageIdentity):\(product.name)"
}

private func extractProductsFromPackage(package: ResolvedPackage, store: ResolvedPackagesStore) async throws -> [SBOMComponent] {
    var productComponents: [SBOMComponent] = []
    for product in package.products {
        let productComponent = try await extractComponent(product: product, store: store)
        productComponents.append(productComponent)
    }
    return productComponents
}

package func extractComponent(package: ResolvedPackage, store: ResolvedPackagesStore) async throws -> SBOMComponent {
    let componentVersion = try await extractComponentVersion(from: package.identity, store: store)
    let products = try await extractProductsFromPackage(package: package, store: store)
    return SBOMComponent(
        category: try await extractCategory(from: package),
        id: await extractComponentID(from: package),
        purl: PURL.from(package: package, version: componentVersion.version).description,
        name: package.identity.description,
        version: componentVersion.version,
        originator: SBOMOriginator(commits: componentVersion.commit.map { [$0] }),
        description: package.description,
        scope: try await extractScope(from: package),
        components: products
    )
}

package func extractComponent(product: ResolvedProduct, store: ResolvedPackagesStore) async throws -> SBOMComponent {
    let componentVersion = try await extractComponentVersion(from: product.packageIdentity, store: store)
    
    // Get the package location from the store for proper PURL namespace extraction
    // If not found in store (e.g., local/root package products), use package identity as fallback
    let packageLocation: String
    if let resolvedPackage = store.resolvedPackages[product.packageIdentity] {
        packageLocation = resolvedPackage.packageRef.kind.locationString
    } else {
        // For local packages not in the store, use the package identity as the location
        // This will be used as the namespace in the PURL
        packageLocation = product.packageIdentity.description
    }
    
    return SBOMComponent(
        category: try await extractCategory(from: product),
        id: await extractComponentID(from: product),
        purl: PURL.from(product: product, version: componentVersion.version, packageLocation: packageLocation).description,
        name: product.name,
        version: componentVersion.version,
        originator: SBOMOriginator(commits: componentVersion.commit.map { [$0] }),
        description: nil,
        scope: try await extractScope(from: product),
    )
}

package func extractPrimaryComponent(graph: ModulesGraph, store: ResolvedPackagesStore, product: String? = nil) async throws -> SBOMComponent {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found in package graph, cannot determine primary component for SBOM")
    }
    // product of root package
    if let productName = product {
        guard let resolvedProduct = rootPackage.products.first(where: { $0.name == productName }) else {
            throw StringError("Product '\(productName)' not found in root package '\(rootPackage.identity)'")
        }
        return try await extractComponent(product: resolvedProduct, store: store)
    }
    // root package
    return try await extractComponent(package: rootPackage, store: store)
}

package func extractSBOM(spec: Spec, graph: ModulesGraph, store: ResolvedPackagesStore, product: String? = nil) async throws -> SBOMDocument {
    return SBOMDocument(
        id: "urn:uuid:\(generateSBOMID())",
        metadata: try await extractMetadata(spec),
        primaryComponent:  try await extractPrimaryComponent(graph: graph, store: store, product: product),
        dependencies: try await extractDependencies(graph: graph, store: store, product: product)
    )
}