//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import Basics
@testable import Commands
@testable import CoreCommands
import PackageGraph
import PackageLoading
import PackageModel
import enum PackageModel.BuildConfiguration
import SPMBuildCore
import _InternalTestSupport
import TSCTestSupport
import Workspace
import Testing

struct BuildResult {
    let binPath: AbsolutePath
    let stdout: String
    let stderr: String
    let binContents: [String]
    let moduleContents: [String]
}

@discardableResult
fileprivate func execute(
    _ args: [String] = [],
    environment: Environment? = nil,
    packagePath: AbsolutePath? = nil,
    configuration: BuildConfiguration,
    buildSystem: BuildSystemProvider.Kind,
    throwIfCommandFails: Bool = true,
) async throws -> (stdout: String, stderr: String) {

    return try await executeSwiftBuild(
        packagePath,
        configuration: configuration,
        extraArgs: args,
        env: environment,
        buildSystem: buildSystem,
        throwIfCommandFails: throwIfCommandFails,
    )
}

fileprivate func build(
    _ args: [String],
    packagePath: AbsolutePath? = nil,
    configuration: BuildConfiguration,
    cleanAfterward: Bool = true,
    buildSystem: BuildSystemProvider.Kind,
) async throws -> BuildResult {
    do {
        let (stdout, stderr) = try await execute(args, packagePath: packagePath,configuration: configuration, buildSystem: buildSystem,)
        defer {
        }
        let (binPathOutput, _) = try await execute(
            ["--show-bin-path"],
            packagePath: packagePath,
            configuration: configuration,
            buildSystem: buildSystem,
        )
        let binPath = try AbsolutePath(validating: binPathOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        let binContents = try localFileSystem.getDirectoryContents(binPath).filter {
            guard let contents = try? localFileSystem.getDirectoryContents(binPath.appending(component: $0)) else {
                return true
            }
            // Filter directories which only contain an output file map since we didn't build anything for those which
            // is what `binContents` is meant to represent.
            return contents != ["output-file-map.json"]
        }
        var moduleContents: [String] = []
        if buildSystem == .native {
            moduleContents = (try? localFileSystem.getDirectoryContents(binPath.appending(component: "Modules"))) ?? []
        } else {
            let moduleDirs = (try? localFileSystem.getDirectoryContents(binPath).filter {
                $0.hasSuffix(".swiftmodule")
            }) ?? []
            for dir: String in moduleDirs {
                moduleContents +=
                    (try? localFileSystem.getDirectoryContents(binPath.appending(component: dir)).map { "\(dir)/\($0)" }) ?? []
            }
        }


        if cleanAfterward {
            try await executeSwiftPackage(
                packagePath,
                extraArgs: ["clean"],
                buildSystem: buildSystem
            )
        }
        return BuildResult(
            binPath: binPath,
            stdout: stdout,
            stderr: stderr,
            binContents: binContents,
            moduleContents: moduleContents
        )
    } catch {
        if cleanAfterward {
            try await executeSwiftPackage(
                packagePath,
                extraArgs: ["clean"],
                buildSystem: buildSystem
            )
        }
        throw error
    }
}

@Suite(
    .serializedIfOnWindows,
    .tags(
        Tag.TestSize.large,
        Tag.Feature.Command.Build,
    ),
)
struct BuildCommandTestCases {


    @Test(
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func usage(
        data: BuildData,
    ) async throws {
        let stdout = try await execute(["-help"], configuration: data.config, buildSystem: data.buildSystem).stdout
        #expect(stdout.contains("USAGE: swift build"))
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.ShowBinPath,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func binSymlink(
        buildData: BuildData,
    ) async throws {
        let buildSystem = buildData.buildSystem
        let configuration = buildData.config
        // Test is not implemented for Xcode build system
        try await fixture(name: "ValidLayouts/SingleModule/ExecutableNew") { fixturePath in
            let fullPath = try resolveSymlinks(fixturePath)

            let targetPath = try fullPath.appending(components: buildSystem.binPath(for: configuration))
            let path = try await execute(
                ["--show-bin-path"],
                packagePath: fullPath,
                configuration: configuration,
                buildSystem: buildSystem,
            ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(
                AbsolutePath(path).pathString == targetPath.pathString
            )
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Help,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func seeAlso(
        data: BuildData,
    ) async throws {
        let stdout = try await execute(
            ["--help"],
            configuration: data.config,
            buildSystem: data.buildSystem,
        ).stdout
        #expect(stdout.contains("SEE ALSO: swift run, swift package, swift test"))
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Help,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func commandDoesNotEmitDuplicateSymbols(
        data: BuildData,
    ) async throws {
        let duplicateSymbolRegex = try #require(duplicateSymbolRegex)
        let (stdout, stderr) = try await execute(
            ["--help"],
            configuration: data.config,
            buildSystem: data.buildSystem,
        )
        #expect(!stdout.contains(duplicateSymbolRegex))
        #expect(!stderr.contains(duplicateSymbolRegex))
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Version,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func version(
        data: BuildData,
    ) async throws {
        let stdout = try await execute(
            ["--version"],
            configuration: data.config,
            buildSystem: data.buildSystem,
        ).stdout
        let expectedRegex = try Regex(#"Swift Package Manager -( \w+ )?\d+.\d+.\d+(-\w+)?"#)
        #expect(stdout.contains(expectedRegex))
    }


    @Test(
        .tags(
            .Feature.CommandLineArguments.ExplicitTargetDependencyImportCheck,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func importOfMissedDepWarning(
        buildData: BuildData,
    ) async throws {
        let buildSystem = buildData.buildSystem
        let configuration = buildData.config
        try await withKnownIssue("SWBINTTODO: Test fails because the warning message regarding missing imports is expected to be more verbose and actionable at the SwiftPM level with mention of the involved targets. This needs to be investigated. See case targetDiagnostic(TargetDiagnosticInfo) as a message type that may help.") {
            try await fixture(name: "Miscellaneous/ImportOfMissingDependency") { path in
                let fullPath = try resolveSymlinks(path)
                let error = await #expect(throws: SwiftPMError.self ) {
                    try await build(
                        ["--explicit-target-dependency-import-check=warn"],
                        packagePath: fullPath,
                        configuration: configuration,
                        buildSystem: buildSystem,
                    )
                }
                guard case SwiftPMError.executionFailure(_, let stdout, let stderr) = try #require(error) else {
                    Issue.record("Incorrect error was raised.")
                    return
                }

                #expect(
                    stderr.contains("warning: Target A imports another target (B) in the package without declaring it a dependency."),
                    "got stdout: \(stdout), stderr: \(stderr)",
                )
            }
        } when: {
            [.swiftbuild, .xcode].contains(buildSystem)
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.ExplicitTargetDependencyImportCheck,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func importOfMissedDepWarningVerifyingErrorFlow(
        data: BuildData
    ) async throws {
        let buildSystem = data.buildSystem
        let config = data.config
        try await withKnownIssue("SWBINTTODO: Test fails because the warning message regarding missing imports is expected to be more verbose and actionable at the SwiftPM level with mention of the involved targets. This needs to be investigated. See case targetDiagnostic(TargetDiagnosticInfo) as a message type that may help.") {
            try await fixture(name: "Miscellaneous/ImportOfMissingDependency") { path in
                let fullPath = try resolveSymlinks(path)
                let error = await #expect(throws: SwiftPMError.self ) {
                    try await build(
                        ["--explicit-target-dependency-import-check=error"],
                        packagePath: fullPath,
                        configuration: config,
                        buildSystem: buildSystem,
                    )
                }
                guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                    Issue.record("Expected error did not occur")
                    return
                }

                #expect(
                    stderr.contains("error: Target A imports another target (B) in the package without declaring it a dependency."),
                    "got stdout: \(String(describing: stdout)), stderr: \(String(describing: stderr))",
                )
            }
        } when: {
            [.swiftbuild, .xcode].contains(buildSystem)
        }
    }

    @Test(
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func importOfMissedDepWarningVerifyingDefaultDoesNotRunTheCheck(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/ImportOfMissingDependency") { path in
            let fullPath = try resolveSymlinks(path)
            let error = await #expect(throws: SwiftPMError.self ) {
                try await build(
                    [],
                    packagePath: fullPath,
                    configuration: data.config,
                    buildSystem: data.buildSystem,
                )
            }
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Expected error did not occur")
                return
            }
            #expect(
                !stderr.contains("warning: Target A imports another target (B) in the package without declaring it a dependency."),
                "got stdout: \(String(describing: stdout)), stderr: \(String(describing: stderr))",
            )
        }
    }

    @Test(
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func symlink(
        data: BuildData,
    ) async throws {
        let buildSystem = data.buildSystem
        let configuration = data.config
        try await withKnownIssue(isIntermittent: true) {
            try await fixture(name: "ValidLayouts/SingleModule/ExecutableNew") { fixturePath in
                let fullPath = try resolveSymlinks(fixturePath)
                // Test symlink.
                try await execute(packagePath: fullPath, configuration: configuration, buildSystem: buildSystem)
                let actualDebug = try resolveSymlinks(fullPath.appending(components: buildSystem.binPath(for: configuration)))
                let expectedDebug = try fullPath.appending(components: buildSystem.binPath(for: configuration))
                #expect(actualDebug == expectedDebug)
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows
        }
    }

    @Test(
        .tags(
              .Feature.Command.Build,
              .Feature.TargetType.Executable
        ),
        .IssueWindowsLongPath,
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildExistingExecutableProductIsSuccessfull(
        data: BuildData,
    ) async throws {
        try await withKnownIssue("Failures possibly due to long file paths", isIntermittent: true) {
            try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
                let fullPath = try resolveSymlinks(fixturePath)

                let result = try await build(
                    ["--product", "exec1"],
                    packagePath: fullPath,
                    configuration: data.config,
                    buildSystem: data.buildSystem,
                )
                #expect(result.binContents.contains(executableName("exec1")))
                #expect(!result.binContents.contains("exec2.build"))
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows && data.buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/9137", relationship: .defect),
        .IssueWindowsCannotSaveAttachment,
        .tags(
            .Feature.CommandLineArguments.Product,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildExistingLibraryProductIsSuccessfull(
        data: BuildData,
    ) async throws {
        let buildSystem = data.buildSystem
        try await withKnownIssue(isIntermittent: true) {
            try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
                let fullPath = try resolveSymlinks(fixturePath)

                let (_, stderr) = try await execute(
                    ["--product", "lib1"],
                    packagePath: fullPath,
                    configuration: data.config,
                    buildSystem: buildSystem,
                )
                switch buildSystem {
                    case .native, .swiftbuild:
                        withKnownIssue("Found multiple targets named 'lib1'") {
                            #expect(
                                stderr.contains(
                                    "'--product' cannot be used with the automatic product 'lib1'; building the default target instead"
                                )
                            )
                        } when: {
                            .swiftbuild == buildSystem
                        }
                    case .xcode:
                        // Do nothing.
                        break
                }
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/9138", relationship: .defect),
        .tags(
            .Feature.CommandLineArguments.Target,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildExistingTargetIsSuccessfull(
        data: BuildData,
    ) async throws {
        let buildSystem = data.buildSystem
        try await withKnownIssue("Could not find target named 'exec2'") {
            try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
                let fullPath = try resolveSymlinks(fixturePath)

                let result = try await build(
                    ["--target", "exec2"],
                    packagePath: fullPath,
                    configuration: data.config,
                    buildSystem: buildSystem,
                )
                #expect(result.binContents.contains("exec2.build"))
                #expect(!result.binContents.contains(executableName("exec1")))
            }
        } when: {
            [
                .swiftbuild,
                .xcode,
            ].contains(buildSystem)
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Product,
            .Feature.CommandLineArguments.Target,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildProductAndTargetsFailsWithAMutuallyExclusiveMessage(
        buildData: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--product", "exec1", "--target", "exec2"],
                    packagePath: fixturePath,
                    configuration: buildData.config,
                    buildSystem: buildData.buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stderr.contains("error: '--product' and '--target' are mutually exclusive"))
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.BuildTests,
            .Feature.CommandLineArguments.Product,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildProductAndTestsFailsWithAMutuallyExclusiveMessage(
        buildData: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--product", "exec1", "--build-tests"],
                    packagePath: fixturePath,
                    configuration: buildData.config,
                    buildSystem: buildData.buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stderr.contains("error: '--product' and '--build-tests' are mutually exclusive"))
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.BuildTests,
            .Feature.CommandLineArguments.Target,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildTargetAndTestsFailsWithAMutuallyExclusiveMessage(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--build-tests", "--target", "exec2"],
                    packagePath: fixturePath,
                    configuration: data.config,
                    buildSystem: data.buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stderr.contains("error: '--target' and '--build-tests' are mutually exclusive"))
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.BuildTests,
            .Feature.CommandLineArguments.Product,
            .Feature.CommandLineArguments.Target,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildProductTargetAndTestsFailsWithAMutuallyExclusiveMessage(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--build-tests", "--target", "exec2", "--product", "exec1"],
                    packagePath: fixturePath,
                    configuration: data.config,
                    buildSystem: data.buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            withKnownIssue(isIntermittent: true) {
                #expect(stderr.contains("error: '--product', '--target', and '--build-tests' are mutually exclusive"), "stout: \(stdout)")
            } when: {
                (
                    ProcessInfo.hostOperatingSystem == .windows && (
                        data.buildSystem == .native
                        || (data.buildSystem == .swiftbuild && data.config == .debug)
                        ))
            }
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Product,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildUnknownProductFailsWithAppropriateMessage(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let productName = "UnknownProduct"
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--product", productName],
                    packagePath: fixturePath,
                    configuration: data.config,
                    buildSystem: data.buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, let stdout, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }

            switch data.buildSystem {
                case .native:
                    #expect(stderr.contains("error: no product named '\(productName)'"))
                case .swiftbuild, .xcode:
                    let expectedErrorMessageRegex = try Regex("error: Could not find target named '\(productName).*'")
                    #expect(
                        stderr.contains(expectedErrorMessageRegex),
                        "expect log not emitted.\nstdout: '\(stdout)'\n\nstderr: '\(stderr)'",
                    )
            }
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Target,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func buildUnknownTargetFailsWithAppropriateMessage(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/MultipleExecutables") { fixturePath in
            let buildSystem = data.buildSystem
            let targetName = "UnknownTargetName"
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--target", targetName],
                    packagePath: fixturePath,
                    configuration: data.config,
                    buildSystem: buildSystem,
                )
            }
            // THEN I expect a failure
            guard case SwiftPMError.executionFailure(_, let stdout, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            let expectedErrorMessage: String
            switch buildSystem {
                case .native:
                    expectedErrorMessage = "error: no target named '\(targetName)'"
                case .swiftbuild, .xcode:
                    expectedErrorMessage = "error: Could not find target named '\(targetName)'"
            }
            #expect(
                stderr.contains(expectedErrorMessage),
                "expect log not emitted.\nstdout: '\(stdout)'\n\nstderr: '\(stderr)'",
            )
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Product,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData, ["ClangExecSingleFile", "SwiftExecSingleFile", "SwiftExecMultiFile"],
    )
    func atMainSupport(
        data: BuildData,
        executable: String,
    ) async throws {
        let buildSystem = data.buildSystem
        let config = data.config
        try await withKnownIssue(
            "SWBINTTODO: File not found or missing libclang errors on windows platforms. This needs to be investigated",
            isIntermittent: true,
        ) {
            try await fixture(name: "Miscellaneous/AtMainSupport") { fixturePath in
                let fullPath = try resolveSymlinks(fixturePath)
                let result = try await build(
                    ["--product", executable],
                    packagePath: fullPath,
                    configuration: config,
                    buildSystem: buildSystem,
                )
                #expect(result.binContents.contains(executableName(executable)))
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows  && buildSystem == .swiftbuild
        }
    }

    @Test(
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func nonReachableProductsAndTargetsFunctional(
        data: BuildData,
    ) async throws {
        try await fixture(name: "Miscellaneous/UnreachableTargets") { fixturePath in
            let aPath = fixturePath.appending("A")

            let result = try await build(
                [],
                packagePath: aPath,
                configuration: data.config,
                buildSystem: data.buildSystem,
            )
            #expect(!result.binContents.contains("bexec"))
            #expect(!result.binContents.contains("BTarget2.build"))
            #expect(!result.binContents.contains("cexec"))
            #expect(!result.binContents.contains("CTarget.build"))
        }
    }

    @Test(
        .tags(
            .Feature.CommandLineArguments.Product,
        ),
        buildDataUsingBuildSystemAvailableOnAllPlatformsWithTags.tags,
        arguments: buildDataUsingBuildSystemAvailableOnAllPlatformsWithTags.buildData,
    )
    func nonReachableProductsAndTargetsFunctionalWhereDependencyContainsADependentProducts(
        data: BuildData,
    ) async throws {
        let buildSystem = data.buildSystem
        try await withKnownIssue("SWBINTTODO: Test failed. This needs to be investigated") {
            try await fixture(name: "Miscellaneous/UnreachableTargets") { fixturePath in
                let aPath = fixturePath.appending("A")

                // Dependency contains a dependent product

                let result = try await build(
                    ["--product", "bexec"],
                    packagePath: aPath,
                    configuration: data.config,
                    buildSystem: buildSystem,
                )
                #expect(result.binContents.contains("BTarget2.build"))
                #expect(result.binContents.contains(executableName("bexec")))
                #expect(!result.binContents.contains(executableName("aexec")))
                #expect(!result.binContents.contains("ATarget.build"))
                #expect(!result.binContents.contains("BLibrary.a"))

                // FIXME: We create the modulemap during build planning, hence this ugliness.
                let bTargetBuildDir =
                ((try? localFileSystem.getDirectoryContents(result.binPath.appending("BTarget1.build"))) ?? [])
                    .filter { $0 != moduleMapFilename }
                #expect(bTargetBuildDir.isEmpty, "bTargetBuildDir should be empty")

                #expect(!result.binContents.contains("cexec"))
                #expect(!result.binContents.contains("CTarget.build"))

                // Also make sure we didn't emit parseable module interfaces
                // (do this here to avoid doing a second build in
                // testParseableInterfaces().
                #expect(!result.moduleContents.contains("ATarget.swiftinterface"))
                #expect(!result.moduleContents.contains("BTarget.swiftinterface"))
                #expect(!result.moduleContents.contains("CTarget.swiftinterface"))
            }
        } when: {
            buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/pull/9130", relationship: .fixedBy),
        .tags(
            .Feature.CommandLineArguments.EnableParseableModuleInterfaces,
        ),
        buildDataUsingAllBuildSystemWithTags.tags,
        arguments: buildDataUsingAllBuildSystemWithTags.buildData,
    )
    func parseableInterfaces(
        data: BuildData,
    ) async throws {
        let buildSystem = data.buildSystem
        try await fixture(name: "Miscellaneous/ParseableInterfaces") { fixturePath in
            try await withKnownIssue(isIntermittent: true) {
                let result = try await build(
                    ["--enable-parseable-module-interfaces"],
                    packagePath: fixturePath,
                    configuration: data.config,
                    buildSystem: buildSystem,
                )
                switch buildSystem {
                    case .native:
                        #expect(result.moduleContents.contains("A.swiftinterface"))
                        #expect(result.moduleContents.contains("B.swiftinterface"))
                    case .swiftbuild, .xcode:
                        let aSwiftInterface = result.moduleContents.first { $0.contains("A.swiftinterface") }
                        #expect(aSwiftInterface != nil)
                        let bSwiftInterface = result.moduleContents.first { $0.contains("B.swiftinterface") }
                        #expect(bSwiftInterface != nil)
                }
            } when: {
                ProcessInfo.hostOperatingSystem == .windows
            }
        }
    }
}

@Suite
struct BuildSBOMCommandTests {
    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithCycloneDXSpec(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(
                fixturePath,
                configuration: data.config,
                extraArgs: ["--sbom-spec", "cyclonedx"],
                buildSystem: data.buildSystem,
            )
            
            #expect(stdout.contains("Build complete!") && stdout.contains("SBOMs created"))
            
            // Parse output to find SBOM path
            if let range = stdout.range(of: "created SBOM at "),
               let endRange = stdout[range.upperBound...].range(of: ".json") {
                let pathString = String(stdout[range.upperBound..<endRange.upperBound])
                let sbomPath = try AbsolutePath(validating: pathString)
                
                #expect(localFileSystem.exists(sbomPath))
                let filesInDirectory = try localFileSystem.getDirectoryContents(sbomPath.parentDirectory)
                #expect(filesInDirectory.filter { $0.hasSuffix(".json") }.count >= 1, "should produce at least 1 CycloneDX SBOM")
            }
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithSPDXSpec(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(
                fixturePath,
                configuration: data.config,
                extraArgs: ["--sbom-spec", "spdx"],
                buildSystem: data.buildSystem,
            )
            
            #expect(stdout.contains("Build complete!") && stdout.contains("SBOMs created"))
            
            // Parse output to find SBOM path
            if let range = stdout.range(of: "created SBOM at "),
               let endRange = stdout[range.upperBound...].range(of: ".json") {
                let pathString = String(stdout[range.upperBound..<endRange.upperBound])
                let sbomPath = try AbsolutePath(validating: pathString)
                
                #expect(localFileSystem.exists(sbomPath))
                let filesInDirectory = try localFileSystem.getDirectoryContents(sbomPath.parentDirectory)
                #expect(filesInDirectory.filter { $0.hasSuffix(".json") }.count >= 1, "should produce at least 1 SPDX SBOM")
            }
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithInvalidSBOMSpec(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            await expectThrowsCommandExecutionError(
                try await executeSwiftBuild(
                    fixturePath,
                    configuration: data.config,
                    extraArgs: ["--sbom-spec", "cyclonedx22"],
                    buildSystem: data.buildSystem,
                )
            ) { error in
                #expect(error.stderr.contains("The value 'cyclonedx22' is invalid"))
            }
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithSBOMSpecAndProduct(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(
                fixturePath,
                configuration: data.config,
                extraArgs: ["--sbom-spec", "cyclonedx", "--product", "Foo"],
                buildSystem: data.buildSystem,
            )
            #expect(stdout.contains("SBOMs created"))
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithSBOMSpecAndTarget(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            await expectThrowsCommandExecutionError(
                try await executeSwiftBuild(
                    fixturePath,
                    configuration: data.config,
                    extraArgs: ["--sbom-spec", "cyclonedx", "--target", "Foo"],
                    buildSystem: data.buildSystem,
                )
            ) { error in
                #expect(error.stderr.contains("--sbom-spec cannot be used with --target flag"))
            }
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms),
    )
    func buildWithMultipleSBOMSpecs(
        data: BuildData,
    ) async throws {
        try await fixture(name: "DependencyResolution/Internal/Simple") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(
                fixturePath,
                configuration: data.config,
                extraArgs: ["--sbom-spec", "cyclonedx", "--sbom-spec", "spdx"],
                buildSystem: data.buildSystem,
            )
            
            #expect(stdout.contains("Build complete!") && stdout.contains("SBOMs created"))
            
            // Check that multiple SBOMs were created
            if stdout.contains("created SBOM at ") {
                let sbomMatches = stdout.matches(of: try Regex("created SBOM at [^\\n]+\\.json"))
                #expect(sbomMatches.count >= 2, "should create at least 2 SBOMs (one for each spec)")
            }
        }
    }
}
