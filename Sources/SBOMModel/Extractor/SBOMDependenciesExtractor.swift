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
import struct TSCBasic.StringError
import TSCUtility

package func extractDependencies(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil,
    cache: SBOMVersionCache? = nil
) async throws -> SBOMDependencies {
    if let name = product {
        return try await extractProductDependencies(graph: graph, store: store, product: name, cache: cache)
    }
    return try await extractRootPackageDependencies(graph: graph, store: store, cache: cache)
}

private func extractRootPackageDependencies(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    cache: SBOMVersionCache? = nil
) async throws -> SBOMDependencies {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found in package graph, cannot extract dependencies")
    }

    var components: [SBOMComponent] = []
    for package in graph.packages {
        for product in package.products {
            let productComponent = try await extractComponent(
                product: product,
                graph: graph,
                store: store,
                cache: cache
            )
            components.append(productComponent)
        }
        let packageComponent = try await extractComponent(package: package, graph: graph, store: store, cache: cache)
        components.append(packageComponent)
    }

    var dependencies: [SBOMRelationship] = []
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
    dependencies.append(SBOMRelationship(
        id: "\(rootPackageID)-depends-on",
        parentID: rootPackageID,
        childrenID: rootChildrenIDs
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
        dependencies.append(SBOMRelationship(
            id: "\(packageID)-depends-on",
            parentID: packageID,
            childrenID: productIDs
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
                    if let containerProduct = graph.allProducts
                        .first(where: { $0.modules.contains(id: dependentModule.id) })
                    {
                        dependencyID = await extractComponentID(from: containerProduct)
                    } else {
                        continue
                    }
                }
                if !childrenID.contains(dependencyID) && productID != dependencyID {
                    childrenID.append(dependencyID)
                }
            }
        }
        if !childrenID.isEmpty {
            dependencies.append(
                SBOMRelationship(
                    id: "\(productID)-depends-on",
                    parentID: productID,
                    childrenID: childrenID
                )
            )
        }
    }
    return SBOMDependencies(components: components, relationships: dependencies)
}

private func extractProductDependencies(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String,
    cache: SBOMVersionCache? = nil
) async throws -> SBOMDependencies {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found in package graph, cannot get product \(product) from root package")
    }
    guard let targetProduct = rootPackage.products.first(where: { $0.name == product }) else {
        throw StringError("Product '\(product)' not found in root package '\(rootPackage.identity)'")
    }
    let rootPackageID = await extractComponentID(from: rootPackage)
    let targetID = await extractComponentID(from: targetProduct)

    var components: [SBOMComponent] = []
    var dependencies: [SBOMRelationship] = []

    var dependenciesDict: [String: Set<String>] = [:] // parentID:childrenID

    func addComponent(_ component: SBOMComponent) {
        if !components.map(\.id).contains(component.id) {
            components.append(component)
        }
    }

    func trackDependency(parentID: String, childID: String) {
        var dependencies = dependenciesDict[parentID] ?? Set<String>()
        dependencies.insert(childID)
        dependenciesDict[parentID] = dependencies
    }

    func processDependencies() {
        for (parentID, childrenSet) in dependenciesDict {
            dependencies.append(SBOMRelationship(
                id: "\(parentID)-depends-on",
                parentID: parentID,
                childrenID: Array(childrenSet)
            ))
        }
    }

    func processModuleDependency(
        from product: ResolvedProduct,
        dependentModule: ResolvedModule
    ) async throws -> ResolvedProduct? {
        guard let containerProduct = graph.allProducts.first(where: { $0.modules.contains(id: dependentModule.id) })
        else {
            return nil
        }
        return try await processProductDependency(from: product, dependentProduct: containerProduct)
    }

    func processProductDependency(
        from product: ResolvedProduct,
        dependentProduct: ResolvedProduct
    ) async throws -> ResolvedProduct? {
        let dependentProductComponent = try await extractComponent(
            product: dependentProduct,
            graph: graph,
            store: store,
            cache: cache
        )
        addComponent(dependentProductComponent)
        let processedProductComponent = try await extractComponent(
            product: product,
            graph: graph,
            store: store,
            cache: cache
        )
        addComponent(processedProductComponent)
        // add product -> dependentProduct dependency
        trackDependency(parentID: processedProductComponent.id, childID: dependentProductComponent.id)

        if let dependentProductPackage = graph.packages
            .first(where: { $0.identity == dependentProduct.packageIdentity })
        {
            let dependentProductPackageComponent = try await extractComponent(
                package: dependentProductPackage,
                graph: graph,
                store: store,
                cache: cache
            )
            addComponent(dependentProductPackageComponent)
            // add dependentProductPackage -> dependentProduct dependency
            trackDependency(parentID: dependentProductPackageComponent.id, childID: dependentProductComponent.id)
            if let productPackage = graph.packages.first(where: { $0.identity == product.packageIdentity }) {
                let productPackageComponent = try await extractComponent(
                    package: productPackage,
                    graph: graph,
                    store: store,
                    cache: cache
                )
                addComponent(productPackageComponent)
                // add productPackage -> dependentProductPackage dependency if they're from different packages
                if product.packageIdentity != dependentProduct.packageIdentity {
                    trackDependency(parentID: productPackageComponent.id, childID: dependentProductPackageComponent.id)
                }
                // add rootPackage -> productPackage dependency if it's not the root package itself
                if productPackageComponent.id != rootPackageID {
                    trackDependency(parentID: rootPackageID, childID: productPackageComponent.id)
                }
                // add rootPackage -> dependentProductPackage dependency if it's not the root package
                if dependentProductPackageComponent.id != rootPackageID {
                    trackDependency(parentID: rootPackageID, childID: dependentProductPackageComponent.id)
                }
            }
        }
        return dependentProduct // needs to be processed
    }

    func findProduct(byID productID: ResolvedProduct.ID) -> ResolvedProduct? {
        graph.allProducts[productID]
    }

    func processDependencies(for product: ResolvedProduct) async throws -> [ResolvedProduct] {
        var productsToProcess = IdentifiableSet<ResolvedProduct>()
        for module in product.modules {
            for dependency in module.dependencies {
                let toProcess: ResolvedProduct? = switch dependency {
                case .product(let dependentProduct, _): // dependencies on products from other packages
                    try await processProductDependency(from: product, dependentProduct: dependentProduct)
                case .module(let dependentModule, _): // dependencies within the same package
                    try await processModuleDependency(from: product, dependentModule: dependentModule)
                }
                if let productToProcess = toProcess {
                    productsToProcess.insert(productToProcess)
                }
            }
        }
        return Array(productsToProcess)
    }

    // add rootPackage -> targetProduct dependency
    try await addComponent(extractComponent(product: targetProduct, graph: graph, store: store, cache: cache))
    try await addComponent(extractComponent(package: rootPackage, graph: graph, store: store, cache: cache))
    trackDependency(parentID: rootPackageID, childID: targetID)

    var processedProducts = IdentifiableSet<ResolvedProduct>()
    processedProducts.insert(targetProduct)
    var productsToProcess = try await processDependencies(for: targetProduct)

    while !productsToProcess.isEmpty {
        let currentProduct = productsToProcess.removeFirst()
        guard !processedProducts.contains(id: currentProduct.id) else {
            continue
        }
        processedProducts.insert(currentProduct)
        let transitiveDeps = try await processDependencies(for: currentProduct)
        for dep in transitiveDeps
            where !processedProducts.contains(id: dep.id) && !productsToProcess.contains(where: { $0.id == dep.id })
        {
            productsToProcess.append(dep)
        }
    }

    processDependencies()
    return SBOMDependencies(components: components, relationships: dependencies)
}
