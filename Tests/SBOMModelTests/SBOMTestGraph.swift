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
import Basics
import PackageGraph
import PackageModel
import _InternalTestSupport
@testable import SBOMModel

struct SBOMTestGraph {

    // MARK: - Helper functions

    static func createSwiftModule(
        name: String,
        dependencies: [Module.Dependency] = [],
        packageAccess: Bool = false,
        type: Module.Kind = .library
    ) -> SwiftModule {
        let path = AbsolutePath("/\(name)")
        let sources = Sources(paths: [], root: path)
        return SwiftModule(
            name: name,
            type: type,
            path: path,
            sources: sources,
            dependencies: dependencies,
            packageAccess: packageAccess,
            usesUnsafeFlags: false,
            implicit: false
        )
    }

    static func createPackage(
        identity: PackageIdentity,
        displayName: String,
        path: String,
        modules: [Module],
        products: [Product]
    ) -> Package {
        let manifest = Manifest.createFileSystemManifest(
            displayName: displayName,
            path: AbsolutePath(path),
            toolsVersion: .vNext
        )
        
        return Package(
            identity: identity,
            manifest: manifest,
            path: AbsolutePath(path),
            targets: modules,
            products: products,
            targetSearchPath: AbsolutePath(path).appending("Sources"),
            testTargetSearchPath: AbsolutePath(path).appending("Tests")
        )
    }

    static func createResolvedModule(
        packageIdentity: PackageIdentity,
        module: Module,
        dependencies: [ResolvedModule.Dependency] = [],
        supportedPlatforms: [SupportedPlatform] = []
    ) -> ResolvedModule {
        return ResolvedModule(
            packageIdentity: packageIdentity,
            underlying: module,
            dependencies: dependencies,
            defaultLocalization: nil,
            supportedPlatforms: supportedPlatforms,
            platformVersionProvider: PlatformVersionProvider(implementation: .minimumDeploymentTargetDefault)
        )
    }

    static func createResolvedProduct(
        packageIdentity: PackageIdentity,
        product: Product,
        modules: IdentifiableSet<ResolvedModule>
    ) -> ResolvedProduct {
        return ResolvedProduct(
            packageIdentity: packageIdentity,
            product: product,
            modules: modules
        )
    }

    static func createResolvedPackage(
        package: Package,
        modules: IdentifiableSet<ResolvedModule>,
        products: [ResolvedProduct],
        dependencies: [PackageIdentity] = [],
        enabledTraits: Set<String>? = nil
    ) -> ResolvedPackage {
        return ResolvedPackage(
            underlying: package,
            defaultLocalization: nil,
            supportedPlatforms: [],
            dependencies: dependencies,
            enabledTraits: enabledTraits,
            modules: modules,
            products: products,
            registryMetadata: nil,
            platformVersionProvider: PlatformVersionProvider(implementation: .minimumDeploymentTargetDefault)
        )
    }

    // MARK: - Swift Package Manager Sample ModulesGraph
    
    static func createSPMModulesGraph(rootPath: String = "/tmp/SwiftPM-mock") throws -> ModulesGraph {
        let swiftPMIdentity = PackageIdentity.plain("SwiftPM")
        let swiftLLBuildIdentity = PackageIdentity.plain("swift-llbuild")
        let swiftArgumentParserIdentity = PackageIdentity.plain("swift-argument-parser")
        let swiftCryptoIdentity = PackageIdentity.plain("swift-crypto")
        let swiftSyntaxIdentity = PackageIdentity.plain("swift-syntax")
        let swiftSystemIdentity = PackageIdentity.plain("swift-system")
        let swiftCollectionsIdentity = PackageIdentity.plain("swift-collections")
        let swiftCertificatesIdentity = PackageIdentity.plain("swift-certificates")
        let swiftToolchainSQLiteIdentity = PackageIdentity.plain("swift-toolchain-sqlite")
        let swiftDoccPluginIdentity = PackageIdentity.plain("swift-docc-plugin")
        let swiftToolsSupportCoreIdentity = PackageIdentity.plain("swift-tools-support-core")
        let swiftDriverIdentity = PackageIdentity.plain("swift-driver")
        let swiftBuildIdentity = PackageIdentity.plain("swift-build")
        let swiftASN1Identity = PackageIdentity.plain("swift-asn1")
        let swiftDoccSymbolKitIdentity = PackageIdentity.plain("swift-docc-symbolkit")
        let swiftJsonSchemaIdentity = PackageIdentity.plain("swift-json-schema")
        
        let basicsModule = createSwiftModule(name: "Basics")
        let packageModelModule = createSwiftModule(name: "PackageModel", dependencies: [
            .module(basicsModule, conditions: [])
        ])
        let sbomModelModule = createSwiftModule(name: "SBOMModel", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let packageGraphModule = createSwiftModule(name: "PackageGraph", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let packageLoadingModule = createSwiftModule(name: "PackageLoading", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let sourceControlModule = createSwiftModule(name: "SourceControl", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let workspaceModule = createSwiftModule(name: "Workspace", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
            .module(packageGraphModule, conditions: [])
        ])
        let buildModule = createSwiftModule(name: "Build", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageGraphModule, conditions: [])
        ])
        let commandsModule = createSwiftModule(name: "Commands", dependencies: [
            .module(basicsModule, conditions: []),
            .module(buildModule, conditions: []),
            .module(workspaceModule, conditions: [])
        ])
        
        // Additional SwiftPM modules to match expected SBOM structure
        let swiftPMModule = createSwiftModule(name: "SwiftPM", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
            .module(packageGraphModule, conditions: []),
            .module(buildModule, conditions: [])
        ])
        let swiftPMAutoModule = createSwiftModule(name: "SwiftPM-auto", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let swiftPMDataModelModule = createSwiftModule(name: "SwiftPMDataModel", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let swiftPMDataModelAutoModule = createSwiftModule(name: "SwiftPMDataModel-auto", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: [])
        ])
        let xcBuildSupportModule = createSwiftModule(name: "XCBuildSupport", dependencies: [
            .module(basicsModule, conditions: [])
        ])
        let packageDescriptionModule = createSwiftModule(name: "PackageDescription")
        let appleProductTypesModule = createSwiftModule(name: "AppleProductTypes")
        let packagePluginModule = createSwiftModule(name: "PackagePlugin")
        let packageCollectionsModelModule = createSwiftModule(name: "PackageCollectionsModel", dependencies: [
            .module(basicsModule, conditions: [])
        ])
        let swiftPMPackageCollectionsModule = createSwiftModule(name: "SwiftPMPackageCollections", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageCollectionsModelModule, conditions: [])
        ])
        
        // swift-system modules
        let systemPackageModule = createSwiftModule(name: "SystemPackage")
        
        // swift-collections modules
        let dequeModuleModule = createSwiftModule(name: "DequeModule")
        let orderedCollectionsModule = createSwiftModule(name: "OrderedCollections")
        let bitCollectionsModule = createSwiftModule(name: "BitCollections")
        let hashTreeCollectionsModule = createSwiftModule(name: "HashTreeCollections")
        let heapModuleModule = createSwiftModule(name: "HeapModule")
        let ropeModuleModule = createSwiftModule(name: "_RopeModule")
        let collectionsModule = createSwiftModule(name: "Collections")
        
        // swift-argument-parser modules
        let argumentParserModule = createSwiftModule(name: "ArgumentParser")
        let generateManualModule = createSwiftModule(name: "GenerateManual")
        
        // swift-llbuild modules
        let llbuildModule = createSwiftModule(name: "llbuild", type: .executable)
        let libllbuildModule = createSwiftModule(name: "libllbuild")
        let llbuildSwiftModule = createSwiftModule(name: "llbuildSwift")
        let llbuildAnalysisModule = createSwiftModule(name: "llbuildAnalysis")
        let llbuildSwiftDynamicModule = createSwiftModule(name: "llbuildSwiftDynamic")
        
        // swift-toolchain-sqlite modules
        let sqliteModule = createSwiftModule(name: "sqlite", type: .executable)
        let swiftToolchainCSQLiteModule = createSwiftModule(name: "SwiftToolchainCSQLite")
        
        // swift-crypto modules
        let cryptoModule = createSwiftModule(name: "Crypto")
        let cryptoExtrasModule = createSwiftModule(name: "_CryptoExtras")
        
        // swift-syntax modules
        let swiftSyntaxModule = createSwiftModule(name: "SwiftSyntax")
        let swiftBasicFormatModule = createSwiftModule(name: "SwiftBasicFormat")
        let swiftCompilerPluginModule = createSwiftModule(name: "SwiftCompilerPlugin")
        let swiftDiagnosticsModule = createSwiftModule(name: "SwiftDiagnostics")
        let swiftIDEUtilsModule = createSwiftModule(name: "SwiftIDEUtils")
        let swiftIfConfigModule = createSwiftModule(name: "SwiftIfConfig")
        let swiftLexicalLookupModule = createSwiftModule(name: "SwiftLexicalLookup")
        let swiftOperatorsModule = createSwiftModule(name: "SwiftOperators")
        let swiftParserModule = createSwiftModule(name: "SwiftParser")
        let swiftParserDiagnosticsModule = createSwiftModule(name: "SwiftParserDiagnostics")
        let swiftRefactorModule = createSwiftModule(name: "SwiftRefactor")
        let swiftSyntaxBuilderModule = createSwiftModule(name: "SwiftSyntaxBuilder")
        let swiftSyntaxMacrosModule = createSwiftModule(name: "SwiftSyntaxMacros")
        let swiftSyntaxMacroExpansionModule = createSwiftModule(name: "SwiftSyntaxMacroExpansion")
        let swiftSyntaxMacrosTestSupportModule = createSwiftModule(name: "SwiftSyntaxMacrosTestSupport")
        let swiftSyntaxMacrosGenericTestSupportModule = createSwiftModule(name: "SwiftSyntaxMacrosGenericTestSupport")
        let swiftCompilerPluginMessageHandlingModule = createSwiftModule(name: "_SwiftCompilerPluginMessageHandling")
        let swiftLibraryPluginProviderModule = createSwiftModule(name: "_SwiftLibraryPluginProvider")
        
        // swift-certificates modules
        let x509Module = createSwiftModule(name: "X509")
        
        // swift-asn1 modules
        let swiftASN1Module = createSwiftModule(name: "SwiftASN1")
        
        // swift-docc-plugin modules
        let swiftDoccModule = createSwiftModule(name: "Swift-DocC")
        let swiftDoccPreviewModule = createSwiftModule(name: "Swift-DocC Preview")
        
        // swift-docc-symbolkit modules
        let swiftDoccSymbolKitModule = createSwiftModule(name: "SymbolKit")
        
        // swift-json-schema modules
        let jsonSchemaModule = createSwiftModule(name: "JSONSchema")
        let jsonSchemaBuilderModule = createSwiftModule(name: "JSONSchemaBuilder")
        let jsonSchemaClientModule = createSwiftModule(name: "JSONSchemaClient", type: .executable)
        let jsonSchemaConversionModule = createSwiftModule(name: "JSONSchemaConversion")
        
        // swift-tools-support-core modules
        let tscBasicModule = createSwiftModule(name: "TSCBasic")
        let swiftToolsSupportModule = createSwiftModule(name: "SwiftToolsSupport")
        let swiftToolsSupportAutoModule = createSwiftModule(name: "SwiftToolsSupport-auto")
        let tscTestSupportModule = createSwiftModule(name: "TSCTestSupport")
        
        // swift-driver modules
        let swiftDriverExecutableModule = createSwiftModule(name: "swift-driver", type: .executable)
        let swiftHelpModule = createSwiftModule(name: "swift-help", type: .executable)
        let swiftBuildSDKInterfacesModule = createSwiftModule(name: "swift-build-sdk-interfaces", type: .executable)
        let swiftDriverModule = createSwiftModule(name: "SwiftDriver")
        let swiftDriverDynamicModule = createSwiftModule(name: "SwiftDriverDynamic")
        let swiftOptionsModule = createSwiftModule(name: "SwiftOptions")
        let swiftDriverExecutionModule = createSwiftModule(name: "SwiftDriverExecution")
        
        // swift-build modules
        let swbuildModule = createSwiftModule(name: "swbuild", type: .executable)
        let swbBuildServiceBundleModule = createSwiftModule(name: "SWBBuildServiceBundle", type: .executable)
        let swiftBuildModule = createSwiftModule(name: "SwiftBuild")
        let swbProtocolModule = createSwiftModule(name: "SWBProtocol")
        let swbUtilModule = createSwiftModule(name: "SWBUtil")
        let swbProjectModelModule = createSwiftModule(name: "SWBProjectModel")
        let swbBuildServiceModule = createSwiftModule(name: "SWBBuildService")
        
        let swiftPMDataModelProduct = try Product(
            package: swiftPMIdentity,
            name: "SwiftPMDataModel",
            type: .library(.dynamic),
            modules: [swiftPMDataModelModule]
        )
        
        let swiftPMDataModelAutoProduct = try Product(
            package: swiftPMIdentity,
            name: "SwiftPMDataModel-auto",
            type: .library(.automatic),
            modules: [swiftPMDataModelAutoModule]
        )
        
        let swiftPMProduct = try Product(
            package: swiftPMIdentity,
            name: "SwiftPM",
            type: .library(.dynamic),
            modules: [swiftPMModule]
        )
        
        let swiftPMAutoProduct = try Product(
            package: swiftPMIdentity,
            name: "SwiftPM-auto",
            type: .library(.automatic),
            modules: [swiftPMAutoModule]
        )
        
        let xcBuildSupportProduct = try Product(
            package: swiftPMIdentity,
            name: "XCBuildSupport",
            type: .library(.automatic),
            modules: [xcBuildSupportModule]
        )
        
        let packageDescriptionProduct = try Product(
            package: swiftPMIdentity,
            name: "PackageDescription",
            type: .library(.automatic),
            modules: [packageDescriptionModule]
        )
        
        let appleProductTypesProduct = try Product(
            package: swiftPMIdentity,
            name: "AppleProductTypes",
            type: .library(.automatic),
            modules: [appleProductTypesModule]
        )
        
        let packagePluginProduct = try Product(
            package: swiftPMIdentity,
            name: "PackagePlugin",
            type: .library(.automatic),
            modules: [packagePluginModule]
        )
        
        let packageCollectionsModelProduct = try Product(
            package: swiftPMIdentity,
            name: "PackageCollectionsModel",
            type: .library(.automatic),
            modules: [packageCollectionsModelModule]
        )
        
        let swiftPMPackageCollectionsProduct = try Product(
            package: swiftPMIdentity,
            name: "SwiftPMPackageCollections",
            type: .library(.automatic),
            modules: [swiftPMPackageCollectionsModule]
        )
        
        let systemPackageProduct = try Product(
            package: swiftSystemIdentity,
            name: "SystemPackage",
            type: .library(.automatic),
            modules: [systemPackageModule]
        )
        
        let dequeModuleProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "DequeModule",
            type: .library(.automatic),
            modules: [dequeModuleModule]
        )
        
        let orderedCollectionsProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "OrderedCollections",
            type: .library(.automatic),
            modules: [orderedCollectionsModule]
        )
        
        let argumentParserProduct = try Product(
            package: swiftArgumentParserIdentity,
            name: "ArgumentParser",
            type: .library(.automatic),
            modules: [argumentParserModule]
        )
        
        let llbuildSwiftProduct = try Product(
            package: swiftLLBuildIdentity,
            name: "llbuildSwift",
            type: .library(.automatic),
            modules: [llbuildSwiftModule]
        )
        
        let swiftToolsSupportAutoOriginalProduct = try Product(
            package: swiftToolsSupportCoreIdentity,
            name: "SwiftToolsSupport-auto",
            type: .library(.automatic),
            modules: [swiftToolsSupportAutoModule]
        )
        
        let swiftDriverProduct = try Product(
            package: swiftDriverIdentity,
            name: "SwiftDriver",
            type: .library(.automatic),
            modules: [swiftDriverModule]
        )
        
        let cryptoProduct = try Product(
            package: swiftCryptoIdentity,
            name: "Crypto",
            type: .library(.automatic),
            modules: [cryptoModule]
        )
        
        let x509Product = try Product(
            package: swiftCertificatesIdentity,
            name: "X509",
            type: .library(.automatic),
            modules: [x509Module]
        )
        
        // Additional swift-collections products
        let bitCollectionsProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "BitCollections",
            type: .library(.automatic),
            modules: [bitCollectionsModule]
        )
        
        let hashTreeCollectionsProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "HashTreeCollections",
            type: .library(.automatic),
            modules: [hashTreeCollectionsModule]
        )
        
        let heapModuleProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "HeapModule",
            type: .library(.automatic),
            modules: [heapModuleModule]
        )
        
        let ropeModuleProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "_RopeModule",
            type: .library(.automatic),
            modules: [ropeModuleModule]
        )
        
        let collectionsProduct = try Product(
            package: swiftCollectionsIdentity,
            name: "Collections",
            type: .library(.automatic),
            modules: [collectionsModule]
        )
        
        // Additional swift-argument-parser products
        let generateManualProduct = try Product(
            package: swiftArgumentParserIdentity,
            name: "GenerateManual",
            type: .library(.automatic),
            modules: [generateManualModule]
        )
        
        // Additional swift-llbuild products
        let llbuildProduct = try Product(
            package: swiftLLBuildIdentity,
            name: "llbuild",
            type: .executable,
            modules: [llbuildModule]
        )
        
        let libllbuildProduct = try Product(
            package: swiftLLBuildIdentity,
            name: "libllbuild",
            type: .library(.automatic),
            modules: [libllbuildModule]
        )
        
        let llbuildAnalysisProduct = try Product(
            package: swiftLLBuildIdentity,
            name: "llbuildAnalysis",
            type: .library(.automatic),
            modules: [llbuildAnalysisModule]
        )
        
        let llbuildSwiftDynamicProduct = try Product(
            package: swiftLLBuildIdentity,
            name: "llbuildSwiftDynamic",
            type: .library(.automatic),
            modules: [llbuildSwiftDynamicModule]
        )
        
        // swift-toolchain-sqlite products
        let sqliteProduct = try Product(
            package: swiftToolchainSQLiteIdentity,
            name: "sqlite",
            type: .executable,
            modules: [sqliteModule]
        )
        
        let swiftToolchainCSQLiteProduct = try Product(
            package: swiftToolchainSQLiteIdentity,
            name: "SwiftToolchainCSQLite",
            type: .library(.automatic),
            modules: [swiftToolchainCSQLiteModule]
        )
        
        // Additional swift-crypto products
        let cryptoExtrasProduct = try Product(
            package: swiftCryptoIdentity,
            name: "_CryptoExtras",
            type: .library(.automatic),
            modules: [cryptoExtrasModule]
        )
        
        // swift-syntax products
        let swiftSyntaxProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntax",
            type: .library(.automatic),
            modules: [swiftSyntaxModule]
        )
        
        let swiftBasicFormatProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftBasicFormat",
            type: .library(.automatic),
            modules: [swiftBasicFormatModule]
        )
        
        let swiftCompilerPluginProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftCompilerPlugin",
            type: .library(.automatic),
            modules: [swiftCompilerPluginModule]
        )
        
        let swiftDiagnosticsProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftDiagnostics",
            type: .library(.automatic),
            modules: [swiftDiagnosticsModule]
        )
        
        let swiftIDEUtilsProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftIDEUtils",
            type: .library(.automatic),
            modules: [swiftIDEUtilsModule]
        )
        
        let swiftIfConfigProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftIfConfig",
            type: .library(.automatic),
            modules: [swiftIfConfigModule]
        )
        
        let swiftLexicalLookupProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftLexicalLookup",
            type: .library(.automatic),
            modules: [swiftLexicalLookupModule]
        )
        
        let swiftOperatorsProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftOperators",
            type: .library(.automatic),
            modules: [swiftOperatorsModule]
        )
        
        let swiftParserProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftParser",
            type: .library(.automatic),
            modules: [swiftParserModule]
        )
        
        let swiftParserDiagnosticsProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftParserDiagnostics",
            type: .library(.automatic),
            modules: [swiftParserDiagnosticsModule]
        )
        
        let swiftRefactorProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftRefactor",
            type: .library(.automatic),
            modules: [swiftRefactorModule]
        )
        
        let swiftSyntaxBuilderProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntaxBuilder",
            type: .library(.automatic),
            modules: [swiftSyntaxBuilderModule]
        )
        
        let swiftSyntaxMacrosProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntaxMacros",
            type: .library(.automatic),
            modules: [swiftSyntaxMacrosModule]
        )
        
        let swiftSyntaxMacroExpansionProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntaxMacroExpansion",
            type: .library(.automatic),
            modules: [swiftSyntaxMacroExpansionModule]
        )
        
        let swiftSyntaxMacrosTestSupportProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntaxMacrosTestSupport",
            type: .library(.automatic),
            modules: [swiftSyntaxMacrosTestSupportModule]
        )
        
        let swiftSyntaxMacrosGenericTestSupportProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "SwiftSyntaxMacrosGenericTestSupport",
            type: .library(.automatic),
            modules: [swiftSyntaxMacrosGenericTestSupportModule]
        )
        
        let swiftCompilerPluginMessageHandlingProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "_SwiftCompilerPluginMessageHandling",
            type: .library(.automatic),
            modules: [swiftCompilerPluginMessageHandlingModule]
        )
        
        let swiftLibraryPluginProviderProduct = try Product(
            package: swiftSyntaxIdentity,
            name: "_SwiftLibraryPluginProvider",
            type: .library(.automatic),
            modules: [swiftLibraryPluginProviderModule]
        )
        
        // swift-asn1 products
        let swiftASN1Product = try Product(
            package: swiftASN1Identity,
            name: "SwiftASN1",
            type: .library(.automatic),
            modules: [swiftASN1Module]
        )
        
        // swift-docc-plugin products
        let swiftDoccProduct = try Product(
            package: swiftDoccPluginIdentity,
            name: "Swift-DocC",
            type: .library(.automatic),
            modules: [swiftDoccModule]
        )
        
        let swiftDoccPreviewProduct = try Product(
            package: swiftDoccPluginIdentity,
            name: "Swift-DocC Preview",
            type: .library(.automatic),
            modules: [swiftDoccPreviewModule]
        )
        
        // swift-docc-symbolkit products
        let swiftDoccSymbolKitProduct = try Product(
            package: swiftDoccSymbolKitIdentity,
            name: "SymbolKit",
            type: .library(.automatic),
            modules: [swiftDoccSymbolKitModule]
        )
        
        // swift-json-schema products
        let jsonSchemaProduct = try Product(
            package: swiftJsonSchemaIdentity,
            name: "JSONSchema",
            type: .library(.automatic),
            modules: [jsonSchemaModule]
        )
        
        let jsonSchemaBuilderProduct = try Product(
            package: swiftJsonSchemaIdentity,
            name: "JSONSchemaBuilder",
            type: .library(.automatic),
            modules: [jsonSchemaBuilderModule]
        )
        
        let jsonSchemaClientProduct = try Product(
            package: swiftJsonSchemaIdentity,
            name: "JSONSchemaClient",
            type: .executable,
            modules: [jsonSchemaClientModule]
        )
        
        let jsonSchemaConversionProduct = try Product(
            package: swiftJsonSchemaIdentity,
            name: "JSONSchemaConversion",
            type: .library(.automatic),
            modules: [jsonSchemaConversionModule]
        )
        
        // Additional swift-tools-support-core products
        let tscBasicProduct = try Product(
            package: swiftToolsSupportCoreIdentity,
            name: "TSCBasic",
            type: .library(.automatic),
            modules: [tscBasicModule]
        )
        
        let swiftToolsSupportProduct = try Product(
            package: swiftToolsSupportCoreIdentity,
            name: "SwiftToolsSupport",
            type: .library(.automatic),
            modules: [swiftToolsSupportModule]
        )
        
        let swiftToolsSupportAutoProduct = try Product(
            package: swiftToolsSupportCoreIdentity,
            name: "SwiftToolsSupport-auto",
            type: .library(.automatic),
            modules: [swiftToolsSupportAutoModule]
        )
        
        let tscTestSupportProduct = try Product(
            package: swiftToolsSupportCoreIdentity,
            name: "TSCTestSupport",
            type: .library(.automatic),
            modules: [tscTestSupportModule]
        )
        
        // Additional swift-driver products
        let swiftDriverExecutableProduct = try Product(
            package: swiftDriverIdentity,
            name: "swift-driver",
            type: .executable,
            modules: [swiftDriverExecutableModule]
        )
        
        let swiftHelpProduct = try Product(
            package: swiftDriverIdentity,
            name: "swift-help",
            type: .executable,
            modules: [swiftHelpModule]
        )
        
        let swiftBuildSDKInterfacesProduct = try Product(
            package: swiftDriverIdentity,
            name: "swift-build-sdk-interfaces",
            type: .executable,
            modules: [swiftBuildSDKInterfacesModule]
        )
        
        let swiftDriverDynamicProduct = try Product(
            package: swiftDriverIdentity,
            name: "SwiftDriverDynamic",
            type: .library(.automatic),
            modules: [swiftDriverDynamicModule]
        )
        
        let swiftOptionsProduct = try Product(
            package: swiftDriverIdentity,
            name: "SwiftOptions",
            type: .library(.automatic),
            modules: [swiftOptionsModule]
        )
        
        let swiftDriverExecutionProduct = try Product(
            package: swiftDriverIdentity,
            name: "SwiftDriverExecution",
            type: .library(.automatic),
            modules: [swiftDriverExecutionModule]
        )
        
        // swift-build products
        let swbuildProduct = try Product(
            package: swiftBuildIdentity,
            name: "swbuild",
            type: .executable,
            modules: [swbuildModule]
        )
        
        let swbBuildServiceBundleProduct = try Product(
            package: swiftBuildIdentity,
            name: "SWBBuildServiceBundle",
            type: .executable,
            modules: [swbBuildServiceBundleModule]
        )
        
        let swiftBuildProduct = try Product(
            package: swiftBuildIdentity,
            name: "SwiftBuild",
            type: .library(.automatic),
            modules: [swiftBuildModule]
        )
        
        let swbProtocolProduct = try Product(
            package: swiftBuildIdentity,
            name: "SWBProtocol",
            type: .library(.automatic),
            modules: [swbProtocolModule]
        )
        
        let swbUtilProduct = try Product(
            package: swiftBuildIdentity,
            name: "SWBUtil",
            type: .library(.automatic),
            modules: [swbUtilModule]
        )
        
        let swbProjectModelProduct = try Product(
            package: swiftBuildIdentity,
            name: "SWBProjectModel",
            type: .library(.automatic),
            modules: [swbProjectModelModule]
        )
        
        let swbBuildServiceProduct = try Product(
            package: swiftBuildIdentity,
            name: "SWBBuildService",
            type: .library(.automatic),
            modules: [swbBuildServiceModule]
        )
        
        let swiftPMPackage = createPackage(
            identity: swiftPMIdentity,
            displayName: "SwiftPM",
            path: rootPath,
            modules: [basicsModule, packageModelModule, packageLoadingModule, packageGraphModule, sourceControlModule, workspaceModule, buildModule, sbomModelModule, commandsModule, swiftPMModule, swiftPMAutoModule, swiftPMDataModelModule, swiftPMDataModelAutoModule, xcBuildSupportModule, packageDescriptionModule, appleProductTypesModule, packagePluginModule, packageCollectionsModelModule, swiftPMPackageCollectionsModule],
            products: [swiftPMDataModelProduct, swiftPMDataModelAutoProduct, swiftPMProduct, swiftPMAutoProduct, xcBuildSupportProduct, packageDescriptionProduct, appleProductTypesProduct, packagePluginProduct, packageCollectionsModelProduct, swiftPMPackageCollectionsProduct]
        )
        
        let swiftSystemPackage = createPackage(
            identity: swiftSystemIdentity,
            displayName: "swift-system",
            path: "/swift-system",
            modules: [systemPackageModule],
            products: [systemPackageProduct]
        )
        
        let swiftCollectionsPackage = createPackage(
            identity: swiftCollectionsIdentity,
            displayName: "swift-collections",
            path: "/swift-collections",
            modules: [dequeModuleModule, orderedCollectionsModule, bitCollectionsModule, hashTreeCollectionsModule, heapModuleModule, ropeModuleModule, collectionsModule],
            products: [dequeModuleProduct, orderedCollectionsProduct, bitCollectionsProduct, hashTreeCollectionsProduct, heapModuleProduct, ropeModuleProduct, collectionsProduct]
        )
        
        let swiftArgumentParserPackage = createPackage(
            identity: swiftArgumentParserIdentity,
            displayName: "swift-argument-parser",
            path: "/swift-argument-parser",
            modules: [argumentParserModule, generateManualModule],
            products: [argumentParserProduct, generateManualProduct]
        )
        
        let swiftLLBuildPackage = createPackage(
            identity: swiftLLBuildIdentity,
            displayName: "swift-llbuild",
            path: "/swift-llbuild",
            modules: [llbuildModule, libllbuildModule, llbuildSwiftModule, llbuildAnalysisModule, llbuildSwiftDynamicModule],
            products: [llbuildProduct, libllbuildProduct, llbuildSwiftProduct, llbuildAnalysisProduct, llbuildSwiftDynamicProduct]
        )
        
        let swiftToolchainSQLitePackage = createPackage(
            identity: swiftToolchainSQLiteIdentity,
            displayName: "swift-toolchain-sqlite",
            path: "/swift-toolchain-sqlite",
            modules: [sqliteModule, swiftToolchainCSQLiteModule],
            products: [sqliteProduct, swiftToolchainCSQLiteProduct]
        )
        
        let swiftToolsSupportCorePackage = createPackage(
            identity: swiftToolsSupportCoreIdentity,
            displayName: "swift-tools-support-core",
            path: "/swift-tools-support-core",
            modules: [tscBasicModule, swiftToolsSupportModule, swiftToolsSupportAutoModule, tscTestSupportModule],
            products: [tscBasicProduct, swiftToolsSupportProduct, swiftToolsSupportAutoProduct, tscTestSupportProduct]
        )
        
        let swiftDriverPackage = createPackage(
            identity: swiftDriverIdentity,
            displayName: "swift-driver",
            path: "/swift-driver",
            modules: [swiftDriverExecutableModule, swiftHelpModule, swiftBuildSDKInterfacesModule, swiftDriverModule, swiftDriverDynamicModule, swiftOptionsModule, swiftDriverExecutionModule],
            products: [swiftDriverExecutableProduct, swiftHelpProduct, swiftBuildSDKInterfacesProduct, swiftDriverProduct, swiftDriverDynamicProduct, swiftOptionsProduct, swiftDriverExecutionProduct]
        )
        
        let swiftCryptoPackage = createPackage(
            identity: swiftCryptoIdentity,
            displayName: "swift-crypto",
            path: "/swift-crypto",
            modules: [cryptoModule, cryptoExtrasModule],
            products: [cryptoProduct, cryptoExtrasProduct]
        )
        
        let swiftSyntaxPackage = createPackage(
            identity: swiftSyntaxIdentity,
            displayName: "swift-syntax",
            path: "/swift-syntax",
            modules: [swiftSyntaxModule, swiftBasicFormatModule, swiftCompilerPluginModule, swiftDiagnosticsModule, swiftIDEUtilsModule, swiftIfConfigModule, swiftLexicalLookupModule, swiftOperatorsModule, swiftParserModule, swiftParserDiagnosticsModule, swiftRefactorModule, swiftSyntaxBuilderModule, swiftSyntaxMacrosModule, swiftSyntaxMacroExpansionModule, swiftSyntaxMacrosTestSupportModule, swiftSyntaxMacrosGenericTestSupportModule, swiftCompilerPluginMessageHandlingModule, swiftLibraryPluginProviderModule],
            products: [swiftSyntaxProduct, swiftBasicFormatProduct, swiftCompilerPluginProduct, swiftDiagnosticsProduct, swiftIDEUtilsProduct, swiftIfConfigProduct, swiftLexicalLookupProduct, swiftOperatorsProduct, swiftParserProduct, swiftParserDiagnosticsProduct, swiftRefactorProduct, swiftSyntaxBuilderProduct, swiftSyntaxMacrosProduct, swiftSyntaxMacroExpansionProduct, swiftSyntaxMacrosTestSupportProduct, swiftSyntaxMacrosGenericTestSupportProduct, swiftCompilerPluginMessageHandlingProduct, swiftLibraryPluginProviderProduct]
        )
        
        let swiftCertificatesPackage = createPackage(
            identity: swiftCertificatesIdentity,
            displayName: "swift-certificates",
            path: "/swift-certificates",
            modules: [x509Module],
            products: [x509Product]
        )
        
        let swiftASN1Package = createPackage(
            identity: swiftASN1Identity,
            displayName: "swift-asn1",
            path: "/swift-asn1",
            modules: [swiftASN1Module],
            products: [swiftASN1Product]
        )
        
        let swiftDoccPluginPackage = createPackage(
            identity: swiftDoccPluginIdentity,
            displayName: "swift-docc-plugin",
            path: "/swift-docc-plugin",
            modules: [swiftDoccModule, swiftDoccPreviewModule],
            products: [swiftDoccProduct, swiftDoccPreviewProduct]
        )
        
        let swiftDoccSymbolKitPackage = createPackage(
            identity: swiftDoccSymbolKitIdentity,
            displayName: "swift-docc-symbolkit",
            path: "/swift-docc-symbolkit",
            modules: [swiftDoccSymbolKitModule],
            products: [swiftDoccSymbolKitProduct]
        )
        
        let swiftJsonSchemaPackage = createPackage(
            identity: swiftJsonSchemaIdentity,
            displayName: "swift-json-schema",
            path: "/swift-json-schema",
            modules: [jsonSchemaModule, jsonSchemaBuilderModule, jsonSchemaClientModule, jsonSchemaConversionModule],
            products: [jsonSchemaProduct, jsonSchemaBuilderProduct, jsonSchemaClientProduct, jsonSchemaConversionProduct]
        )
        
        let swiftBuildPackage = createPackage(
            identity: swiftBuildIdentity,
            displayName: "swift-build",
            path: "/swift-build",
            modules: [swbuildModule, swbBuildServiceBundleModule, swiftBuildModule, swbProtocolModule, swbUtilModule, swbProjectModelModule, swbBuildServiceModule],
            products: [swbuildProduct, swbBuildServiceBundleProduct, swiftBuildProduct, swbProtocolProduct, swbUtilProduct, swbProjectModelProduct, swbBuildServiceProduct]
        )
        
        // Create resolved modules for external dependencies
        let resolvedSystemPackageModule = createResolvedModule(
            packageIdentity: swiftSystemIdentity,
            module: systemPackageModule
        )
        
        let resolvedDequeModuleModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: dequeModuleModule
        )
        
        let resolvedOrderedCollectionsModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: orderedCollectionsModule
        )
        
        let resolvedBitCollectionsModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: bitCollectionsModule
        )
        
        let resolvedHashTreeCollectionsModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: hashTreeCollectionsModule
        )
        
        let resolvedHeapModuleModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: heapModuleModule
        )
        
        let resolvedRopeModuleModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: ropeModuleModule
        )
        
        let resolvedCollectionsModule = createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: collectionsModule
        )
        
        let resolvedArgumentParserModule = createResolvedModule(
            packageIdentity: swiftArgumentParserIdentity,
            module: argumentParserModule
        )
        
        let resolvedGenerateManualModule = createResolvedModule(
            packageIdentity: swiftArgumentParserIdentity,
            module: generateManualModule
        )
        
        let resolvedLLBuildModule = createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildModule
        )
        
        let resolvedLibllbuildModule = createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: libllbuildModule
        )
        
        let resolvedLLBuildSwiftModule = createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildSwiftModule
        )
        
        let resolvedLLBuildAnalysisModule = createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildAnalysisModule
        )
        
        let resolvedLLBuildSwiftDynamicModule = createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildSwiftDynamicModule
        )
        
        let resolvedTSCBasicModule = createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: tscBasicModule
        )
        
        let resolvedSwiftToolsSupportModule = createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: swiftToolsSupportModule
        )
        
        let resolvedSwiftToolsSupportAutoModule = createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: swiftToolsSupportAutoModule
        )
        
        let resolvedTSCTestSupportModule = createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: tscTestSupportModule
        )
        
        let resolvedSwiftDriverModule = createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftDriverModule
        )
        
        let resolvedCryptoModule = createResolvedModule(
            packageIdentity: swiftCryptoIdentity,
            module: cryptoModule
        )
        
        let resolvedCryptoExtrasModule = createResolvedModule(
            packageIdentity: swiftCryptoIdentity,
            module: cryptoExtrasModule
        )
        
        let resolvedX509Module = createResolvedModule(
            packageIdentity: swiftCertificatesIdentity,
            module: x509Module
        )
        
        let resolvedBasicsModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: basicsModule,
            dependencies: [
                .product(createResolvedProduct(
                    packageIdentity: swiftSystemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: dequeModuleProduct,
                    modules: IdentifiableSet([resolvedDequeModuleModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftToolsSupportCoreIdentity,
                    product: swiftToolsSupportAutoOriginalProduct,
                    modules: IdentifiableSet([resolvedSwiftToolsSupportAutoModule])
                ), conditions: [])
            ]
        )
        
        let resolvedPackageModelModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageModelModule,
            dependencies: [.module(resolvedBasicsModule, conditions: [])]
        )
        
        let resolvedPackageLoadingModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageLoadingModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: [])
            ]
        )
        
        let resolvedSourceControlModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: sourceControlModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: [])
            ]
        )
        
        let resolvedPackageGraphModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageGraphModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageLoadingModule, conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: [])
            ]
        )
        
        let resolvedWorkspaceModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: workspaceModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: [])
            ]
        )
        
        let resolvedBuildModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: buildModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftLLBuildIdentity,
                    product: llbuildSwiftProduct,
                    modules: IdentifiableSet([resolvedLLBuildSwiftModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftDriverIdentity,
                    product: swiftDriverProduct,
                    modules: IdentifiableSet([resolvedSwiftDriverModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: [])
            ]
        )
        
        let resolvedCommandsModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: commandsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedBuildModule, conditions: []),
                .module(resolvedWorkspaceModule, conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftArgumentParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: [])
            ]
        )
        
        let resolvedSBOMModelModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: sbomModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedBuildModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMAutoModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMAutoModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMDataModelModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMDataModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMDataModelAutoModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMDataModelAutoModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: [])
            ]
        )
        
        let resolvedXCBuildSupportModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: xcBuildSupportModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: [])
            ]
        )
        
        let resolvedPackageDescriptionModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageDescriptionModule
        )
        
        let resolvedAppleProductTypesModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: appleProductTypesModule
        )
        
        let resolvedPackagePluginModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packagePluginModule
        )
        
        let resolvedPackageCollectionsModelModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageCollectionsModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMPackageCollectionsModule = createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMPackageCollectionsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageCollectionsModelModule, conditions: [])
            ]
        )
        
        let resolvedSwiftPMDataModelProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMDataModelProduct,
            modules: IdentifiableSet([resolvedSwiftPMDataModelModule])
        )
        
        let resolvedSwiftPMDataModelAutoProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMDataModelAutoProduct,
            modules: IdentifiableSet([resolvedSwiftPMDataModelAutoModule])
        )
        
        let resolvedSwiftPMProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMProduct,
            modules: IdentifiableSet([resolvedSwiftPMModule])
        )
        
        let resolvedSwiftPMAutoProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMAutoProduct,
            modules: IdentifiableSet([resolvedSwiftPMAutoModule])
        )
        
        let resolvedXCBuildSupportProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: xcBuildSupportProduct,
            modules: IdentifiableSet([resolvedXCBuildSupportModule])
        )
        
        let resolvedPackageDescriptionProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packageDescriptionProduct,
            modules: IdentifiableSet([resolvedPackageDescriptionModule])
        )
        
        let resolvedAppleProductTypesProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: appleProductTypesProduct,
            modules: IdentifiableSet([resolvedAppleProductTypesModule])
        )
        
        let resolvedPackagePluginProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packagePluginProduct,
            modules: IdentifiableSet([resolvedPackagePluginModule])
        )
        
        let resolvedPackageCollectionsModelProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packageCollectionsModelProduct,
            modules: IdentifiableSet([resolvedPackageCollectionsModelModule])
        )
        
        let resolvedSwiftPMPackageCollectionsProduct = createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMPackageCollectionsProduct,
            modules: IdentifiableSet([resolvedSwiftPMPackageCollectionsModule])
        )
        
        let resolvedSystemPackageProduct = createResolvedProduct(
            packageIdentity: swiftSystemIdentity,
            product: systemPackageProduct,
            modules: IdentifiableSet([resolvedSystemPackageModule])
        )
        
        let resolvedDequeModuleProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: dequeModuleProduct,
            modules: IdentifiableSet([resolvedDequeModuleModule])
        )
        
        let resolvedBitCollectionsProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: bitCollectionsProduct,
            modules: IdentifiableSet([resolvedBitCollectionsModule])
        )
        
        let resolvedHashTreeCollectionsProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: hashTreeCollectionsProduct,
            modules: IdentifiableSet([resolvedHashTreeCollectionsModule])
        )
        
        let resolvedHeapModuleProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: heapModuleProduct,
            modules: IdentifiableSet([resolvedHeapModuleModule])
        )
        
        let resolvedRopeModuleProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: ropeModuleProduct,
            modules: IdentifiableSet([resolvedRopeModuleModule])
        )
        
        let resolvedCollectionsProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: collectionsProduct,
            modules: IdentifiableSet([resolvedCollectionsModule])
        )
        
        let resolvedOrderedCollectionsProduct = createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: orderedCollectionsProduct,
            modules: IdentifiableSet([resolvedOrderedCollectionsModule])
        )
        
        let resolvedGenerateManualProduct = createResolvedProduct(
            packageIdentity: swiftArgumentParserIdentity,
            product: generateManualProduct,
            modules: IdentifiableSet([resolvedGenerateManualModule])
        )
        
        let resolvedArgumentParserProduct = createResolvedProduct(
            packageIdentity: swiftArgumentParserIdentity,
            product: argumentParserProduct,
            modules: IdentifiableSet([resolvedArgumentParserModule])
        )
        
        let resolvedLLBuildProduct = createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildProduct,
            modules: IdentifiableSet([resolvedLLBuildModule])
        )
        
        let resolvedLibllbuildProduct = createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: libllbuildProduct,
            modules: IdentifiableSet([resolvedLibllbuildModule])
        )
        
        let resolvedLLBuildSwiftProduct = createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildSwiftProduct,
            modules: IdentifiableSet([resolvedLLBuildSwiftModule])
        )
        
        let resolvedLLBuildAnalysisProduct = createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildAnalysisProduct,
            modules: IdentifiableSet([resolvedLLBuildAnalysisModule])
        )
        
        let resolvedLLBuildSwiftDynamicProduct = createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildSwiftDynamicProduct,
            modules: IdentifiableSet([resolvedLLBuildSwiftDynamicModule])
        )
        
        let resolvedTSCBasicProduct = createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: tscBasicProduct,
            modules: IdentifiableSet([resolvedTSCBasicModule])
        )
        
        let resolvedSwiftToolsSupportProduct = createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: swiftToolsSupportProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
        )
        
        let resolvedSwiftToolsSupportAutoProduct = createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: swiftToolsSupportAutoOriginalProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportAutoModule])
        )
        
        let resolvedTSCTestSupportProduct = createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: tscTestSupportProduct,
            modules: IdentifiableSet([resolvedTSCTestSupportModule])
        )
        
        let resolvedCryptoExtrasProduct = createResolvedProduct(
            packageIdentity: swiftCryptoIdentity,
            product: cryptoExtrasProduct,
            modules: IdentifiableSet([resolvedCryptoExtrasModule])
        )
        
        let resolvedSwiftDriverProduct = createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftDriverProduct,
            modules: IdentifiableSet([resolvedSwiftDriverModule])
        )
        
        let resolvedCryptoProduct = createResolvedProduct(
            packageIdentity: swiftCryptoIdentity,
            product: cryptoProduct,
            modules: IdentifiableSet([resolvedCryptoModule])
        )
        
        let resolvedX509Product = createResolvedProduct(
            packageIdentity: swiftCertificatesIdentity,
            product: x509Product,
            modules: IdentifiableSet([resolvedX509Module])
        )
        
        let resolvedSwiftPMPackage = createResolvedPackage(
            package: swiftPMPackage,
            modules: IdentifiableSet([
                resolvedBasicsModule, resolvedPackageModelModule, resolvedPackageLoadingModule,
                resolvedPackageGraphModule, resolvedSourceControlModule, resolvedWorkspaceModule,
                resolvedBuildModule, resolvedSBOMModelModule, resolvedCommandsModule,
                resolvedSwiftPMModule, resolvedSwiftPMAutoModule, resolvedSwiftPMDataModelModule,
                resolvedSwiftPMDataModelAutoModule, resolvedXCBuildSupportModule, resolvedPackageDescriptionModule,
                resolvedAppleProductTypesModule, resolvedPackagePluginModule, resolvedPackageCollectionsModelModule,
                resolvedSwiftPMPackageCollectionsModule
            ]),
            products: [resolvedSwiftPMDataModelProduct, resolvedSwiftPMDataModelAutoProduct, resolvedSwiftPMProduct, resolvedSwiftPMAutoProduct, resolvedXCBuildSupportProduct, resolvedPackageDescriptionProduct, resolvedAppleProductTypesProduct, resolvedPackagePluginProduct, resolvedPackageCollectionsModelProduct, resolvedSwiftPMPackageCollectionsProduct],
            dependencies: [swiftSystemIdentity, swiftCollectionsIdentity, swiftArgumentParserIdentity, swiftLLBuildIdentity, swiftToolsSupportCoreIdentity, swiftDriverIdentity, swiftCryptoIdentity, swiftCertificatesIdentity]
        )
        
        let resolvedSwiftSystemPackage = createResolvedPackage(
            package: swiftSystemPackage,
            modules: IdentifiableSet([resolvedSystemPackageModule]),
            products: [resolvedSystemPackageProduct]
        )
        
        let resolvedSwiftCollectionsPackage = createResolvedPackage(
            package: swiftCollectionsPackage,
            modules: IdentifiableSet([resolvedDequeModuleModule, resolvedOrderedCollectionsModule, resolvedBitCollectionsModule, resolvedHashTreeCollectionsModule, resolvedHeapModuleModule, resolvedRopeModuleModule, resolvedCollectionsModule]),
            products: [resolvedDequeModuleProduct, resolvedOrderedCollectionsProduct, resolvedBitCollectionsProduct, resolvedHashTreeCollectionsProduct, resolvedHeapModuleProduct, resolvedRopeModuleProduct, resolvedCollectionsProduct]
        )
        
        let resolvedSwiftArgumentParserPackage = createResolvedPackage(
            package: swiftArgumentParserPackage,
            modules: IdentifiableSet([resolvedArgumentParserModule, resolvedGenerateManualModule]),
            products: [resolvedArgumentParserProduct, resolvedGenerateManualProduct]
        )
        
        let resolvedSwiftLLBuildPackage = createResolvedPackage(
            package: swiftLLBuildPackage,
            modules: IdentifiableSet([resolvedLLBuildModule, resolvedLibllbuildModule, resolvedLLBuildSwiftModule, resolvedLLBuildAnalysisModule, resolvedLLBuildSwiftDynamicModule]),
            products: [resolvedLLBuildProduct, resolvedLibllbuildProduct, resolvedLLBuildSwiftProduct, resolvedLLBuildAnalysisProduct, resolvedLLBuildSwiftDynamicProduct]
        )
        
        let resolvedSwiftToolsSupportCorePackage = createResolvedPackage(
            package: swiftToolsSupportCorePackage,
            modules: IdentifiableSet([resolvedTSCBasicModule, resolvedSwiftToolsSupportModule, resolvedSwiftToolsSupportAutoModule, resolvedTSCTestSupportModule]),
            products: [resolvedTSCBasicProduct, resolvedSwiftToolsSupportProduct, resolvedSwiftToolsSupportAutoProduct, resolvedTSCTestSupportProduct]
        )
        
        let resolvedSwiftDriverPackage = createResolvedPackage(
            package: swiftDriverPackage,
            modules: IdentifiableSet([resolvedSwiftDriverModule]),
            products: [resolvedSwiftDriverProduct]
        )
        
        let resolvedSwiftCryptoPackage = createResolvedPackage(
            package: swiftCryptoPackage,
            modules: IdentifiableSet([resolvedCryptoModule, resolvedCryptoExtrasModule]),
            products: [resolvedCryptoProduct, resolvedCryptoExtrasProduct]
        )
        
        let resolvedSwiftCertificatesPackage = createResolvedPackage(
            package: swiftCertificatesPackage,
            modules: IdentifiableSet([resolvedX509Module]),
            products: [resolvedX509Product]
        )
        
        // Create PackageReference dependencies - based on actual swift package show-dependencies output
        let swiftSystemRef = PackageReference(
            identity: swiftSystemIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-system.git"))
        )
        
        let swiftCollectionsRef = PackageReference(
            identity: swiftCollectionsIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-collections.git"))
        )
        
        let swiftArgumentParserRef = PackageReference(
            identity: swiftArgumentParserIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-argument-parser.git"))
        )
        
        let swiftLLBuildRef = PackageReference(
            identity: swiftLLBuildIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-llbuild.git"))
        )
        
        let swiftToolsSupportCoreRef = PackageReference(
            identity: swiftToolsSupportCoreIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-tools-support-core.git"))
        )
        
        let swiftDriverRef = PackageReference(
            identity: swiftDriverIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-driver.git"))
        )
        
        let swiftCryptoRef = PackageReference(
            identity: swiftCryptoIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-crypto.git"))
        )
        
        let swiftCertificatesRef = PackageReference(
            identity: swiftCertificatesIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-certificates.git"))
        )
        
        let swiftSyntaxRef = PackageReference(
            identity: swiftSyntaxIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-syntax.git"))
        )
        
        let swiftToolchainSQLiteRef = PackageReference(
            identity: swiftToolchainSQLiteIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-toolchain-sqlite.git"))
        )
        
        let swiftDoccPluginRef = PackageReference(
            identity: swiftDoccPluginIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-docc-plugin.git"))
        )
        
        let swiftBuildRef = PackageReference(
            identity: swiftBuildIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swiftlang/swift-build.git"))
        )
        
        // Create the final ModulesGraph
        let allResolvedPackages: IdentifiableSet<ResolvedPackage> = IdentifiableSet([
            resolvedSwiftPMPackage,
            resolvedSwiftSystemPackage,
            resolvedSwiftCollectionsPackage,
            resolvedSwiftArgumentParserPackage,
            resolvedSwiftLLBuildPackage,
            resolvedSwiftToolsSupportCorePackage,
            resolvedSwiftDriverPackage,
            resolvedSwiftCryptoPackage,
            resolvedSwiftCertificatesPackage
        ])
        
        // Root dependencies are the direct dependency packages of the root package
        let rootDependencies = [
            resolvedSwiftSystemPackage,
            resolvedSwiftCollectionsPackage,
            resolvedSwiftArgumentParserPackage,
            resolvedSwiftLLBuildPackage,
            resolvedSwiftToolsSupportCorePackage,
            resolvedSwiftDriverPackage,
            resolvedSwiftCryptoPackage,
            resolvedSwiftCertificatesPackage
        ]
        
        // All PackageReference dependencies
        let packageReferences = [
            swiftSystemRef,
            swiftCollectionsRef,
            swiftArgumentParserRef,
            swiftLLBuildRef,
            swiftToolsSupportCoreRef,
            swiftDriverRef,
            swiftCryptoRef,
            swiftCertificatesRef,
            swiftSyntaxRef,
            swiftToolchainSQLiteRef,
            swiftDoccPluginRef,
            swiftBuildRef
        ]
        
        return try ModulesGraph(
            rootPackages: [resolvedSwiftPMPackage],
            rootDependencies: rootDependencies,
            packages: allResolvedPackages,
            dependencies: packageReferences, // All external package dependencies
            binaryArtifacts: [:]
        )
    }

    // MARK: - Swiftly Sample ModulesGraph

    static func createSwiftlyModulesGraph(rootPath: String = "/tmp/swiftly-mock") throws -> ModulesGraph {
        let swiftlyIdentity = PackageIdentity.plain("swiftly")
        let argParserIdentity = PackageIdentity.plain("swift-argument-parser")
        let httpClientIdentity = PackageIdentity.plain("async-http-client")
        let openAPIAsyncHTTPClientIdentity = PackageIdentity.plain("swift-openapi-async-http-client")
        let nioIdentity = PackageIdentity.plain("swift-nio")
        let toolsSupportIdentity = PackageIdentity.plain("swift-tools-support-core")
        let openAPIRuntimeIdentity = PackageIdentity.plain("swift-openapi-runtime")
        let systemIdentity = PackageIdentity.plain("swift-system")

        let argumentParserModule = createSwiftModule(name: "ArgumentParser")
        let asyncHTTPClientModule = createSwiftModule(name: "AsyncHTTPClient")
        let openAPIAsyncHTTPClientModule = createSwiftModule(name: "OpenAPIAsyncHTTPClient")
        let nioFoundationCompatModule = createSwiftModule(name: "NIOFoundationCompat")
        let swiftToolsSupportModule = createSwiftModule(name: "SwiftToolsSupport-auto")
        let openAPIRuntimeModule = createSwiftModule(name: "OpenAPIRuntime")
        let systemPackageModule = createSwiftModule(name: "SystemPackage")
        
        let swiftlyModule = createSwiftModule(name: "Swiftly", type: .executable)
        let testSwiftlyModule = createSwiftModule(name: "TestSwiftly", type: .executable)
        let swiftlyWebsiteAPIModule = createSwiftModule(name: "SwiftlyWebsiteAPI")
        let swiftlyDownloadAPIModule = createSwiftModule(name: "SwiftlyDownloadAPI")
        let swiftlyCoreModule = createSwiftModule(name: "SwiftlyCore")
        let macOSPlatformModule = createSwiftModule(name: "MacOSPlatform")
        let linuxPlatformModule = createSwiftModule(name: "LinuxPlatform")
        
        let swiftlyProduct = try Product(
            package: swiftlyIdentity,
            name: "swiftly",
            type: .executable,
            modules: [swiftlyModule]
        )
        
        let testSwiftlyProduct = try Product(
            package: swiftlyIdentity,
            name: "test-swiftly",
            type: .executable,
            modules: [testSwiftlyModule]
        )
        
        let argumentParserProduct = try Product(
            package: argParserIdentity,
            name: "ArgumentParser",
            type: .library(.automatic),
            modules: [argumentParserModule]
        )
        
        let asyncHTTPClientProduct = try Product(
            package: httpClientIdentity,
            name: "AsyncHTTPClient",
            type: .library(.automatic),
            modules: [asyncHTTPClientModule]
        )
        
        let openAPIAsyncHTTPClientProduct = try Product(
            package: openAPIAsyncHTTPClientIdentity,
            name: "OpenAPIAsyncHTTPClient",
            type: .library(.automatic),
            modules: [openAPIAsyncHTTPClientModule]
        )
        
        let nioFoundationCompatProduct = try Product(
            package: nioIdentity,
            name: "NIOFoundationCompat",
            type: .library(.automatic),
            modules: [nioFoundationCompatModule]
        )
        
        let swiftToolsSupportProduct = try Product(
            package: toolsSupportIdentity,
            name: "SwiftToolsSupport-auto",
            type: .library(.automatic),
            modules: [swiftToolsSupportModule]
        )
        
        let openAPIRuntimeProduct = try Product(
            package: openAPIRuntimeIdentity,
            name: "OpenAPIRuntime",
            type: .library(.automatic),
            modules: [openAPIRuntimeModule]
        )
        
        let systemPackageProduct = try Product(
            package: systemIdentity,
            name: "SystemPackage",
            type: .library(.automatic),
            modules: [systemPackageModule]
        )
        
        let swiftlyPackage = createPackage(
            identity: swiftlyIdentity,
            displayName: "swiftly",
            path: rootPath,
            modules: [swiftlyModule, testSwiftlyModule, swiftlyWebsiteAPIModule, swiftlyDownloadAPIModule, swiftlyCoreModule, macOSPlatformModule, linuxPlatformModule],
            products: [swiftlyProduct, testSwiftlyProduct]
        )
        
        let argParserPackage = createPackage(
            identity: argParserIdentity,
            displayName: "swift-argument-parser",
            path: "/swift-argument-parser",
            modules: [argumentParserModule],
            products: [argumentParserProduct]
        )
        
        let httpClientPackage = createPackage(
            identity: httpClientIdentity,
            displayName: "async-http-client",
            path: "/async-http-client",
            modules: [asyncHTTPClientModule],
            products: [asyncHTTPClientProduct]
        )
        
        let openAPIAsyncHTTPClientPackage = createPackage(
            identity: openAPIAsyncHTTPClientIdentity,
            displayName: "swift-openapi-async-http-client",
            path: "/swift-openapi-async-http-client",
            modules: [openAPIAsyncHTTPClientModule],
            products: [openAPIAsyncHTTPClientProduct]
        )
        
        let nioPackage = createPackage(
            identity: nioIdentity,
            displayName: "swift-nio",
            path: "/swift-nio",
            modules: [nioFoundationCompatModule],
            products: [nioFoundationCompatProduct]
        )
        
        let toolsSupportPackage = createPackage(
            identity: toolsSupportIdentity,
            displayName: "swift-tools-support-core",
            path: "/swift-tools-support-core",
            modules: [swiftToolsSupportModule],
            products: [swiftToolsSupportProduct]
        )
        
        let openAPIRuntimePackage = createPackage(
            identity: openAPIRuntimeIdentity,
            displayName: "swift-openapi-runtime",
            path: "/swift-openapi-runtime",
            modules: [openAPIRuntimeModule],
            products: [openAPIRuntimeProduct]
        )
        
        let systemPackage = createPackage(
            identity: systemIdentity,
            displayName: "swift-system",
            path: "/swift-system",
            modules: [systemPackageModule],
            products: [systemPackageProduct]
        )
        
        let resolvedArgumentParserModule = createResolvedModule(
            packageIdentity: argParserIdentity,
            module: argumentParserModule
        )
        
        let resolvedAsyncHTTPClientModule = createResolvedModule(
            packageIdentity: httpClientIdentity,
            module: asyncHTTPClientModule
        )
        
        let resolvedOpenAPIAsyncHTTPClientModule = createResolvedModule(
            packageIdentity: openAPIAsyncHTTPClientIdentity,
            module: openAPIAsyncHTTPClientModule
        )
        
        let resolvedNIOFoundationCompatModule = createResolvedModule(
            packageIdentity: nioIdentity,
            module: nioFoundationCompatModule
        )
        
        let resolvedSwiftToolsSupportModule = createResolvedModule(
            packageIdentity: toolsSupportIdentity,
            module: swiftToolsSupportModule
        )
        
        let resolvedOpenAPIRuntimeModule = createResolvedModule(
            packageIdentity: openAPIRuntimeIdentity,
            module: openAPIRuntimeModule
        )
        
        let resolvedSystemPackageModule = createResolvedModule(
            packageIdentity: systemIdentity,
            module: systemPackageModule
        )
        
        let resolvedSwiftlyModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyModule,
            dependencies: [
                .product(createResolvedProduct(
                    packageIdentity: argParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyCoreModule), conditions: []),
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: macOSPlatformModule), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: toolsSupportIdentity,
                    product: swiftToolsSupportProduct,
                    modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: [])
            ]
        )
        
        let resolvedTestSwiftlyModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: testSwiftlyModule,
            dependencies: [
                .product(createResolvedProduct(
                    packageIdentity: argParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyCoreModule), conditions: []),
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: macOSPlatformModule), conditions: [])
            ]
        )
        
        let resolvedSwiftlyWebsiteAPIModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyWebsiteAPIModule,
            dependencies: [
                .product(createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: [])
            ]
        )
        
        let resolvedSwiftlyDownloadAPIModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyDownloadAPIModule,
            dependencies: [
                .product(createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: [])
            ]
        )
        
        let resolvedSwiftlyCoreModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyCoreModule,
            dependencies: [
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyDownloadAPIModule), conditions: []),
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyWebsiteAPIModule), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: httpClientIdentity,
                    product: asyncHTTPClientProduct,
                    modules: IdentifiableSet([resolvedAsyncHTTPClientModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: nioIdentity,
                    product: nioFoundationCompatProduct,
                    modules: IdentifiableSet([resolvedNIOFoundationCompatModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: openAPIAsyncHTTPClientIdentity,
                    product: openAPIAsyncHTTPClientProduct,
                    modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule])
                ), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: [])
            ]
        )
        
        let resolvedMacOSPlatformModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: macOSPlatformModule,
            dependencies: [
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyCoreModule), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: [])
            ]
        )
        
        let resolvedLinuxPlatformModule = createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: linuxPlatformModule,
            dependencies: [
                .module(createResolvedModule(packageIdentity: swiftlyIdentity, module: swiftlyCoreModule), conditions: []),
                .product(createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: [])
            ]
        )
        
        let resolvedSwiftlyProduct = createResolvedProduct(
            packageIdentity: swiftlyIdentity,
            product: swiftlyProduct,
            modules: IdentifiableSet([resolvedSwiftlyModule])
        )
        
        let resolvedTestSwiftlyProduct = createResolvedProduct(
            packageIdentity: swiftlyIdentity,
            product: testSwiftlyProduct,
            modules: IdentifiableSet([resolvedTestSwiftlyModule])
        )
        
        let resolvedArgumentParserProduct = createResolvedProduct(
            packageIdentity: argParserIdentity,
            product: argumentParserProduct,
            modules: IdentifiableSet([resolvedArgumentParserModule])
        )
        
        let resolvedAsyncHTTPClientProduct = createResolvedProduct(
            packageIdentity: httpClientIdentity,
            product: asyncHTTPClientProduct,
            modules: IdentifiableSet([resolvedAsyncHTTPClientModule])
        )
        
        let resolvedOpenAPIAsyncHTTPClientProduct = createResolvedProduct(
            packageIdentity: openAPIAsyncHTTPClientIdentity,
            product: openAPIAsyncHTTPClientProduct,
            modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule])
        )
        
        let resolvedNIOFoundationCompatProduct = createResolvedProduct(
            packageIdentity: nioIdentity,
            product: nioFoundationCompatProduct,
            modules: IdentifiableSet([resolvedNIOFoundationCompatModule])
        )
        
        let resolvedSwiftToolsSupportProduct = createResolvedProduct(
            packageIdentity: toolsSupportIdentity,
            product: swiftToolsSupportProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
        )
        
        let resolvedOpenAPIRuntimeProduct = createResolvedProduct(
            packageIdentity: openAPIRuntimeIdentity,
            product: openAPIRuntimeProduct,
            modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
        )
        
        let resolvedSystemPackageProduct = createResolvedProduct(
            packageIdentity: systemIdentity,
            product: systemPackageProduct,
            modules: IdentifiableSet([resolvedSystemPackageModule])
        )
        
        let resolvedSwiftlyPackage = createResolvedPackage(
            package: swiftlyPackage,
            modules: IdentifiableSet([
                resolvedSwiftlyModule, resolvedTestSwiftlyModule, resolvedSwiftlyWebsiteAPIModule,
                resolvedSwiftlyDownloadAPIModule, resolvedSwiftlyCoreModule, resolvedMacOSPlatformModule, resolvedLinuxPlatformModule
            ]),
            products: [resolvedSwiftlyProduct, resolvedTestSwiftlyProduct],
            dependencies: [argParserIdentity, httpClientIdentity, openAPIAsyncHTTPClientIdentity, nioIdentity, toolsSupportIdentity, openAPIRuntimeIdentity, systemIdentity]
        )
        
        let resolvedArgParserPackage = createResolvedPackage(
            package: argParserPackage,
            modules: IdentifiableSet([resolvedArgumentParserModule]),
            products: [resolvedArgumentParserProduct]
        )
        
        let resolvedHttpClientPackage = createResolvedPackage(
            package: httpClientPackage,
            modules: IdentifiableSet([resolvedAsyncHTTPClientModule]),
            products: [resolvedAsyncHTTPClientProduct]
        )
        
        let resolvedOpenAPIAsyncHTTPClientPackage = createResolvedPackage(
            package: openAPIAsyncHTTPClientPackage,
            modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule]),
            products: [resolvedOpenAPIAsyncHTTPClientProduct]
        )
        
        let resolvedNIOPackage = createResolvedPackage(
            package: nioPackage,
            modules: IdentifiableSet([resolvedNIOFoundationCompatModule]),
            products: [resolvedNIOFoundationCompatProduct]
        )
        
        let resolvedToolsSupportPackage = createResolvedPackage(
            package: toolsSupportPackage,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule]),
            products: [resolvedSwiftToolsSupportProduct]
        )
        
        let resolvedOpenAPIRuntimePackage = createResolvedPackage(
            package: openAPIRuntimePackage,
            modules: IdentifiableSet([resolvedOpenAPIRuntimeModule]),
            products: [resolvedOpenAPIRuntimeProduct]
        )
        
        let resolvedSystemPackage = createResolvedPackage(
            package: systemPackage,
            modules: IdentifiableSet([resolvedSystemPackageModule]),
            products: [resolvedSystemPackageProduct]
        )
        
        let argParserRef = PackageReference(
            identity: argParserIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-argument-parser.git"))
        )
        
        let httpClientRef = PackageReference(
            identity: httpClientIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swift-server/async-http-client.git"))
        )
        
        let openAPIAsyncHTTPClientRef = PackageReference(
            identity: openAPIAsyncHTTPClientIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/swift-server/swift-openapi-async-http-client.git"))
        )
        
        let nioRef = PackageReference(
            identity: nioIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-nio.git"))
        )
        
        let toolsSupportRef = PackageReference(
            identity: toolsSupportIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-tools-support-core.git"))
        )
        
        let openAPIRuntimeRef = PackageReference(
            identity: openAPIRuntimeIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-openapi-runtime.git"))
        )
        
        let systemRef = PackageReference(
            identity: systemIdentity,
            kind: .remoteSourceControl(SourceControlURL("https://github.com/apple/swift-system.git"))
        )
        
        let allResolvedPackages: IdentifiableSet<ResolvedPackage> = IdentifiableSet([
            resolvedSwiftlyPackage,
            resolvedSystemPackage,
            resolvedOpenAPIRuntimePackage,
            resolvedToolsSupportPackage,
            resolvedNIOPackage,
            resolvedOpenAPIAsyncHTTPClientPackage,
            resolvedHttpClientPackage,
            resolvedArgParserPackage
        ])
        
        let rootDependencies = [
            resolvedArgParserPackage,
            resolvedHttpClientPackage,
            resolvedOpenAPIAsyncHTTPClientPackage,
            resolvedNIOPackage,
            resolvedToolsSupportPackage,
            resolvedOpenAPIRuntimePackage,
            resolvedSystemPackage
        ]
        
        let packageReferences = [
            argParserRef,
            httpClientRef,
            openAPIAsyncHTTPClientRef,
            nioRef,
            toolsSupportRef,
            openAPIRuntimeRef,
            systemRef
        ]
        
        return try ModulesGraph(
            rootPackages: [resolvedSwiftlyPackage],
            rootDependencies: rootDependencies,
            packages: allResolvedPackages,
            dependencies: packageReferences,
            binaryArtifacts: [:]
        )
    }
}