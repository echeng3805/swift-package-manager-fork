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

private func generateSPDXID() ->
 String {
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
            created: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 0)), // cannot be nil
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

    let creationInfoID = "_:creationInfo"
    let creationInfo = SPDXCreationInfo(
        id: creationInfoID,
        type: .CreationInfo,
        specVersion: document.metadata.spec.version,
        createdBy: creators.map{ $0.id },
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
        version: component.version,
        creationInfoID: "_:creationInfo",
        description: component.description,
    )
}

package func convertToSPDXExternalIdentifiers(from components: [SBOMComponent]?) async -> [Any] {
    guard let comps = components, !comps.isEmpty else {
        return []
    }

    var externalIdentifiers: [Any] = []
    for component in comps {
        if let commits = component.originator.commits {
            for commit in commits {
            let externalIdentifier = SPDXExternalIdentifier(
                identifier: commit.sha,
                identifierLocator: commit.repository,
                type: .ExternalIdentifier,
                category: .gitoid
            )
            externalIdentifiers.append(externalIdentifier)
            let relationship = SPDXRelationship(
                id: "\(component.id)-wasGeneratedFrom-\(commit.sha)",
                type: .Relationship,
                category: .wasGeneratedFrom,
                creationInfoID: "_:creationInfo",
                parentID: component.id,
                childrenID: [commit.sha],  
            )
            externalIdentifiers.append(relationship)
            }
        }
    }
    
    return externalIdentifiers
}

package func convertToSPDXRelationships(from dependencies: [SBOMDependency]?) async -> [Any] {
    guard let deps = dependencies, !deps.isEmpty else {
        return []
    }

    var relationships: [Any] = []
    for dependency in deps {
        let relationship = SPDXRelationship(
            id: "\(dependency.parentID)-dependsOn",
            type: .Relationship,
            category: .dependsOn,
            creationInfoID: "_:creationInfo",
            parentID: dependency.parentID,
            childrenID: dependency.childrenID,  
        )
        relationships.append(relationship)
    }
    // TODO ev_cheng handle optionalDependency and hasTest relationships
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

    let relationships = await convertToSPDXRelationships(from: document.dependencies.dependencies)
    let commits = await convertToSPDXExternalIdentifiers(from: document.dependencies.components)

    return SPDXGraph(
        context: SPDXConstants.spdx3Context,
        graph: agents + elements + packages + relationships + commits
    )
}

    