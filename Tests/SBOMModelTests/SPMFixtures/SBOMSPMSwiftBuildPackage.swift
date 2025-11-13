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

extension SBOMTestModulesGraph {
    
    // MARK: - swift-build Package (26 modules)
    
    static func createSPMSwiftBuildPackage(
        swiftSyntaxProduct: ResolvedProduct,
        swiftParserProduct: ResolvedProduct,
        swiftDriverProduct: ResolvedProduct,
        swiftDriverExecutionProduct: ResolvedProduct,
        llbuildSwiftProduct: ResolvedProduct,
        swiftToolsSupportAutoProduct: ResolvedProduct,
        argumentParserProduct: ResolvedProduct,
        systemPackageProduct: ResolvedProduct,
        cryptoProduct: ResolvedProduct,
        x509Product: ResolvedProduct
    ) -> (
        package: Package,
        modules: [Module],
        products: [Product],
        resolvedPackage: ResolvedPackage,
        resolvedModules: [ResolvedModule],
        resolvedProducts: [ResolvedProduct],
        packageRef: PackageReference
    ) {
        let identity = PackageIdentity.plain("swift-build")
        
        // MARK: - Create all 26 modules
        
        // Core modules
        let basicsModule = self.createSwiftModule(name: "Basics")
        let packageModelModule = self.createSwiftModule(name: "PackageModel")
        let packageLoadingModule = self.createSwiftModule(name: "PackageLoading")
        let packageGraphModule = self.createSwiftModule(name: "PackageGraph")
        let sourceControlModule = self.createSwiftModule(name: "SourceControl")
        let workspaceModule = self.createSwiftModule(name: "Workspace")
        
        // Build system modules
        let buildModule = self.createSwiftModule(name: "Build")
        let llbuildManifestModule = self.createSwiftModule(name: "LLBuildManifest")
        let spmlLLBuildModule = self.createSwiftModule(name: "SPMLLBuild")
        
        // Package registry modules
        let packageRegistryModule = self.createSwiftModule(name: "PackageRegistry")
        let packageSigningModule = self.createSwiftModule(name: "PackageSigning")
        let packageFingerprintModule = self.createSwiftModule(name: "PackageFingerprint")
        let packageMetadataModule = self.createSwiftModule(name: "PackageMetadata")
        
        // Commands modules
        let commandsModule = self.createSwiftModule(name: "Commands")
        let packageCollectionsModule = self.createSwiftModule(name: "PackageCollections")
        let packageCollectionsSigningModule = self.createSwiftModule(name: "PackageCollectionsSigning")
        
        // Plugin modules
        let packagePluginModule = self.createSwiftModule(name: "PackagePlugin")
        
        // SBOM modules
        let sbomModelModule = self.createSwiftModule(name: "SBOMModel")
        
        // Executable modules
        let swiftBuildModule = self.createSwiftModule(name: "swift-build", type: .executable)
        let swiftPackageModule = self.createSwiftModule(name: "swift-package", type: .executable)
        let swiftRunModule = self.createSwiftModule(name: "swift-run", type: .executable)
        let swiftTestModule = self.createSwiftModule(name: "swift-test", type: .executable)
        let swiftPackageRegistryModule = self.createSwiftModule(name: "swift-package-registry", type: .executable)
        let swiftPackageCollectionModule = self.createSwiftModule(name: "swift-package-collection", type: .executable)
        
        // Test support modules
        let internalTestSupportModule = self.createSwiftModule(name: "_InternalTestSupport")
        let workspaceTestSupportModule = self.createSwiftModule(name: "WorkspaceTestSupport")
        
        // MARK: - Create products
        
        let basicsProduct = try! Product(package: identity, name: "SwiftPMPackageModel", type: .library(.automatic), modules: [basicsModule, packageModelModule])
        let packageLoadingProduct = try! Product(package: identity, name: "PackageLoading", type: .library(.automatic), modules: [packageLoadingModule])
        let packageGraphProduct = try! Product(package: identity, name: "PackageGraph", type: .library(.automatic), modules: [packageGraphModule])
        let sourceControlProduct = try! Product(package: identity, name: "SourceControl", type: .library(.automatic), modules: [sourceControlModule])
        let workspaceProduct = try! Product(package: identity, name: "Workspace", type: .library(.automatic), modules: [workspaceModule])
        let buildProduct = try! Product(package: identity, name: "Build", type: .library(.automatic), modules: [buildModule])
        let packageRegistryProduct = try! Product(package: identity, name: "PackageRegistry", type: .library(.automatic), modules: [packageRegistryModule])
        let packageSigningProduct = try! Product(package: identity, name: "PackageSigning", type: .library(.automatic), modules: [packageSigningModule])
        let commandsProduct = try! Product(package: identity, name: "Commands", type: .library(.automatic), modules: [commandsModule])
        let sbomModelProduct = try! Product(package: identity, name: "SBOMModel", type: .library(.automatic), modules: [sbomModelModule])
        
        let swiftBuildProduct = try! Product(package: identity, name: "swift-build", type: .executable, modules: [swiftBuildModule])
        let swiftPackageProduct = try! Product(package: identity, name: "swift-package", type: .executable, modules: [swiftPackageModule])
        let swiftRunProduct = try! Product(package: identity, name: "swift-run", type: .executable, modules: [swiftRunModule])
        let swiftTestProduct = try! Product(package: identity, name: "swift-test", type: .executable, modules: [swiftTestModule])
        let swiftPackageRegistryProduct = try! Product(package: identity, name: "swift-package-registry", type: .executable, modules: [swiftPackageRegistryModule])
        let swiftPackageCollectionProduct = try! Product(package: identity, name: "swift-package-collection", type: .executable, modules: [swiftPackageCollectionModule])
        
        // MARK: - Create package
        
        let package = self.createPackage(
            identity: identity,
            displayName: "swift-package-manager",
            path: "/swift-package-manager",
            modules: [
                basicsModule, packageModelModule, packageLoadingModule, packageGraphModule,
                sourceControlModule, workspaceModule, buildModule, llbuildManifestModule,
                spmlLLBuildModule, packageRegistryModule, packageSigningModule, packageFingerprintModule,
                packageMetadataModule, commandsModule, packageCollectionsModule, packageCollectionsSigningModule,
                packagePluginModule, sbomModelModule, swiftBuildModule, swiftPackageModule,
                swiftRunModule, swiftTestModule, swiftPackageRegistryModule, swiftPackageCollectionModule,
                internalTestSupportModule, workspaceTestSupportModule
            ],
            products: [
                basicsProduct, packageLoadingProduct, packageGraphProduct, sourceControlProduct,
                workspaceProduct, buildProduct, packageRegistryProduct, packageSigningProduct,
                commandsProduct, sbomModelProduct, swiftBuildProduct, swiftPackageProduct,
                swiftRunProduct, swiftTestProduct, swiftPackageRegistryProduct, swiftPackageCollectionProduct
            ]
        )
        
        // MARK: - Create resolved modules with dependencies
        
        let resolvedBasicsModule = self.createResolvedModule(
            packageIdentity: identity,
            module: basicsModule,
            dependencies: [
                .product(swiftToolsSupportAutoProduct, conditions: []),
                .product(systemPackageProduct, conditions: [])
            ]
        )
        
        let resolvedPackageModelModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageLoadingModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageLoadingModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftSyntaxProduct, conditions: []),
                .product(swiftParserProduct, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedSourceControlModule = self.createResolvedModule(
            packageIdentity: identity,
            module: sourceControlModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageGraphModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageGraphModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageLoadingModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageRegistryModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageRegistryModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageSigningModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageSigningModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(cryptoProduct, conditions: []),
                .product(x509Product, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageFingerprintModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageFingerprintModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageMetadataModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageMetadataModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageCollectionsModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageCollectionsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackageCollectionsSigningModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packageCollectionsSigningModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageCollectionsModule, conditions: []),
                .product(cryptoProduct, conditions: []),
                .product(x509Product, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedWorkspaceModule = self.createResolvedModule(
            packageIdentity: identity,
            module: workspaceModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageLoadingModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: []),
                .module(resolvedPackageRegistryModule, conditions: []),
                .module(resolvedPackageFingerprintModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedLLBuildManifestModule = self.createResolvedModule(
            packageIdentity: identity,
            module: llbuildManifestModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedSPMLLBuildModule = self.createResolvedModule(
            packageIdentity: identity,
            module: spmlLLBuildModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .product(llbuildSwiftProduct, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedBuildModule = self.createResolvedModule(
            packageIdentity: identity,
            module: buildModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedLLBuildManifestModule, conditions: []),
                .module(resolvedSPMLLBuildModule, conditions: []),
                .product(swiftDriverProduct, conditions: []),
                .product(swiftDriverExecutionProduct, conditions: []),
                .product(llbuildSwiftProduct, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedPackagePluginModule = self.createResolvedModule(
            packageIdentity: identity,
            module: packagePluginModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedSBOMModelModule = self.createResolvedModule(
            packageIdentity: identity,
            module: sbomModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedCommandsModule = self.createResolvedModule(
            packageIdentity: identity,
            module: commandsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageLoadingModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: []),
                .module(resolvedWorkspaceModule, conditions: []),
                .module(resolvedBuildModule, conditions: []),
                .module(resolvedPackageRegistryModule, conditions: []),
                .module(resolvedPackageSigningModule, conditions: []),
                .module(resolvedPackageCollectionsModule, conditions: []),
                .module(resolvedPackagePluginModule, conditions: []),
                .module(resolvedSBOMModelModule, conditions: []),
                .product(argumentParserProduct, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedInternalTestSupportModule = self.createResolvedModule(
            packageIdentity: identity,
            module: internalTestSupportModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedWorkspaceTestSupportModule = self.createResolvedModule(
            packageIdentity: identity,
            module: workspaceTestSupportModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedWorkspaceModule, conditions: []),
                .module(resolvedInternalTestSupportModule, conditions: []),
                .product(swiftToolsSupportAutoProduct, conditions: [])
            ]
        )
        
        let resolvedSwiftBuildModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftBuildModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPackageModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftPackageModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftRunModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftRunModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftTestModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftTestModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPackageRegistryModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftPackageRegistryModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPackageCollectionModule = self.createResolvedModule(
            packageIdentity: identity,
            module: swiftPackageCollectionModule,
            dependencies: [
                .module(resolvedCommandsModule, conditions: [])
            ]
        )
        
        // MARK: - Create resolved products
        
        let resolvedBasicsProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: basicsProduct,
            modules: IdentifiableSet([resolvedBasicsModule, resolvedPackageModelModule])
        )
        
        let resolvedPackageLoadingProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: packageLoadingProduct,
            modules: IdentifiableSet([resolvedPackageLoadingModule])
        )
        
        let resolvedPackageGraphProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: packageGraphProduct,
            modules: IdentifiableSet([resolvedPackageGraphModule])
        )
        
        let resolvedSourceControlProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: sourceControlProduct,
            modules: IdentifiableSet([resolvedSourceControlModule])
        )
        
        let resolvedWorkspaceProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: workspaceProduct,
            modules: IdentifiableSet([resolvedWorkspaceModule])
        )
        
        let resolvedBuildProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: buildProduct,
            modules: IdentifiableSet([resolvedBuildModule])
        )
        
        let resolvedPackageRegistryProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: packageRegistryProduct,
            modules: IdentifiableSet([resolvedPackageRegistryModule])
        )
        
        let resolvedPackageSigningProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: packageSigningProduct,
            modules: IdentifiableSet([resolvedPackageSigningModule])
        )
        
        let resolvedCommandsProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: commandsProduct,
            modules: IdentifiableSet([resolvedCommandsModule])
        )
        
        let resolvedSBOMModelProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: sbomModelProduct,
            modules: IdentifiableSet([resolvedSBOMModelModule])
        )
        
        let resolvedSwiftBuildProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftBuildProduct,
            modules: IdentifiableSet([resolvedSwiftBuildModule])
        )
        
        let resolvedSwiftPackageProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftPackageProduct,
            modules: IdentifiableSet([resolvedSwiftPackageModule])
        )
        
        let resolvedSwiftRunProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftRunProduct,
            modules: IdentifiableSet([resolvedSwiftRunModule])
        )
        
        let resolvedSwiftTestProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftTestProduct,
            modules: IdentifiableSet([resolvedSwiftTestModule])
        )
        
        let resolvedSwiftPackageRegistryProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftPackageRegistryProduct,
            modules: IdentifiableSet([resolvedSwiftPackageRegistryModule])
        )
        
        let resolvedSwiftPackageCollectionProduct = self.createResolvedProduct(
            packageIdentity: identity,
            product: swiftPackageCollectionProduct,
            modules: IdentifiableSet([resolvedSwiftPackageCollectionModule])
        )
        
        // MARK: - Create resolved package
        
        let resolvedPackage = self.createResolvedPackage(
            package: package,
            modules: IdentifiableSet([
                resolvedBasicsModule, resolvedPackageModelModule, resolvedPackageLoadingModule,
                resolvedPackageGraphModule, resolvedSourceControlModule, resolvedWorkspaceModule,
                resolvedBuildModule, resolvedLLBuildManifestModule, resolvedSPMLLBuildModule,
                resolvedPackageRegistryModule, resolvedPackageSigningModule, resolvedPackageFingerprintModule,
                resolvedPackageMetadataModule, resolvedCommandsModule, resolvedPackageCollectionsModule,
                resolvedPackageCollectionsSigningModule, resolvedPackagePluginModule, resolvedSBOMModelModule,
                resolvedSwiftBuildModule, resolvedSwiftPackageModule, resolvedSwiftRunModule,
                resolvedSwiftTestModule, resolvedSwiftPackageRegistryModule, resolvedSwiftPackageCollectionModule,
                resolvedInternalTestSupportModule, resolvedWorkspaceTestSupportModule
            ]),
            products: [
                resolvedBasicsProduct, resolvedPackageLoadingProduct, resolvedPackageGraphProduct,
                resolvedSourceControlProduct, resolvedWorkspaceProduct, resolvedBuildProduct,
                resolvedPackageRegistryProduct, resolvedPackageSigningProduct, resolvedCommandsProduct,
                resolvedSBOMModelProduct, resolvedSwiftBuildProduct, resolvedSwiftPackageProduct,
                resolvedSwiftRunProduct, resolvedSwiftTestProduct, resolvedSwiftPackageRegistryProduct,
                resolvedSwiftPackageCollectionProduct
            ],
            dependencies: [
                PackageIdentity.plain("swift-syntax"),
                PackageIdentity.plain("swift-driver"),
                PackageIdentity.plain("swift-llbuild"),
                PackageIdentity.plain("swift-tools-support-core"),
                PackageIdentity.plain("swift-argument-parser"),
                PackageIdentity.plain("swift-system"),
                PackageIdentity.plain("swift-crypto"),
                PackageIdentity.plain("swift-certificates")
            ]
        )
        
        // Package reference
        let packageRef = PackageReference(
            identity: identity,
            kind: .root(AbsolutePath("/swift-package-manager"))
        )
        
        return (
            package: package,
            modules: [
                basicsModule, packageModelModule, packageLoadingModule, packageGraphModule,
                sourceControlModule, workspaceModule, buildModule, llbuildManifestModule,
                spmlLLBuildModule, packageRegistryModule, packageSigningModule, packageFingerprintModule,
                packageMetadataModule, commandsModule, packageCollectionsModule, packageCollectionsSigningModule,
                packagePluginModule, sbomModelModule, swiftBuildModule, swiftPackageModule,
                swiftRunModule, swiftTestModule, swiftPackageRegistryModule, swiftPackageCollectionModule,
                internalTestSupportModule, workspaceTestSupportModule
            ],
            products: [
                basicsProduct, packageLoadingProduct, packageGraphProduct, sourceControlProduct,
                workspaceProduct, buildProduct, packageRegistryProduct, packageSigningProduct,
                commandsProduct, sbomModelProduct, swiftBuildProduct, swiftPackageProduct,
                swiftRunProduct, swiftTestProduct, swiftPackageRegistryProduct, swiftPackageCollectionProduct
            ],
            resolvedPackage: resolvedPackage,
            resolvedModules: [
                resolvedBasicsModule, resolvedPackageModelModule, resolvedPackageLoadingModule,
                resolvedPackageGraphModule, resolvedSourceControlModule, resolvedWorkspaceModule,
                resolvedBuildModule, resolvedLLBuildManifestModule, resolvedSPMLLBuildModule,
                resolvedPackageRegistryModule, resolvedPackageSigningModule, resolvedPackageFingerprintModule,
                resolvedPackageMetadataModule, resolvedCommandsModule, resolvedPackageCollectionsModule,
                resolvedPackageCollectionsSigningModule, resolvedPackagePluginModule, resolvedSBOMModelModule,
                resolvedSwiftBuildModule, resolvedSwiftPackageModule, resolvedSwiftRunModule,
                resolvedSwiftTestModule, resolvedSwiftPackageRegistryModule, resolvedSwiftPackageCollectionModule,
                resolvedInternalTestSupportModule, resolvedWorkspaceTestSupportModule
            ],
            resolvedProducts: [
                resolvedBasicsProduct, resolvedPackageLoadingProduct, resolvedPackageGraphProduct,
                resolvedSourceControlProduct, resolvedWorkspaceProduct, resolvedBuildProduct,
                resolvedPackageRegistryProduct, resolvedPackageSigningProduct, resolvedCommandsProduct,
                resolvedSBOMModelProduct, resolvedSwiftBuildProduct, resolvedSwiftPackageProduct,
                resolvedSwiftRunProduct, resolvedSwiftTestProduct, resolvedSwiftPackageRegistryProduct,
                resolvedSwiftPackageCollectionProduct
            ],
            packageRef: packageRef
        )
    }
}