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

struct SBOMExtractScopeTests {
    @Test("extractScopeFromProduct with executable product returns runtime")
    func extractScopeFromExecutableProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let scope = try await SBOMModel.extractScope(from: resolvedProduct)
        #expect(scope == SBOMComponent.Scope.runtime)
    }

    @Test("extractScopeFromProduct with library product returns runtime")
    func extractScopeFromLibraryProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let scope = try await SBOMModel.extractScope(from: resolvedProduct)
        #expect(scope == SBOMComponent.Scope.runtime)
    }

    @Test("extractScopeFromProduct with test product returns test")
    func extractScopeFromTestProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let scope = try await SBOMModel.extractScope(from: resolvedProduct)
        #expect(scope == SBOMComponent.Scope.test)
    }

    @Test("extractScopeFromProduct with library product containing test module returns test")
    func extractScopeFromLibraryProductWithTestModule() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic), moduleType: .test)
        let scope = try await SBOMModel.extractScope(from: resolvedProduct)
        #expect(scope == SBOMComponent.Scope.test)
    }

    @Test("extractScopeFromPackage with executable product returns runtime")
    func extractScopeFromPackageWithExecutable() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "Executable", products: [resolvedProduct])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.runtime)
    }

    @Test("extractScopeFromPackage with library product returns runtime")
    func extractScopeFromPackageWithLibrary() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "Library", products: [resolvedProduct])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.runtime)
    }

    @Test("extractScopeFromPackage with test product returns test")
    func extractScopeFromPackageWithTestProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "TestPackage", products: [resolvedProduct])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.test)
    }

    @Test("extractScopeFromPackage with mixed products containing test returns test")
    func extractScopeFromPackageWithMixedProductsIncludingTest() async throws {
        let executableProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let testProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "MixedPackage", products: [executableProduct, testProduct])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.test)
    }

    @Test("extractScopeFromPackage with test module but no test product returns test")
    func extractScopeFromPackageWithTestModule() async throws {
        let libraryProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let testModule = SBOMTestGraph.createSwiftModule(name: "TestModule", type: .test)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "PackageWithTests", products: [libraryProduct], modules: [testModule])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.test)
    }

    @Test("extractScopeFromPackage with only runtime products and modules returns runtime")
    func extractScopeFromPackageWithOnlyRuntimeComponents() async throws {
        let executableProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let libraryProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "RuntimePackage", products: [executableProduct, libraryProduct])
        let scope = try await SBOMModel.extractScope(from: resolvedPackage)
        #expect(scope == SBOMComponent.Scope.runtime)
    }
}