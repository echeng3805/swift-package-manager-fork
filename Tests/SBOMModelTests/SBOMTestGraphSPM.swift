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

extension SBOMTestGraph {
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

        let basicsModule = self.createSwiftModule(name: "Basics")
        let packageModelModule = self.createSwiftModule(name: "PackageModel", dependencies: [
            .module(basicsModule, conditions: []),
        ])
        let sbomModelModule = self.createSwiftModule(name: "SBOMModel", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let packageGraphModule = self.createSwiftModule(name: "PackageGraph", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let packageLoadingModule = self.createSwiftModule(name: "PackageLoading", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let sourceControlModule = self.createSwiftModule(name: "SourceControl", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let workspaceModule = self.createSwiftModule(name: "Workspace", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
            .module(packageGraphModule, conditions: []),
        ])
        let buildModule = self.createSwiftModule(name: "Build", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageGraphModule, conditions: []),
        ])
        let commandsModule = self.createSwiftModule(name: "Commands", dependencies: [
            .module(basicsModule, conditions: []),
            .module(buildModule, conditions: []),
            .module(workspaceModule, conditions: []),
        ])

        // Additional SwiftPM modules to match expected SBOM structure
        let swiftPMModule = self.createSwiftModule(name: "SwiftPM", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
            .module(packageGraphModule, conditions: []),
            .module(buildModule, conditions: []),
        ])
        let swiftPMAutoModule = self.createSwiftModule(name: "SwiftPM-auto", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let swiftPMDataModelModule = self.createSwiftModule(name: "SwiftPMDataModel", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let swiftPMDataModelAutoModule = self.createSwiftModule(name: "SwiftPMDataModel-auto", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageModelModule, conditions: []),
        ])
        let xcBuildSupportModule = self.createSwiftModule(name: "XCBuildSupport", dependencies: [
            .module(basicsModule, conditions: []),
        ])
        let packageDescriptionModule = self.createSwiftModule(name: "PackageDescription")
        let appleProductTypesModule = self.createSwiftModule(name: "AppleProductTypes")
        let packagePluginModule = self.createSwiftModule(name: "PackagePlugin")
        let packageCollectionsModelModule = self.createSwiftModule(name: "PackageCollectionsModel", dependencies: [
            .module(basicsModule, conditions: []),
        ])
        let swiftPMPackageCollectionsModule = self.createSwiftModule(name: "SwiftPMPackageCollections", dependencies: [
            .module(basicsModule, conditions: []),
            .module(packageCollectionsModelModule, conditions: []),
        ])

        // swift-system modules
        let systemPackageModule = self.createSwiftModule(name: "SystemPackage")

        // swift-collections modules
        let dequeModuleModule = self.createSwiftModule(name: "DequeModule")
        let orderedCollectionsModule = self.createSwiftModule(name: "OrderedCollections")
        let bitCollectionsModule = self.createSwiftModule(name: "BitCollections")
        let hashTreeCollectionsModule = self.createSwiftModule(name: "HashTreeCollections")
        let heapModuleModule = self.createSwiftModule(name: "HeapModule")
        let ropeModuleModule = self.createSwiftModule(name: "_RopeModule")
        let collectionsModule = self.createSwiftModule(name: "Collections")

        // swift-argument-parser modules
        let argumentParserModule = self.createSwiftModule(name: "ArgumentParser")
        let generateManualModule = self.createSwiftModule(name: "GenerateManual")

        // swift-llbuild modules
        let llbuildModule = self.createSwiftModule(name: "llbuild", type: .executable)
        let libllbuildModule = self.createSwiftModule(name: "libllbuild")
        let llbuildSwiftModule = self.createSwiftModule(name: "llbuildSwift")
        let llbuildAnalysisModule = self.createSwiftModule(name: "llbuildAnalysis")
        let llbuildSwiftDynamicModule = self.createSwiftModule(name: "llbuildSwiftDynamic")

        // swift-toolchain-sqlite modules
        let sqliteModule = self.createSwiftModule(name: "sqlite", type: .executable)
        let swiftToolchainCSQLiteModule = self.createSwiftModule(name: "SwiftToolchainCSQLite")

        // swift-crypto modules
        let cryptoModule = self.createSwiftModule(name: "Crypto")
        let cryptoExtrasModule = self.createSwiftModule(name: "_CryptoExtras")

        // swift-syntax modules
        let swiftSyntaxModule = self.createSwiftModule(name: "SwiftSyntax")
        let swiftBasicFormatModule = self.createSwiftModule(name: "SwiftBasicFormat")
        let swiftCompilerPluginModule = self.createSwiftModule(name: "SwiftCompilerPlugin")
        let swiftDiagnosticsModule = self.createSwiftModule(name: "SwiftDiagnostics")
        let swiftIDEUtilsModule = self.createSwiftModule(name: "SwiftIDEUtils")
        let swiftIfConfigModule = self.createSwiftModule(name: "SwiftIfConfig")
        let swiftLexicalLookupModule = self.createSwiftModule(name: "SwiftLexicalLookup")
        let swiftOperatorsModule = self.createSwiftModule(name: "SwiftOperators")
        let swiftParserModule = self.createSwiftModule(name: "SwiftParser")
        let swiftParserDiagnosticsModule = self.createSwiftModule(name: "SwiftParserDiagnostics")
        let swiftRefactorModule = self.createSwiftModule(name: "SwiftRefactor")
        let swiftSyntaxBuilderModule = self.createSwiftModule(name: "SwiftSyntaxBuilder")
        let swiftSyntaxMacrosModule = self.createSwiftModule(name: "SwiftSyntaxMacros")
        let swiftSyntaxMacroExpansionModule = self.createSwiftModule(name: "SwiftSyntaxMacroExpansion")
        let swiftSyntaxMacrosTestSupportModule = self.createSwiftModule(name: "SwiftSyntaxMacrosTestSupport")
        let swiftSyntaxMacrosGenericTestSupportModule = self
            .createSwiftModule(name: "SwiftSyntaxMacrosGenericTestSupport")
        let swiftCompilerPluginMessageHandlingModule = self
            .createSwiftModule(name: "_SwiftCompilerPluginMessageHandling")
        let swiftLibraryPluginProviderModule = self.createSwiftModule(name: "_SwiftLibraryPluginProvider")

        // swift-certificates modules
        let x509Module = self.createSwiftModule(name: "X509")

        // swift-asn1 modules
        let swiftASN1Module = self.createSwiftModule(name: "SwiftASN1")

        // swift-docc-plugin modules
        let swiftDoccModule = self.createSwiftModule(name: "Swift-DocC")
        let swiftDoccPreviewModule = self.createSwiftModule(name: "Swift-DocC Preview")

        // swift-docc-symbolkit modules
        let swiftDoccSymbolKitModule = self.createSwiftModule(name: "SymbolKit")

        // swift-json-schema modules
        let jsonSchemaModule = self.createSwiftModule(name: "JSONSchema")
        let jsonSchemaBuilderModule = self.createSwiftModule(name: "JSONSchemaBuilder")
        let jsonSchemaClientModule = self.createSwiftModule(name: "JSONSchemaClient", type: .executable)
        let jsonSchemaConversionModule = self.createSwiftModule(name: "JSONSchemaConversion")

        // swift-tools-support-core modules
        let tscBasicModule = self.createSwiftModule(name: "TSCBasic")
        let swiftToolsSupportModule = self.createSwiftModule(name: "SwiftToolsSupport")
        let swiftToolsSupportAutoModule = self.createSwiftModule(name: "SwiftToolsSupport-auto")
        let tscTestSupportModule = self.createSwiftModule(name: "TSCTestSupport")

        // swift-driver modules
        let swiftDriverExecutableModule = self.createSwiftModule(name: "swift-driver", type: .executable)
        let swiftHelpModule = self.createSwiftModule(name: "swift-help", type: .executable)
        let swiftBuildSDKInterfacesModule = self.createSwiftModule(
            name: "swift-build-sdk-interfaces",
            type: .executable
        )
        let swiftDriverModule = self.createSwiftModule(name: "SwiftDriver")
        let swiftDriverDynamicModule = self.createSwiftModule(name: "SwiftDriverDynamic")
        let swiftOptionsModule = self.createSwiftModule(name: "SwiftOptions")
        let swiftDriverExecutionModule = self.createSwiftModule(name: "SwiftDriverExecution")

        // swift-build modules
        let swbuildModule = self.createSwiftModule(name: "swbuild", type: .executable)
        let swbBuildServiceBundleModule = self.createSwiftModule(name: "SWBBuildServiceBundle", type: .executable)
        let swiftBuildModule = self.createSwiftModule(name: "SwiftBuild")
        let swbProtocolModule = self.createSwiftModule(name: "SWBProtocol")
        let swbUtilModule = self.createSwiftModule(name: "SWBUtil")
        let swbProjectModelModule = self.createSwiftModule(name: "SWBProjectModel")
        let swbBuildServiceModule = self.createSwiftModule(name: "SWBBuildService")

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

        let swiftPMPackage = self.createPackage(
            identity: swiftPMIdentity,
            displayName: "SwiftPM",
            path: rootPath,
            modules: [
                basicsModule,
                packageModelModule,
                packageLoadingModule,
                packageGraphModule,
                sourceControlModule,
                workspaceModule,
                buildModule,
                sbomModelModule,
                commandsModule,
                swiftPMModule,
                swiftPMAutoModule,
                swiftPMDataModelModule,
                swiftPMDataModelAutoModule,
                xcBuildSupportModule,
                packageDescriptionModule,
                appleProductTypesModule,
                packagePluginModule,
                packageCollectionsModelModule,
                swiftPMPackageCollectionsModule,
            ],
            products: [
                swiftPMDataModelProduct,
                swiftPMDataModelAutoProduct,
                swiftPMProduct,
                swiftPMAutoProduct,
                xcBuildSupportProduct,
                packageDescriptionProduct,
                appleProductTypesProduct,
                packagePluginProduct,
                packageCollectionsModelProduct,
                swiftPMPackageCollectionsProduct,
            ]
        )

        let swiftSystemPackage = self.createPackage(
            identity: swiftSystemIdentity,
            displayName: "swift-system",
            path: "/swift-system",
            modules: [systemPackageModule],
            products: [systemPackageProduct]
        )

        let swiftCollectionsPackage = self.createPackage(
            identity: swiftCollectionsIdentity,
            displayName: "swift-collections",
            path: "/swift-collections",
            modules: [
                dequeModuleModule,
                orderedCollectionsModule,
                bitCollectionsModule,
                hashTreeCollectionsModule,
                heapModuleModule,
                ropeModuleModule,
                collectionsModule,
            ],
            products: [
                dequeModuleProduct,
                orderedCollectionsProduct,
                bitCollectionsProduct,
                hashTreeCollectionsProduct,
                heapModuleProduct,
                ropeModuleProduct,
                collectionsProduct,
            ]
        )

        let swiftArgumentParserPackage = self.createPackage(
            identity: swiftArgumentParserIdentity,
            displayName: "swift-argument-parser",
            path: "/swift-argument-parser",
            modules: [argumentParserModule, generateManualModule],
            products: [argumentParserProduct, generateManualProduct]
        )

        let swiftLLBuildPackage = self.createPackage(
            identity: swiftLLBuildIdentity,
            displayName: "swift-llbuild",
            path: "/swift-llbuild",
            modules: [
                llbuildModule,
                libllbuildModule,
                llbuildSwiftModule,
                llbuildAnalysisModule,
                llbuildSwiftDynamicModule,
            ],
            products: [
                llbuildProduct,
                libllbuildProduct,
                llbuildSwiftProduct,
                llbuildAnalysisProduct,
                llbuildSwiftDynamicProduct,
            ]
        )

        let swiftToolchainSQLitePackage = self.createPackage(
            identity: swiftToolchainSQLiteIdentity,
            displayName: "swift-toolchain-sqlite",
            path: "/swift-toolchain-sqlite",
            modules: [sqliteModule, swiftToolchainCSQLiteModule],
            products: [sqliteProduct, swiftToolchainCSQLiteProduct]
        )

        let swiftToolsSupportCorePackage = self.createPackage(
            identity: swiftToolsSupportCoreIdentity,
            displayName: "swift-tools-support-core",
            path: "/swift-tools-support-core",
            modules: [tscBasicModule, swiftToolsSupportModule, swiftToolsSupportAutoModule, tscTestSupportModule],
            products: [tscBasicProduct, swiftToolsSupportProduct, swiftToolsSupportAutoProduct, tscTestSupportProduct]
        )

        let swiftDriverPackage = self.createPackage(
            identity: swiftDriverIdentity,
            displayName: "swift-driver",
            path: "/swift-driver",
            modules: [
                swiftDriverExecutableModule,
                swiftHelpModule,
                swiftBuildSDKInterfacesModule,
                swiftDriverModule,
                swiftDriverDynamicModule,
                swiftOptionsModule,
                swiftDriverExecutionModule,
            ],
            products: [
                swiftDriverExecutableProduct,
                swiftHelpProduct,
                swiftBuildSDKInterfacesProduct,
                swiftDriverProduct,
                swiftDriverDynamicProduct,
                swiftOptionsProduct,
                swiftDriverExecutionProduct,
            ]
        )

        let swiftCryptoPackage = self.createPackage(
            identity: swiftCryptoIdentity,
            displayName: "swift-crypto",
            path: "/swift-crypto",
            modules: [cryptoModule, cryptoExtrasModule],
            products: [cryptoProduct, cryptoExtrasProduct]
        )

        let swiftSyntaxPackage = self.createPackage(
            identity: swiftSyntaxIdentity,
            displayName: "swift-syntax",
            path: "/swift-syntax",
            modules: [
                swiftSyntaxModule,
                swiftBasicFormatModule,
                swiftCompilerPluginModule,
                swiftDiagnosticsModule,
                swiftIDEUtilsModule,
                swiftIfConfigModule,
                swiftLexicalLookupModule,
                swiftOperatorsModule,
                swiftParserModule,
                swiftParserDiagnosticsModule,
                swiftRefactorModule,
                swiftSyntaxBuilderModule,
                swiftSyntaxMacrosModule,
                swiftSyntaxMacroExpansionModule,
                swiftSyntaxMacrosTestSupportModule,
                swiftSyntaxMacrosGenericTestSupportModule,
                swiftCompilerPluginMessageHandlingModule,
                swiftLibraryPluginProviderModule,
            ],
            products: [
                swiftSyntaxProduct,
                swiftBasicFormatProduct,
                swiftCompilerPluginProduct,
                swiftDiagnosticsProduct,
                swiftIDEUtilsProduct,
                swiftIfConfigProduct,
                swiftLexicalLookupProduct,
                swiftOperatorsProduct,
                swiftParserProduct,
                swiftParserDiagnosticsProduct,
                swiftRefactorProduct,
                swiftSyntaxBuilderProduct,
                swiftSyntaxMacrosProduct,
                swiftSyntaxMacroExpansionProduct,
                swiftSyntaxMacrosTestSupportProduct,
                swiftSyntaxMacrosGenericTestSupportProduct,
                swiftCompilerPluginMessageHandlingProduct,
                swiftLibraryPluginProviderProduct,
            ]
        )

        let swiftCertificatesPackage = self.createPackage(
            identity: swiftCertificatesIdentity,
            displayName: "swift-certificates",
            path: "/swift-certificates",
            modules: [x509Module],
            products: [x509Product]
        )

        let swiftASN1Package = self.createPackage(
            identity: swiftASN1Identity,
            displayName: "swift-asn1",
            path: "/swift-asn1",
            modules: [swiftASN1Module],
            products: [swiftASN1Product]
        )

        let swiftDoccPluginPackage = self.createPackage(
            identity: swiftDoccPluginIdentity,
            displayName: "swift-docc-plugin",
            path: "/swift-docc-plugin",
            modules: [swiftDoccModule, swiftDoccPreviewModule],
            products: [swiftDoccProduct, swiftDoccPreviewProduct]
        )

        let swiftDoccSymbolKitPackage = self.createPackage(
            identity: swiftDoccSymbolKitIdentity,
            displayName: "swift-docc-symbolkit",
            path: "/swift-docc-symbolkit",
            modules: [swiftDoccSymbolKitModule],
            products: [swiftDoccSymbolKitProduct]
        )

        let swiftJsonSchemaPackage = self.createPackage(
            identity: swiftJsonSchemaIdentity,
            displayName: "swift-json-schema",
            path: "/swift-json-schema",
            modules: [jsonSchemaModule, jsonSchemaBuilderModule, jsonSchemaClientModule, jsonSchemaConversionModule],
            products: [
                jsonSchemaProduct,
                jsonSchemaBuilderProduct,
                jsonSchemaClientProduct,
                jsonSchemaConversionProduct,
            ]
        )

        let swiftBuildPackage = self.createPackage(
            identity: swiftBuildIdentity,
            displayName: "swift-build",
            path: "/swift-build",
            modules: [
                swbuildModule,
                swbBuildServiceBundleModule,
                swiftBuildModule,
                swbProtocolModule,
                swbUtilModule,
                swbProjectModelModule,
                swbBuildServiceModule,
            ],
            products: [
                swbuildProduct,
                swbBuildServiceBundleProduct,
                swiftBuildProduct,
                swbProtocolProduct,
                swbUtilProduct,
                swbProjectModelProduct,
                swbBuildServiceProduct,
            ]
        )

        // Create resolved modules for external dependencies
        let resolvedSystemPackageModule = self.createResolvedModule(
            packageIdentity: swiftSystemIdentity,
            module: systemPackageModule
        )

        let resolvedDequeModuleModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: dequeModuleModule
        )

        let resolvedOrderedCollectionsModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: orderedCollectionsModule
        )

        let resolvedBitCollectionsModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: bitCollectionsModule
        )

        let resolvedHashTreeCollectionsModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: hashTreeCollectionsModule
        )

        let resolvedHeapModuleModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: heapModuleModule
        )

        let resolvedRopeModuleModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: ropeModuleModule
        )

        let resolvedCollectionsModule = self.createResolvedModule(
            packageIdentity: swiftCollectionsIdentity,
            module: collectionsModule
        )

        let resolvedArgumentParserModule = self.createResolvedModule(
            packageIdentity: swiftArgumentParserIdentity,
            module: argumentParserModule
        )

        let resolvedGenerateManualModule = self.createResolvedModule(
            packageIdentity: swiftArgumentParserIdentity,
            module: generateManualModule
        )

        let resolvedLLBuildModule = self.createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildModule
        )

        let resolvedLibllbuildModule = self.createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: libllbuildModule
        )

        let resolvedLLBuildSwiftModule = self.createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildSwiftModule
        )

        let resolvedLLBuildAnalysisModule = self.createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildAnalysisModule
        )

        let resolvedLLBuildSwiftDynamicModule = self.createResolvedModule(
            packageIdentity: swiftLLBuildIdentity,
            module: llbuildSwiftDynamicModule
        )

        let resolvedTSCBasicModule = self.createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: tscBasicModule
        )

        let resolvedSwiftToolsSupportModule = self.createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: swiftToolsSupportModule
        )

        let resolvedSwiftToolsSupportAutoModule = self.createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: swiftToolsSupportAutoModule
        )

        let resolvedTSCTestSupportModule = self.createResolvedModule(
            packageIdentity: swiftToolsSupportCoreIdentity,
            module: tscTestSupportModule
        )

        let resolvedSwiftDriverExecutableModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftDriverExecutableModule
        )

        let resolvedSwiftHelpModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftHelpModule
        )

        let resolvedSwiftBuildSDKInterfacesModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftBuildSDKInterfacesModule
        )

        let resolvedSwiftDriverModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftDriverModule
        )

        let resolvedSwiftDriverDynamicModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftDriverDynamicModule
        )

        let resolvedSwiftOptionsModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftOptionsModule
        )

        let resolvedSwiftDriverExecutionModule = self.createResolvedModule(
            packageIdentity: swiftDriverIdentity,
            module: swiftDriverExecutionModule
        )

        let resolvedCryptoModule = self.createResolvedModule(
            packageIdentity: swiftCryptoIdentity,
            module: cryptoModule
        )

        let resolvedCryptoExtrasModule = self.createResolvedModule(
            packageIdentity: swiftCryptoIdentity,
            module: cryptoExtrasModule
        )

        let resolvedX509Module = self.createResolvedModule(
            packageIdentity: swiftCertificatesIdentity,
            module: x509Module
        )

        let resolvedBasicsModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: basicsModule,
            dependencies: [
                .product(self.createResolvedProduct(
                    packageIdentity: swiftSystemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: dequeModuleProduct,
                    modules: IdentifiableSet([resolvedDequeModuleModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftToolsSupportCoreIdentity,
                    product: swiftToolsSupportAutoOriginalProduct,
                    modules: IdentifiableSet([resolvedSwiftToolsSupportAutoModule])
                ), conditions: []),
            ]
        )

        let resolvedPackageModelModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageModelModule,
            dependencies: [.module(resolvedBasicsModule, conditions: [])]
        )

        let resolvedPackageLoadingModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageLoadingModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
            ]
        )

        let resolvedSourceControlModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: sourceControlModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
            ]
        )

        let resolvedPackageGraphModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageGraphModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageLoadingModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
            ]
        )

        let resolvedWorkspaceModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: workspaceModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
            ]
        )

        let resolvedBuildModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: buildModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftLLBuildIdentity,
                    product: llbuildSwiftProduct,
                    modules: IdentifiableSet([resolvedLLBuildSwiftModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftDriverIdentity,
                    product: swiftDriverProduct,
                    modules: IdentifiableSet([resolvedSwiftDriverModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
            ]
        )

        let resolvedCommandsModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: commandsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedBuildModule, conditions: []),
                .module(resolvedWorkspaceModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftArgumentParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: swiftCollectionsIdentity,
                    product: orderedCollectionsProduct,
                    modules: IdentifiableSet([resolvedOrderedCollectionsModule])
                ), conditions: []),
            ]
        )

        let resolvedSBOMModelModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: sbomModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedSourceControlModule, conditions: []),
            ]
        )

        let resolvedSwiftPMModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
                .module(resolvedPackageGraphModule, conditions: []),
                .module(resolvedBuildModule, conditions: []),
            ]
        )

        let resolvedSwiftPMAutoModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMAutoModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
            ]
        )

        let resolvedSwiftPMDataModelModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMDataModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
            ]
        )

        let resolvedSwiftPMDataModelAutoModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMDataModelAutoModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageModelModule, conditions: []),
            ]
        )

        let resolvedXCBuildSupportModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: xcBuildSupportModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
            ]
        )

        let resolvedPackageDescriptionModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageDescriptionModule
        )

        let resolvedAppleProductTypesModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: appleProductTypesModule
        )

        let resolvedPackagePluginModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packagePluginModule
        )

        let resolvedPackageCollectionsModelModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: packageCollectionsModelModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
            ]
        )

        let resolvedSwiftPMPackageCollectionsModule = self.createResolvedModule(
            packageIdentity: swiftPMIdentity,
            module: swiftPMPackageCollectionsModule,
            dependencies: [
                .module(resolvedBasicsModule, conditions: []),
                .module(resolvedPackageCollectionsModelModule, conditions: []),
            ]
        )

        let resolvedSwiftPMDataModelProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMDataModelProduct,
            modules: IdentifiableSet([resolvedSwiftPMDataModelModule])
        )

        let resolvedSwiftPMDataModelAutoProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMDataModelAutoProduct,
            modules: IdentifiableSet([resolvedSwiftPMDataModelAutoModule])
        )

        let resolvedSwiftPMProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMProduct,
            modules: IdentifiableSet([resolvedSwiftPMModule])
        )

        let resolvedSwiftPMAutoProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMAutoProduct,
            modules: IdentifiableSet([resolvedSwiftPMAutoModule])
        )

        let resolvedXCBuildSupportProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: xcBuildSupportProduct,
            modules: IdentifiableSet([resolvedXCBuildSupportModule])
        )

        let resolvedPackageDescriptionProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packageDescriptionProduct,
            modules: IdentifiableSet([resolvedPackageDescriptionModule])
        )

        let resolvedAppleProductTypesProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: appleProductTypesProduct,
            modules: IdentifiableSet([resolvedAppleProductTypesModule])
        )

        let resolvedPackagePluginProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packagePluginProduct,
            modules: IdentifiableSet([resolvedPackagePluginModule])
        )

        let resolvedPackageCollectionsModelProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: packageCollectionsModelProduct,
            modules: IdentifiableSet([resolvedPackageCollectionsModelModule])
        )

        let resolvedSwiftPMPackageCollectionsProduct = self.createResolvedProduct(
            packageIdentity: swiftPMIdentity,
            product: swiftPMPackageCollectionsProduct,
            modules: IdentifiableSet([resolvedSwiftPMPackageCollectionsModule])
        )

        let resolvedSystemPackageProduct = self.createResolvedProduct(
            packageIdentity: swiftSystemIdentity,
            product: systemPackageProduct,
            modules: IdentifiableSet([resolvedSystemPackageModule])
        )

        let resolvedDequeModuleProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: dequeModuleProduct,
            modules: IdentifiableSet([resolvedDequeModuleModule])
        )

        let resolvedBitCollectionsProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: bitCollectionsProduct,
            modules: IdentifiableSet([resolvedBitCollectionsModule])
        )

        let resolvedHashTreeCollectionsProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: hashTreeCollectionsProduct,
            modules: IdentifiableSet([resolvedHashTreeCollectionsModule])
        )

        let resolvedHeapModuleProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: heapModuleProduct,
            modules: IdentifiableSet([resolvedHeapModuleModule])
        )

        let resolvedRopeModuleProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: ropeModuleProduct,
            modules: IdentifiableSet([resolvedRopeModuleModule])
        )

        let resolvedCollectionsProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: collectionsProduct,
            modules: IdentifiableSet([resolvedCollectionsModule])
        )

        let resolvedOrderedCollectionsProduct = self.createResolvedProduct(
            packageIdentity: swiftCollectionsIdentity,
            product: orderedCollectionsProduct,
            modules: IdentifiableSet([resolvedOrderedCollectionsModule])
        )

        let resolvedGenerateManualProduct = self.createResolvedProduct(
            packageIdentity: swiftArgumentParserIdentity,
            product: generateManualProduct,
            modules: IdentifiableSet([resolvedGenerateManualModule])
        )

        let resolvedArgumentParserProduct = self.createResolvedProduct(
            packageIdentity: swiftArgumentParserIdentity,
            product: argumentParserProduct,
            modules: IdentifiableSet([resolvedArgumentParserModule])
        )

        let resolvedLLBuildProduct = self.createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildProduct,
            modules: IdentifiableSet([resolvedLLBuildModule])
        )

        let resolvedLibllbuildProduct = self.createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: libllbuildProduct,
            modules: IdentifiableSet([resolvedLibllbuildModule])
        )

        let resolvedLLBuildSwiftProduct = self.createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildSwiftProduct,
            modules: IdentifiableSet([resolvedLLBuildSwiftModule])
        )

        let resolvedLLBuildAnalysisProduct = self.createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildAnalysisProduct,
            modules: IdentifiableSet([resolvedLLBuildAnalysisModule])
        )

        let resolvedLLBuildSwiftDynamicProduct = self.createResolvedProduct(
            packageIdentity: swiftLLBuildIdentity,
            product: llbuildSwiftDynamicProduct,
            modules: IdentifiableSet([resolvedLLBuildSwiftDynamicModule])
        )

        let resolvedTSCBasicProduct = self.createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: tscBasicProduct,
            modules: IdentifiableSet([resolvedTSCBasicModule])
        )

        let resolvedSwiftToolsSupportProduct = self.createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: swiftToolsSupportProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
        )

        let resolvedSwiftToolsSupportAutoProduct = self.createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: swiftToolsSupportAutoOriginalProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportAutoModule])
        )

        let resolvedTSCTestSupportProduct = self.createResolvedProduct(
            packageIdentity: swiftToolsSupportCoreIdentity,
            product: tscTestSupportProduct,
            modules: IdentifiableSet([resolvedTSCTestSupportModule])
        )

        let resolvedCryptoExtrasProduct = self.createResolvedProduct(
            packageIdentity: swiftCryptoIdentity,
            product: cryptoExtrasProduct,
            modules: IdentifiableSet([resolvedCryptoExtrasModule])
        )

        let resolvedSwiftDriverExecutableProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftDriverExecutableProduct,
            modules: IdentifiableSet([resolvedSwiftDriverExecutableModule])
        )

        let resolvedSwiftHelpProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftHelpProduct,
            modules: IdentifiableSet([resolvedSwiftHelpModule])
        )

        let resolvedSwiftBuildSDKInterfacesProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftBuildSDKInterfacesProduct,
            modules: IdentifiableSet([resolvedSwiftBuildSDKInterfacesModule])
        )

        let resolvedSwiftDriverProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftDriverProduct,
            modules: IdentifiableSet([resolvedSwiftDriverModule])
        )

        let resolvedSwiftDriverDynamicProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftDriverDynamicProduct,
            modules: IdentifiableSet([resolvedSwiftDriverDynamicModule])
        )

        let resolvedSwiftOptionsProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftOptionsProduct,
            modules: IdentifiableSet([resolvedSwiftOptionsModule])
        )

        let resolvedSwiftDriverExecutionProduct = self.createResolvedProduct(
            packageIdentity: swiftDriverIdentity,
            product: swiftDriverExecutionProduct,
            modules: IdentifiableSet([resolvedSwiftDriverExecutionModule])
        )

        let resolvedCryptoProduct = self.createResolvedProduct(
            packageIdentity: swiftCryptoIdentity,
            product: cryptoProduct,
            modules: IdentifiableSet([resolvedCryptoModule])
        )

        let resolvedX509Product = self.createResolvedProduct(
            packageIdentity: swiftCertificatesIdentity,
            product: x509Product,
            modules: IdentifiableSet([resolvedX509Module])
        )

        let resolvedSwiftPMPackage = self.createResolvedPackage(
            package: swiftPMPackage,
            modules: IdentifiableSet([
                resolvedBasicsModule, resolvedPackageModelModule, resolvedPackageLoadingModule,
                resolvedPackageGraphModule, resolvedSourceControlModule, resolvedWorkspaceModule,
                resolvedBuildModule, resolvedSBOMModelModule, resolvedCommandsModule,
                resolvedSwiftPMModule, resolvedSwiftPMAutoModule, resolvedSwiftPMDataModelModule,
                resolvedSwiftPMDataModelAutoModule, resolvedXCBuildSupportModule, resolvedPackageDescriptionModule,
                resolvedAppleProductTypesModule, resolvedPackagePluginModule, resolvedPackageCollectionsModelModule,
                resolvedSwiftPMPackageCollectionsModule,
            ]),
            products: [
                resolvedSwiftPMDataModelProduct,
                resolvedSwiftPMDataModelAutoProduct,
                resolvedSwiftPMProduct,
                resolvedSwiftPMAutoProduct,
                resolvedXCBuildSupportProduct,
                resolvedPackageDescriptionProduct,
                resolvedAppleProductTypesProduct,
                resolvedPackagePluginProduct,
                resolvedPackageCollectionsModelProduct,
                resolvedSwiftPMPackageCollectionsProduct,
            ],
            dependencies: [
                swiftSystemIdentity,
                swiftCollectionsIdentity,
                swiftArgumentParserIdentity,
                swiftLLBuildIdentity,
                swiftToolsSupportCoreIdentity,
                swiftDriverIdentity,
                swiftCryptoIdentity,
                swiftCertificatesIdentity,
            ]
        )

        let resolvedSwiftSystemPackage = self.createResolvedPackage(
            package: swiftSystemPackage,
            modules: IdentifiableSet([resolvedSystemPackageModule]),
            products: [resolvedSystemPackageProduct]
        )

        let resolvedSwiftCollectionsPackage = self.createResolvedPackage(
            package: swiftCollectionsPackage,
            modules: IdentifiableSet([
                resolvedDequeModuleModule,
                resolvedOrderedCollectionsModule,
                resolvedBitCollectionsModule,
                resolvedHashTreeCollectionsModule,
                resolvedHeapModuleModule,
                resolvedRopeModuleModule,
                resolvedCollectionsModule,
            ]),
            products: [
                resolvedDequeModuleProduct,
                resolvedOrderedCollectionsProduct,
                resolvedBitCollectionsProduct,
                resolvedHashTreeCollectionsProduct,
                resolvedHeapModuleProduct,
                resolvedRopeModuleProduct,
                resolvedCollectionsProduct,
            ]
        )

        let resolvedSwiftArgumentParserPackage = self.createResolvedPackage(
            package: swiftArgumentParserPackage,
            modules: IdentifiableSet([resolvedArgumentParserModule, resolvedGenerateManualModule]),
            products: [resolvedArgumentParserProduct, resolvedGenerateManualProduct]
        )

        let resolvedSwiftLLBuildPackage = self.createResolvedPackage(
            package: swiftLLBuildPackage,
            modules: IdentifiableSet([
                resolvedLLBuildModule,
                resolvedLibllbuildModule,
                resolvedLLBuildSwiftModule,
                resolvedLLBuildAnalysisModule,
                resolvedLLBuildSwiftDynamicModule,
            ]),
            products: [
                resolvedLLBuildProduct,
                resolvedLibllbuildProduct,
                resolvedLLBuildSwiftProduct,
                resolvedLLBuildAnalysisProduct,
                resolvedLLBuildSwiftDynamicProduct,
            ]
        )

        let resolvedSwiftToolsSupportCorePackage = self.createResolvedPackage(
            package: swiftToolsSupportCorePackage,
            modules: IdentifiableSet([
                resolvedTSCBasicModule,
                resolvedSwiftToolsSupportModule,
                resolvedSwiftToolsSupportAutoModule,
                resolvedTSCTestSupportModule,
            ]),
            products: [
                resolvedTSCBasicProduct,
                resolvedSwiftToolsSupportProduct,
                resolvedSwiftToolsSupportAutoProduct,
                resolvedTSCTestSupportProduct,
            ]
        )

        let resolvedSwiftDriverPackage = self.createResolvedPackage(
            package: swiftDriverPackage,
            modules: IdentifiableSet([
                resolvedSwiftDriverExecutableModule,
                resolvedSwiftHelpModule,
                resolvedSwiftBuildSDKInterfacesModule,
                resolvedSwiftDriverModule,
                resolvedSwiftDriverDynamicModule,
                resolvedSwiftOptionsModule,
                resolvedSwiftDriverExecutionModule,
            ]),
            products: [
                resolvedSwiftDriverExecutableProduct,
                resolvedSwiftHelpProduct,
                resolvedSwiftBuildSDKInterfacesProduct,
                resolvedSwiftDriverProduct,
                resolvedSwiftDriverDynamicProduct,
                resolvedSwiftOptionsProduct,
                resolvedSwiftDriverExecutionProduct,
            ]
        )

        let resolvedSwiftCryptoPackage = self.createResolvedPackage(
            package: swiftCryptoPackage,
            modules: IdentifiableSet([resolvedCryptoModule, resolvedCryptoExtrasModule]),
            products: [resolvedCryptoProduct, resolvedCryptoExtrasProduct]
        )

        let resolvedSwiftCertificatesPackage = self.createResolvedPackage(
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
            resolvedSwiftCertificatesPackage,
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
            resolvedSwiftCertificatesPackage,
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
            swiftBuildRef,
        ]

        return try ModulesGraph(
            rootPackages: [resolvedSwiftPMPackage],
            rootDependencies: rootDependencies,
            packages: allResolvedPackages,
            dependencies: packageReferences, // All external package dependencies
            binaryArtifacts: [:]
        )
    }
}
