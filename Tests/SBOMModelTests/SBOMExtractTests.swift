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
import Foundation
@testable import SBOMModel
import Testing

struct SBOMExtractTests {
    @Test("extractSBOM with product filter for SwiftPM")
    func extractSBOMWithProductFilterForSwiftPM() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        let productName = "SwiftPMPackageCollections"
        let sbom = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store, product: productName)

        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id == "SwiftPM:\(productName)")
        #expect(sbom.primaryComponent.category == .library)

        let fullSbom = try await SBOMModel.extractSBOM(spec: .cyclonedx, graph: graph, store: store)
        #expect(fullSbom.primaryComponent.name == "SwiftPM")
        #expect(fullSbom.primaryComponent.id == "SwiftPM")
        #expect(fullSbom.primaryComponent.category == .library)

        #expect(sbom.dependencies.components.count == 9)
        #expect(fullSbom.dependencies.components.count == 22)

        #expect(sbom.dependencies.relationships?.count == 5)
        #expect(fullSbom.dependencies.relationships?.count == 13)

        let componentIDs = Set(sbom.dependencies.components.map(\.id))

        #expect(componentIDs.contains("SwiftPM:SwiftPMPackageCollections"), "should contain target product")
        #expect(componentIDs.contains("SwiftPM"), "should contain root package")

        let swiftPMDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "SwiftPM" }))
        #expect(Set(swiftPMDependency.childrenID) == Set([
            "swift-tools-support-core", "swift-system", "swift-collections", "SwiftPM:SwiftPMPackageCollections"
        ]))
    }

    @Test("extractSBOM with product filter for Swiftly")
    func extractSBOMWithProductFilterForSwiftly() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()

        let productName = "swiftly"
        let sbom = try await SBOMModel.extractSBOM(spec: .spdx, graph: graph, store: store, product: productName)

        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id == "swiftly:swiftly")
        #expect(sbom.primaryComponent.category == .application)

        let fullSbom = try await SBOMModel.extractSBOM(spec: .spdx, graph: graph, store: store)
        #expect(fullSbom.primaryComponent.name == "swiftly")
        #expect(fullSbom.primaryComponent.id == "swiftly")
        #expect(fullSbom.primaryComponent.category == .application)

        #expect(sbom.dependencies.components.count == 16)
        #expect(fullSbom.dependencies.components.count == 17)

        #expect(sbom.dependencies.relationships?.count == 9)
        #expect(fullSbom.dependencies.relationships?.count == 10)

        let componentIDs = Set(sbom.dependencies.components.map(\.id))
        #expect(componentIDs.contains("swiftly:swiftly"), "should contain target product")
        #expect(componentIDs.contains("swiftly"), "should contain root package")
        #expect(
            componentIDs.contains("swift-tools-support-core:SwiftToolsSupport-auto"),
            "should contain a dependency product"
        )

        let swiftlyDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "swiftly" }))
        #expect(Set(swiftlyDependency.childrenID) == Set([
            "swiftly:swiftly",
            "swift-tools-support-core",
            "swift-argument-parser",
            "swift-system",
            "async-http-client",
            "swift-openapi-async-http-client",
            "swift-nio",
            "swift-openapi-runtime",
        ]))
        let swiftlyProductDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "swiftly:swiftly" }))
        #expect(Set(swiftlyProductDependency.childrenID) == Set([
            "async-http-client:AsyncHTTPClient",
            "swift-openapi-async-http-client:OpenAPIAsyncHTTPClient",
            "swift-openapi-runtime:OpenAPIRuntime",
            "swift-tools-support-core:SwiftToolsSupport-auto",
            "swift-argument-parser:ArgumentParser",
            "swift-nio:NIOFoundationCompat",
            "swift-system:SystemPackage",
        ]))
        let swiftSystemDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "swift-system" }))
        #expect(Set(swiftSystemDependency.childrenID) == Set(["swift-system:SystemPackage"]))
        let swiftArgumentParserDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "swift-argument-parser" }))
        #expect(Set(swiftArgumentParserDependency.childrenID) == Set(["swift-argument-parser:ArgumentParser"]))
        let swiftToolsSupportDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID == "swift-tools-support-core" }))
        #expect(Set(swiftToolsSupportDependency.childrenID) == Set(["swift-tools-support-core:SwiftToolsSupport-auto"]))
    }

    @Test("extractSBOM with invalid product name throws error")
    func extractSBOMWithInvalidProductNameThrowsError() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        await #expect(throws: SBOMExtractorError.self) {
            _ = try await SBOMModel.extractSBOM(
                spec: .cyclonedx,
                graph: graph,
                store: store,
                product: "NonExistentProduct"
            )
        }
    }
}
