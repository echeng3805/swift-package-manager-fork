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

// MARK: - Base Validator

/// Base validator containing all core JSON Schema validation logic
internal struct SBOMValidator: SBOMValidatorProtocol {
    // MARK: - Constants
    
    internal enum SchemaKeys {
        static let type = "type"
        static let required = "required"
        static let properties = "properties"
        static let items = "items"
        static let enumKey = "enum"
        static let pattern = "pattern"
        static let format = "format"
        static let ref = "$ref"
        static let oneOf = "oneOf"
        static let anyOf = "anyOf"
        static let allOf = "allOf"
        static let const = "const"
        static let not = "not"
        static let additionalProperties = "additionalProperties"
        static let unevaluatedProperties = "unevaluatedProperties"
        static let minimum = "minimum"
        static let maximum = "maximum"
        static let minLength = "minLength"
        static let maxLength = "maxLength"
        static let minItems = "minItems"
        static let maxItems = "maxItems"
        static let uniqueItems = "uniqueItems"
    }
    
    let schema: [String: Any]
    
    internal init(schema: [String: Any]) {
        self.schema = schema
    }
    
    // MARK: - SBOMValidatorProtocol Implementation
    
    internal func validate(_ jsonObject: Any) throws {
        try validateValue(jsonObject, against: schema, path: "$")
    }
    
    internal func validateValue(_ value: Any, against schema: [String: Any], path: String) throws {
        // Type validation
        if let expectedType = schema[SchemaKeys.type] as? String {
            try validateType(value, expectedType: expectedType, path: path)
        }

        // Schema composition keywords
        if let ref = schema[SchemaKeys.ref] as? String {
            try validateReference(value, ref: ref, path: path)
        }
        if let oneOf = schema[SchemaKeys.oneOf] as? [[String: Any]] {
            try validateOneOf(value, schemas: oneOf, path: path)
        }
        if let anyOf = schema[SchemaKeys.anyOf] as? [[String: Any]] {
            try validateAnyOf(value, schemas: anyOf, path: path)
        }
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            try validateAllOf(value, schemas: allOf, path: path)
        }
        if let notSchema = schema[SchemaKeys.not] as? [String: Any] {
            try validateNot(value, schema: notSchema, path: path)
        }

        // Value-specific validations
        if let constValue = schema[SchemaKeys.const] {
            try validateConst(value, expectedValue: constValue, path: path)
        }
        if let enumValues = schema[SchemaKeys.enumKey] as? [Any] {
            try validateEnum(value, allowedValues: enumValues, path: path)
        }

        // Type-specific validations
        try validateObjectIfNeeded(value, schema: schema, path: path)
        try validateArrayIfNeeded(value, schema: schema, path: path)
        try validateStringIfNeeded(value, schema: schema, path: path)
        try validateNumberIfNeeded(value, schema: schema, path: path)
    }
    
    // MARK: - Type-Specific Validation
    
    private func validateObjectIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let objectValue = value as? [String: Any] else { return }

        let allRequired = collectAllRequired(from: schema)
        if !allRequired.isEmpty {
            try validateRequiredProperties(objectValue, required: allRequired, path: path)
        }

        let allProperties = collectAllProperties(from: schema)
        if !allProperties.isEmpty {
            try validateObjectProperties(objectValue, properties: allProperties, path: path)
        }

        try validateAdditionalProperties(objectValue, schema: schema, path: path)
        try validateUnevaluatedProperties(objectValue, schema: schema, path: path)
    }

    private func validateArrayIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let arrayValue = value as? [Any] else { return }

        if let items = schema[SchemaKeys.items] as? [String: Any] {
            try validateArrayItems(arrayValue, itemSchema: items, path: path)
        }
        try validateArrayConstraints(arrayValue, schema: schema, path: path)
    }

    private func validateStringIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let stringValue = value as? String else { return }

        if let minLength = schema[SchemaKeys.minLength] as? Int {
            if stringValue.count < minLength {
                throw StringError(
                    "String at \(path) is shorter than minimum length. Expected at least \(minLength), got \(stringValue.count)"
                )
            }
        }

        if let maxLength = schema[SchemaKeys.maxLength] as? Int {
            if stringValue.count > maxLength {
                throw StringError(
                    "String at \(path) is longer than maximum length. Expected at most \(maxLength), got \(stringValue.count)"
                )
            }
        }

        if let pattern = schema[SchemaKeys.pattern] as? String {
            try validatePattern(stringValue, pattern: pattern, path: path)
        }
        if let format = schema[SchemaKeys.format] as? String {
            try validateFormat(stringValue, format: format, path: path)
        }
    }

    private func validateNumberIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let numberValue = value as? NSNumber else { return }
        try validateNumericConstraints(numberValue, schema: schema, path: path)
    }
    
    // MARK: - Schema Collection Helpers

    private func collectAllRequired(from schema: [String: Any]) -> [String] {
        var allRequired: [String] = []
        if let required = schema[SchemaKeys.required] as? [String] {
            allRequired.append(contentsOf: required)
        }
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            for subSchema in allOf {
                collectRequiredProperties(from: subSchema, into: &allRequired)
            }
        }
        return allRequired
    }

    private func collectAllProperties(from schema: [String: Any]) -> [String: [String: Any]] {
        var allProperties: [String: [String: Any]] = [:]
        if let properties = schema[SchemaKeys.properties] as? [String: [String: Any]] {
            allProperties.merge(properties) { _, new in new }
        }
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            for subSchema in allOf {
                collectProperties(from: subSchema, into: &allProperties)
            }
        }
        return allProperties
    }
    
    // MARK: - Type Validation

    private func validateType(_ value: Any, expectedType: String, path: String) throws {
        let (actualType, debugInfo) = determineActualType(value)

        // Allow integers where numbers are expected
        if expectedType == "number" && actualType == "integer" {
            return
        }

        guard actualType == expectedType else {
            throw StringError("Type mismatch at \(path): expected \(expectedType), got \(actualType) (\(debugInfo))")
        }
    }

    private func determineActualType(_ value: Any) -> (type: String, debugInfo: String) {
        switch value {
        case is String:
            return ("string", "value: \"\(value)\"")
        case let number as NSNumber:
            return determineNumberType(number)
        case let array as [Any]:
            return ("array", "length: \(array.count)")
        case let dict as [String: Any]:
            let keys = dict.keys.sorted().joined(separator: ", ")
            return ("object", "keys: \(keys)")
        case is NSNull:
            return ("null", "null")
        default:
            return ("unknown", "type: \(type(of: value))")
        }
    }

    private func determineNumberType(_ number: NSNumber) -> (type: String, debugInfo: String) {
        // Check for boolean type
        if isBoolean(number) {
            return ("boolean", "value: \(number.boolValue)")
        }

        // Check for floating point
        if CFNumberIsFloatType(number) {
            return ("number", "value: \(number.doubleValue)")
        }

        // Default to integer
        return ("integer", "value: \(number.intValue)")
    }

    private func isBoolean(_ number: NSNumber) -> Bool {
        let objCType = String(cString: number.objCType)
        return (objCType == "c" || objCType == "B") &&
            (number === kCFBooleanTrue as NSNumber || number === kCFBooleanFalse as NSNumber)
    }

    private func validateRequiredProperties(_ object: [String: Any], required: [String], path: String) throws {
        for property in required {
            guard object[property] != nil else {
                throw StringError("Missing required property '\(property)' at \(path)")
            }
        }
    }

    private func validateObjectProperties(
        _ object: [String: Any],
        properties: [String: [String: Any]],
        path: String
    ) throws {
        for (key, value) in object {
            guard let propertySchema = properties[key] else {
                continue
            }
            try validateValue(value, against: propertySchema, path: "\(path).\(key)")
        }
    }

    private func validateArrayItems(_ array: [Any], itemSchema: [String: Any], path: String) throws {
        for (index, item) in array.enumerated() {
            try validateValue(item, against: itemSchema, path: "\(path)[\(index)]")
        }
    }

    private func validateEnum(_ value: Any, allowedValues: [Any], path: String) throws {
        let isValid = allowedValues.contains { allowedValue in
            areEqual(value, allowedValue)
        }

        if !isValid {
            let valueStr = describeValue(value)
            let allowedStr = allowedValues.map { describeValue($0) }.joined(separator: ", ")
            throw StringError(
                "Value at \(path) is not one of the allowed enum values. Got: \(valueStr), allowed: [\(allowedStr)]"
            )
        }
    }

    private func validatePattern(_ value: String, pattern: String, path: String) throws {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw StringError("Invalid regex pattern: \(pattern)")
        }

        let range = NSRange(location: 0, length: value.utf16.count)

        guard let match = regex.firstMatch(in: value, options: [], range: range) else {
            throw StringError("String at \(path) does not match pattern: \(pattern). Value: \"\(value)\"")
        }

        // Verify the match covers the entire string (JSON Schema pattern must match the whole string)
        if match.range.location != 0 || match.range.length != value.utf16.count {
            throw StringError("String at \(path) does not match pattern: \(pattern). Value: \"\(value)\"")
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
            // Unknown format - skip validation but log in debug builds
            break
        }
    }

    private func validateNumericConstraints(_ value: NSNumber, schema: [String: Any], path: String) throws {
        if let minimum = schema[SchemaKeys.minimum] as? NSNumber, value.compare(minimum) == .orderedAscending {
            throw StringError("Value at \(path) is below minimum: \(minimum). Got: \(value)")
        }

        if let maximum = schema[SchemaKeys.maximum] as? NSNumber, value.compare(maximum) == .orderedDescending {
            throw StringError("Value at \(path) is above maximum: \(maximum). Got: \(value)")
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
        try validateOneOf(value, schemas: schemas, path: path, preValidation: nil)
    }
    
    /// Validate oneOf with optional pre-validation hook for subclass customization
    internal func validateOneOf(_ value: Any, schemas: [[String: Any]], path: String, preValidation: ((Any, [String: Any], Int, String) throws -> Void)?) throws {
        var validCount = 0
        var validationErrors: [String] = []
        var matchingSchemas: [Int] = []

        for (index, schema) in schemas.enumerated() {
            do {
                // Allow custom pre-validation logic (e.g., SPDX-specific checks)
                try preValidation?(value, schema, index, path)
                
                try validateValue(value, against: schema, path: path)
                validCount += 1
                matchingSchemas.append(index)
            } catch {
                validationErrors.append("Schema \(index): \(error.localizedDescription)")
            }
        }

        if validCount != 1 {
            let valueDesc = describeValue(value, maxLength: 200)
            if validCount == 0 {
                let allErrors = validationErrors.joined(separator: "\n  ")
                throw StringError(
                    "Value at \(path) does not match any oneOf schemas.\nValue: \(valueDesc)\nErrors:\n  \(allErrors)"
                )
            } else {
                let matchingIndices = matchingSchemas.map(String.init).joined(separator: ", ")
                throw StringError(
                    "Value at \(path) matches multiple oneOf schemas (expected exactly one). Matched \(validCount) schemas at indices: \(matchingIndices)\nValue: \(valueDesc)"
                )
            }
        }
    }

    private func validateAnyOf(_ value: Any, schemas: [[String: Any]], path: String) throws {
        var schemaNames: [String] = []
        var detailedErrors: [String: String] = [:]

        for (index, schema) in schemas.enumerated() {
            do {
                try validateValue(value, against: schema, path: path)
                return // Successfully validated against one schema, we're done
            } catch {
                // Extract just the schema name/type for concise error reporting
                let schemaName = extractSchemaName(from: schema, index: index)
                schemaNames.append(schemaName)

                // For specific schemas, capture the detailed error
                if schemaName == "CreationInfo" || schemaName == "ExternalIdentifier" || schemaName == "Relationship" {
                    detailedErrors[schemaName] = error.localizedDescription
                }
            }
        }

        // None of the schemas matched
        let valueDesc = describeValue(value, maxLength: 200)

        // Show concise list of attempted schemas
        let summary: String
        if schemaNames.count > 15 {
            let shown = schemaNames.prefix(10).joined(separator: ", ")
            summary = "Tried \(schemaNames.count) schemas: \(shown), ... and \(schemaNames.count - 10) more"
        } else {
            summary = "Tried schemas: \(schemaNames.joined(separator: ", "))"
        }

        throw StringError("Value at \(path) does not match any anyOf schemas.\nValue: \(valueDesc)\n\(summary)")
    }

    private func validateAllOf(_ value: Any, schemas: [[String: Any]], path: String) throws {
        var errors: [String] = []

        for (index, schema) in schemas.enumerated() {
            do {
                try validateValue(value, against: schema, path: path)
            } catch {
                errors.append("Schema \(index): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            let valueDesc = describeValue(value, maxLength: 200)
            let allErrors = errors.joined(separator: "\n  ")
            throw StringError(
                "Value at \(path) does not match all allOf schemas.\nValue: \(valueDesc)\nErrors:\n  \(allErrors)"
            )
        }
    }

    private func validateConst(_ value: Any, expectedValue: Any, path: String) throws {
        if !areEqual(value, expectedValue) {
            let valueDesc = describeValue(value)
            let expectedDesc = describeValue(expectedValue)
            throw StringError("Value at \(path) does not match const. Expected: \(expectedDesc), got: \(valueDesc)")
        }
    }

    private func validateArrayConstraints(_ array: [Any], schema: [String: Any], path: String) throws {
        if let minItems = schema["minItems"] as? Int {
            if array.count < minItems {
                throw StringError(
                    "Array at \(path) has fewer items than minimum. Expected at least \(minItems), got \(array.count)"
                )
            }
        }

        if let maxItems = schema["maxItems"] as? Int {
            if array.count > maxItems {
                throw StringError(
                    "Array at \(path) has more items than maximum. Expected at most \(maxItems), got \(array.count)"
                )
            }
        }

        // Validate uniqueItems constraint
        if let uniqueItems = schema["uniqueItems"] as? Bool, uniqueItems {
            try validateUniqueItems(array, path: path)
        }
    }

    private func validateUniqueItems(_ array: [Any], path: String) throws {
        // For uniqueness checking, we need to compare items
        // We'll use a simple approach: serialize each item to JSON and compare strings
        var seen = Set<String>()

        for (index, item) in array.enumerated() {
            // Create a canonical representation of the item for comparison
            let itemKey = try canonicalRepresentation(of: item)

            if seen.contains(itemKey) {
                let itemDesc = describeValue(item, maxLength: 100)
                throw StringError(
                    "Array at \(path) contains duplicate items. Duplicate found at index \(index): \(itemDesc)"
                )
            }
            seen.insert(itemKey)
        }
    }

    private func canonicalRepresentation(of value: Any) throws -> String {
        // Convert value to a canonical JSON string for comparison
        // This handles objects, arrays, strings, numbers, booleans, and null
        if let dict = value as? [String: Any] {
            // Sort keys for consistent comparison
            let sortedData = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
            return String(data: sortedData, encoding: .utf8) ?? ""
        } else if let array = value as? [Any] {
            let data = try JSONSerialization.data(withJSONObject: array, options: [])
            return String(data: data, encoding: .utf8) ?? ""
        } else if let string = value as? String {
            return "\"\(string)\""
        } else if let number = value as? NSNumber {
            // Handle booleans and numbers
            if isBoolean(number) {
                return number.boolValue ? "true" : "false"
            }
            return "\(number)"
        } else if value is NSNull {
            return "null"
        }
        return "\(value)"
    }

    private func validateAdditionalProperties(_ object: [String: Any], schema: [String: Any], path: String) throws {
        guard let additionalProps = schema[SchemaKeys.additionalProperties] else { return }

        let allowedProperties = collectAllAllowedProperties(from: schema)
        let extraProperties = Set(object.keys).subtracting(allowedProperties)

        if let allowsAdditional = additionalProps as? Bool, !allowsAdditional {
            guard extraProperties.isEmpty else {
                let extraList = extraProperties.sorted().joined(separator: ", ")
                throw StringError("Additional properties not allowed at \(path): \(extraList)")
            }
        } else if let additionalPropsSchema = additionalProps as? [String: Any] {
            for key in extraProperties {
                if let value = object[key] {
                    try validateValue(value, against: additionalPropsSchema, path: "\(path).\(key)")
                }
            }
        }
    }

    private func collectAllAllowedProperties(from schema: [String: Any]) -> Set<String> {
        var allowedProperties = Set<String>()

        if let properties = schema[SchemaKeys.properties] as? [String: Any] {
            allowedProperties.formUnion(properties.keys)
        }

        for compositionKey in [SchemaKeys.allOf, SchemaKeys.anyOf, SchemaKeys.oneOf] {
            if let schemas = schema[compositionKey] as? [[String: Any]] {
                for subSchema in schemas {
                    collectAllowedProperties(from: subSchema, into: &allowedProperties)
                }
            }
        }

        return allowedProperties
    }

    private func collectAllowedProperties(from schema: [String: Any], into allowedProperties: inout Set<String>) {
        collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: Any]) in
            allowedProperties.formUnion(properties.keys)
        }
    }

    private func validateNot(_ value: Any, schema: [String: Any], path: String) throws {
        do {
            try validateValue(value, against: schema, path: path)
            // If validation succeeds, it means the value matches the schema, which violates "not"
            let valueDesc = describeValue(value, maxLength: 200)
            throw StringError("Value at \(path) matches 'not' schema (should not match).\nValue: \(valueDesc)")
        } catch {
            // If validation fails, it's what we want for "not" - the value doesn't match
            // Only rethrow if it's our own "not" error
            if error.localizedDescription.contains("matches 'not' schema") {
                throw error
            }
            // Otherwise, validation failed as expected for "not", so we're good
            return
        }
    }

    private func validateUnevaluatedProperties(_ object: [String: Any], schema: [String: Any], path: String) throws {
        guard let unevaluatedProps = schema[SchemaKeys.unevaluatedProperties] as? Bool,
              !unevaluatedProps else {
            return
        }

        let evaluatedProperties = collectAllEvaluatedProperties(from: schema)
        let unevaluated = Set(object.keys).subtracting(evaluatedProperties)

        guard unevaluated.isEmpty else {
            let unevaluatedList = unevaluated.sorted().joined(separator: ", ")
            throw StringError("Unevaluated properties found at \(path): \(unevaluatedList)")
        }
    }

    private func collectAllEvaluatedProperties(from schema: [String: Any]) -> Set<String> {
        var evaluatedProperties = Set<String>()

        if let properties = schema[SchemaKeys.properties] as? [String: Any] {
            evaluatedProperties.formUnion(properties.keys)
        }

        if let required = schema[SchemaKeys.required] as? [String] {
            evaluatedProperties.formUnion(required)
        }

        for compositionKey in [SchemaKeys.allOf, SchemaKeys.anyOf, SchemaKeys.oneOf] {
            if let schemas = schema[compositionKey] as? [[String: Any]] {
                for subSchema in schemas {
                    collectEvaluatedProperties(from: subSchema, into: &evaluatedProperties)
                }
            }
        }

        return evaluatedProperties
    }

    private func collectRequiredProperties(from schema: [String: Any], into allRequired: inout [String]) {
        collectFromSchema(schema, key: SchemaKeys.required) { (required: [String]) in
            allRequired.append(contentsOf: required)
        }
    }

    private func collectProperties(from schema: [String: Any], into allProperties: inout [String: [String: Any]]) {
        collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: [String: Any]]) in
            allProperties.merge(properties) { _, new in new }
        }
    }

    private func collectEvaluatedProperties(from schema: [String: Any], into evaluatedProperties: inout Set<String>) {
        collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: Any]) in
            evaluatedProperties.formUnion(properties.keys)
        }
    }

    /// Generic helper to collect data from schema with $ref and allOf resolution
    private func collectFromSchema<T>(_ schema: [String: Any], key: String, collector: (T) -> Void) {
        // Collect from direct key
        if let value = schema[key] as? T {
            collector(value)
        }

        // Resolve and collect from $ref
        if let ref = schema[SchemaKeys.ref] as? String, ref.hasPrefix("#/") {
            let pointer = String(ref.dropFirst(2))
            let components = pointer.components(separatedBy: "/")
            if let referencedSchema = resolveReference(components: components, in: self.schema) {
                collectFromSchema(referencedSchema, key: key, collector: collector)
            }
        }

        // Recursively collect from allOf
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            for subSchema in allOf {
                collectFromSchema(subSchema, key: key, collector: collector)
            }
        }
    }

    private func resolveReference(components: [String], in schema: [String: Any]) -> [String: Any]? {
        var current: Any = schema

        for component in components {
            guard let dict = current as? [String: Any],
                  let next = dict[component]
            else {
                return nil
            }
            current = next
        }

        return current as? [String: Any]
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

    /// Extract a concise schema name for error reporting
    private func extractSchemaName(from schema: [String: Any], index: Int) -> String {
        // Check for $ref first
        if let ref = schema["$ref"] as? String {
            // Extract the last component of the reference path
            let components = ref.components(separatedBy: "/")
            if let last = components.last {
                return last
            }
        }

        // Check for const type value
        if let constValue = schema["const"] as? String {
            return constValue
        }

        // Check for type in properties
        if let properties = schema["properties"] as? [String: Any],
           let typeSchema = properties["type"] as? [String: Any],
           let oneOf = typeSchema["oneOf"] as? [[String: Any]],
           let firstConst = oneOf.first?["const"] as? String
        {
            return firstConst
        }

        // Fallback to index
        return "#\(index)"
    }

    /// Helper function to describe a value for debugging purposes
    internal func describeValue(_ value: Any, maxLength: Int = 100) -> String {
        let description: String

        switch value {
        case let str as String:
            description = "\"\(str)\""
        case let num as NSNumber:
            if isBoolean(num) {
                description = "\(num.boolValue) (boolean)"
            } else if CFNumberIsFloatType(num) {
                description = "\(num.doubleValue) (number)"
            } else {
                description = "\(num.intValue) (integer)"
            }
        case let array as [Any]:
            description = "[\(array.count) items]"
        case let dict as [String: Any]:
            let keys = dict.keys.sorted().prefix(5).joined(separator: ", ")
            let more = dict.keys.count > 5 ? ", ..." : ""
            description = "{keys: \(keys)\(more)}"
        case is NSNull:
            description = "null"
        default:
            description = "\(type(of: value))"
        }

        if description.count > maxLength {
            let truncated = description.prefix(maxLength - 3)
            return "\(truncated)..."
        }
        return description
    }
}
