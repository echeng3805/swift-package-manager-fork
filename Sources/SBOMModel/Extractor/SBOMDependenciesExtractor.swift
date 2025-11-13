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
    package static func getTargetName(fromProduct name: String) -> String {
        return "\(name)-product"
    }
    
    /// Converts a dependency graph target name back to a ModulesGraph product name.
    /// Removes the "-product" suffix if present.
    package static func getProductName(fromTarget name: String) -> String? {
        guard name.hasSuffix("-product") else {
            return nil
        }
        return String(name.dropLast("-product".count))
    }

    /// Converts a dependency graph target name back to a ModulesGraph module package and name.
    package static func getPackageAndModuleNames(fromTarget name: String) -> (packageName: String?, moduleName: String)? {
        guard !name.hasSuffix("-product") else {
            return nil
        }
        // Handles cases like: swift-nio_NIOPosix, swift-nio-ssl_NIOSSL, swift-crypto_Crypto, swift-crypto__CryptoExtras
        if let firstUnderscoreIndex = name.firstIndex(of: "_") {
            // Handles cases like _CryptoExtras, _AsyncFileSystem
            if firstUnderscoreIndex == name.startIndex {
                return (nil, name)
            }
            let packageName = String(name[..<firstUnderscoreIndex])
            let moduleName = String(name[name.index(after: firstUnderscoreIndex)...])
            guard !packageName.isEmpty, !moduleName.isEmpty else {
                return nil
            }
            return (packageName, moduleName)
        }
        return (nil, name)
    }

    internal func toProduct(fromTarget name: String) -> ResolvedProduct? {
        Self.getProductName(fromTarget: name).flatMap { modulesGraph.product(for: $0) }
    }

    internal func toModule(fromTarget name: String) -> ResolvedModule? {
        guard let (packageName, moduleName) = Self.getPackageAndModuleNames(fromTarget: name) else {
            return nil
        }
        if let packageName = packageName {
            return modulesGraph.allModules.first { module in
                module.name == moduleName && module.packageIdentity.description == packageName
            }
        }
        return modulesGraph.module(for: moduleName)
    }

    private static func processRelationships(from dict: [SBOMIdentifier: Set<SBOMIdentifier>]) -> [SBOMRelationship] {
        return dict.map { (parentID, childrenSet) in
            SBOMRelationship(
                id: SBOMIdentifier(value: "\(parentID.value)-depends-on"),
                parentID: parentID,
                childrenID: Array(childrenSet),
            )
        }
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

    private func populateTargetNameCache() async {
        if let buildGraph = dependencyGraph {
            for targetName in buildGraph.keys {
                if let module = toModule(fromTarget: targetName) {
                    await targetNameCache.set(module.id, targetName: targetName)
                }
            }
        }
    }

    private func extractDependenciesForProducts(targetProducts: [ResolvedProduct]) async throws -> SBOMDependencies {        
        guard let rootPackage = modulesGraph.rootPackages.first else {
            throw SBOMExtractorError.noRootPackage(context: "extract dependencies for the following products: \(targetProducts)")
        }
        let rootPackageID = SBOMExtractor.extractComponentID(from: rootPackage)

        // This is to avoid trying to remap modules back to targets
        await populateTargetNameCache()

        var components: Set<SBOMComponent> = []
        func addComponent(_ component: SBOMComponent) {
            if !components.contains(component) {
                components.insert(component)
            }
        }

        var relationships: [SBOMIdentifier: Set<SBOMIdentifier>] = [:] // parentID:childrenID
        func trackRelationship(parentID: SBOMIdentifier, childID: SBOMIdentifier) {
            guard parentID != childID else { return }  // prevent self-referential dependencies
            relationships[parentID, default: []].insert(childID)
        }

        // Processes modules recursively and returns a list of products to process
        // Only looks at the modules graph
        func processModuleDependency(
            from product: ResolvedProduct,
            dependentModule: ResolvedModule
        ) async throws -> [ResolvedProduct] {
            var result: [ResolvedProduct] = []
            var modulesToProcess: [ResolvedModule] = [dependentModule]
            var processedModules = Set<ResolvedModule.ID>()
            
            while !modulesToProcess.isEmpty {
                let currentModule = modulesToProcess.removeFirst()
                guard !processedModules.contains(currentModule.id) else {
                    continue
                }
                processedModules.insert(currentModule.id)

                if let buildGraph = dependencyGraph {
                    if let targetName = await targetNameCache.get(currentModule.id),
                      let targetDeps = buildGraph[targetName] {
                        for targetDep in targetDeps {
                            if let dependentProduct = toProduct(fromTarget: targetDep) {
                                if let toProcess = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                                    result.append(toProcess)
                                }
                            }
                            else if let dependentModule = toModule(fromTarget: targetDep) {
                                if !processedModules.contains(dependentModule.id) {
                                    modulesToProcess.append(dependentModule)
                                }
                            }
                            // else it's not in the modules graph
                            // TODO ev_cheng, print a warning?
                        }
                    } 
                }    
            }
            return result
        }

        // Processes modules recursively and returns a list of products to process
        // Only looks at the modules graph
        func processModuleDependencyUsingModulesGraph(
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

                // Find the module in the build graph
                // Look at the module's dependency in the build graph
                // Try to convert the dep to a product, if it's a product, process it
                // Else convert the dep to a product and add it to the modulesToProcess list
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
        
        // Takes a product and a dependent product, processes the relationships, and then returns the dependent product.
        func processProductDependency(
            from product: ResolvedProduct,
            dependentProduct: ResolvedProduct
        ) async throws -> ResolvedProduct? {
            // if this relationship was already seen, return early
            let productID = SBOMExtractor.extractComponentID(from: product)
            let dependentProductID = SBOMExtractor.extractComponentID(from: dependentProduct)
            if let productRelationships = relationships[productID],
               productRelationships.contains(dependentProductID) {
                return dependentProduct
            }
            
            let processedProductComponent = try await extractComponent(product: product)
            let dependentProductComponent = try await extractComponent(product: dependentProduct)
            addComponent(dependentProductComponent)
            addComponent(processedProductComponent)

            // check if both products are in the same root package
            let bothInRootPackage = product.packageIdentity == rootPackage.identity &&
                                    dependentProduct.packageIdentity == rootPackage.identity

            // only track dependency if not both in root package (skip internal-to-internal relationships)
            if !bothInRootPackage {
                // add product -> dependentProduct dependency
                trackRelationship(parentID: processedProductComponent.id, childID: dependentProductComponent.id)
            }
            if let dependentProductPackage = modulesGraph.packages.first(where: { $0.identity == dependentProduct.packageIdentity }) {
                let dependentProductPackageComponent = try await extractComponent(package: dependentProductPackage)
                addComponent(dependentProductPackageComponent)
                // add dependentProductPackage -> dependentProduct dependency
                trackRelationship(parentID: dependentProductPackageComponent.id, childID: dependentProductComponent.id)
                if let productPackage = modulesGraph.packages.first(where: { $0.identity == product.packageIdentity }) {
                    let productPackageComponent = try await extractComponent(package: productPackage)
                    addComponent(productPackageComponent)
                    // add productPackage -> dependentProductPackage dependency if they're from different packages
                    if product.packageIdentity != dependentProduct.packageIdentity {
                        trackRelationship(parentID: productPackageComponent.id, childID: dependentProductPackageComponent.id)
                    }
                    // add rootPackage -> productPackage dependency if it's not the root package itself
                    if productPackageComponent.id != rootPackageID {
                        trackRelationship(parentID: rootPackageID, childID: productPackageComponent.id)
                    }
                }
            }
            return dependentProduct
        }

        func processDependencies(for product: ResolvedProduct) async throws -> [ResolvedProduct] {
            var result = IdentifiableSet<ResolvedProduct>()
            // Use the build graph with the modules graph
            // TODO: ev_cheng, optimize so this if let isn't being run a million times
            if let buildGraph = dependencyGraph {
                if let targetDeps = buildGraph[Self.getTargetName(fromProduct: product.name)] {
                    for targetDep in targetDeps {
                        if let dependentProduct = toProduct(fromTarget: targetDep) {
                            if let toProcess = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                                result.insert(toProcess)
                            }
                        }
                        else if let dependentModule = toModule(fromTarget: targetDep) {
                            let toProcess = try await processModuleDependency(from: product, dependentModule: dependentModule)
                            for productToProcess in toProcess {
                                result.insert(productToProcess)
                            }
                        }
                        // else it's not in the modules graph
                        // TODO ev_cheng, print a warning?
                    }
                }
            } else {
                // Fall back to using the modules graph only
                // TODO: ev_cheng, remove?
                for module in product.modules {
                    for dependency in module.dependencies {
                        switch dependency {
                        case .product(let dependentProduct, _): // dependencies on products from other packages
                            if let toProcess = try await processProductDependency(from: product, dependentProduct: dependentProduct) {
                                result.insert(toProcess)
                            }
                        case .module(let dependentModule, _): // dependencies within the same package
                            let toProcess = try await processModuleDependencyUsingModulesGraph(from: product, dependentModule: dependentModule)
                            for productToProcess in toProcess {
                                result.insert(productToProcess)
                            }
                        }
                    }
                }
            }            
            return Array(result)
        }

        // Add rootPackage component and create dependencies to all its products
        try await addComponent(extractComponent(package: rootPackage))
        for targetProduct in targetProducts {
            let targetComponent = try await extractComponent(product: targetProduct)
            addComponent(targetComponent)
            trackRelationship(parentID: rootPackageID, childID: targetComponent.id)
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

        return SBOMDependencies(
            components: Array(components),
            relationships: SBOMExtractor.processRelationships(from: relationships)
        )
    }
}

