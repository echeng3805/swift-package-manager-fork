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
import struct TSCBasic.StringError

private func generateSPDXID() -> String {
    return "urn:uuid:\(generateSBOMID())"
}

private func convertToSPDXPurpose(from category: SBOMComponent.Category) async -> SPDXPackage.Purpose {
    switch category {
    case .application:
        return .application
    case .framework:
        return .framework
    case .library:
        return .library
    case .file:
        return .file
    }
}

package func convertToSPDXAgent(from metadata: SBOMMetadata?) async -> [Any] {
    guard let metadata = metadata,
          let creators = metadata.creators,
          !creators.isEmpty else {
        return []
    }
    var agents: [Any] = []
    for creator in creators {
        let toolCreationInfoID = "\(creator.id):creationInfo"
        let toolCreationInfo = SPDXCreationInfo(
            id: toolCreationInfoID,
            type: .CreationInfo,
            specVersion: creator.version,
            createdBy: [creator.id],
            created: "1970-01-01T00:00:00Z",
        )
        let tool = SPDXAgent(
            id: creator.id,
            type: .Agent,
            name: creator.name,
            creationInfoID: toolCreationInfoID,
        )
        agents.append(toolCreationInfo)
        agents.append(tool)
    }
    return agents
}

package func convertToSPDXDocument(from document: SBOMDocument) async throws -> [Any] {
    guard let timestamp = document.metadata.timestamp,
        let creators = document.metadata.creators,
        !creators.isEmpty else {
            throw StringError("timestamp or creators are missing from SBOM document metadata, required for SPDX format")
        }

    var elements: [Any] = []

    let creationInfoID = SPDXConstants.spdxRootCreationInfoID
    
    let creationInfo = SPDXCreationInfo(
        id: creationInfoID,
        type: .CreationInfo,
        specVersion: document.metadata.spec.version,
        createdBy: creators.map { $0.id },
        created: timestamp,
    )
    elements.append(creationInfo)

    let spdxSBOMID = generateSPDXID()
    let profileConformance = ["core", "software"]
    
    let spdxSBOM = SPDXSBOM(
        id: spdxSBOMID,
        type: .SoftwareSBOM,
        creationInfoID: creationInfoID,
        profileConformance: profileConformance,
        rootElementIDs: [document.primaryComponent.id],        
    )
    elements.append(spdxSBOM)
    
    let describes = SPDXRelationship(
        id: "\(spdxSBOMID)-describes-\(document.primaryComponent.id)",
        type: .Relationship,
        category: .describes,
        creationInfoID: creationInfoID,
        parentID: spdxSBOMID,
        childrenID: [document.primaryComponent.id],  
    )
    elements.append(describes)

    let spdxDocument = SPDXDocument(
        id: document.id,
        type: .SpdxDocument,
        creationInfoID: creationInfoID,
        profileConformance: profileConformance,
        rootElementIDs: [spdxSBOMID],
    )
    elements.append(spdxDocument)

    return elements
}

package func convertToSPDXPackage(from component: SBOMComponent) async throws -> SPDXPackage {
    return SPDXPackage(
        id: component.id,
        type: .SoftwarePackage,
        purpose: await convertToSPDXPurpose(from: component.category),
        purl: component.purl,
        name: component.name,
        version: component.version.revision,
        creationInfoID: SPDXConstants.spdxRootCreationInfoID,
        description: component.description,
    )
}

package func convertToSPDXExternalIdentifiers(from components: [SBOMComponent]?) async -> [Any] {
    guard let comps = components, !comps.isEmpty else {
        return []
    }

    var externalIdentifiers: [Any] = []
    var commitToComponents: [String: (repository: String, componentIDs: [String])] = [:]
    for component in comps {
        if let commits = component.originator.commits {
            for commit in commits {
                if commitToComponents[commit.sha] != nil {
                    commitToComponents[commit.sha]?.componentIDs.append(component.id)
                } else {
                    commitToComponents[commit.sha] = (repository: commit.repository, componentIDs: [component.id])
                }
            }
        }
    }
    for (commitSHA, commitInfo) in commitToComponents {
        let externalIdentifier = SPDXExternalIdentifier(
            identifier: commitSHA,
            identifierLocator: [commitInfo.repository],
            type: .ExternalIdentifier,
            category: .gitoid
        )
        externalIdentifiers.append(externalIdentifier)
        let relationship = SPDXRelationship(
            id: "\(commitSHA)-generates",
            type: .Relationship,
            category: .generates,
            creationInfoID: SPDXConstants.spdxRootCreationInfoID,
            parentID: commitSHA,
            childrenID: commitInfo.componentIDs
        )
        externalIdentifiers.append(relationship)
    }
    
    return externalIdentifiers
}

package func convertToSPDXRelationships(from dependencies: SBOMDependencies?) async -> [Any] {
    guard let dependencies = dependencies else {
        return []
    }

    var relationships: [Any] = []
    if let sbomRelationships = dependencies.relationships {
        for dependency in sbomRelationships {
            let relationship = SPDXRelationship(
                id: "\(dependency.parentID)-dependsOn",
                type: .Relationship,
                category: .dependsOn,
                creationInfoID: SPDXConstants.spdxRootCreationInfoID,
                parentID: dependency.parentID,
                childrenID: dependency.childrenID,  
            )
            relationships.append(relationship)
            
            var optionalDependencies: [String] = []
            var testDependencies: [String] = []
            for childID in dependency.childrenID {
                guard let comp = dependencies.components.first(where: { $0.id == childID }) else {
                    continue
                }
                switch comp.scope {
                case .optional:
                    optionalDependencies.append(childID)
                case .test:
                    testDependencies.append(childID)
                default:
                    break
                }
            }
            if !optionalDependencies.isEmpty {
                let relationship = SPDXRelationship(
                    id: "\(dependency.parentID)-hasOptionalDependency",
                    type: .Relationship,
                    category: .hasOptionalDependency,
                    creationInfoID: SPDXConstants.spdxRootCreationInfoID,
                    parentID: dependency.parentID,
                    childrenID: optionalDependencies,
                )
                relationships.append(relationship)
            }
            if !testDependencies.isEmpty {
                let relationship = SPDXRelationship(
                    id: "\(dependency.parentID)-hasTest",
                    type: .Relationship,
                    category: .hasTest,
                    creationInfoID: SPDXConstants.spdxRootCreationInfoID,
                    parentID: dependency.parentID,
                    childrenID: testDependencies,
                )
                relationships.append(relationship)
            }
        }
    }

    return relationships
}

package func convertToSPDXGraph(from document: SBOMDocument) async throws -> SPDXGraph {
    guard document.metadata.spec.type == .spdx || document.metadata.spec.type == .spdx3 else {
        throw StringError("internal SBOMDocument spec type is not spdx, cannot convert to spdx")
    }

    let agents = await convertToSPDXAgent(from: document.metadata)
    let elements = try await convertToSPDXDocument(from: document)

    var packages: [Any] = []
    for comp in document.dependencies.components {
        let p = try await convertToSPDXPackage(from: comp)
        packages.append(p)
    }

    let relationships = await convertToSPDXRelationships(from: document.dependencies)
    let commits = await convertToSPDXExternalIdentifiers(from: document.dependencies.components)

    return SPDXGraph(
        context: SPDXConstants.spdx3Context,
        graph: agents + elements + packages + relationships + commits
    )
}

    