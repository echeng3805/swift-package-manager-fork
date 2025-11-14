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

import ArgumentParser
import Basics
import CoreCommands
import Foundation
import PackageGraph
import PackageModel
import SBOMModel
import SPMBuildCore
import Workspace

extension SwiftPackageCommand {
    struct GenerateSbom: AsyncSwiftCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a Software Bill of Materials (SBOM).")

        @OptionGroup()
        var globalOptions: GlobalOptions

        @Option(help: "The product to generate an SBOM for.")
        var product: String?

        func run(_ swiftCommandState: SwiftCommandState) async throws {
            guard swiftCommandState.options.build.buildSystem == .swiftbuild else {
                throw SBOMGenerationError.notSwiftBuild
            }

            let workspace = try swiftCommandState.getActiveWorkspace()
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: swiftCommandState.getWorkspaceRoot(),
                explicitProduct: self.product,
                observabilityScope: swiftCommandState.observabilityScope
            )
            let resolvedPackagesStore = try workspace.resolvedPackagesStore.load()

            let buildSystem = try await swiftCommandState.createBuildSystem(
                explicitProduct: self.product
            )
            let buildResult = try await buildSystem.build(
                subset: self.product.map { .product($0) } ?? .allExcludingTests,
                buildOutputs: [.dependencyGraph]
            )

            let input = SBOMInput(
                modulesGraph: packageGraph,
                dependencyGraph: buildResult.dependencyGraph,
                store: resolvedPackagesStore,
                filter: self.globalOptions.sbom.sbomFilter,
                product: self.product,
                specs: self.globalOptions.sbom.sbomSpecs,
                dir: try self.globalOptions.sbom.sbomDirectory ?? swiftCommandState.productsBuildParameters.buildPath
                    .appending(component: "sboms")
            )

            let creator = SBOMCreator(input: input)
            try await creator.createSBOMs()
        }
    }
}

package enum SBOMGenerationError: Error, LocalizedError, CustomStringConvertible {
    case notSwiftBuild
    package var errorDescription: String? {
        switch self {
        case .notSwiftBuild:
            "SBOM generation requires the SwiftBuild build system. Please use '--build-system swiftbuild'."
        }
    }
    package var description: String {
        self.errorDescription ?? "Unknown SBOM generation error"
    }
}