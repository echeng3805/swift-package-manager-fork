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

internal enum SBOMValidationError: Error, LocalizedError {
    case notSchemaViolation(path: String, valueDescription: String)
    case typeMismatch(path: String, expected: String, actual: String, debugInfo: String)
    case missingRequired(path: String, property: String)
    case invalidValue(path: String, message: String)
    case schemaComposition(path: String, message: String)
    case constraintViolation(path: String, message: String)
    
    var errorDescription: String? {
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
}