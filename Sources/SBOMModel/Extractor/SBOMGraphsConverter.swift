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

import PackageGraph
import PackageModel

/// Utilities for converting between ModulesGraph and dependency graph naming conventions.
package struct SBOMGraphsConverter {
    // TODO: ev_cheng, there has to be a better way to do all these conversions

    /// Converts a ModulesGraph product name to a dependency graph target name.
    package static func getTargetName(fromProduct name: String) -> String {
        "\(name)-product"
    }

    /// Converts a dependency graph target name back to a ModulesGraph product name.
    package static func getProductName(fromTarget name: String) -> String? {
        guard name.hasSuffix("-product") else {
            return nil
        }
        return String(name.dropLast("-product".count))
    }

    /// Converts a dependency graph target name back to a ModulesGraph module package and name.
    package static func getPackageAndModuleNames(fromTarget name: String)
        -> (packageName: String?, moduleName: String)?
    {
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

    /// Converts a dependency graph target name to a ModulesGraph product.
    package static func toProduct(fromTarget name: String, modulesGraph: ModulesGraph) -> ResolvedProduct? {
        getProductName(fromTarget: name).flatMap { modulesGraph.product(for: $0) }
    }

    /// Converts a dependency graph target name to a ModulesGraph module.
    package static func toModule(fromTarget name: String, modulesGraph: ModulesGraph) -> ResolvedModule? {
        guard let (packageName, moduleName) = getPackageAndModuleNames(fromTarget: name) else {
            return nil
        }
        if let packageName {
            return modulesGraph.allModules.first { module in
                module.name == moduleName && module.packageIdentity.description == packageName
            }
        }
        return modulesGraph.module(for: moduleName)
    }
}