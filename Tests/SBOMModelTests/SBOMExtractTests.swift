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
        let sbom = try await SBOMModel.extractSBOM(modulesGraph: graph, dependencyGraph: nil, store: store, product: productName)

        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id.value == "SwiftPM:\(productName)")
        #expect(sbom.primaryComponent.category == .library)

        let fullSbom = try await SBOMModel.extractSBOM(modulesGraph: graph, dependencyGraph: nil, store: store)
        #expect(fullSbom.primaryComponent.name == "SwiftPM")
        #expect(fullSbom.primaryComponent.id.value == "SwiftPM")
        #expect(fullSbom.primaryComponent.category == .library)

        #expect(sbom.dependencies.components.count == 9)
        #expect(fullSbom.dependencies.components.count == 22)

        #expect(sbom.dependencies.relationships?.count == 5)
        #expect(fullSbom.dependencies.relationships?.count == 13)

        let componentIDs = Set(sbom.dependencies.components.map(\.id.value))

        #expect(componentIDs.contains("SwiftPM:SwiftPMPackageCollections"), "should contain target product")
        #expect(componentIDs.contains("SwiftPM"), "should contain root package")

        let swiftPMDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID.value == "SwiftPM" }))
        #expect(Set(swiftPMDependency.childrenID.map(\.value)) == Set([
            "swift-tools-support-core", "swift-system", "swift-collections", "SwiftPM:SwiftPMPackageCollections"
        ]))
    }

    @Test("extractSBOM with product filter for Swiftly")
    func extractSBOMWithProductFilterForSwiftly() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()

        let productName = "swiftly"
        let sbom = try await SBOMModel.extractSBOM(modulesGraph: graph, dependencyGraph: nil, store: store, product: productName)

        #expect(sbom.primaryComponent.name == productName)
        #expect(sbom.primaryComponent.id.value == "swiftly:swiftly")
        #expect(sbom.primaryComponent.category == .application)

        let fullSbom = try await SBOMModel.extractSBOM(modulesGraph: graph, dependencyGraph: nil, store: store)
        #expect(fullSbom.primaryComponent.name == "swiftly")
        #expect(fullSbom.primaryComponent.id.value == "swiftly")
        #expect(fullSbom.primaryComponent.category == .application)

        #expect(sbom.dependencies.components.count == 16)
        #expect(fullSbom.dependencies.components.count == 17)

        #expect(sbom.dependencies.relationships?.count == 9)
        #expect(fullSbom.dependencies.relationships?.count == 10)

        let componentIDs = Set(sbom.dependencies.components.map(\.id.value))
        #expect(componentIDs.contains("swiftly:swiftly"), "should contain target product")
        #expect(componentIDs.contains("swiftly"), "should contain root package")
        #expect(
            componentIDs.contains("swift-tools-support-core:SwiftToolsSupport-auto"),
            "should contain a dependency product"
        )

        let swiftlyDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID.value == "swiftly" }))
        #expect(Set(swiftlyDependency.childrenID.map(\.value)) == Set([
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
            .first(where: { $0.parentID.value == "swiftly:swiftly" }))
        #expect(Set(swiftlyProductDependency.childrenID.map(\.value)) == Set([
            "async-http-client:AsyncHTTPClient",
            "swift-openapi-async-http-client:OpenAPIAsyncHTTPClient",
            "swift-openapi-runtime:OpenAPIRuntime",
            "swift-tools-support-core:SwiftToolsSupport-auto",
            "swift-argument-parser:ArgumentParser",
            "swift-nio:NIOFoundationCompat",
            "swift-system:SystemPackage",
        ]))
        let swiftSystemDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID.value == "swift-system" }))
        #expect(Set(swiftSystemDependency.childrenID.map(\.value)) == Set(["swift-system:SystemPackage"]))
        let swiftArgumentParserDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID.value == "swift-argument-parser" }))
        #expect(Set(swiftArgumentParserDependency.childrenID.map(\.value)) == Set(["swift-argument-parser:ArgumentParser"]))
        let swiftToolsSupportDependency = try #require(sbom.dependencies.relationships?
            .first(where: { $0.parentID.value == "swift-tools-support-core" }))
        #expect(Set(swiftToolsSupportDependency.childrenID.map(\.value)) == Set(["swift-tools-support-core:SwiftToolsSupport-auto"]))
    }

    @Test("extractSBOM with invalid product name throws error")
    func extractSBOMWithInvalidProductNameThrowsError() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()

        await #expect(throws: SBOMExtractorError.self) {
            _ = try await SBOMModel.extractSBOM(
                modulesGraph: graph,
                dependencyGraph: nil,
                store: store,
                product: "NonExistentProduct"
            )
        }
    }

    @Test("generateSBOMID generates valid URN UUID format")
    func generateSBOMIDGeneratesValidURNUUIDFormat() async throws {
        let id1 = SBOMIdentifier.generate()
        let id2 = SBOMIdentifier.generate()

        #expect(id1.value.hasPrefix("urn:uuid:"))
        #expect(id2.value.hasPrefix("urn:uuid:"))

        let uuid1String = String(id1.value.dropFirst("urn:uuid:".count))
        let uuid2String = String(id2.value.dropFirst("urn:uuid:".count))

        #expect(UUID(uuidString: uuid1String) != nil, "Should be a valid UUID")
        #expect(UUID(uuidString: uuid2String) != nil, "Should be a valid UUID")

        #expect(uuid1String == uuid1String.lowercased(), "UUID should be lowercase")
        #expect(uuid2String == uuid2String.lowercased(), "UUID should be lowercase")

        #expect(id1 != id2, "Each call should generate a unique ID")
    }
}
