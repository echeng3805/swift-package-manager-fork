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

enum SBOMTestGraph {
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
        ResolvedModule(
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
        ResolvedProduct(
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
        ResolvedPackage(
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
}