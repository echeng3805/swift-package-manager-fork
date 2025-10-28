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
    return SBOMComponent(
        category: try await extractCategory(from: product),
        id: await extractComponentID(from: product),
        purl: PURL.from(product: product, version: componentVersion.version).description,
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

package func extractRootPackageDependencies(graph: ModulesGraph, store: ResolvedPackagesStore) async throws -> SBOMDependencies {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found in package graph, cannot extract dependencies")
    }

    var components: [SBOMComponent] = []
    for package in graph.packages {
        for product in package.products {
            let productComponent = try await extractComponent(product: product, store: store)
            components.append(productComponent)
        }
        let packageComponent = try await extractComponent(package: package, store: store)
        components.append(packageComponent)
    }

    var dependencies: [SBOMDependency] = []
    // root package depends on dependency packages and its own products
    let rootPackageID = await extractComponentID(from: rootPackage)
    var rootChildrenIDs: [String] = []
    for package in graph.packages {
        let packageID = await extractComponentID(from: package)
        if packageID == rootPackageID {
            continue
        }
        rootChildrenIDs.append(packageID)
    }
    for product in rootPackage.products {
        let productID = await extractComponentID(from: product)
        rootChildrenIDs.append(productID)
    }
    dependencies.append(SBOMDependency(
        id: "\(rootPackageID)-\(generateSBOMID())",
        parentID: rootPackageID,
        childrenID: rootChildrenIDs,
    ))
    // non-root packages depend on their own products
    for package in graph.packages {
        let packageID = await extractComponentID(from: package)
        if packageID == rootPackageID {
            continue // handled above
        }
        var productIDs: [String] = []
        for product in package.products {
            let productID = await extractComponentID(from: product)
            productIDs.append(productID)
        }
        dependencies.append(SBOMDependency(
            id: "\(packageID)-\(generateSBOMID())",
            parentID: packageID,
            childrenID: productIDs,
        ))
    }
    // products depend on other products
    let allProducts = graph.allProducts
    for product in allProducts {
        let productID = await extractComponentID(from: product)
        var childrenID: [String] = []
        for module in product.modules {
            for dependency in module.dependencies {
                let dependencyID: String
                switch dependency {
                case .product(let dependentProduct, _): // dependencies on products from other packages
                    dependencyID = await extractComponentID(from: dependentProduct)
                case .module(let dependentModule, _): // dependencies within the same package
                    if let containerProduct = graph.allProducts.first(where: { $0.modules.contains(id: dependentModule.id) }) {
                        dependencyID = await extractComponentID(from: containerProduct)
                    } else {
                        continue
                    }
                }
                if !childrenID.contains(dependencyID) {
                    childrenID.append(dependencyID)
                }
            }
        }
        if !childrenID.isEmpty {
            dependencies.append(
                SBOMDependency(
                    id: "\(productID)-\(generateSBOMID())",
                    parentID: productID,
                    childrenID: childrenID,
                )
            )
        }
    }
    return SBOMDependencies(components: components, dependencies: dependencies)
}

package func extractProductDependencies(graph: ModulesGraph, store: ResolvedPackagesStore, product: String) async throws -> SBOMDependencies {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found in package graph, cannot get product \(product) from root package")
    }
    guard let targetProduct = rootPackage.products.first(where: { $0.name == product }) else {
        throw StringError("Product '\(product)' not found in root package '\(rootPackage.identity)'")
    }
    
    var components: [SBOMComponent] = []
    var dependencies: [SBOMDependency] = []
    var componentIDs: Set<String> = []
    var dependencyKeys: Set<String> = []
    var dependentPackages: Set<PackageIdentity> = []
    
    let rootPackageID = await extractComponentID(from: rootPackage)
    let targetID = await extractComponentID(from: targetProduct)
    
    // Helper: Add component if not already present
    func addComponent(_ component: SBOMComponent) {
        if !componentIDs.contains(component.id) {
            components.append(component)
            componentIDs.insert(component.id)
        }
    }
    
    // Helper: Add dependency if not already present
    func addDependency(parentID: String, childrenID: [String]) {
        let newChildren = childrenID.filter { childID in
            let key = "\(parentID)->\(childID)"
            return !dependencyKeys.contains(key)
        }
        
        guard !newChildren.isEmpty else { return }
        
        newChildren.forEach { childID in
            dependencyKeys.insert("\(parentID)->\(childID)")
        }
        dependencies.append(SBOMDependency(
            id: "\(parentID)-\(generateSBOMID())",
            parentID: parentID,
            childrenID: newChildren
        ))
    }
    
    // Helper: Process a product dependency
    func processProductDependency(_ dependentProduct: ResolvedProduct) async throws -> String {
        let productComponent = try await extractComponent(product: dependentProduct, store: store)
        addComponent(productComponent)
        
        let productID = await extractComponentID(from: dependentProduct)
        
        // Handle the package if not already processed
        if !dependentPackages.contains(dependentProduct.packageIdentity) {
            dependentPackages.insert(dependentProduct.packageIdentity)
            if let package = graph.packages.first(where: { $0.identity == dependentProduct.packageIdentity }) {
                addComponent(try await extractComponent(package: package, store: store))
                let packageID = await extractComponentID(from: package)
                addDependency(parentID: packageID, childrenID: [productID])
                addDependency(parentID: rootPackageID, childrenID: [packageID])
            }
        }
        
        return productID
    }
    
    // Helper: Process a module dependency
    func processModuleDependency(_ dependentModule: ResolvedModule) async throws -> String? {
        guard let containerProduct = graph.allProducts.first(where: { $0.modules.contains(id: dependentModule.id) }) else {
            return nil
        }
        
        let productComponent = try await extractComponent(product: containerProduct, store: store)
        addComponent(productComponent)
        
        let productID = await extractComponentID(from: containerProduct)
        addDependency(parentID: rootPackageID, childrenID: [productID])
        
        return productID
    }
    
    // Helper: Find product by ID
    func findProduct(byID productID: String) async -> ResolvedProduct? {
        for product in graph.allProducts {
            if await extractComponentID(from: product) == productID {
                return product
            }
        }
        return nil
    }
    
    // Helper: Process dependencies for a product
    func processDependencies(for product: ResolvedProduct) async throws -> [String] {
        var depIDs: [String] = []
        
        for module in product.modules {
            for dependency in module.dependencies {
                let depID: String?
                switch dependency {
                case .product(let dependentProduct, _):
                    depID = try await processProductDependency(dependentProduct)
                case .module(let dependentModule, _):
                    depID = try await processModuleDependency(dependentModule)
                }
                
                if let depID = depID, !depIDs.contains(depID) {
                    depIDs.append(depID)
                }
            }
        }
        
        return depIDs
    }
    
    // Initialize with target and root package
    addComponent(try await extractComponent(product: targetProduct, store: store))
    addComponent(try await extractComponent(package: rootPackage, store: store))
    addDependency(parentID: rootPackageID, childrenID: [targetID])
    
    // Process all dependencies transitively
    var processedProducts: Set<String> = [targetID]
    var productsToProcess = try await processDependencies(for: targetProduct)
    
    if !productsToProcess.isEmpty {
        addDependency(parentID: targetID, childrenID: productsToProcess)
    }
    
    while !productsToProcess.isEmpty {
        let currentProductID = productsToProcess.removeFirst()
        
        guard !processedProducts.contains(currentProductID),
              let currentProduct = await findProduct(byID: currentProductID) else {
            continue
        }
        processedProducts.insert(currentProductID)
        
        let transitiveDepIDs = try await processDependencies(for: currentProduct)
        
        if !transitiveDepIDs.isEmpty {
            addDependency(parentID: currentProductID, childrenID: transitiveDepIDs)
        }
        
        // Add new products to processing queue
        for depID in transitiveDepIDs where !processedProducts.contains(depID) && !productsToProcess.contains(depID) {
            productsToProcess.append(depID)
        }
    }

    return SBOMDependencies(components: components, dependencies: dependencies)
}

package func extractDependencies(graph: ModulesGraph, store: ResolvedPackagesStore, product: String? = nil) async throws -> SBOMDependencies {
    if let name = product {
        return try await extractProductDependencies(graph: graph, store: store, product: name)
    }
    return try await extractRootPackageDependencies(graph: graph, store: store)
}

package func extractSBOM(spec: Spec, graph: ModulesGraph, store: ResolvedPackagesStore, product: String? = nil) async throws -> SBOMDocument {
    return SBOMDocument(
        id: "urn:uuid:\(generateSBOMID())",
        metadata: try await extractMetadata(spec),
        primaryComponent:  try await extractPrimaryComponent(graph: graph, store: store, product: product),
        dependencies: try await extractDependencies(graph: graph, store: store, product: product)
    )
}