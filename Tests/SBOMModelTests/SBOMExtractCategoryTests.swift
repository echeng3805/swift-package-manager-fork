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
import Testing

private func createProduct(name: String, type: ProductType) throws -> ResolvedProduct {
    let packageName = PackageIdentity.plain("Package\(name)")
    let module = SBOMTestGraph.createSwiftModule(
        name: "\(name)Module",
        type: type == .executable ? .executable : .library
    )
    let product = try Product(
        package: packageName,
        name: name,
        type: type,
        modules: [module]
    )
    let resolvedModule = SBOMTestGraph.createResolvedModule(
        packageIdentity: packageName,
        module: module
    )
    return SBOMTestGraph.createResolvedProduct(
        packageIdentity: packageName,
        product: product,
        modules: IdentifiableSet([resolvedModule])
    )
}

private func createPackage(name: String, products: [ResolvedProduct]) throws -> ResolvedPackage {
    let packageName = PackageIdentity.plain("Package\(name)")
    let package = SBOMTestGraph.createPackage(
        identity: packageName,
        displayName: name,
        path: "/\(name)",
        modules: [],
        products: products.map(\.underlying)
    )
    return SBOMTestGraph.createResolvedPackage(
        package: package,
        modules: [],
        products: products
    )
}

struct SBOMExtractCategoryTests {
    @Test("extractCategoryFromProduct with executable product returns application")
    func extractCategoryFromExecutableProduct() async throws {
        let resolvedProduct = try createProduct(name: "MyExecutableProduct", type: .executable)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromProduct with library product returns library")
    func extractCategoryFromLibraryProduct() async throws {
        let resolvedProduct = try createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with 1 executable product returns application")
    func extractCategoryFromPackageWithExecutable() async throws {
        let resolvedProduct = try createProduct(name: "MyExecutableProduct", type: .executable)
        let resolvedPackage = try createPackage(name: "Executable", products: [resolvedProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromPackage with 1 library product returns library")
    func extractCategoryFromPackageWithLibrary() async throws {
        let resolvedProduct = try createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let resolvedPackage = try createPackage(name: "Library", products: [resolvedProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with mixed products returns application")
    func extractCategoryFromPackageWithMixedProducts() async throws {
        let executableProduct = try createProduct(name: "MyExecutableProduct", type: .executable)
        let libraryProduct = try createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let resolvedPackage = try createPackage(name: "Library", products: [executableProduct, libraryProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }
}
