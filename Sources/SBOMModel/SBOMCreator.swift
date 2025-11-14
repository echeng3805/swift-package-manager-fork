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

package struct SBOMCreator {
    package let input: SBOMInput
    
    package init(input: SBOMInput) {
        self.input = input
    }

    package func createSBOMs() async throws {
        let extractor = SBOMExtractor(
            modulesGraph: input.modulesGraph,
            dependencyGraph: input.dependencyGraph,
            store: input.store
        )
        
        let sbom = try await extractor.extractSBOM(
            product: input.product,
            filter: input.filter)
        
        let encoder = SBOMEncoder(sbom: sbom)
        try await encoder.writeSBOMs(
            specs: input.specs,
            outputDir: input.dir,
            filter: input.filter
        )
    }
}
