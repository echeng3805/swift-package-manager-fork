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

extension SwiftPackageCommand {
    struct SBOM: AsyncSwiftCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a Software Bill of Materials (SBOM).")

        @OptionGroup(visibility: .hidden)
        var globalOptions: GlobalOptions

        @Option(help: "Set the SBOM specification.")
        var spec: SBOMModel.Spec

        @Option(name: [.long, .customShort("o") ],
                help: "The absolute or relative path to generate the SBOM at.")
        var outputPath: AbsolutePath?

        @Option(help: "The product to generate an SBOM for.")
        var product: String?

        @Option(help: "Whether to validate the generated SBOM against the appropriate specification schema.")
        var validate: Bool = false

        @Option(help: "Whether to include information about test targets.")
        var includeTestTargets: Bool = false // TODO ev_cheng

        func run(_ swiftCommandState: SwiftCommandState) async throws {
           let graph = try await swiftCommandState.loadPackageGraph(explicitProduct: product)
           let workspace = try swiftCommandState.getActiveWorkspace()
           let resolvedPackagesStore = try workspace.resolvedPackagesStore.load()
           
           let sbom = try await SBOMModel.extractSBOM(spec: spec, graph: graph, store: resolvedPackagesStore, product: product)
           try await encodeSBOM(from: sbom, validate: validate, outputPath: outputPath)
        }
    }
}