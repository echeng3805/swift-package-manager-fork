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

private func convertToCDXScope(from scope: SBOMComponent.Scope) async -> CDXComponent.Scope {
    switch scope {
    case .runtime:
        return .required
    case .optional:
        return .optional
    case .test:
        return .excluded
    }
}

private func convertToCDXCategory(from category: SBOMComponent.Category) async -> CDXComponent.Category {
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

package func convertToCDXSchema(from spec: SBOMSpec) async throws -> String {
    switch spec.type {
        case .cyclonedx, .cyclonedx1:
            return CDXConstants.cyclonedx1Schema
        case .spdx, .spdx3: 
            throw StringError("expected cyclonedx spec")
    }
}

package func convertToCDXPedigree(from originator: SBOMOriginator) async throws -> CDXPedigree {
    guard let sbomCommits = originator.commits else {
        return CDXPedigree(commits: nil)
    }
    
    let cdxCommits = sbomCommits.map { sbomCommit in
        let cdxAuthor: CDXAction? = sbomCommit.authors?.first.map { sbomPerson in
            CDXAction(
                timestamp: sbomPerson.timestamp,
                name: sbomPerson.name,
                email: sbomPerson.email
            )
        }
        
        return CDXCommit(
            uid: sbomCommit.sha,
            url: sbomCommit.repository,
            author: cdxAuthor,
            message: sbomCommit.message
        )
    }
    
    return CDXPedigree(commits: cdxCommits)
}

package func convertToCDXComponent(from comp: SBOMComponent) async throws -> CDXComponent {
    // TODO ev_cheng, handle nested components?
    return CDXComponent(
        type: await convertToCDXCategory(from: comp.category),
        bomRef: comp.id,
        name: comp.name,
        version: comp.version.revision,
        scope: await convertToCDXScope(from: comp.scope ?? .runtime),
        purl: comp.purl,
        pedigree: try await convertToCDXPedigree(from: comp.originator),
    )
}

private func convertToCDXComponent(from tool: SBOMTool) async throws -> CDXComponent {
    return CDXComponent(
        type: .application,
        bomRef: tool.id,
        name: tool.name,
        version: tool.version,
        scope: .excluded,
        purl: "pkg:swift/github.com/swiftlang/\(tool.name)@\(tool.version)",
        pedigree: nil
    )
}

package func convertToCDXDependency(from dep: SBOMRelationship) async throws -> CDXDependency {
    return CDXDependency(
        ref: dep.parentID,
        dependsOn: dep.childrenID,
    )
}

package func convertToCDXMetadata(from document: SBOMDocument) async throws -> CDXMetadata {
    var tools: CDXTools? = nil
    if let creators = document.metadata.creators, !creators.isEmpty {
        var toolsComponents: [CDXComponent] = []
        for creator in creators {
            let cdxTool = try await convertToCDXComponent(from: creator)
            toolsComponents.append(cdxTool)
        }
        tools = CDXTools(components: toolsComponents)
    }
    
    return CDXMetadata(
        timestamp: document.metadata.timestamp,
        component: try await convertToCDXComponent(from: document.primaryComponent),
        tools: tools
    )
}

package func convertToCDXDocument(from document: SBOMDocument) async throws -> CDXDocument {
    guard document.metadata.spec.type == .cyclonedx || document.metadata.spec.type == .cyclonedx1 else {
        throw StringError("internal SBOMDocument spec type is not cyclonedx, cannot convert to cyclonedx")
    }

    // TODO ev_cheng -> handle spec versions

    var components: [CDXComponent] = []
    for sbomComp in document.dependencies.components {
        let cdxComp = try await convertToCDXComponent(from: sbomComp)
        components.append(cdxComp)
    }

    var dependencies: [CDXDependency] = []
    if let documentDependencies = document.dependencies.relationships {
        for sbomDep in documentDependencies {
            let cdxDep = try await convertToCDXDependency(from: sbomDep)
            dependencies.append(cdxDep)
        }
    }

    return CDXDocument(
        schema: try await convertToCDXSchema(from: document.metadata.spec),
        bomFormat: "CycloneDX",
        specVersion: document.metadata.spec.version,
        serialNumber: document.id,
        version: 1,
        metadata: try await convertToCDXMetadata(from: document),
        components: components,
        dependencies: dependencies,
    )
}
