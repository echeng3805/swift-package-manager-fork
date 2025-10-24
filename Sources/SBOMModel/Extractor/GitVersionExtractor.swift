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
import Basics
import PackageModel

package struct GitVersionInfo {
    package let version: String
    package let commit: SBOMCommit?
    
    package init(version: String, commit: SBOMCommit?) {
        self.version = version
        self.commit = commit
    }
}

package func extractGitVersionInfo(from packagePath: Basics.AbsolutePath) async throws -> GitVersionInfo? {
    let fileSystem = Basics.localFileSystem
    
    // Check if this is a git repository
    let gitDir = packagePath.appending(".git")
    guard fileSystem.exists(gitDir) else {
        return nil
    }
    
    // Try to get the current commit SHA
    let commitSHA = try await executeGitCommand(["rev-parse", "HEAD"], in: packagePath)
    
    // Try to get the current tag (version)
    let version = try await getGitVersion(in: packagePath)
    
    // Try to get the remote URL
    let remoteURL = try await executeGitCommand(["config", "--get", "remote.origin.url"], in: packagePath)
    
    let commit = SBOMCommit(
        sha: commitSHA,
        repository: remoteURL
    )
    
    return GitVersionInfo(version: version, commit: commit)
}

private func getGitVersion(in packagePath: Basics.AbsolutePath) async throws -> String {
    // Try to get the current tag
    if let tag = try? await executeGitCommand(["describe", "--tags", "--exact-match", "HEAD"], in: packagePath) {
        return tag
    }
    
    // Try to get the latest tag with commit count
    if let describe = try? await executeGitCommand(["describe", "--tags", "--always"], in: packagePath) {
        return describe
    }
    
    // Fall back to commit SHA
    return try await executeGitCommand(["rev-parse", "HEAD"], in: packagePath)
}

private func executeGitCommand(_ args: [String], in workingDirectory: Basics.AbsolutePath) async throws -> String {
    let process = AsyncProcess(
        arguments: ["git"] + args,
        workingDirectory: workingDirectory,
        outputRedirection: .collect
    )
    
    let stdin = try process.launch()
    try stdin.close()
    let result = try await process.waitUntilExit()
    
    guard result.exitStatus == .terminated(code: 0) else {
        let errorOutput = try result.stderrOutput.get()
        throw StringError("Git command failed: \(errorOutput)")
    }
    
    let output = try result.utf8Output().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    return output
}