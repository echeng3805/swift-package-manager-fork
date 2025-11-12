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
    static func createSwiftlyModulesGraph(rootPath: String = "/tmp/swiftly-mock") throws -> ModulesGraph {
        let swiftlyIdentity = PackageIdentity.plain("swiftly")
        let argParserIdentity = PackageIdentity.plain("swift-argument-parser")
        let httpClientIdentity = PackageIdentity.plain("async-http-client")
        let openAPIAsyncHTTPClientIdentity = PackageIdentity.plain("swift-openapi-async-http-client")
        let nioIdentity = PackageIdentity.plain("swift-nio")
        let toolsSupportIdentity = PackageIdentity.plain("swift-tools-support-core")
        let openAPIRuntimeIdentity = PackageIdentity.plain("swift-openapi-runtime")
        let systemIdentity = PackageIdentity.plain("swift-system")

        let argumentParserModule = self.createSwiftModule(name: "ArgumentParser")
        let asyncHTTPClientModule = self.createSwiftModule(name: "AsyncHTTPClient")
        let openAPIAsyncHTTPClientModule = self.createSwiftModule(name: "OpenAPIAsyncHTTPClient")
        let nioFoundationCompatModule = self.createSwiftModule(name: "NIOFoundationCompat")
        let swiftToolsSupportModule = self.createSwiftModule(name: "SwiftToolsSupport-auto")
        let openAPIRuntimeModule = self.createSwiftModule(name: "OpenAPIRuntime")
        let systemPackageModule = self.createSwiftModule(name: "SystemPackage")

        let swiftlyModule = self.createSwiftModule(name: "Swiftly", type: .executable)
        let testSwiftlyModule = self.createSwiftModule(name: "TestSwiftly", type: .executable)
        let swiftlyWebsiteAPIModule = self.createSwiftModule(name: "SwiftlyWebsiteAPI")
        let swiftlyDownloadAPIModule = self.createSwiftModule(name: "SwiftlyDownloadAPI")
        let swiftlyCoreModule = self.createSwiftModule(name: "SwiftlyCore")
        let macOSPlatformModule = self.createSwiftModule(name: "MacOSPlatform")
        let linuxPlatformModule = self.createSwiftModule(name: "LinuxPlatform")

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

        let swiftlyPackage = self.createPackage(
            identity: swiftlyIdentity,
            displayName: "swiftly",
            path: rootPath,
            modules: [
                swiftlyModule,
                testSwiftlyModule,
                swiftlyWebsiteAPIModule,
                swiftlyDownloadAPIModule,
                swiftlyCoreModule,
                macOSPlatformModule,
                linuxPlatformModule,
            ],
            products: [swiftlyProduct, testSwiftlyProduct]
        )

        let argParserPackage = self.createPackage(
            identity: argParserIdentity,
            displayName: "swift-argument-parser",
            path: "/swift-argument-parser",
            modules: [argumentParserModule],
            products: [argumentParserProduct]
        )

        let httpClientPackage = self.createPackage(
            identity: httpClientIdentity,
            displayName: "async-http-client",
            path: "/async-http-client",
            modules: [asyncHTTPClientModule],
            products: [asyncHTTPClientProduct]
        )

        let openAPIAsyncHTTPClientPackage = self.createPackage(
            identity: openAPIAsyncHTTPClientIdentity,
            displayName: "swift-openapi-async-http-client",
            path: "/swift-openapi-async-http-client",
            modules: [openAPIAsyncHTTPClientModule],
            products: [openAPIAsyncHTTPClientProduct]
        )

        let nioPackage = self.createPackage(
            identity: nioIdentity,
            displayName: "swift-nio",
            path: "/swift-nio",
            modules: [nioFoundationCompatModule],
            products: [nioFoundationCompatProduct]
        )

        let toolsSupportPackage = self.createPackage(
            identity: toolsSupportIdentity,
            displayName: "swift-tools-support-core",
            path: "/swift-tools-support-core",
            modules: [swiftToolsSupportModule],
            products: [swiftToolsSupportProduct]
        )

        let openAPIRuntimePackage = self.createPackage(
            identity: openAPIRuntimeIdentity,
            displayName: "swift-openapi-runtime",
            path: "/swift-openapi-runtime",
            modules: [openAPIRuntimeModule],
            products: [openAPIRuntimeProduct]
        )

        let systemPackage = self.createPackage(
            identity: systemIdentity,
            displayName: "swift-system",
            path: "/swift-system",
            modules: [systemPackageModule],
            products: [systemPackageProduct]
        )

        let resolvedArgumentParserModule = self.createResolvedModule(
            packageIdentity: argParserIdentity,
            module: argumentParserModule
        )

        let resolvedAsyncHTTPClientModule = self.createResolvedModule(
            packageIdentity: httpClientIdentity,
            module: asyncHTTPClientModule
        )

        let resolvedOpenAPIAsyncHTTPClientModule = self.createResolvedModule(
            packageIdentity: openAPIAsyncHTTPClientIdentity,
            module: openAPIAsyncHTTPClientModule
        )

        let resolvedNIOFoundationCompatModule = self.createResolvedModule(
            packageIdentity: nioIdentity,
            module: nioFoundationCompatModule
        )

        let resolvedSwiftToolsSupportModule = self.createResolvedModule(
            packageIdentity: toolsSupportIdentity,
            module: swiftToolsSupportModule
        )

        let resolvedOpenAPIRuntimeModule = self.createResolvedModule(
            packageIdentity: openAPIRuntimeIdentity,
            module: openAPIRuntimeModule
        )

        let resolvedSystemPackageModule = self.createResolvedModule(
            packageIdentity: systemIdentity,
            module: systemPackageModule
        )

        // Create internal modules first (without dependencies to avoid circular references)
        let resolvedSwiftlyWebsiteAPIModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyWebsiteAPIModule,
            dependencies: [
                .product(self.createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: []),
            ]
        )

        let resolvedSwiftlyDownloadAPIModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyDownloadAPIModule,
            dependencies: [
                .product(self.createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: []),
            ]
        )

        let resolvedSwiftlyCoreModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyCoreModule,
            dependencies: [
                .module(resolvedSwiftlyDownloadAPIModule, conditions: []),
                .module(resolvedSwiftlyWebsiteAPIModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: httpClientIdentity,
                    product: asyncHTTPClientProduct,
                    modules: IdentifiableSet([resolvedAsyncHTTPClientModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: nioIdentity,
                    product: nioFoundationCompatProduct,
                    modules: IdentifiableSet([resolvedNIOFoundationCompatModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: openAPIRuntimeIdentity,
                    product: openAPIRuntimeProduct,
                    modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: openAPIAsyncHTTPClientIdentity,
                    product: openAPIAsyncHTTPClientProduct,
                    modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
            ]
        )

        let resolvedMacOSPlatformModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: macOSPlatformModule,
            dependencies: [
                .module(resolvedSwiftlyCoreModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
            ]
        )

        let resolvedLinuxPlatformModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: linuxPlatformModule,
            dependencies: [
                .module(resolvedSwiftlyCoreModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
            ]
        )

        let resolvedSwiftlyModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: swiftlyModule,
            dependencies: [
                .product(self.createResolvedProduct(
                    packageIdentity: argParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .module(resolvedSwiftlyCoreModule, conditions: []),
                .module(resolvedMacOSPlatformModule, conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: toolsSupportIdentity,
                    product: swiftToolsSupportProduct,
                    modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
                ), conditions: []),
                .product(self.createResolvedProduct(
                    packageIdentity: systemIdentity,
                    product: systemPackageProduct,
                    modules: IdentifiableSet([resolvedSystemPackageModule])
                ), conditions: []),
            ]
        )

        let resolvedTestSwiftlyModule = self.createResolvedModule(
            packageIdentity: swiftlyIdentity,
            module: testSwiftlyModule,
            dependencies: [
                .product(self.createResolvedProduct(
                    packageIdentity: argParserIdentity,
                    product: argumentParserProduct,
                    modules: IdentifiableSet([resolvedArgumentParserModule])
                ), conditions: []),
                .module(resolvedSwiftlyCoreModule, conditions: []),
                .module(resolvedMacOSPlatformModule, conditions: []),
            ]
        )

        let resolvedSwiftlyProduct = self.createResolvedProduct(
            packageIdentity: swiftlyIdentity,
            product: swiftlyProduct,
            modules: IdentifiableSet([resolvedSwiftlyModule])
        )

        let resolvedTestSwiftlyProduct = self.createResolvedProduct(
            packageIdentity: swiftlyIdentity,
            product: testSwiftlyProduct,
            modules: IdentifiableSet([resolvedTestSwiftlyModule])
        )

        let resolvedArgumentParserProduct = self.createResolvedProduct(
            packageIdentity: argParserIdentity,
            product: argumentParserProduct,
            modules: IdentifiableSet([resolvedArgumentParserModule])
        )

        let resolvedAsyncHTTPClientProduct = self.createResolvedProduct(
            packageIdentity: httpClientIdentity,
            product: asyncHTTPClientProduct,
            modules: IdentifiableSet([resolvedAsyncHTTPClientModule])
        )

        let resolvedOpenAPIAsyncHTTPClientProduct = self.createResolvedProduct(
            packageIdentity: openAPIAsyncHTTPClientIdentity,
            product: openAPIAsyncHTTPClientProduct,
            modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule])
        )

        let resolvedNIOFoundationCompatProduct = self.createResolvedProduct(
            packageIdentity: nioIdentity,
            product: nioFoundationCompatProduct,
            modules: IdentifiableSet([resolvedNIOFoundationCompatModule])
        )

        let resolvedSwiftToolsSupportProduct = self.createResolvedProduct(
            packageIdentity: toolsSupportIdentity,
            product: swiftToolsSupportProduct,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule])
        )

        let resolvedOpenAPIRuntimeProduct = self.createResolvedProduct(
            packageIdentity: openAPIRuntimeIdentity,
            product: openAPIRuntimeProduct,
            modules: IdentifiableSet([resolvedOpenAPIRuntimeModule])
        )

        let resolvedSystemPackageProduct = self.createResolvedProduct(
            packageIdentity: systemIdentity,
            product: systemPackageProduct,
            modules: IdentifiableSet([resolvedSystemPackageModule])
        )

        let resolvedSwiftlyPackage = self.createResolvedPackage(
            package: swiftlyPackage,
            modules: IdentifiableSet([
                resolvedSwiftlyModule, resolvedTestSwiftlyModule, resolvedSwiftlyWebsiteAPIModule,
                resolvedSwiftlyDownloadAPIModule, resolvedSwiftlyCoreModule, resolvedMacOSPlatformModule,
                resolvedLinuxPlatformModule,
            ]),
            products: [resolvedSwiftlyProduct, resolvedTestSwiftlyProduct],
            dependencies: [
                argParserIdentity,
                httpClientIdentity,
                openAPIAsyncHTTPClientIdentity,
                nioIdentity,
                toolsSupportIdentity,
                openAPIRuntimeIdentity,
                systemIdentity,
            ]
        )

        let resolvedArgParserPackage = self.createResolvedPackage(
            package: argParserPackage,
            modules: IdentifiableSet([resolvedArgumentParserModule]),
            products: [resolvedArgumentParserProduct]
        )

        let resolvedHttpClientPackage = self.createResolvedPackage(
            package: httpClientPackage,
            modules: IdentifiableSet([resolvedAsyncHTTPClientModule]),
            products: [resolvedAsyncHTTPClientProduct]
        )

        let resolvedOpenAPIAsyncHTTPClientPackage = self.createResolvedPackage(
            package: openAPIAsyncHTTPClientPackage,
            modules: IdentifiableSet([resolvedOpenAPIAsyncHTTPClientModule]),
            products: [resolvedOpenAPIAsyncHTTPClientProduct]
        )

        let resolvedNIOPackage = self.createResolvedPackage(
            package: nioPackage,
            modules: IdentifiableSet([resolvedNIOFoundationCompatModule]),
            products: [resolvedNIOFoundationCompatProduct]
        )

        let resolvedToolsSupportPackage = self.createResolvedPackage(
            package: toolsSupportPackage,
            modules: IdentifiableSet([resolvedSwiftToolsSupportModule]),
            products: [resolvedSwiftToolsSupportProduct]
        )

        let resolvedOpenAPIRuntimePackage = self.createResolvedPackage(
            package: openAPIRuntimePackage,
            modules: IdentifiableSet([resolvedOpenAPIRuntimeModule]),
            products: [resolvedOpenAPIRuntimeProduct]
        )

        let resolvedSystemPackage = self.createResolvedPackage(
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
            kind: .remoteSourceControl(
                SourceControlURL("https://github.com/swift-server/swift-openapi-async-http-client.git")
            )
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
            resolvedArgParserPackage,
        ])

        let rootDependencies = [
            resolvedArgParserPackage,
            resolvedHttpClientPackage,
            resolvedOpenAPIAsyncHTTPClientPackage,
            resolvedNIOPackage,
            resolvedToolsSupportPackage,
            resolvedOpenAPIRuntimePackage,
            resolvedSystemPackage,
        ]

        let packageReferences = [
            argParserRef,
            httpClientRef,
            openAPIAsyncHTTPClientRef,
            nioRef,
            toolsSupportRef,
            openAPIRuntimeRef,
            systemRef,
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
