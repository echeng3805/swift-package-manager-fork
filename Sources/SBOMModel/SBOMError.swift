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

// MARK: - Schema Errors

/// Errors that can occur during SBOM schema operations
package enum SBOMSchemaError: Error, LocalizedError, CustomStringConvertible {
    /// Schema file not found in bundle
    case schemaFileNotFound(filename: String, bundlePath: String)
    /// Invalid JSON schema format
    case invalidSchemaFormat(message: String)
    package var errorDescription: String? {
        switch self {
        case .schemaFileNotFound(let filename, let bundlePath):
            return "SBOM schema file '\(filename).json' not found in bundle: \(bundlePath)"
        case .invalidSchemaFormat(let message):
            return "Invalid JSON schema format: \(message)"
        }
    }
    package var description: String {
        errorDescription ?? "Unknown SBOM schema error"
    }
}

// MARK: - Converter Errors

/// Errors that can occur during SBOM format conversion
package enum SBOMConverterError: Error, LocalizedError, CustomStringConvertible {
    /// Expected a specific SBOM spec type but got another
    case unexpectedSpecType(expected: String, actual: Spec)
    /// Missing required metadata for conversion
    case missingRequiredMetadata(message: String)
    package var errorDescription: String? {
        switch self {
        case .unexpectedSpecType(let expected, let actual):
            return "Expected \(expected) spec but got \(actual)"
        case .missingRequiredMetadata(let message):
            return "Missing required metadata: \(message)"
        }
    }
    package var description: String {
        errorDescription ?? "Unknown SBOM converter error"
    }
}

// MARK: - Extractor Errors

/// Errors that can occur during SBOM data extraction
package enum SBOMExtractorError: Error, LocalizedError, CustomStringConvertible {
    /// No root package found in package graph
    case noRootPackage(context: String)
    /// Product not found in package
    case productNotFound(productName: String, packageIdentity: String)
    package var errorDescription: String? {
        switch self {
        case .noRootPackage(let context):
            return "No root package found in package graph, cannot \(context)"
        case .productNotFound(let productName, let packageIdentity):
            return "Product '\(productName)' not found in root package '\(packageIdentity)'"
        }
    }
    package var description: String {
        errorDescription ?? "Unknown SBOM extractor error"
    }
}

// MARK: - Encoder Errors

/// Errors that can occur during SBOM encoding
package enum SBOMEncoderError: Error, LocalizedError, CustomStringConvertible {
    /// Failed to convert SBOM to JSON object
    case jsonConversionFailed(message: String)
    package var errorDescription: String? {
        switch self {
        case .jsonConversionFailed(let message):
            return "Failed to convert SBOM to JSON: \(message)"
        }
    }
    package var description: String {
        errorDescription ?? "Unknown SBOM encoder error"
    }
}

// MARK: - Validator Errors

/// Errors that can occur during SBOM validation
package enum SBOMValidatorError: Error, LocalizedError, CustomStringConvertible {
    /// Value does not match 'not' schema (should not match)
    case notSchemaViolation(path: String, valueDescription: String)
    /// Type mismatch during validation
    case typeMismatch(path: String, expected: String, actual: String, debugInfo: String)
    /// Missing required property
    case missingRequired(path: String, property: String)
    /// Invalid value
    case invalidValue(path: String, message: String)
    /// Schema composition error (oneOf, anyOf, allOf)
    case schemaComposition(path: String, message: String)
    /// Constraint violation (min/max, pattern, etc.)
    case constraintViolation(path: String, message: String)
    package var errorDescription: String? {
        switch self {
        case .notSchemaViolation(let path, let valueDescription):
            return "Value at \(path) matches 'not' schema (should not match). Value: \(valueDescription)"
        case .typeMismatch(let path, let expected, let actual, let debugInfo):
            return "Type mismatch at \(path): expected \(expected), got \(actual) (\(debugInfo))"
        case .missingRequired(let path, let property):
            return "Missing required property '\(property)' at \(path)"
        case .invalidValue(let path, let message):
            return "Invalid value at \(path): \(message)"
        case .schemaComposition(let path, let message):
            return "Schema composition error at \(path): \(message)"
        case .constraintViolation(let path, let message):
            return "Constraint violation at \(path): \(message)"
        }
    }
    package var description: String {
        errorDescription ?? "Unknown SBOM validator error"
    }
}