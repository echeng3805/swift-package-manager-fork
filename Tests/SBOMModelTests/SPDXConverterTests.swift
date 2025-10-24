
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

struct SPDXConverterTests {
    
    @Test("convertToSPDXAgent with nil metadata")
    func convertToSPDXAgentWithNilMetadata() async throws {
        let result = await convertToSPDXAgent(from: nil)
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXAgent with nil creators")
    func convertToSPDXAgentWithNilCreators() async throws {
        let metadata = SBOMMetadata(
            spec: SBOMSpec(type: .spdx, version: "3.0.1"),
            timestamp: "2025-01-01T00:00:00Z",
            creators: nil
        )
        let result = await convertToSPDXAgent(from: metadata)
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXAgent with empty creators")
    func convertToSPDXAgentWithEmptyCreators() async throws {
        let metadata = SBOMMetadata(
            spec: SBOMSpec(type: .spdx, version: "3.0.1"),
            timestamp: "2025-01-01T00:00:00Z",
            creators: []
        )
        let result = await convertToSPDXAgent(from: metadata)
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXAgent with single creator")
    func convertToSPDXAgentWithSingleCreator() async throws {
        let creator = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let metadata = SBOMMetadata(
            spec: SBOMSpec(type: .spdx, version: "3.0.1"),
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator]
        )
        
        let result = await convertToSPDXAgent(from: metadata)
        #expect(result.count == 2)
        
        let creationInfo = result[0] as? SPDXCreationInfo
        let creationInfoUnwrapped = try #require(creationInfo)
        #expect(creationInfoUnwrapped.id == "tool-1:creationInfo")
        #expect(creationInfoUnwrapped.type == .CreationInfo)
        #expect(creationInfoUnwrapped.specVersion == "3.0.1")
        #expect(creationInfoUnwrapped.createdBy == ["tool-1"])
        #expect(creationInfoUnwrapped.created == "1970-01-01T00:00:00Z")
        
        let agent = result[1] as? SPDXAgent
        let agentUnwrapped = try #require(agent)
        #expect(agentUnwrapped.id == "tool-1")
        #expect(agentUnwrapped.type == .Agent)
        #expect(agentUnwrapped.name == "SwiftPM")
        #expect(agentUnwrapped.creationInfoID == "tool-1:creationInfo")
    }
    
    @Test("convertToSPDXAgent with multiple creators")
    func convertToSPDXAgentWithMultipleCreators() async throws {
        let creator1 = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let creator2 = SBOMTool(
            id: "tool-2",
            name: "CustomTool",
            version: "1.0.0"
        )
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator1, creator2]
        )
        
        let result = await convertToSPDXAgent(from: metadata)
        #expect(result.count == 4) // 2 CreationInfos and 2 Agents
        
        let creationInfo1 = result[0] as? SPDXCreationInfo
        let creationInfo1Unwrapped = try #require(creationInfo1)
        #expect(creationInfo1Unwrapped.id == "tool-1:creationInfo")
        #expect(creationInfo1Unwrapped.createdBy == ["tool-1"])
        
        let agent1 = result[1] as? SPDXAgent
        let agent1Unwrapped = try #require(agent1)
        #expect(agent1Unwrapped.id == "tool-1")
        #expect(agent1Unwrapped.name == "SwiftPM")
        
        let creationInfo2 = result[2] as? SPDXCreationInfo
        let creationInfo2Unwrapped = try #require(creationInfo2)
        #expect(creationInfo2Unwrapped.id == "tool-2:creationInfo")
        #expect(creationInfo2Unwrapped.createdBy == ["tool-2"])
        
        let agent2 = result[3] as? SPDXAgent
        let agent2Unwrapped = try #require(agent2)
        #expect(agent2Unwrapped.id == "tool-2")
        #expect(agent2Unwrapped.name == "CustomTool")
    }
    
    @Test("convertToSPDXDocument with missing timestamp throws error")
    func convertToSPDXDocumentWithMissingTimestamp() async throws {
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: nil,
            creators: [SBOMTool(id: "tool-1", name: "SwiftPM", version: "3.0.1")]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent
        )
        
        await #expect(throws: Error.self) {
            try await convertToSPDXDocument(from: document)
        }
    }
    
    @Test("convertToSPDXDocument with missing creators throws error")
    func convertToSPDXDocumentWithMissingCreators() async throws {
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: nil
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent
        )
        
        await #expect(throws: Error.self) {
            try await convertToSPDXDocument(from: document)
        }
    }
    
    @Test("convertToSPDXDocument with empty creators throws error")
    func convertToSPDXDocumentWithEmptyCreators() async throws {
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: []
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent
        )
        
        await #expect(throws: Error.self) {
            try await convertToSPDXDocument(from: document)
        }
    }
    
    @Test("convertToSPDXDocument with valid data")
    func convertToSPDXDocumentWithValidData() async throws {
        let creator = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent
        )
        
        let result = try await convertToSPDXDocument(from: document)
        #expect(result.count == 4)
        
        let creationInfo = result[0] as? SPDXCreationInfo
        let creationInfoUnwrapped = try #require(creationInfo)
        #expect(creationInfoUnwrapped.id == "_:creationInfo")
        #expect(creationInfoUnwrapped.type == .CreationInfo)
        #expect(creationInfoUnwrapped.specVersion == "3.0.1")
        #expect(creationInfoUnwrapped.createdBy == ["tool-1"])
        #expect(creationInfoUnwrapped.created == "2025-01-01T00:00:00Z")
        
        let sbom = result[1] as? SPDXSBOM
        let sbomUnwrapped = try #require(sbom)
        #expect(sbomUnwrapped.type == .SoftwareSBOM)
        #expect(sbomUnwrapped.creationInfoID == "_:creationInfo")
        #expect(sbomUnwrapped.profileConformance == ["core", "software"])
        #expect(sbomUnwrapped.rootElementIDs == ["primary-id"])
        
        let relationship = result[2] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .describes)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == sbomUnwrapped.id)
        #expect(relationshipUnwrapped.childrenID == ["primary-id"])
        
        let spdxDocument = result[3] as? SPDXDocument
        let documentUnwrapped = try #require(spdxDocument)
        #expect(documentUnwrapped.id == "doc-1")
        #expect(documentUnwrapped.type == .SpdxDocument)
        #expect(documentUnwrapped.creationInfoID == "_:creationInfo")
        #expect(documentUnwrapped.profileConformance == ["core", "software"])
        #expect(documentUnwrapped.rootElementIDs == [sbomUnwrapped.id])
    }
    
    @Test("convertToSPDXPackage with all categories")
    func convertToSPDXPackageWithAllCategories() async throws {
        let categories: [(SBOMComponent.Category, SPDXPackage.Purpose)] = [
            (.application, .application),
            (.framework, .framework),
            (.library, .library),
            (.file, .file)
        ]
        
        for (sbomCategory, expectedSPDXPurpose) in categories {
            let component = SBOMComponent(
                category: sbomCategory,
                id: "test-id",
                purl: "pkg:swift/test@1.0.0",
                name: "TestComponent",
                version: "1.0.0",
                originator: SBOMOriginator(commits: nil),
                description: "Test description",
                scope: .runtime
            )
            
            let result = try await convertToSPDXPackage(from: component)
            
            #expect(result.id == "test-id")
            #expect(result.type == .SoftwarePackage)
            #expect(result.purpose == expectedSPDXPurpose)
            #expect(result.purl == "pkg:swift/test@1.0.0")
            #expect(result.name == "TestComponent")
            #expect(result.version == "1.0.0")
            #expect(result.creationInfoID == "_:creationInfo")
            #expect(result.description == "Test description")
        }
    }
    
    @Test("convertToSPDXPackage with nil description")
    func convertToSPDXPackageWithNilDescription() async throws {
        let component = SBOMComponent(
            category: .library,
            id: "test-id",
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            description: nil,
            scope: .runtime
        )
        
        let result = try await convertToSPDXPackage(from: component)
        
        #expect(result.id == "test-id")
        #expect(result.type == .SoftwarePackage)
        #expect(result.purpose == .library)
        #expect(result.description == nil)
    }
    
    @Test("convertToSPDXExternalIdentifiers with nil components")
    func convertToSPDXExternalIdentifiersWithNilComponents() async throws {
        let result = await convertToSPDXExternalIdentifiers(from: nil)
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXExternalIdentifiers with empty components")
    func convertToSPDXExternalIdentifiersWithEmptyComponents() async throws {
        let result = await convertToSPDXExternalIdentifiers(from: [])
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXExternalIdentifiers with components without commits")
    func convertToSPDXExternalIdentifiersWithComponentsWithoutCommits() async throws {
        let component = SBOMComponent(
            category: .library,
            id: "test-id",
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        
        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXExternalIdentifiers with components with empty commits")
    func convertToSPDXExternalIdentifiersWithComponentsWithEmptyCommits() async throws {
        let component = SBOMComponent(
            category: .library,
            id: "test-id",
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: "1.0.0",
            originator: SBOMOriginator(commits: []),
            scope: .runtime
        )
        
        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXExternalIdentifiers with single commit")
    func convertToSPDXExternalIdentifiersWithSingleCommit() async throws {
        let commit = SBOMCommit(
            sha: "abc123",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: "https://github.com/swiftlang/swift-package-manager/commit/abc123",
            authors: nil,
            message: "Initial commit"
        )
        let component = SBOMComponent(
            category: .library,
            id: "test-id",
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: "1.0.0",
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )
        
        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.count == 2) // ExternalIdentifier and Relationship
        
        let externalIdentifier = result[0] as? SPDXExternalIdentifier
        let externalIdentifierUnwrapped = try #require(externalIdentifier)
        #expect(externalIdentifierUnwrapped.identifier == "abc123")
        #expect(externalIdentifierUnwrapped.identifierLocator == "https://github.com/swiftlang/swift-package-manager")
        #expect(externalIdentifierUnwrapped.type == .ExternalIdentifier)
        #expect(externalIdentifierUnwrapped.category == .gitoid)
        
        let relationship = result[1] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.id == "test-id-wasGeneratedFrom-abc123")
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .wasGeneratedFrom)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == "test-id")
        #expect(relationshipUnwrapped.childrenID == ["abc123"])
    }
    
    @Test("convertToSPDXExternalIdentifiers with multiple commits")
    func convertToSPDXExternalIdentifiersWithMultipleCommits() async throws {
        let commit1 = SBOMCommit(
            sha: "abc123",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: nil,
            authors: nil,
            message: "First commit"
        )
        let commit2 = SBOMCommit(
            sha: "def456",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: nil,
            authors: nil,
            message: "Second commit"
        )
        let component = SBOMComponent(
            category: .library,
            id: "test-id",
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: "1.0.0",
            originator: SBOMOriginator(commits: [commit1, commit2]),
            scope: .runtime
        )
        
        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.count == 4) // 2 ExternalIdentifiers and 2 Relationships
        
        let externalIdentifier1 = result[0] as? SPDXExternalIdentifier
        let externalIdentifier1Unwrapped = try #require(externalIdentifier1)
        #expect(externalIdentifier1Unwrapped.identifier == "abc123")
        
        let relationship1 = result[1] as? SPDXRelationship
        let relationship1Unwrapped = try #require(relationship1)
        #expect(relationship1Unwrapped.id == "test-id-wasGeneratedFrom-abc123")
        #expect(relationship1Unwrapped.childrenID == ["abc123"])
        
        let externalIdentifier2 = result[2] as? SPDXExternalIdentifier
        let externalIdentifier2Unwrapped = try #require(externalIdentifier2)
        #expect(externalIdentifier2Unwrapped.identifier == "def456")
        
        let relationship2 = result[3] as? SPDXRelationship
        let relationship2Unwrapped = try #require(relationship2)
        #expect(relationship2Unwrapped.id == "test-id-wasGeneratedFrom-def456")
        #expect(relationship2Unwrapped.childrenID == ["def456"])
    }
    
    @Test("convertToSPDXRelationships with nil dependencies")
    func convertToSPDXRelationshipsWithNilDependencies() async throws {
        let result = await convertToSPDXRelationships(from: nil)
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXRelationships with empty dependencies")
    func convertToSPDXRelationshipsWithEmptyDependencies() async throws {
        let result = await convertToSPDXRelationships(from: [])
        #expect(result.isEmpty)
    }
    
    @Test("convertToSPDXRelationships with single dependency")
    func convertToSPDXRelationshipsWithSingleDependency() async throws {
        let dependency = SBOMDependency(
            id: "dep-1",
            parentID: "parent-component",
            childrenID: ["child1", "child2"]
        )
        
        let result = await convertToSPDXRelationships(from: [dependency])
        #expect(result.count == 1)
        
        let relationship = result[0] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.id == "parent-component-dependsOn")
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .dependsOn)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == "parent-component")
        #expect(relationshipUnwrapped.childrenID == ["child1", "child2"])
    }
    
    @Test("convertToSPDXRelationships with multiple dependencies")
    func convertToSPDXRelationshipsWithMultipleDependencies() async throws {
        let dependency1 = SBOMDependency(
            id: "dep-1",
            parentID: "parent1",
            childrenID: ["child1"]
        )
        let dependency2 = SBOMDependency(
            id: "dep-2",
            parentID: "parent2",
            childrenID: ["child2", "child3"]
        )
        
        let result = await convertToSPDXRelationships(from: [dependency1, dependency2])
        #expect(result.count == 2)
        
        let relationship1 = result[0] as? SPDXRelationship
        let relationship1Unwrapped = try #require(relationship1)
        #expect(relationship1Unwrapped.id == "parent1-dependsOn")
        #expect(relationship1Unwrapped.parentID == "parent1")
        #expect(relationship1Unwrapped.childrenID == ["child1"])
        
        let relationship2 = result[1] as? SPDXRelationship
        let relationship2Unwrapped = try #require(relationship2)
        #expect(relationship2Unwrapped.id == "parent2-dependsOn")
        #expect(relationship2Unwrapped.parentID == "parent2")
        #expect(relationship2Unwrapped.childrenID == ["child2", "child3"])
    }
    
    @Test("convertToSPDXGraph with non-SPDX spec throws error")
    func convertToSPDXGraphWithNonSPDXSpec() async throws {
        let spec = SBOMSpec(type: .cyclonedx, version: "1.7")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [SBOMTool(id: "tool-1", name: "SwiftPM", version: "3.0.1")]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent
        )
        
        await #expect(throws: Error.self) {
            try await convertToSPDXGraph(from: document)
        }
    }
    
    @Test("convertToSPDXGraph with minimal SPDX document")
    func convertToSPDXGraphWithMinimalSPDXDocument() async throws {
        let creator = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent,
            components: nil,
            dependencies: nil
        )
        
        let result = try await convertToSPDXGraph(from: document)
        
        #expect(result.context == SPDXConstants.spdx3Context)
        #expect(result.graph.count == 6) // 1 agent CreationInfo + 1 agent + 4 document elements + 0 packages + 0 relationships + 0 commits
    }
    
    @Test("convertToSPDXGraph with components and dependencies")
    func convertToSPDXGraphWithComponentsAndDependencies() async throws {
        let creator = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let spec = SBOMSpec(type: .spdx3, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let component1 = SBOMComponent(
            category: .library,
            id: "lib1-id",
            purl: "pkg:swift/lib1@1.0.0",
            name: "Library1",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let dependency = SBOMDependency(
            id: "dep-1",
            parentID: "primary-id",
            childrenID: ["lib1-id"]
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent,
            components: [component1],
            dependencies: [dependency]
        )
        
        let result = try await convertToSPDXGraph(from: document)
        
        #expect(result.context == SPDXConstants.spdx3Context)
        #expect(result.graph.count == 8) // 1 agent CreationInfo + 1 agent + 4 document elements + 1 package + 1 relationship + 0 commits
        
        let agents = result.graph.compactMap { $0.getValue() as SPDXAgent? }
        #expect(agents.count == 1)
        
        let creationInfos = result.graph.compactMap { $0.getValue() as SPDXCreationInfo? }
        #expect(creationInfos.count == 2) // 1 from agent + 1 from document
        
        let packages = result.graph.compactMap { $0.getValue() as SPDXPackage? }
        #expect(packages.count == 1)
        #expect(packages[0].id == "lib1-id")
        
        let relationships = result.graph.compactMap { $0.getValue() as SPDXRelationship? }
        #expect(relationships.count == 2) // 1 describes + 1 dependsOn relationship
        
        let sboms = result.graph.compactMap { $0.getValue() as SPDXSBOM? }
        #expect(sboms.count == 1)
        
        let documents = result.graph.compactMap { $0.getValue() as SPDXDocument? }
        #expect(documents.count == 1)
    }
    
    @Test("convertToSPDXGraph with components containing commits")
    func convertToSPDXGraphWithComponentsContainingCommits() async throws {
        let creator = SBOMTool(
            id: "tool-1",
            name: "SwiftPM",
            version: "3.0.1"
        )
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [creator]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: "primary-id",
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: "1.0.0",
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let commit = SBOMCommit(
            sha: "abc123",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: "https://github.com/swiftlang/swift-package-manager/commit/abc123",
            authors: nil,
            message: "Initial commit"
        )
        let component1 = SBOMComponent(
            category: .library,
            id: "lib1-id",
            purl: "pkg:swift/lib1@1.0.0",
            name: "Library1",
            version: "1.0.0",
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: "doc-1",
            metadata: metadata,
            primaryComponent: primaryComponent,
            components: [component1],
            dependencies: nil
        )
        
        let result = try await convertToSPDXGraph(from: document)
        
        #expect(result.context == SPDXConstants.spdx3Context)
        
        let externalIdentifiers = result.graph.compactMap { $0.getValue() as SPDXExternalIdentifier? }
        #expect(externalIdentifiers.count == 1)
        #expect(externalIdentifiers[0].identifier == "abc123")
        
        let relationships = result.graph.compactMap { $0.getValue() as SPDXRelationship? }
        let wasGeneratedFromRelationships = relationships.filter { $0.category == .wasGeneratedFrom }
        #expect(wasGeneratedFromRelationships.count == 1)
        #expect(wasGeneratedFromRelationships[0].parentID == "lib1-id")
        #expect(wasGeneratedFromRelationships[0].childrenID == ["abc123"])
    }
}