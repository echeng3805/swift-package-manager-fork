# SPM Test Fixtures

This directory contains organized test fixtures for creating a complete SwiftPM (Swift Package Manager) ModulesGraph for SBOM testing.

## Structure

The fixtures are split across multiple files for maintainability:

### Foundation Packages
- **SPMFoundationPackages.swift** - Basic utility packages
  - swift-system (2 modules)
  - swift-collections (8 modules)
  - swift-argument-parser (6 modules)
  - swift-toolchain-sqlite (2 modules)

### Build Tooling Packages
- **SPMBuildToolingPackages.swift** - Build and compilation tools
  - swift-llbuild (10 modules)
  - swift-tools-support-core (5 modules)
  - swift-driver (7 modules)

### Security Packages
- **SPMSecurityPackages.swift** - Cryptography and certificates
  - swift-asn1 (1 module)
  - swift-crypto (5 modules)
  - swift-certificates (2 modules)

### Documentation Packages
- **SPMDocumentationPackages.swift** - Documentation generation
  - swift-docc-symbolkit (1 module)
  - swift-docc-plugin (4 modules)

### Swift Syntax Package
- **SPMSwiftSyntaxPackage.swift** - Swift syntax parsing and manipulation (26 modules)

### Swift Build Package
- **SPMSwiftBuildPackage.swift** - Swift build system (26 modules)

### Root Package
- **SPMRootPackage.swift** - The SwiftPM package itself (86 modules)

### Assembly
- **SPMModulesGraphComplete.swift** - Main assembly file that creates the complete graph

## Usage

```swift
// Create a complete SPM ModulesGraph for testing
let graph = try SBOMTestModulesGraph.createCompleteSPMModulesGraph()

// Or use the legacy wrapper (calls the complete implementation)
let graph = try SBOMTestModulesGraph.createSPMModulesGraph()
```

## Package Count

- **15 packages total** (including root SwiftPM)
- **~200+ modules** across all packages
- **Complex dependency relationships** accurately modeled

## Source

The structure is based on the actual Swift Package Manager dependency graph captured from the project's build system.