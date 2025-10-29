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
import PackageGraph
import PackageModel
import TSCUtility

package struct PURL: Codable, Equatable, CustomStringConvertible {
    package let scheme: String
    package let type: String
    package let namespace: String?
    package let name: String
    package let version: String?
    package let qualifiers: [String: String]?
    package let subpath: String?

    package init(
        scheme: String,
        type: String,
        namespace: String? = nil,
        name: String,
        version: String? = nil,
        qualifiers: [String: String]? = nil,
        subpath: String? = nil,

    ) {
        self.scheme = scheme
        self.type = type
        self.namespace = namespace
        self.name = name
        self.version = version
        self.qualifiers = qualifiers
        self.subpath = subpath
    }
    
    package var description: String {
        var result = "\(scheme):\(type)"
        
        if let namespace = namespace {
            result += "/\(namespace)"
        }
        
        result += "/\(name)"
        
        if let version = version, version != "unknown" {
            result += "@\(version)"
        }
        
        if let qualifiers = qualifiers, !qualifiers.isEmpty {
            let qualifierPairs = qualifiers.map { "\($0.key)=\($0.value)" }.sorted()
            result += "?" + qualifierPairs.joined(separator: "&")
        }
        
        if let subpath = subpath {
            result += "#\(subpath)"
        }
        
        return result
    }
}

extension PURL {
    package static func from(package: ResolvedPackage, version: SBOMComponent.Version) async -> PURL {
        return PURL(
            scheme: "pkg",
            type: "swift",
            namespace: await extractPackageNamespace(from: version.commit),
            name: await extractComponentID(from: package),
            version: version.revision,
        )
    }

    package static func from(product: ResolvedProduct, version: SBOMComponent.Version) async -> PURL {
        // use the full package path as the namespace (e.g., "github.com/swiftlang/swift-package-manager")
        // and the package identity + product name as the name (e.g., "SwiftPM:SwiftPMDataModel")
        return PURL(
            scheme: "pkg",
            type: "swift",
            namespace: await extractProductNamespace(from: version.commit) ?? product.packageIdentity.description,
            name: await extractComponentID(from: product),
            version: version.revision,
        )
    }

    package static func extractPackageNamespace(from commit: SBOMCommit?) async -> String? {
        // TODO: ev_cheng Rewrite this function, it's an AI stopgap to unblock the rest of the code
        // TODO ev_cheng deal with local paths
        guard let packageLocation = commit?.repository else {
            return nil
        }

        // Handle SSH URLs (git@host:org/repo.git or git@host:org/repo)
        // Use regex to match SSH URL pattern: user@host:org/repo with optional path suffix
        // Handles both git@host:org/repo.git and git@host:org/repo (bare repository names)
        let sshPattern = #"^[^@]+@([^:]+):([^/]+)(?:/.*)?$"#
        if let regex = try? NSRegularExpression(pattern: sshPattern, options: []),
           let match = regex.firstMatch(in: packageLocation, options: [], range: NSRange(location: 0, length: packageLocation.count)),
           match.numberOfRanges == 3 {
            
            let hostRange = Range(match.range(at: 1), in: packageLocation)
            let orgRange = Range(match.range(at: 2), in: packageLocation)
            
            if let hostRange = hostRange, let orgRange = orgRange {
                let host = String(packageLocation[hostRange])
                let org = String(packageLocation[orgRange])
                return "\(host)/\(org)"
            }
        }
        
        // Handle HTTP/HTTPS URLs
        if let url = URL(string: packageLocation), let host = url.host {
            let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if pathComponents.count >= 2 {
                let org = pathComponents[0] // apple
                return "\(host)/\(org)"
            }
        }
        
        // Handle registry identities (scope.package-name format)
        // Exclude email addresses and other @ containing strings
        if packageLocation.contains(".") && !packageLocation.hasPrefix("/") && !packageLocation.contains("://") && !packageLocation.contains("@") {
            let components = packageLocation.components(separatedBy: ".")
            if components.count >= 2 {
                // Return everything except the last component (which is the package name)
                // For "com.example.package" -> "com.example"
                // For "org.foo" -> "org"
                return components.dropLast().joined(separator: ".")
            }
        }
        
        // Handle local file system paths - extract parent directory name
        if packageLocation.hasPrefix("/") {
            let pathComponents = packageLocation.components(separatedBy: "/").filter { !$0.isEmpty }
            if pathComponents.count >= 2 {
                // Return the parent directory name for local paths
                return pathComponents[pathComponents.count - 2]
            }
        }
        
        return nil
    }
    
    package static func extractProductNamespace(from commit: SBOMCommit?) async -> String? {
        // For products, extract the full repository path including the repo name
        // e.g., "https://github.com/swiftlang/swift-package-manager.git" -> "github.com/swiftlang/swift-package-manager"
        guard let packageLocation = commit?.repository else {
            return nil
        }

        // Handle SSH URLs (git@host:org/repo.git or git@host:org/repo)
        let sshPattern = #"^[^@]+@([^:]+):(.+?)(?:\.git)?$"#
        if let regex = try? NSRegularExpression(pattern: sshPattern, options: []),
           let match = regex.firstMatch(in: packageLocation, options: [], range: NSRange(location: 0, length: packageLocation.count)),
           match.numberOfRanges == 3 {
            
            let hostRange = Range(match.range(at: 1), in: packageLocation)
            let pathRange = Range(match.range(at: 2), in: packageLocation)
            
            if let hostRange = hostRange, let pathRange = pathRange {
                let host = String(packageLocation[hostRange])
                let path = String(packageLocation[pathRange])
                return "\(host)/\(path)"
            }
        }
        
        // Handle HTTP/HTTPS URLs
        if let url = URL(string: packageLocation), let host = url.host {
            var pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            // Remove .git extension if present
            if let last = pathComponents.last, last.hasSuffix(".git") {
                pathComponents[pathComponents.count - 1] = String(last.dropLast(4))
            }
            if pathComponents.count >= 2 {
                // Return host + full path (org/repo)
                return "\(host)/\(pathComponents.joined(separator: "/"))"
            }
        }
        
        return await extractPackageNamespace(from: commit)
    }
}
