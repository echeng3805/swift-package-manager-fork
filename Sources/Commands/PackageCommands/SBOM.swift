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
import PackageGraph
import Workspace
import SBOMModel
import SPMBuildCore
import TSCBasic

extension SwiftPackageCommand {
    struct SBOM: AsyncSwiftCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a Software Bill of Materials (SBOM).")

        @OptionGroup()
        var globalOptions: GlobalOptions

        @Option(help: "The product to generate an SBOM for.")
        var product: String?

        func run(_ swiftCommandState: SwiftCommandState) async throws {
            let workspace = try swiftCommandState.getActiveWorkspace()
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: try swiftCommandState.getWorkspaceRoot(),
                explicitProduct: product,
                observabilityScope: swiftCommandState.observabilityScope
            )
            let resolvedPackagesStore = try workspace.resolvedPackagesStore.load()
           
            guard swiftCommandState.options.build.buildSystem == .swiftbuild else {
                throw StringError("SBOM generation requires the SwiftBuild build system. Please use '--build-system swiftbuild'.")
            }
            
            let buildSystem = try await swiftCommandState.createBuildSystem(
                explicitProduct: product
            )
            let buildResult = try await buildSystem.build(
                subset: product.map { .product($0) } ?? .allExcludingTests,
                buildOutputs: [.dependencyGraph]
            )

            let extractor = SBOMExtractor(
                modulesGraph: packageGraph,
                dependencyGraph: buildResult.dependencyGraph,
                store: resolvedPackagesStore
            )
            let sbom = try await extractor.extractSBOM(product: product)
            let encoder = SBOMEncoder(sbom: sbom)
            try await encoder.writeSBOMs(
                specs: globalOptions.sbom.sbomSpecs,
                outputDir: try globalOptions.sbom.sbomDirectory ?? swiftCommandState.productsBuildParameters.buildPath.appending(component: "sboms")
            )
        }
    }
}