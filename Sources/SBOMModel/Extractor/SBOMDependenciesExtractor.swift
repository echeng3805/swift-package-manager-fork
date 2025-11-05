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

package func extractDependencies(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    product: String? = nil,
    cache: SBOMVersionCache? = nil
) async throws -> SBOMDependencies {

    guard let rootPackage = graph.rootPackages.first else {
        throw SBOMExtractorError.noRootPackage(context: "extract dependencies")
    }
    
    let targetProducts: [ResolvedProduct]
    if let name = product {
        guard let targetProduct = rootPackage.products.first(where: { $0.name == name }) else {
            throw SBOMExtractorError.productNotFound(productName: name, packageIdentity: rootPackage.identity.description)
        }
        targetProducts = [targetProduct]
    } else {
        targetProducts = rootPackage.products
    }
    
    return try await extractDependenciesForProducts(
        graph: graph,
        store: store,
        targetProducts: targetProducts,
        cache: cache
    )
}

private func extractDependenciesForProducts(
    graph: ModulesGraph,
    store: ResolvedPackagesStore,
    targetProducts: [ResolvedProduct],
    cache: SBOMVersionCache? = nil
) async throws -> SBOMDependencies {
    guard let rootPackage = graph.rootPackages.first else {
        throw SBOMExtractorError.noRootPackage(context: "extract dependencies")
    }
    let rootPackageID = await extractComponentID(from: rootPackage)

    var components: [SBOMComponent] = []
    var dependencies: [SBOMRelationship] = []

    var dependenciesDict: [String: Set<String>] = [:] // parentID:childrenID

    func addComponent(_ component: SBOMComponent) {
        if !components.map(\.id).contains(component.id) {
            components.append(component)
        }
    }

    func trackDependency(parentID: String, childID: String) {
        guard parentID != childID else { return }  // prevent self-referential dependencies
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
    ) async throws -> [ResolvedProduct] {
        var results: [ResolvedProduct] = []
        for dependency in dependentModule.dependencies {
            switch dependency {
            case .product(let dependentProduct, _):
                if let processed = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                    results.append(processed)
                }
            case .module(let nestedModule, _):
                // Recursively process nested module dependencies
                let nestedResults = try await processModuleDependency(from: product, dependentModule: nestedModule)
                results.append(contentsOf: nestedResults)
            }
        }
        return results
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
        let processedProductComponent = try await extractComponent(
            product: product,
            graph: graph,
            store: store,
            cache: cache
        )
        
        // check if both products are in the same root package
        let bothInRootPackage = product.packageIdentity == rootPackage.identity &&
                                dependentProduct.packageIdentity == rootPackage.identity

        addComponent(dependentProductComponent)
        addComponent(processedProductComponent)
        
        // only track dependency if not both in root package (skip internal-to-internal relationships)
        if !bothInRootPackage {
            // add product -> dependentProduct dependency
            trackDependency(parentID: processedProductComponent.id, childID: dependentProductComponent.id)
        }
        
        if let dependentProductPackage = graph.packages.first(where: { $0.identity == dependentProduct.packageIdentity }) {
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
            }
        }
        
        return dependentProduct
    }

    func findProduct(byID productID: ResolvedProduct.ID) -> ResolvedProduct? {
        graph.allProducts[productID]
    }

    func processDependencies(for product: ResolvedProduct) async throws -> [ResolvedProduct] {
        var productsToProcess = IdentifiableSet<ResolvedProduct>()
        for module in product.modules {
            for dependency in module.dependencies {
                switch dependency {
                case .product(let dependentProduct, _): // dependencies on products from other packages
                    if let toProcess = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                        productsToProcess.insert(toProcess)
                    }
                case .module(let dependentModule, _): // dependencies within the same package
                    let toProcess = try await processModuleDependency(from: product, dependentModule: dependentModule)
                    for productToProcess in toProcess {
                        productsToProcess.insert(productToProcess)
                    }
                }
            }
        }
        return Array(productsToProcess)
    }

    // Add rootPackage component and create dependencies to all target products
    try await addComponent(extractComponent(package: rootPackage, graph: graph, store: store, cache: cache))
    
    for targetProduct in targetProducts {
        let targetComponent = try await extractComponent(product: targetProduct, graph: graph, store: store, cache: cache)
        addComponent(targetComponent)
        trackDependency(parentID: rootPackageID, childID: targetComponent.id)
    }

    var processedProducts = IdentifiableSet<ResolvedProduct>()
    var productsToProcess: [ResolvedProduct] = targetProducts

    while !productsToProcess.isEmpty {
        let currentProduct = productsToProcess.removeFirst()
        
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
