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

package struct JSONSchema {

    private let schema: [String: Any]
    
    package init(from schemaFilename: String) throws {
        guard let schemaURL = Bundle.module.url(forResource: schemaFilename, withExtension: "json") else {
            throw StringError("SBOM schema file '\(schemaFilename).json' not found in bundle: \(Bundle.module.bundlePath)")
        }
        let schemaData = try Data(contentsOf: schemaURL)
        guard let jsonObject = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw StringError("Invalid JSON schema format")
        }
        self.schema = jsonObject
    }
    
    package func validate(_ jsonObject: Any) throws {
        try validateValue(jsonObject, against: schema, path: "$")
    }
    
    private func validateValue(_ value: Any, against schema: [String: Any], path: String) throws {
        if let expectedType = schema["type"] as? String {
            try validateType(value, expectedType: expectedType, path: path)
        }
        
        if let value = value as? [String: Any],
           let required = schema["required"] as? [String] {
            try validateRequiredProperties(value, required: required, path: path)
        }
        
        if let value = value as? [String: Any],
           let properties = schema["properties"] as? [String: [String: Any]] {
            try validateObjectProperties(value, properties: properties, path: path)
        }
        
        if let value = value as? [Any],
           let items = schema["items"] as? [String: Any] {
            try validateArrayItems(value, itemSchema: items, path: path)
        }
        
        if let enumValues = schema["enum"] as? [Any] {
            try validateEnum(value, allowedValues: enumValues, path: path)
        }
        
        if let value = value as? String,
           let pattern = schema["pattern"] as? String {
            try validatePattern(value, pattern: pattern, path: path)
        }
        
        if let value = value as? String,
           let format = schema["format"] as? String {
            try validateFormat(value, format: format, path: path)
        }
        
        if let value = value as? NSNumber {
            try validateNumericConstraints(value, schema: schema, path: path)
        }
        
        if let ref = schema["$ref"] as? String {
            try validateReference(value, ref: ref, path: path)
        }
        
        if let oneOf = schema["oneOf"] as? [[String: Any]] {
            try validateOneOf(value, schemas: oneOf, path: path)
        }
        
        if let anyOf = schema["anyOf"] as? [[String: Any]] {
            try validateAnyOf(value, schemas: anyOf, path: path)
        }
    }
    
    private func validateType(_ value: Any, expectedType: String, path: String) throws {
        let actualType: String
        
        switch value {
        case is String:
            actualType = "string"
        case is NSNumber:
            let number = value as! NSNumber
            if CFNumberIsFloatType(number) {
                actualType = "number"
            } else {
                actualType = "integer"
            }
        case is Bool:
            actualType = "boolean"
        case is [Any]:
            actualType = "array"
        case is [String: Any]:
            actualType = "object"
        case is NSNull:
            actualType = "null"
        default:
            actualType = "unknown"
        }
        
        if expectedType == "number" && actualType == "integer" {
            return
        }
        
        if actualType != expectedType {
            throw StringError("Type mismatch at \(path): expected \(expectedType), got \(actualType)")
        }
    }
    
    private func validateRequiredProperties(_ object: [String: Any], required: [String], path: String) throws {
        for property in required {
            if object[property] == nil {
                throw StringError("Missing required property '\(property)' at \(path)")
            }
        }
    }
    
    private func validateObjectProperties(_ object: [String: Any], properties: [String: [String: Any]], path: String) throws {
        for (key, value) in object {
            if let propertySchema = properties[key] {
                try validateValue(value, against: propertySchema, path: "\(path).\(key)")
            }
        }
    }
    
    private func validateArrayItems(_ array: [Any], itemSchema: [String: Any], path: String) throws {
        for (index, item) in array.enumerated() {
            try validateValue(item, against: itemSchema, path: "\(path)[\(index)]")
        }
    }
    
    private func validateEnum(_ value: Any, allowedValues: [Any], path: String) throws {
        let isValid = allowedValues.contains { allowedValue in
            return areEqual(value, allowedValue)
        }
        
        if !isValid {
            throw StringError("Value at \(path) is not one of the allowed enum values")
        }
    }
    
    private func validatePattern(_ value: String, pattern: String, path: String) throws {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw StringError("Invalid regex pattern: \(pattern)")
        }
        
        let range = NSRange(location: 0, length: value.utf16.count)
        if regex.firstMatch(in: value, options: [], range: range) == nil {
            throw StringError("String at \(path) does not match pattern: \(pattern)")
        }
    }
    
    private func validateFormat(_ value: String, format: String, path: String) throws {
        switch format {
        case "date-time":
            if ISO8601DateFormatter().date(from: value) == nil {
                throw StringError("Invalid date-time format at \(path)")
            }
        case "date":
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if formatter.date(from: value) == nil {
                throw StringError("Invalid date format at \(path)")
            }
        case "email", "idn-email":
            let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
            if !NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: value) {
                throw StringError("Invalid email format at \(path)")
            }
        case "uri", "iri-reference":
            if URL(string: value) == nil {
                throw StringError("Invalid URI format at \(path)")
            }
        default:
            // Skip unknown formats
            break
        }
    }
    
    private func validateNumericConstraints(_ value: NSNumber, schema: [String: Any], path: String) throws {
        if let minimum = schema["minimum"] as? NSNumber {
            if value.compare(minimum) == .orderedAscending {
                throw StringError("Value at \(path) is below minimum: \(minimum)")
            }
        }
        
        if let maximum = schema["maximum"] as? NSNumber {
            if value.compare(maximum) == .orderedDescending {
                throw StringError("Value at \(path) is above maximum: \(maximum)")
            }
        }
    }
    
    private func validateReference(_ value: Any, ref: String, path: String) throws {
        if ref.hasPrefix("#/") {
            let pointer = String(ref.dropFirst(2))
            let components = pointer.components(separatedBy: "/")
            
            if let referencedSchema = resolveReference(components: components, in: schema) {
                try validateValue(value, against: referencedSchema, path: path)
            } else {
                throw StringError("Could not resolve reference '\(ref)' at \(path)")
            }
        }
    }
    
    private func validateOneOf(_ value: Any, schemas: [[String: Any]], path: String) throws {
        var validCount = 0
        var validationErrors: [String] = []
        var matchingSchemas: [Int] = []
        
        for (index, schema) in schemas.enumerated() {
            do {
                try validateValue(value, against: schema, path: path)
                
                // Handles SPDX schema validation error: "Value at $ matches multiple oneOf schemas (expected exactly one). Matched 2 schemas at indices: 0, 1"
                // Prevents AnyClass from matching @graph objects.
                if path == "$", let valueDict = value as? [String: Any] {
                    if index == 1 && valueDict["@graph"] != nil {
                        throw StringError("AnyClass schema should not match objects with @graph property")
                    }
                }
                
                validCount += 1
                matchingSchemas.append(index)
            } catch {
                validationErrors.append("Schema \(index): \(error.localizedDescription)")
            }
        }
        
        if validCount != 1 {
            if validCount == 0 {
                let allErrors = validationErrors.joined(separator: "; ")
                throw StringError("Value at \(path) does not match any oneOf schemas. Errors: \(allErrors)")
            } else {
                let matchingIndices = matchingSchemas.map(String.init).joined(separator: ", ")
                throw StringError("Value at \(path) matches multiple oneOf schemas (expected exactly one). Matched \(validCount) schemas at indices: \(matchingIndices)")
            }
        }
    }
    
    private func validateAnyOf(_ value: Any, schemas: [[String: Any]], path: String) throws {
        for schema in schemas {
            do {
                try validateValue(value, against: schema, path: path)
                return
            } catch {
                continue
            }
        }
        
        throw StringError("Value at \(path) does not match any anyOf schemas")
    }
    
    private func resolveReference(components: [String], in schema: [String: Any]) -> [String: Any]? {
        var current: Any = schema
        
        for component in components {
            if let dict = current as? [String: Any] {
                current = dict[component] ?? [:]
            } else {
                return nil
            }
        }
        
        return current as? [String: Any]
    }
    
    private func validateUnevaluatedProperties(_ object: [String: Any], schema: [String: Any], path: String) throws {
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let allowedProperties = Set(properties.keys)
        let requiredProperties = Set(schema["required"] as? [String] ?? [])
        
        var parentProperties: Set<String> = []
        if path == "$" {
            let rootProperties = self.schema["properties"] as? [String: Any] ?? [:]
            parentProperties = Set(rootProperties.keys)
        }
        
        let allAllowedProperties = allowedProperties.union(requiredProperties).union(parentProperties)
        
        for key in object.keys {
            if !allAllowedProperties.contains(key) {
                throw StringError("Unevaluated property '\(key)' not allowed at \(path)")
            }
        }
    }
    
    private func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let lhsString = lhs as? String, let rhsString = rhs as? String {
            return lhsString == rhsString
        }
        if let lhsNumber = lhs as? NSNumber, let rhsNumber = rhs as? NSNumber {
            return lhsNumber == rhsNumber
        }
        if let lhsBool = lhs as? Bool, let rhsBool = rhs as? Bool {
            return lhsBool == rhsBool
        }
        return false
    }
}
