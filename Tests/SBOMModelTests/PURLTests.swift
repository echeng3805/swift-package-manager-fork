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

struct PURLTests {
    
    struct PURLStringTestCase {
        let purl: PURL
        let expectedString: String
        let description: String
    }
    
    static let stringRepresentationTestCases: [PURLStringTestCase] = [
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: nil,
                qualifiers: nil,
                subpath: nil
            ),
            expectedString: "pkg:swift/MyPackage",
            description: "Basic PURL with scheme, type, and name only"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: "apple",
                name: "swift-package-manager",
                version: nil,
                qualifiers: nil,
                subpath: nil
            ),
            expectedString: "pkg:swift/apple/swift-package-manager",
            description: "PURL with namespace"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: "1.0.0",
                qualifiers: nil,
                subpath: nil
            ),
            expectedString: "pkg:swift/MyPackage@1.0.0",
            description: "PURL with version"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: nil,
                qualifiers: ["arch": "arm64"],
                subpath: nil
            ),
            expectedString: "pkg:swift/MyPackage?arch=arm64",
            description: "PURL with single qualifier"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: nil,
                qualifiers: ["os": "macos", "arch": "arm64"],
                subpath: nil
            ),
            expectedString: "pkg:swift/MyPackage?arch=arm64&os=macos",
            description: "PURL with multiple qualifiers"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: nil,
                qualifiers: nil,
                subpath: "Sources/MyModule"
            ),
            expectedString: "pkg:swift/MyPackage#Sources/MyModule",
            description: "PURL with subpath"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: "apple",
                name: "swift-package-manager",
                version: "5.9.0",
                qualifiers: ["arch": "arm64", "os": "macos"],
                subpath: "Sources/PackageModel"
            ),
            expectedString: "pkg:swift/apple/swift-package-manager@5.9.0?arch=arm64&os=macos#Sources/PackageModel",
            description: "Complete PURL with all components"
        ),
        
        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: "kitty",
                name: "meowmeow",
                version: "18.0.0",
                qualifiers: [:],
                subpath: nil
            ),
            expectedString: "pkg:swift/kitty/meowmeow@18.0.0",
            description: "PURL with empty qualifiers dictionary"
        ),

        PURLStringTestCase(
            purl: PURL(
                scheme: "pkg",
                type: "swift",
                namespace: nil,
                name: "MyPackage",
                version: nil,
                qualifiers: nil,
                subpath: "Meow/MeowMeow/MeowMeowMeow/Meow/Meow.swift"
            ),
            expectedString: "pkg:swift/MyPackage#Meow/MeowMeow/MeowMeowMeow/Meow/Meow.swift",
            description: "PURL with complex subpath"
        )
    ]

    @Test("PURL string representation", arguments: stringRepresentationTestCases)
    func purlStringRepresentation(testCase: PURLStringTestCase) throws {
        let actualString = testCase.purl.description
        #expect(actualString == testCase.expectedString, "Expected '\(testCase.expectedString)' but got '\(actualString)' for case \(testCase.description)")
    }
    
    @Test("Extract namespace from different packageLocation formats")
    func extractNamespaceFromPackageLocation() throws {
        #expect(PURL.extractNamespace(from: "https://github.com/apple/swift-system.git") == "github.com/apple")
        #expect(PURL.extractNamespace(from: "https://github.com/swiftlang/swift-llbuild.git") == "github.com/swiftlang")
        #expect(PURL.extractNamespace(from: "https://gitlab.com/myorg/mypackage.git") == "gitlab.com/myorg")
        
        #expect(PURL.extractNamespace(from: "git@github.com:apple/swift-system.git") == "github.com/apple")
        #expect(PURL.extractNamespace(from: "git@gitlab.com:myorg/mypackage.git") == "gitlab.com/myorg")
        
        #expect(PURL.extractNamespace(from: "org.foo") == "org")
        #expect(PURL.extractNamespace(from: "com.example.package") == "com.example")
        #expect(PURL.extractNamespace(from: "scope.package-name") == "scope")
        
        #expect(PURL.extractNamespace(from: "/Users/username/MyPackage") == "username")
        #expect(PURL.extractNamespace(from: "/swift-system") == nil)
        #expect(PURL.extractNamespace(from: "/path/to/package") == "to")
        #expect(PURL.extractNamespace(from: "/special.character/in/path.to/package") == "path.to")
        
        #expect(PURL.extractNamespace(from: "") == nil)
        #expect(PURL.extractNamespace(from: "invalid") == nil)
        #expect(PURL.extractNamespace(from: "https://github.com/") == nil) 
        #expect(PURL.extractNamespace(from: "git@github.com:") == nil)
        #expect(PURL.extractNamespace(from: "user@email.com") == nil)
        #expect(PURL.extractNamespace(from: "tcp://host.com:5000") == nil)
    }
    
    @Test("Extract product namespace from different packageLocation formats")
    func extractProductNamespaceFromPackageLocation() throws {
        // HTTPS URLs with .git extension
        #expect(PURL.extractProductNamespace(from: "https://github.com/apple/swift-system.git") == "github.com/apple/swift-system")
        #expect(PURL.extractProductNamespace(from: "https://github.com/swiftlang/swift-package-manager.git") == "github.com/swiftlang/swift-package-manager")
        #expect(PURL.extractProductNamespace(from: "https://gitlab.com/myorg/mypackage.git") == "gitlab.com/myorg/mypackage")
        
        // HTTPS URLs without .git extension
        #expect(PURL.extractProductNamespace(from: "https://github.com/apple/swift-system") == "github.com/apple/swift-system")
        #expect(PURL.extractProductNamespace(from: "https://github.com/swiftlang/swift-llbuild") == "github.com/swiftlang/swift-llbuild")
        
        // SSH URLs with .git extension
        #expect(PURL.extractProductNamespace(from: "git@github.com:apple/swift-system.git") == "github.com/apple/swift-system")
        #expect(PURL.extractProductNamespace(from: "git@gitlab.com:myorg/mypackage.git") == "gitlab.com/myorg/mypackage")
        
        // SSH URLs without .git extension
        #expect(PURL.extractProductNamespace(from: "git@github.com:apple/swift-system") == "github.com/apple/swift-system")
        #expect(PURL.extractProductNamespace(from: "git@github.com:swiftlang/swiftly") == "github.com/swiftlang/swiftly")
        
        // Registry identities (fallback to extractNamespace)
        #expect(PURL.extractProductNamespace(from: "org.foo") == "org")
        #expect(PURL.extractProductNamespace(from: "com.example.package") == "com.example")
        
        // Local paths (fallback to extractNamespace)
        #expect(PURL.extractProductNamespace(from: "/Users/username/MyPackage") == "username")
        
        // Edge cases
        #expect(PURL.extractProductNamespace(from: "") == nil)
        #expect(PURL.extractProductNamespace(from: "https://github.com/") == nil)
    }
    
    @Test("Create PURL from ResolvedPackage")
    func createPURLFromResolvedPackage() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let rootPackage = try #require(graph.rootPackages.first)
        
        let purl = PURL.from(package: rootPackage, version: "1.0.0")
        
        #expect(purl.scheme == "pkg")
        #expect(purl.type == "swift")
        // Root package in test has local path "/SwiftPM", so namespace extraction returns nil
        #expect(purl.namespace == nil)
        #expect(purl.name == "SwiftPM")
        #expect(purl.version == "1.0.0")
        #expect(purl.description == "pkg:swift/SwiftPM@1.0.0")
    }
    
    @Test("Create PURL from ResolvedProduct with package location")
    func createPURLFromResolvedProduct() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })
        
        let packageLocation = "https://github.com/swiftlang/swift-package-manager.git"
        let purl = PURL.from(product: product, version: "1.0.0", packageLocation: packageLocation)
        
        #expect(purl.scheme == "pkg")
        #expect(purl.type == "swift")
        #expect(purl.namespace == "github.com/swiftlang/swift-package-manager")
        #expect(purl.name == "SwiftPM:SwiftPMDataModel")
        #expect(purl.version == "1.0.0")
        #expect(purl.description == "pkg:swift/github.com/swiftlang/swift-package-manager/SwiftPM:SwiftPMDataModel@1.0.0")
    }
    
    @Test("Create PURL from ResolvedProduct with local package")
    func createPURLFromResolvedProductLocalPackage() async throws {
        let graph = try SBOMTestGraph.createSPMModulesGraph()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first { $0.name == "SwiftPMDataModel" })
        
        // Simulate a local package by using the package identity as location
        let packageLocation = "SwiftPM"
        let purl = PURL.from(product: product, version: "1.0.0", packageLocation: packageLocation)
        
        #expect(purl.scheme == "pkg")
        #expect(purl.type == "swift")
        // For local packages, namespace should fall back to nil or package identity
        #expect(purl.name == "SwiftPM:SwiftPMDataModel")
        #expect(purl.version == "1.0.0")
        #expect(purl.description == "pkg:swift/SwiftPM:SwiftPMDataModel@1.0.0")
    }
    
    @Test("Create PURL from ResolvedProduct with SSH URL")
    func createPURLFromResolvedProductSSH() async throws {
        let graph = try SBOMTestGraph.createSwiftlyModulesGraph()
        let rootPackage = try #require(graph.rootPackages.first)
        let product = try #require(rootPackage.products.first)
        
        let packageLocation = "git@github.com:swiftlang/swiftly.git"
        let purl = PURL.from(product: product, version: "1.0.0", packageLocation: packageLocation)
        
        #expect(purl.scheme == "pkg")
        #expect(purl.type == "swift")
        #expect(purl.namespace == "github.com/swiftlang/swiftly")
        #expect(purl.name == "swiftly:swiftly")
        #expect(purl.version == "1.0.0")
        #expect(purl.description == "pkg:swift/github.com/swiftlang/swiftly/swiftly:swiftly@1.0.0")
    }
}