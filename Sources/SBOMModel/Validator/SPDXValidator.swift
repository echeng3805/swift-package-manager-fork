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

internal struct SPDXValidator: SBOMValidatorProtocol {
    
    internal enum SPDXKeys {
        static let context = "@context"
        static let graph = "@graph"
        static let id = "@id"
        static let spdxId = "spdxId"
    }
    
    private let validator: SBOMValidator
    
    internal init(schema: [String: Any]) {
        self.validator = SBOMValidator(schema: schema)
    }
        
    internal func validate(_ jsonObject: Any) throws {
        guard let rootDict = jsonObject as? [String: Any] else {
            throw StringError("Expected dictionary for SPDX JSON-LD document at $")
        }

        try validateContext(rootDict[SPDXKeys.context])

        guard let graph = rootDict[SPDXKeys.graph] as? [Any] else {
            throw StringError("@graph at $ must be an array")
        }
        guard !graph.isEmpty else {
            throw StringError("@graph at $ is empty")
        }

        let graphElementSchema = extractGraphElementSchema()
        for (index, element) in graph.enumerated() {
            try validateValue(element, against: graphElementSchema, path: "$[@graph][\(index)]")
        }
    }
    
    internal func validateValue(_ value: Any, against schema: [String: Any], path: String) throws {
        if let objectValue = value as? [String: Any] {
            try validateObjectWithSPDXRules(objectValue, against: schema, path: path)
        } else {
            try validator.validateValue(value, against: schema, path: path)
        }
    }
        
    private func validateObjectWithSPDXRules(_ object: [String: Any], against schema: [String: Any], path: String) throws {
        if let required = schema["required"] as? [String] {
            for property in required {
                // allow @id as substitute for spdxId
                if property == SPDXKeys.spdxId && object[SPDXKeys.id] != nil {
                    continue
                }
                guard object[property] != nil else {
                    throw StringError("Missing required property '\(property)' at \(path)")
                }
            }
        }
        
        // Handle properties with SPDX-specific resolution
        if let properties = schema["properties"] as? [String: [String: Any]] {
            for (key, value) in object {
                let propertySchema: [String: Any]?
                
                // SPDX JSON-LD: @id can use spdxId schema
                if key == SPDXKeys.id, let spdxIdSchema = properties[SPDXKeys.spdxId] {
                    propertySchema = spdxIdSchema
                }
                // SPDX JSON-LD: Skip spdxId if @id is present
                else if key == SPDXKeys.spdxId && object[SPDXKeys.id] != nil {
                    continue
                }
                else {
                    propertySchema = properties[key]
                }
                
                if let schema = propertySchema {
                    try validateValue(value, against: schema, path: "\(path).\(key)")
                }
            }
        }
        
        // Handle oneOf with SPDX-specific logic
        if let oneOf = schema["oneOf"] as? [[String: Any]] {
            // Use base validator's validateOneOf with SPDX-specific pre-validation
            try validator.validateOneOf(object, schemas: oneOf, path: path) { value, schema, index, path in
                // SPDX-specific: Prevent AnyClass from matching @graph objects
                if path == "$", let valueDict = value as? [String: Any] {
                    if index == 1 && valueDict[SPDXKeys.graph] != nil {
                        throw StringError("AnyClass schema should not match objects with @graph property")
                    }
                }
            }
            return
        }
        
        try validator.validateValue(object, against: schema, path: path)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateContext(_ context: Any?) throws {
        guard let contextString = context as? String else {
            throw StringError("@context at $ must be a string")
        }
        guard !contextString.isEmpty else {
            throw StringError("@context at $ is empty")
        }
    }
    
    private func extractGraphElementSchema() -> [String: Any] {
        // Graph elements use AnyClass schema (oneOf[1]) rather than root schema
        if let oneOf = validator.schema[SBOMValidator.SchemaKeys.oneOf] as? [[String: Any]], oneOf.count > 1 {
            return oneOf[1]
        } else if let anyOf = validator.schema[SBOMValidator.SchemaKeys.anyOf] as? [[String: Any]], !anyOf.isEmpty {
            return anyOf[0]
        }
        return validator.schema
    }
}