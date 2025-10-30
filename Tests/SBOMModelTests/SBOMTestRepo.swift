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
import Basics
import SourceControl
import _InternalTestSupport
import class TSCBasic.Process

struct SBOMTestRepo {
    
    static func setupSPMTestRepo() throws -> (GitRepository, AbsolutePath) {
        let uniqueID = UUID().uuidString
        let path = AbsolutePath("/tmp/SwiftPM-mock-\(uniqueID)")
        
        try localFileSystem.createDirectory(path, recursive: true)
        initGitRepo(path, addFile: true)

        try Process.checkNonZeroExit(args: "git", "-C", path.pathString, "remote", "add", "origin", SBOMTestStore.swiftPMURL)
        
        return (GitRepository(path: path), path)
    }
    
    static func setupSwiftlyTestRepo() throws -> (GitRepository, AbsolutePath) {
        let uniqueID = UUID().uuidString
        let path = AbsolutePath("/tmp/swiftly-mock-\(uniqueID)")
        
        try localFileSystem.createDirectory(path, recursive: true)
        initGitRepo(path, tag: "v1.0.0", addFile: true)
        
        try Process.checkNonZeroExit(args: "git", "-C", path.pathString, "remote", "add", "origin", SBOMTestStore.swiftlyURL)
        
        return (GitRepository(path: path), path)
    }
    
    /// Clean up a test repository directory
    static func cleanup(_ path: AbsolutePath) throws {
        if localFileSystem.exists(path) {
            try localFileSystem.removeFileTree(path)
        }
    }
}