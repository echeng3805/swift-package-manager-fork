# Swiftly Test Fixtures

This directory contains test fixtures for the Swiftly package graph, split across multiple files for maintainability.

## File Organization

- `SwiftlyRootPackage.swift` - The root Swiftly package with all its modules
- `SwiftNIOPackages.swift` - swift-nio and related packages (nio-ssl, nio-http2, nio-extras, nio-transport-services)
- `SwiftOpenAPIPackages.swift` - OpenAPI-related packages (runtime, generator, async-http-client)
- `SwiftFoundationPackages.swift` - Foundation packages (system, subprocess, argument-parser, tools-support-core)
- `SwiftCollectionsPackages.swift` - Collections and algorithms packages
- `SwiftUtilityPackages.swift` - Utility packages (log, distributed-tracing, atomics, numerics, etc.)
- `SwiftlyModulesGraphComplete.swift` - Main entry point that assembles all packages into a complete ModulesGraph

## Usage

```swift
let graph = try SBOMTestModulesGraph.createCompleteSwiftlyModulesGraph()
```

This will create a complete ModulesGraph with all packages and their dependencies properly configured.