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

import Basics
import Foundation
import PackageCollections
import PackageGraph
import PackageModel
import SourceControl
import TSCUtility

package struct SBOMGitInfo {
    package let version: SBOMComponent.Version
    package let originator: SBOMOriginator
    
    package init(version: SBOMComponent.Version, originator: SBOMOriginator) {
        self.version = version
        self.originator = originator
    }
}

/// Cache for storing root package Git info (to minimize calls to Git)
package actor SBOMGitCache {
    private var cache: [PackageIdentity: SBOMGitInfo] = [:]
    package func get(_ identity: PackageIdentity) -> SBOMGitInfo? {
        self.cache[identity]
    }

    package func set(_ identity: PackageIdentity, gitInfo: SBOMGitInfo) {
        self.cache[identity] = gitInfo
    }
}

/// Cache for storing extracted components (to avoid redundant extraction)
package actor SBOMComponentCache {
    private var packageCache: [PackageIdentity: SBOMComponent] = [:]
    private var productCache: [String: SBOMComponent] = [:] // key: "packageIdentity:productName"
    
    package func getPackage(_ identity: PackageIdentity) -> SBOMComponent? {
        self.packageCache[identity]
    }
    
    package func setPackage(_ identity: PackageIdentity, component: SBOMComponent) {
        self.packageCache[identity] = component
    }
    
    package func getProduct(_ packageIdentity: PackageIdentity, productName: String) -> SBOMComponent? {
        let key = "\(packageIdentity):\(productName)"
        return self.productCache[key]
    }
    
    package func setProduct(_ packageIdentity: PackageIdentity, productName: String, component: SBOMComponent) {
        let key = "\(packageIdentity):\(productName)"
        self.productCache[key] = component
    }
}

/// Cache for storing module-to-target-name mappings from the build graph
package actor SBOMTargetNameCache {
    private var cache: [ResolvedModule.ID: String] = [:]
    
    package func get(_ moduleID: ResolvedModule.ID) -> String? {
        self.cache[moduleID]
    }
    
    package func set(_ moduleID: ResolvedModule.ID, targetName: String) {
        self.cache[moduleID] = targetName
    }
}

/// Consolidated container for all SBOM extraction caches
package struct SBOMCaches {
    package let git: SBOMGitCache
    package let component: SBOMComponentCache
    package let targetName: SBOMTargetNameCache
    
    package init() {
        self.git = SBOMGitCache()
        self.component = SBOMComponentCache()
        self.targetName = SBOMTargetNameCache()
    }
    
    package init(
        git: SBOMGitCache,
        component: SBOMComponentCache,
        targetName: SBOMTargetNameCache
    ) {
        self.git = git
        self.component = component
        self.targetName = targetName
    }
}