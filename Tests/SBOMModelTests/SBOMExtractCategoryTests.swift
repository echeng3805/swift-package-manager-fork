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

struct SBOMExtractCategoryTests {
    // MARK: - Product Category Tests
    
    @Test("extractCategoryFromProduct with executable product returns application")
    func extractCategoryFromExecutableProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromProduct with library product returns library")
    func extractCategoryFromLibraryProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromProduct with test product returns library")
    func extractCategoryFromTestProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromProduct with snippet product returns library")
    func extractCategoryFromSnippetProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MySnippetProduct", type: .snippet)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromProduct with plugin product returns library")
    func extractCategoryFromPluginProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyPluginProduct", type: .plugin)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromProduct with macro product returns library")
    func extractCategoryFromMacroProduct() async throws {
        let resolvedProduct = try SBOMTestGraph.createProduct(name: "MyMacroProduct", type: .macro)
        let category = try await SBOMModel.extractCategory(from: resolvedProduct)
        #expect(category == SBOMComponent.Category.library)
    }

    // MARK: - Package Category Tests
    
    @Test("extractCategoryFromPackage with executable product returns application")
    func extractCategoryFromPackageWithExecutable() async throws {
        let executableProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "ExecutablePackage", products: [executableProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromPackage with only library products returns library")
    func extractCategoryFromPackageWithOnlyLibraries() async throws {
        let libraryProduct1 = try SBOMTestGraph.createProduct(name: "MyLibraryProduct1", type: .library(.automatic))
        let libraryProduct2 = try SBOMTestGraph.createProduct(name: "MyLibraryProduct2", type: .library(.dynamic))
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "LibraryPackage", products: [libraryProduct1, libraryProduct2])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with mixed products containing executable returns application")
    func extractCategoryFromPackageWithMixedProductsIncludingExecutable() async throws {
        let libraryProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let executableProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "MixedPackage", products: [libraryProduct, executableProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromPackage with test product returns library")
    func extractCategoryFromPackageWithTestProduct() async throws {
        let testProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "TestPackage", products: [testProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with snippet product returns library")
    func extractCategoryFromPackageWithSnippetProduct() async throws {
        let snippetProduct = try SBOMTestGraph.createProduct(name: "MySnippetProduct", type: .snippet)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "SnippetPackage", products: [snippetProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with plugin product returns library")
    func extractCategoryFromPackageWithPluginProduct() async throws {
        let pluginProduct = try SBOMTestGraph.createProduct(name: "MyPluginProduct", type: .plugin)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "PluginPackage", products: [pluginProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with macro product returns library")
    func extractCategoryFromPackageWithMacroProduct() async throws {
        let macroProduct = try SBOMTestGraph.createProduct(name: "MyMacroProduct", type: .macro)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "MacroPackage", products: [macroProduct])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.library)
    }

    @Test("extractCategoryFromPackage with multiple executables returns application")
    func extractCategoryFromPackageWithMultipleExecutables() async throws {
        let executableProduct1 = try SBOMTestGraph.createProduct(name: "MyExecutableProduct1", type: .executable, moduleType: .executable)
        let executableProduct2 = try SBOMTestGraph.createProduct(name: "MyExecutableProduct2", type: .executable, moduleType: .executable)
        let resolvedPackage = try SBOMTestGraph.createPackage(name: "MultiExecPackage", products: [executableProduct1, executableProduct2])
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }

    @Test("extractCategoryFromPackage with all product types including executable returns application")
    func extractCategoryFromPackageWithAllProductTypes() async throws {
        let libraryProduct = try SBOMTestGraph.createProduct(name: "MyLibraryProduct", type: .library(.automatic))
        let executableProduct = try SBOMTestGraph.createProduct(name: "MyExecutableProduct", type: .executable, moduleType: .executable)
        let testProduct = try SBOMTestGraph.createProduct(name: "MyTestProduct", type: .test, moduleType: .test)
        let pluginProduct = try SBOMTestGraph.createProduct(name: "MyPluginProduct", type: .plugin)
        let resolvedPackage = try SBOMTestGraph.createPackage(
            name: "ComplexPackage",
            products: [libraryProduct, executableProduct, testProduct, pluginProduct]
        )
        let category = try await SBOMModel.extractCategory(from: resolvedPackage)
        #expect(category == SBOMComponent.Category.application)
    }
}
