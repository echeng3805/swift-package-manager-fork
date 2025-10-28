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
@testable import SBOMModel
import _InternalTestSupport

struct SBOMExtractPrimaryComponentTests {

    @Test("extractPrimaryComponent from sample SwiftPM ModulesGraph")
    func extractPrimaryComponentFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        let rootPackage = try #require(graph.rootPackages.first)

        #expect(component.category == SBOMComponent.Category.library)
        #expect(component.name == rootPackage.identity.description)
        #expect(component.id == rootPackage.identity.description)
        #expect(component.purl == "pkg:swift/SwiftPM@\(SBOMTestStore.swiftPMRevision)")
        #expect(component.version == SBOMTestStore.swiftPMRevision)
        #expect(component.scope == .runtime)
        #expect(component.description == rootPackage.description)
        
        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == SBOMTestStore.swiftPMRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractPrimaryComponent from sample Swiftly ModulesGraph")
    func extractPrimaryComponentFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let component = try await SBOMModel.extractPrimaryComponent(graph: graph, store: store)
        let rootPackage = try #require(graph.rootPackages.first)

        #expect(component.category == SBOMComponent.Category.application)
        #expect(component.name == rootPackage.identity.description)
        #expect(component.id == rootPackage.identity.description)
        #expect(component.purl == "pkg:swift/swiftly@\(SBOMTestStore.swiftlyRevision)")
        #expect(component.version == SBOMTestStore.swiftlyRevision)
        #expect(component.scope == .runtime)
        #expect(component.description == rootPackage.description)
        
        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == SBOMTestStore.swiftlyRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftlyURL)
    }

    @Test("extractComponent from product from primary component from sample SwiftPM ModulesGraph")
    func extractComponentFromProductFromSPMModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let store = try SBOMTestStore.createSPMResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let resolvedProduct = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })

        let component = try await SBOMModel.extractComponent(product: resolvedProduct, store: store)
        
        #expect(component.category == SBOMComponent.Category.library)
        #expect(component.name == "SwiftPMDataModel")
        #expect(component.id == "SwiftPM:SwiftPMDataModel")
        #expect(component.version == SBOMTestStore.swiftPMRevision)
        #expect(component.scope == .runtime)
        #expect(component.purl.contains("pkg:swift/github.com/swiftlang/swift-package-manager/SwiftPM:SwiftPMDataModel@\(SBOMTestStore.swiftPMRevision)"))
        #expect(component.description == nil)

        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == SBOMTestStore.swiftPMRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftPMURL)
    }

    @Test("extractComponent from product from primary component from sample Swiftly ModulesGraph")
    func extractComponentFromProductFromSwiftlyModulesGraph() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let store = try SBOMTestStore.createSwiftlyResolvedPackagesStore()
        let rootPackage = try #require(graph.rootPackages.first)
        let resolvedProduct = try #require(rootPackage.products.first)

        let component = try await SBOMModel.extractComponent(product: resolvedProduct, store: store)
        
        #expect(component.category == SBOMComponent.Category.application)
        #expect(component.name == "swiftly")
        #expect(component.id == "swiftly:swiftly")
        #expect(component.version == SBOMTestStore.swiftlyRevision)
        #expect(component.scope == .runtime)
        #expect(component.purl.contains("pkg:swift/github.com/swiftlang/swiftly/swiftly:swiftly@\(SBOMTestStore.swiftlyRevision)"))
        #expect(component.description == nil)

        #expect(component.originator.commits != nil)
        #expect(component.originator.commits?.count == 1)
        #expect(component.originator.commits?.first?.sha == SBOMTestStore.swiftlyRevision)
        #expect(component.originator.commits?.first?.repository == SBOMTestStore.swiftlyURL)
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
        #expect(component.category == .library)
        
        #expect(component.id != packageComponent.id)
    }
}