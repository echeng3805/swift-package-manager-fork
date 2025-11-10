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

import Foundation
@testable import SBOMModel
import Testing

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
            timestamp: "1970-01-01T00:00:00Z",
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
            id: SBOMIdentifier(value: "tool-1"),
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
        #expect(creationInfoUnwrapped.id == "urn:spdx:tool-1:creationInfo")
        #expect(creationInfoUnwrapped.type == .CreationInfo)
        #expect(creationInfoUnwrapped.specVersion == "3.0.1")
        #expect(creationInfoUnwrapped.createdBy == ["urn:spdx:tool-1"])
        #expect(creationInfoUnwrapped.created == "1970-01-01T00:00:00Z")

        let agent = result[1] as? SPDXAgent
        let agentUnwrapped = try #require(agent)
        #expect(agentUnwrapped.id == "urn:spdx:tool-1")
        #expect(agentUnwrapped.type == .Agent)
        #expect(agentUnwrapped.name == "SwiftPM")
        #expect(agentUnwrapped.creationInfoID == "urn:spdx:tool-1:creationInfo")
    }

    @Test("convertToSPDXAgent with multiple creators")
    func convertToSPDXAgentWithMultipleCreators() async throws {
        let creator1 = SBOMTool(
            id: SBOMIdentifier(value: "tool-1"),
            name: "SwiftPM",
            version: "3.0.1"
        )
        let creator2 = SBOMTool(
            id: SBOMIdentifier(value: "tool-2"),
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
        #expect(creationInfo1Unwrapped.id == "urn:spdx:tool-1:creationInfo")
        #expect(creationInfo1Unwrapped.createdBy == ["urn:spdx:tool-1"])

        let agent1 = result[1] as? SPDXAgent
        let agent1Unwrapped = try #require(agent1)
        #expect(agent1Unwrapped.id == "urn:spdx:tool-1")
        #expect(agent1Unwrapped.name == "SwiftPM")

        let creationInfo2 = result[2] as? SPDXCreationInfo
        let creationInfo2Unwrapped = try #require(creationInfo2)
        #expect(creationInfo2Unwrapped.id == "urn:spdx:tool-2:creationInfo")
        #expect(creationInfo2Unwrapped.createdBy == ["urn:spdx:tool-2"])

        let agent2 = result[3] as? SPDXAgent
        let agent2Unwrapped = try #require(agent2)
        #expect(agent2Unwrapped.id == "urn:spdx:tool-2")
        #expect(agent2Unwrapped.name == "CustomTool")
    }

    @Test("convertToSPDXDocument with missing timestamp throws error")
    func convertToSPDXDocumentWithMissingTimestamp() async throws {
        let spec = SBOMSpec(type: .spdx, version: "3.0.1")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: nil,
            creators: [SBOMTool(id: SBOMIdentifier(value: "tool-1"), name: "SwiftPM", version: "3.0.1")]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: nil)
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: nil)
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: nil)
        )

        await #expect(throws: Error.self) {
            try await convertToSPDXDocument(from: document)
        }
    }

    @Test("convertToSPDXDocument with valid data")
    func convertToSPDXDocumentWithValidData() async throws {
        let creator = SBOMTool(
            id: SBOMIdentifier(value: "tool-1"),
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: nil)
        )

        let result = try await convertToSPDXDocument(from: document)
        #expect(result.count == 4)

        let creationInfo = result[0] as? SPDXCreationInfo
        let creationInfoUnwrapped = try #require(creationInfo)
        #expect(creationInfoUnwrapped.id == "_:creationInfo")
        #expect(creationInfoUnwrapped.type == .CreationInfo)
        #expect(creationInfoUnwrapped.specVersion == "3.0.1")
        #expect(creationInfoUnwrapped.createdBy == ["urn:spdx:tool-1"])
        #expect(creationInfoUnwrapped.created == "2025-01-01T00:00:00Z")

        let sbom = result[1] as? SPDXSBOM
        let sbomUnwrapped = try #require(sbom)
        #expect(sbomUnwrapped.type == .SoftwareSBOM)
        #expect(sbomUnwrapped.creationInfoID == "_:creationInfo")
        #expect(sbomUnwrapped.profileConformance == ["core", "software"])
        #expect(sbomUnwrapped.rootElementIDs == ["urn:spdx:primary-id"])

        let relationship = result[2] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .describes)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == sbomUnwrapped.id)
        #expect(relationshipUnwrapped.childrenID == ["urn:spdx:primary-id"])

        let spdxDocument = result[3] as? SPDXDocument
        let documentUnwrapped = try #require(spdxDocument)
        #expect(documentUnwrapped.id == "urn:spdx:doc-1")
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
            (.file, .file),
        ]

        for (sbomCategory, expectedSPDXPurpose) in categories {
            let component = SBOMComponent(
                category: sbomCategory,
                id: SBOMIdentifier(value: "test-id"),
                purl: "pkg:swift/test@1.0.0",
                name: "TestComponent",
                version: SBOMComponent.Version(revision: "1.0.0"),
                originator: SBOMOriginator(commits: nil),
                description: "Test description",
                scope: .runtime
            )

            let result = try await convertToSPDXPackage(from: component)

            #expect(result.id == "urn:spdx:test-id")
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
            id: SBOMIdentifier(value: "urn:spdx:test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            description: nil,
            scope: .runtime
        )

        let result = try await convertToSPDXPackage(from: component)

        #expect(result.id == "urn:spdx:test-id")
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
            id: SBOMIdentifier(value: "test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
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
            id: SBOMIdentifier(value: "test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
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
            id: SBOMIdentifier(value: "test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )

        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.count == 2)

        let externalIdentifier = result[0] as? SPDXExternalIdentifier
        let externalIdentifierUnwrapped = try #require(externalIdentifier)
        #expect(externalIdentifierUnwrapped.identifier == "urn:spdx:abc123")
        #expect(externalIdentifierUnwrapped.identifierLocator == ["https://github.com/swiftlang/swift-package-manager"])
        #expect(externalIdentifierUnwrapped.type == .ExternalIdentifier)
        #expect(externalIdentifierUnwrapped.category == .gitoid)

        let relationship = result[1] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.id == "urn:spdx:abc123-generates")
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .generates)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == "urn:spdx:abc123")
        #expect(relationshipUnwrapped.childrenID == ["urn:spdx:test-id"])
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
            id: SBOMIdentifier(value: "test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit1, commit2]),
            scope: .runtime
        )

        let result = await convertToSPDXExternalIdentifiers(from: [component])
        #expect(result.count == 4) // 2 ExternalIdentifiers and 2 Relationships

        let externalIdentifiers = result.compactMap { $0 as? SPDXExternalIdentifier }
        let relationships = result.compactMap { $0 as? SPDXRelationship }

        #expect(externalIdentifiers.count == 2)
        #expect(relationships.count == 2)

        let identifiers = externalIdentifiers.map(\.identifier)
        #expect(identifiers.contains("urn:spdx:abc123"))
        #expect(identifiers.contains("urn:spdx:def456"))

        for relationship in relationships {
            #expect(relationship.type == .Relationship)
            #expect(relationship.category == .generates)
            #expect(relationship.creationInfoID == "_:creationInfo")
            #expect(relationship.childrenID == ["urn:spdx:test-id"])
            #expect(["urn:spdx:abc123", "urn:spdx:def456"].contains(relationship.parentID))
        }
    }

    @Test("convertToSPDXExternalIdentifiers with multiple components sharing same commit")
    func convertToSPDXExternalIdentifiersWithMultipleComponentsSharingSameCommit() async throws {
        let commit = SBOMCommit(
            sha: "abc123",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: nil,
            authors: nil,
            message: "Shared commit"
        )
        let component1 = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "test-id-1"),
            purl: "pkg:swift/test1@1.0.0",
            name: "TestComponent1",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )
        let component2 = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "test-id-2"),
            purl: "pkg:swift/test2@1.0.0",
            name: "TestComponent2",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )

        let result = await convertToSPDXExternalIdentifiers(from: [component1, component2])
        #expect(result.count == 2) // 1 ExternalIdentifier and 1 Relationship

        let externalIdentifier = result[0] as? SPDXExternalIdentifier
        let externalIdentifierUnwrapped = try #require(externalIdentifier)
        #expect(externalIdentifierUnwrapped.identifier == "urn:spdx:abc123")
        #expect(externalIdentifierUnwrapped.identifierLocator == ["https://github.com/swiftlang/swift-package-manager"])
        #expect(externalIdentifierUnwrapped.type == .ExternalIdentifier)
        #expect(externalIdentifierUnwrapped.category == .gitoid)

        let relationship = result[1] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .generates)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == "urn:spdx:abc123")

        #expect(relationshipUnwrapped.childrenID.count == 2)
        #expect(relationshipUnwrapped.childrenID.contains("urn:spdx:test-id-1"))
        #expect(relationshipUnwrapped.childrenID.contains("urn:spdx:test-id-2"))
    }

    @Test("convertToSPDXRelationships with nil dependencies")
    func convertToSPDXRelationshipsWithNilDependencies() async throws {
        let result = await convertToSPDXRelationships(from: nil)
        #expect(result.isEmpty)
    }

    @Test("convertToSPDXRelationships with empty dependencies")
    func convertToSPDXRelationshipsWithEmptyDependencies() async throws {
        let result = await convertToSPDXRelationships(from: SBOMDependencies(components: [], relationships: []))
        #expect(result.isEmpty)
    }

    @Test("convertToSPDXRelationships with single dependency")
    func convertToSPDXRelationshipsWithSingleDependency() async throws {
        let dependency = SBOMRelationship(
            id: SBOMIdentifier(value: "dep-1"),
            parentID: SBOMIdentifier(value: "parent-component"),
            childrenID: [SBOMIdentifier(value: "child1"), SBOMIdentifier(value: "child2")]
        )

        let result = await convertToSPDXRelationships(from: SBOMDependencies(
            components: [],
            relationships: [dependency]
        ))
        #expect(result.count == 1)

        let relationship = result[0] as? SPDXRelationship
        let relationshipUnwrapped = try #require(relationship)
        #expect(relationshipUnwrapped.id == "urn:spdx:parent-component-dependsOn")
        #expect(relationshipUnwrapped.type == .Relationship)
        #expect(relationshipUnwrapped.category == .dependsOn)
        #expect(relationshipUnwrapped.creationInfoID == "_:creationInfo")
        #expect(relationshipUnwrapped.parentID == "urn:spdx:parent-component")
        #expect(relationshipUnwrapped.childrenID == ["urn:spdx:child1", "urn:spdx:child2"])
    }

    @Test("convertToSPDXRelationships with multiple dependencies")
    func convertToSPDXRelationshipsWithMultipleDependencies() async throws {
        let dependency1 = SBOMRelationship(
            id: SBOMIdentifier(value: "dep-1"),
            parentID: SBOMIdentifier(value: "parent1"),
            childrenID: [SBOMIdentifier(value: "child1")]
        )
        let dependency2 = SBOMRelationship(
            id: SBOMIdentifier(value: "dep-2"),
            parentID: SBOMIdentifier(value: "parent2"),
            childrenID: [SBOMIdentifier(value: "child2"), SBOMIdentifier(value: "child3")]
        )

        let result = await convertToSPDXRelationships(from: SBOMDependencies(
            components: [],
            relationships: [dependency1, dependency2]
        ))
        #expect(result.count == 2)

        let relationship1 = result[0] as? SPDXRelationship
        let relationship1Unwrapped = try #require(relationship1)
        #expect(relationship1Unwrapped.id == "urn:spdx:parent1-dependsOn")
        #expect(relationship1Unwrapped.parentID == "urn:spdx:parent1")
        #expect(relationship1Unwrapped.childrenID == ["urn:spdx:child1"])
        #expect(relationship1Unwrapped.category == .dependsOn)

        let relationship2 = result[1] as? SPDXRelationship
        let relationship2Unwrapped = try #require(relationship2)
        #expect(relationship2Unwrapped.id == "urn:spdx:parent2-dependsOn")
        #expect(relationship2Unwrapped.parentID == "urn:spdx:parent2")
        #expect(relationship2Unwrapped.childrenID == ["urn:spdx:child2", "urn:spdx:child3"])
        #expect(relationship2Unwrapped.category == .dependsOn)
    }

    @Test("convertToSPDXRelationships with test and optional relationships")
    func convertToSPDXRelationshipsWithTestAndOptionalRelationships() async throws {
        let commit1 = SBOMCommit(
            sha: "abc123",
            repository: "https://github.com/swiftlang/swift-package-manager",
            url: nil,
            authors: nil,
            message: "First commit"
        )
        let parent = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "parent-id"),
            purl: "pkg:swift/test3@1.0.0",
            name: "TestComponent3",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit1]),
            scope: .runtime
        )
        let component = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "test-id"),
            purl: "pkg:swift/test@1.0.0",
            name: "TestComponent",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit1]),
            scope: .test
        )
        let component2 = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "test-id2"),
            purl: "pkg:swift/test2@1.0.0",
            name: "TestComponent2",
            version: SBOMComponent.Version(revision: "2.0.0"),
            originator: SBOMOriginator(commits: [commit1]),
            scope: .optional
        )
        let dependency1 = SBOMRelationship(
            id: SBOMIdentifier(value: "dep1"),
            parentID: SBOMIdentifier(value: "parent-id"),
            childrenID: [SBOMIdentifier(value: "test-id"), SBOMIdentifier(value: "test-id2")]
        )

        let result = await convertToSPDXRelationships(from: SBOMDependencies(
            components: [parent, component, component2],
            relationships: [dependency1]
        ))
        #expect(result.count == 3) // 1 dependsOn, 1 hasOptionalDependency, 1 hasTest

        let relationship2 = result[1] as? SPDXRelationship
        let relationship2Unwrapped = try #require(relationship2)
        #expect(relationship2Unwrapped.id == "urn:spdx:parent-id-hasOptionalDependency")
        #expect(relationship2Unwrapped.parentID == "urn:spdx:parent-id")
        #expect(relationship2Unwrapped.childrenID == ["urn:spdx:test-id2"])
        #expect(relationship2Unwrapped.category == .hasOptionalDependency)

        let relationship1 = result[2] as? SPDXRelationship
        let relationship1Unwrapped = try #require(relationship1)
        #expect(relationship1Unwrapped.id == "urn:spdx:parent-id-hasTest")
        #expect(relationship1Unwrapped.parentID == "urn:spdx:parent-id")
        #expect(relationship1Unwrapped.childrenID == ["urn:spdx:test-id"])
        #expect(relationship1Unwrapped.category == .hasTest)
    }

    @Test("convertToSPDXGraph with non-SPDX spec throws error")
    func convertToSPDXGraphWithNonSPDXSpec() async throws {
        let spec = SBOMSpec(type: .cyclonedx, version: "1.7")
        let metadata = SBOMMetadata(
            spec: spec,
            timestamp: "2025-01-01T00:00:00Z",
            creators: [SBOMTool(id: SBOMIdentifier(value: "tool-1"), name: "SwiftPM", version: "3.0.1")]
        )
        let primaryComponent = SBOMComponent(
            category: .application,
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: [])
        )

        await #expect(throws: Error.self) {
            try await convertToSPDXGraph(from: document)
        }
    }

    @Test("convertToSPDXGraph with minimal SPDX document")
    func convertToSPDXGraphWithMinimalSPDXDocument() async throws {
        let creator = SBOMTool(
            id: SBOMIdentifier(value: "tool-1"),
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [], relationships: [])
        )

        let result = try await convertToSPDXGraph(from: document)

        #expect(result.context == SPDXConstants.spdx3Context)
        #expect(result.graph
            .count ==
            6) // 1 agent CreationInfo + 1 agent + 4 document elements + 0 packages + 0 relationships + 0 commits
    }

    @Test("convertToSPDXGraph with components and dependencies")
    func convertToSPDXGraphWithComponentsAndDependencies() async throws {
        let creator = SBOMTool(
            id: SBOMIdentifier(value: "tool-1"),
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let component1 = SBOMComponent(
            category: .library,
            id: SBOMIdentifier(value: "lib1-id"),
            purl: "pkg:swift/lib1@1.0.0",
            name: "Library1",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: nil),
            scope: .runtime
        )
        let dependency = SBOMRelationship(
            id: SBOMIdentifier(value: "dep-1"),
            parentID: SBOMIdentifier(value: "primary-id"),
            childrenID: [SBOMIdentifier(value: "lib1-id")]
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [component1], relationships: [dependency])
        )

        let result = try await convertToSPDXGraph(from: document)

        #expect(result.context == SPDXConstants.spdx3Context)
        #expect(result.graph
            .count ==
            8) // 1 agent CreationInfo + 1 agent + 4 document elements + 1 package + 1 relationship + 0 commits

        let agents = result.graph.compactMap { $0.getValue() as SPDXAgent? }
        #expect(agents.count == 1)

        let creationInfos = result.graph.compactMap { $0.getValue() as SPDXCreationInfo? }
        #expect(creationInfos.count == 2) // 1 from agent + 1 from document

        let packages = result.graph.compactMap { $0.getValue() as SPDXPackage? }
        #expect(packages.count == 1)
        #expect(packages[0].id == "urn:spdx:lib1-id")

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
            id: SBOMIdentifier(value: "tool-1"),
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
            id: SBOMIdentifier(value: "primary-id"),
            purl: "pkg:swift/primary@1.0.0",
            name: "PrimaryApp",
            version: SBOMComponent.Version(revision: "1.0.0"),
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
            id: SBOMIdentifier(value: "lib1-id"),
            purl: "pkg:swift/lib1@1.0.0",
            name: "Library1",
            version: SBOMComponent.Version(revision: "1.0.0"),
            originator: SBOMOriginator(commits: [commit]),
            scope: .runtime
        )
        let document = SBOMDocument(
            id: SBOMIdentifier(value: "doc-1"),
            metadata: metadata,
            primaryComponent: primaryComponent,
            dependencies: SBOMDependencies(components: [component1], relationships: nil)
        )

        let result = try await convertToSPDXGraph(from: document)

        #expect(result.context == SPDXConstants.spdx3Context)

        let externalIdentifiers = result.graph.compactMap { $0.getValue() as SPDXExternalIdentifier? }
        #expect(externalIdentifiers.count == 1)
        #expect(externalIdentifiers[0].identifier == "urn:spdx:abc123")

        let relationships = result.graph.compactMap { $0.getValue() as SPDXRelationship? }
        let generatesRelationships = relationships.filter { $0.category == .generates }
        #expect(generatesRelationships.count == 1)
        #expect(generatesRelationships[0].parentID == "urn:spdx:abc123")
        #expect(generatesRelationships[0].childrenID == ["urn:spdx:lib1-id"])
    }
}
