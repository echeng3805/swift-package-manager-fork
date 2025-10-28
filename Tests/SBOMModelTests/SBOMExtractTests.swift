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

import Testing
import Foundation
import struct TSCBasic.StringError
@testable import SBOMModel
import _InternalTestSupport

struct SBOMExtractTests {

    @Test("extractSBOM with product filter for SwiftPM")
    func extractSBOMWithProductFilterForSwiftPM() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        // Extract SBOM for a specific product
        let productName = "SwiftPMDataModel"
        let sbom = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store, product: productName)
        
        // The primary component should be the specified product, not the root package
        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id == "SwiftPM:SwiftPMDataModel")
        #expect(sbom.primaryComponent.category == .library)
        
        // Extract SBOM without product filter for comparison
        let fullSbom = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store)
        
        // The product-specific SBOM should have fewer components than the full SBOM
        #expect((sbom.dependencies.components.count ?? 0) < (fullSbom.dependencies.components.count ?? 0))
        
        // The product-specific SBOM should have fewer dependencies than the full SBOM
        #expect((sbom.dependencies.dependencies?.count ?? 0) < (fullSbom.dependencies.dependencies?.count ?? 0))
        
        // Verify that the product-specific SBOM contains only relevant components
        let componentIDs = Set((sbom.dependencies.components ?? []).map { $0.id })
        
        // Should contain the target product
        #expect(componentIDs.contains("SwiftPM:SwiftPMDataModel"))
        
        // Should contain the root package (since the product belongs to it)
        #expect(componentIDs.contains("SwiftPM"))
        
        // Should contain dependencies of the SwiftPMDataModel product
        // Based on the test graph, SwiftPMDataModel depends on Basics and PackageModel
        let rootPackage = try #require(graph.rootPackages.first)
        let targetProduct = try #require(rootPackage.products.first { $0.name == productName })
        
        // Verify that dependencies are properly filtered
        var expectedDependencyIDs = Set<String>()
        for module in targetProduct.modules {
            for dependency in module.dependencies {
                switch dependency {
                case .product(let dependentProduct, _):
                    expectedDependencyIDs.insert(await SBOMModel.extractComponentID(from: dependentProduct))
                case .module(let dependentModule, _):
                    if let containerProduct = graph.allProducts.first(where: { $0.modules.contains(id: dependentModule.id) }) {
                        expectedDependencyIDs.insert(await SBOMModel.extractComponentID(from: containerProduct))
                    }
                }
            }
        }
        
        // All expected dependencies should be present in the filtered components
        for expectedID in expectedDependencyIDs {
            #expect(componentIDs.contains(expectedID), "Missing expected dependency: \(expectedID)")
        }
    }

    @Test("extractSBOM with product filter for Swiftly")
    func extractSBOMWithProductFilterForSwiftly() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        
        // Extract SBOM for the main executable product
        let productName = "swiftly"
        let sbom = try await SBOMModel.extractSBOM(spec: .spdx, graph: graph, store: store, product: productName)
        
        // The primary component should be the specified product
        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id == "swiftly:swiftly")
        #expect(sbom.primaryComponent.category == .application)
        
        // Extract SBOM without product filter for comparison
        let fullSbom = try await SBOMModel.extractSBOM(spec: .spdx, graph: graph, store: store)
        
        // The product-specific SBOM should have fewer or equal components than the full SBOM
        #expect((sbom.dependencies.components.count ?? 0) <= (fullSbom.dependencies.components.count ?? 0))
        
        // The product-specific SBOM should have fewer or equal dependencies than the full SBOM
        #expect((sbom.dependencies.dependencies?.count ?? 0) <= (fullSbom.dependencies.dependencies?.count ?? 0))
        
        // Verify that the product-specific SBOM contains the main product
        let componentIDs = Set((sbom.dependencies.components ?? []).map { $0.id })
        #expect(componentIDs.contains("swiftly:swiftly"))
        #expect(componentIDs.contains("swiftly"))
    }

    @Test("extractSBOM with invalid product name throws error")
    func extractSBOMWithInvalidProductNameThrowsError() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        // Try to extract SBOM for a non-existent product
        await #expect(throws: StringError.self) {
            _ = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store, product: "NonExistentProduct")
        }
    }

    @Test("extractPrimaryComponent with product filter")
    func extractPrimaryComponentWithProductFilter() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        
        let productName = "SwiftPMDataModel"
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store, product: productName)
        
        #expect(component.name == productName)
        #expect(component.id == "SwiftPM:SwiftPMDataModel")
        #expect(component.category == .library)
        
        let packageComponent = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        #expect(packageComponent.name == "SwiftPM")
        #expect(packageComponent.id == "SwiftPM")
        
        #expect(component.id != packageComponent.id)
    }
}