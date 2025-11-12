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

extension SBOMExtractor {
    /// Converts a ModulesGraph product name to a dependency graph target name.
    /// Products in the dependency graph have a "-product" suffix.
    package static func productNameToTargetName(_ productName: String) -> String {
        return "\(productName)-product"
    }
    
    /// Converts a dependency graph target name back to a ModulesGraph product name.
    /// Removes the "-product" suffix if present.
    package static func targetNameToProductName(_ targetName: String) -> String? {
        guard targetName.hasSuffix("-product") else {
            return nil
        }
        return String(targetName.dropLast("-product".count))
    }
    
    /// Converts a ModulesGraph module name to a dependency graph target name.
    /// Module names remain unchanged in the dependency graph.
    package static func moduleNameToTargetName(_ moduleName: String) -> String {
        return moduleName
    }
    
    /// Converts a dependency graph target name back to a ModulesGraph module name.
    /// Returns the target name if it's not a product (doesn't have "-product" suffix).
    package static func targetNameToModuleName(_ targetName: String) -> String? {
        guard !targetName.hasSuffix("-product") else {
            return nil
        }
        return targetName
    }

    package func extractDependencies(product: String? = nil) async throws -> SBOMDependencies {
        guard let rootPackage = modulesGraph.rootPackages.first else {
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
        
        return try await extractDependenciesForProducts(targetProducts: targetProducts)
    }

    private func extractDependenciesForProducts(targetProducts: [ResolvedProduct]) async throws -> SBOMDependencies {
        guard let rootPackage = modulesGraph.rootPackages.first else {
            throw SBOMExtractorError.noRootPackage(context: "extract dependencies")
        }
        let rootPackageID = SBOMExtractor.extractComponentID(from: rootPackage)

        var components: [SBOMComponent] = []
        var componentIDs: Set<SBOMIdentifier> = [] // Track component IDs for O(1) lookup
        var dependencies: [SBOMRelationship] = []

        var dependenciesDict: [SBOMIdentifier: Set<SBOMIdentifier>] = [:] // parentID:childrenID
        
        var processedProductPairs = Set<String>() // "fromProductID:toProductID"

        func addComponent(_ component: SBOMComponent) {
            if !componentIDs.contains(component.id) {
                components.append(component)
                componentIDs.insert(component.id)
            }
        }

        func trackDependency(parentID: SBOMIdentifier, childID: SBOMIdentifier) {
            guard parentID != childID else { return }  // prevent self-referential dependencies
            dependenciesDict[parentID, default: []].insert(childID)
        }

        func processDependencies() {
            for (parentID, childrenSet) in dependenciesDict {
                dependencies.append(SBOMRelationship(
                    id: SBOMIdentifier(value: "\(parentID.value)-depends-on"),
                    parentID: parentID,
                    childrenID: Array(childrenSet),
                    metadata: SBOMRelationship.Metadata(source: .modules)
                ))
            }
        }

        func processModuleDependency(
            from product: ResolvedProduct,
            dependentModule: ResolvedModule
        ) async throws -> [ResolvedProduct] {
            var results: [ResolvedProduct] = []
            var modulesToProcess: [ResolvedModule] = [dependentModule]
            var processedModules = Set<ResolvedModule.ID>()
            
            while !modulesToProcess.isEmpty {
                let currentModule = modulesToProcess.removeFirst()
                
                guard !processedModules.contains(currentModule.id) else {
                    continue
                }
                processedModules.insert(currentModule.id)
                
                for dependency in currentModule.dependencies {
                    switch dependency {
                    case .product(let dependentProduct, _):
                        if let processed = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                            results.append(processed)
                        }
                    case .module(let nestedModule, _):
                        if !processedModules.contains(nestedModule.id) {
                            modulesToProcess.append(nestedModule)
                        }
                    }
                }
            }
            return results
        }

        func processProductDependency(
            from product: ResolvedProduct,
            dependentProduct: ResolvedProduct
        ) async throws -> ResolvedProduct? {

            let pairKey = "\(product.id):\(dependentProduct.id)"
            guard !processedProductPairs.contains(pairKey) else {
                return dependentProduct
            }
            processedProductPairs.insert(pairKey)
            
            let dependentProductComponent = try await extractComponent(product: dependentProduct)
            let processedProductComponent = try await extractComponent(product: product)
            
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
            
            if let dependentProductPackage = modulesGraph.packages.first(where: { $0.identity == dependentProduct.packageIdentity }) {
                let dependentProductPackageComponent = try await extractComponent(package: dependentProductPackage)
                addComponent(dependentProductPackageComponent)
                // add dependentProductPackage -> dependentProduct dependency
                trackDependency(parentID: dependentProductPackageComponent.id, childID: dependentProductComponent.id)
                if let productPackage = modulesGraph.packages.first(where: { $0.identity == product.packageIdentity }) {
                    let productPackageComponent = try await extractComponent(package: productPackage)
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
            modulesGraph.allProducts[productID]
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
        try await addComponent(extractComponent(package: rootPackage))
        
        for targetProduct in targetProducts {
            let targetComponent = try await extractComponent(product: targetProduct)
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
}
