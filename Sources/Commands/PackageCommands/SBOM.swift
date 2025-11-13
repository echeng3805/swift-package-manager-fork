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
import TSCBasic
import Workspace

extension SwiftPackageCommand {
    struct SBOM: AsyncSwiftCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a Software Bill of Materials (SBOM).")

        @OptionGroup()
        var globalOptions: GlobalOptions

        @Option(help: "The product to generate an SBOM for.")
        var product: String?

        @Flag(help: "Print graph structure for test fixture generation.")
        var printGraphStructure: Bool = false

        func run(_ swiftCommandState: SwiftCommandState) async throws {
            // TODO: ev_cheng: remove?
            guard swiftCommandState.options.build.buildSystem == .swiftbuild else {
                throw StringError(
                    "SBOM generation requires the SwiftBuild build system. Please use '--build-system swiftbuild'."
                )
            }

            let workspace = try swiftCommandState.getActiveWorkspace()
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: swiftCommandState.getWorkspaceRoot(),
                explicitProduct: self.product,
                observabilityScope: swiftCommandState.observabilityScope
            )
            let resolvedPackagesStore = try workspace.resolvedPackagesStore.load()

            // Print graph structure if requested
            if self.printGraphStructure {
                self.printModulesGraphStructure(packageGraph)
                return
            }

            let buildSystem = try await swiftCommandState.createBuildSystem(
                explicitProduct: self.product
            )
            let buildResult = try await buildSystem.build(
                subset: self.product.map { .product($0) } ?? .allExcludingTests,
                buildOutputs: [.dependencyGraph]
            )

            let extractor = SBOMExtractor(
                modulesGraph: packageGraph,
                dependencyGraph: buildResult.dependencyGraph,
                store: resolvedPackagesStore
            )
            let sbom = try await extractor.extractSBOM(product: self.product)
            let encoder = SBOMEncoder(sbom: sbom)
            try await encoder.writeSBOMs(
                specs: self.globalOptions.sbom.sbomSpecs,
                outputDir: self.globalOptions.sbom.sbomDirectory ?? swiftCommandState.productsBuildParameters.buildPath
                    .appending(component: "sboms")
            )
        }

        func printModulesGraphStructure(_ graph: ModulesGraph) {
            print("=== PACKAGES ===")
            for package in graph.packages.sorted(by: { $0.identity.description < $1.identity.description }) {
                print("\nPackage: \(package.identity.description)")
                print("  Display Name: \(package.manifest.displayName)")
                print("  Path: \(package.manifest.path.pathString)")

                print("  Modules:")
                for module in package.modules.sorted(by: { $0.name < $1.name }) {
                    print("    - \(module.name) (\(module.type))")
                }

                print("  Products:")
                for product in package.products.sorted(by: { $0.name < $1.name }) {
                    let moduleNames = product.modules.map(\.name).sorted().joined(separator: ", ")
                    print("    - \(product.name) (\(product.type)): [\(moduleNames)]")
                }

                print("  Dependencies:")
                for dep in package.dependencies.sorted(by: { $0.description < $1.description }) {
                    print("    - \(dep.description)")
                }
            }

            print("\n=== MODULE DEPENDENCIES ===")
            for package in graph.packages.sorted(by: { $0.identity.description < $1.identity.description }) {
                for module in package.modules.sorted(by: { $0.name < $1.name }) {
                    if !module.dependencies.isEmpty {
                        print("\nModule: \(package.identity.description).\(module.name)")
                        for dep in module.dependencies {
                            switch dep {
                            case .module(let targetDep, _):
                                print("  -> module: \(targetDep.packageIdentity.description).\(targetDep.name)")
                            case .product(let productDep, _):
                                let moduleNames = productDep.modules.map(\.name).sorted().joined(separator: ", ")
                                print(
                                    "  -> product: \(productDep.packageIdentity.description).\(productDep.name) [\(moduleNames)]"
                                )
                            }
                        }
                    }
                }
            }

            print("\n=== PACKAGE REFERENCES ===")
            for ref in graph.requiredDependencies.sorted(by: { $0.identity.description < $1.identity.description }) {
                print("\nPackage Reference: \(ref.identity.description)")
                switch ref.kind {
                case .root(let path):
                    print("  Kind: root")
                    print("  Path: \(path.pathString)")
                case .fileSystem(let path):
                    print("  Kind: fileSystem")
                    print("  Path: \(path.pathString)")
                case .localSourceControl(let path):
                    print("  Kind: localSourceControl")
                    print("  Path: \(path.pathString)")
                case .remoteSourceControl(let url):
                    print("  Kind: remoteSourceControl")
                    print("  URL: \(url)")
                case .registry(let identity):
                    print("  Kind: registry")
                    print("  Identity: \(identity)")
                }
            }
        }
    }
}
