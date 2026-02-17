# Software Bill of Materials (SBOM)

Generate Software Bill of Materials (SBOM) documents for Swift packages and products.

## Overview

Swift Package Manager supports generating Software Bill of Materials (SBOM) documents that provide an inventory of components and dependencies in a Swift package or product.

SwiftPM currently supports two SBOM formats: CycloneDX and SPDX. 

## Generating SBOMs

SBOMs can be generated using either the [`swift build`](doc:SwiftBuild) command with SBOM flags or the dedicated [`swift package generate-sbom`](doc:PackageGenerateSBOM) subcommand.

### Using `swift build`

Both NativeBuild and SwiftBuild support SBOM generation. However, NativeBuild's generated SBOM does not factor in build-time conditionals (e.g., operating system), so NativeBuild's generated SBOM is less accurate than SwiftBuild's generated SBOM.

Our recommendation is to generate SBOMs through SwiftBuild whenever possible for the highest accuracy.

```bash
swift build --sbom-spec cyclonedx
swift build --sbom-spec spdx
swift build --sbom-spec cyclonedx --sbom-spec spdx

swift build --build-system swiftbuild --sbom-spec cyclonedx
swift build --build-system swiftbuild --sbom-spec spdx
swift build --build-system swiftbuild --sbom-spec cyclonedx --sbom-spec spdx
```

If `--sbom-spec` and `--target` flags are used together, SBOM generation will emit an error.

### Using `swift package generate-sbom`

`swift package generate-sbom` generates SBOM without building. The SBOM generated through `swift package generate-sbom` is less accurate than an SBOM generated through `swift build`. Build-time conditionals are not applied to the SBOM, and there is the possibility of the package graph changing before the SBOM is generated.

Our recommendation is to generate SBOMs through `swift build` whenever possible for the highest accuracy.

```bash
swift package generate-sbom --sbom-spec cyclonedx
swift package generate-sbom --sbom-spec spdx
swift package generate-sbom --sbom-spec cyclonedx --sbom-spec spdx
```

### Additional Flags

The following apply to both SBOM generation for `swift build` and `swift package generate-sbom`:

An SBOM can be generated for a specific product in a package by using the `--product` flag.

```bash
swift build --build-system swiftbuild --product MyProduct --sbom-spec cyclonedx
swift package generate-sbom --product MyProduct --sbom-spec spdx
```

An SBOM can also be filtered by packages or products. By default, both packages and products are included in the generated SBOM. Note that the primary component is always included, no matter what filter is applied.

```bash
swift build --build-system swiftbuild --sbom-spec cyclonedx --sbom-filter package
swift package generate-sbom --sbom-spec spdx --sbom-filter product
```

Generated SBOMs are placed in `<scratch_path>/sboms` by default, but `--sbom-output-dir` can be used to specify a different directory for generated SBOMs.

```bash
swift build --build-system swiftbuild --sbom-spec cyclonedx --sbom-output-dir /path/to/some/directory
swift package generate-sbom --sbom-spec spdx --sbom-output-dir /path/to/some/directory
```

By default, if SBOM generation fails, the `build` or `package` command will also fail. However, `--sbom-warning-only` converts all SBOM generation errors to warnings.

```bash
swift build --build-system swiftbuild --sbom-spec cyclonedx --sbom-output-dir / --sbom-warning-only
swift package generate-sbom --sbom-spec spdx --sbom-output-dir / --sbom-warning-only
```

### Environment Variables

SBOM generation can also be triggered and configured through environment variables. CLI flags will take precedence over environment variables.

The following environment variables can be configured:

- `SWIFTPM_BUILD_SBOM_SPEC`
- `SWIFTPM_BUILD_SBOM_OUTPUT_DIR`
- `SWIFTPM_BUILD_SBOM_FILTER`
- `SWIFTPM_BUILD_SBOM_WARNING_ONLY`

```bash
SWIFTPM_BUILD_SBOM_SPEC=cyclonedx,spdx swift build --build-system swiftbuild
```

If using environment variables, note that SBOM generation will only trigger if `SWIFTPM_BUILD_SBOM_SPEC` is set. 
