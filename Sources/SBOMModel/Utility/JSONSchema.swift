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
    // MARK: - Constants

    private enum JSONLDKeys {
        static let context = "@context"
        static let graph = "@graph"
        static let id = "@id"
    }

    private enum SPDXKeys {
        static let spdxId = "spdxId"
    }

    private enum SchemaKeys {
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
        static let minItems = "minItems"
        static let maxItems = "maxItems"
        static let uniqueItems = "uniqueItems"
    }

    private let schema: [String: Any]

    package init(from schemaFilename: String) throws {
        guard let schemaURL = Bundle.module.url(forResource: schemaFilename, withExtension: "json") else {
            throw StringError(
                "SBOM schema file '\(schemaFilename).json' not found in bundle: \(Bundle.module.bundlePath)"
            )
        }
        let schemaData = try Data(contentsOf: schemaURL)
        guard let jsonObject = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw StringError("Invalid JSON schema format")
        }
        self.schema = jsonObject
    }

    package func validate(_ jsonObject: Any) throws {
        if self.isJSONLDDocument(jsonObject) {
            try self.validateJSONLDDocument(jsonObject as! [String: Any])
        } else {
            try self.validateValue(jsonObject, against: self.schema, path: "$")
        }
    }

    // MARK: - JSON-LD Validation

    private func isJSONLDDocument(_ jsonObject: Any) -> Bool {
        guard let rootDict = jsonObject as? [String: Any] else { return false }
        return rootDict[JSONLDKeys.context] != nil && rootDict[JSONLDKeys.graph] != nil
    }

    private func validateJSONLDDocument(_ rootDict: [String: Any]) throws {
        try self.validateJSONLDContext(rootDict[JSONLDKeys.context])

        guard let graph = rootDict[JSONLDKeys.graph] as? [Any] else {
            throw StringError("@graph at $ must be an array")
        }

        guard !graph.isEmpty else {
            throw StringError("@graph at $ is empty")
        }

        let graphElementSchema = self.extractGraphElementSchema()
        for (index, element) in graph.enumerated() {
            try self.validateValue(element, against: graphElementSchema, path: "$[@graph][\(index)]")
        }
    }

    private func validateJSONLDContext(_ context: Any?) throws {
        guard let contextString = context as? String else {
            throw StringError("@context at $ must be a string")
        }
        guard !contextString.isEmpty else {
            throw StringError("@context at $ is empty")
        }
    }

    private func extractGraphElementSchema() -> [String: Any] {
        // Graph elements use AnyClass schema (oneOf[1]) rather than root schema
        if let oneOf = schema[SchemaKeys.oneOf] as? [[String: Any]], oneOf.count > 1 {
            return oneOf[1]
        } else if let anyOf = schema[SchemaKeys.anyOf] as? [[String: Any]], !anyOf.isEmpty {
            return anyOf[0]
        }
        return self.schema
    }

    // MARK: - Core Validation

    private func validateValue(_ value: Any, against schema: [String: Any], path: String) throws {
        // Type validation
        if let expectedType = schema[SchemaKeys.type] as? String {
            try self.validateType(value, expectedType: expectedType, path: path)
        }

        // Schema composition keywords
        if let ref = schema[SchemaKeys.ref] as? String {
            try self.validateReference(value, ref: ref, path: path)
        }
        if let oneOf = schema[SchemaKeys.oneOf] as? [[String: Any]] {
            try self.validateOneOf(value, schemas: oneOf, path: path)
        }
        if let anyOf = schema[SchemaKeys.anyOf] as? [[String: Any]] {
            try self.validateAnyOf(value, schemas: anyOf, path: path)
        }
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            try self.validateAllOf(value, schemas: allOf, path: path)
        }
        if let notSchema = schema[SchemaKeys.not] as? [String: Any] {
            try self.validateNot(value, schema: notSchema, path: path)
        }

        // Value-specific validations
        if let constValue = schema[SchemaKeys.const] {
            try self.validateConst(value, expectedValue: constValue, path: path)
        }
        if let enumValues = schema[SchemaKeys.enumKey] as? [Any] {
            try self.validateEnum(value, allowedValues: enumValues, path: path)
        }

        // Type-specific validations
        try self.validateObjectIfNeeded(value, schema: schema, path: path)
        try self.validateArrayIfNeeded(value, schema: schema, path: path)
        try self.validateStringIfNeeded(value, schema: schema, path: path)
        try self.validateNumberIfNeeded(value, schema: schema, path: path)
    }

    private func validateObjectIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let objectValue = value as? [String: Any] else { return }

        let allRequired = self.collectAllRequired(from: schema)
        if !allRequired.isEmpty {
            try self.validateRequiredProperties(objectValue, required: allRequired, path: path)
        }

        let allProperties = self.collectAllProperties(from: schema)
        if !allProperties.isEmpty {
            try self.validateObjectProperties(objectValue, properties: allProperties, path: path)
        }

        try self.validateAdditionalProperties(objectValue, schema: schema, path: path)
        try self.validateUnevaluatedProperties(objectValue, schema: schema, path: path)
    }

    private func validateArrayIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let arrayValue = value as? [Any] else { return }

        if let items = schema[SchemaKeys.items] as? [String: Any] {
            try self.validateArrayItems(arrayValue, itemSchema: items, path: path)
        }
        try self.validateArrayConstraints(arrayValue, schema: schema, path: path)
    }

    private func validateStringIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let stringValue = value as? String else { return }

        if let pattern = schema[SchemaKeys.pattern] as? String {
            try self.validatePattern(stringValue, pattern: pattern, path: path)
        }
        if let format = schema[SchemaKeys.format] as? String {
            try self.validateFormat(stringValue, format: format, path: path)
        }
    }

    private func validateNumberIfNeeded(_ value: Any, schema: [String: Any], path: String) throws {
        guard let numberValue = value as? NSNumber else { return }
        try self.validateNumericConstraints(numberValue, schema: schema, path: path)
    }

    // MARK: - Schema Collection Helpers

    private func collectAllRequired(from schema: [String: Any]) -> [String] {
        var allRequired: [String] = []
        if let required = schema[SchemaKeys.required] as? [String] {
            allRequired.append(contentsOf: required)
        }
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            for subSchema in allOf {
                self.collectRequiredProperties(from: subSchema, into: &allRequired)
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
                self.collectProperties(from: subSchema, into: &allProperties)
            }
        }
        return allProperties
    }

    // MARK: - Type Validation

    private func validateType(_ value: Any, expectedType: String, path: String) throws {
        let (actualType, debugInfo) = self.determineActualType(value)

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
            return self.determineNumberType(number)
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
        let objCType = String(cString: number.objCType)

        // Check for boolean type
        if (objCType == "c" || objCType == "B") &&
            (number === kCFBooleanTrue as NSNumber || number === kCFBooleanFalse as NSNumber)
        {
            return ("boolean", "value: \(number.boolValue)")
        }

        // Check for floating point
        if CFNumberIsFloatType(number) {
            return ("number", "value: \(number.doubleValue)")
        }

        // Default to integer
        return ("integer", "value: \(number.intValue)")
    }

    private func validateRequiredProperties(_ object: [String: Any], required: [String], path: String) throws {
        for property in required {
            if self.isSPDXPropertySatisfied(property: property, in: object) {
                continue
            }
            guard object[property] != nil else {
                throw StringError("Missing required property '\(property)' at \(path)")
            }
        }
    }

    private func isSPDXPropertySatisfied(property: String, in object: [String: Any]) -> Bool {
        // SPDX 3.0.1 allows @id as substitute for spdxId in JSON-LD context
        property == SPDXKeys.spdxId && object[JSONLDKeys.id] != nil
    }

    private func validateObjectProperties(
        _ object: [String: Any],
        properties: [String: [String: Any]],
        path: String
    ) throws {
        for (key, value) in object {
            guard let propertySchema = resolvePropertySchema(key: key, properties: properties, object: object) else {
                continue
            }
            try self.validateValue(value, against: propertySchema, path: "\(path).\(key)")
        }
    }

    private func resolvePropertySchema(
        key: String,
        properties: [String: [String: Any]],
        object: [String: Any]
    ) -> [String: Any]? {
        // Direct schema lookup
        if let schema = properties[key] {
            return schema
        }

        // SPDX JSON-LD: @id can use spdxId schema
        if key == JSONLDKeys.id, let schema = properties[SPDXKeys.spdxId] {
            return schema
        }

        // SPDX JSON-LD: Skip spdxId if @id is present
        if key == SPDXKeys.spdxId && object[JSONLDKeys.id] != nil {
            return nil
        }

        return nil
    }

    private func validateArrayItems(_ array: [Any], itemSchema: [String: Any], path: String) throws {
        for (index, item) in array.enumerated() {
            try self.validateValue(item, against: itemSchema, path: "\(path)[\(index)]")
        }
    }

    private func validateEnum(_ value: Any, allowedValues: [Any], path: String) throws {
        let isValid = allowedValues.contains { allowedValue in
            self.areEqual(value, allowedValue)
        }

        if !isValid {
            let valueStr = self.describeValue(value)
            let allowedStr = allowedValues.map { self.describeValue($0) }.joined(separator: ", ")
            throw StringError(
                "Value at \(path) is not one of the allowed enum values. Got: \(valueStr), allowed: [\(allowedStr)]"
            )
        }
    }

    private func validatePattern(_ value: String, pattern: String, path: String) throws {
        // Special case for SPDX 3.0.1 JSON-LD: Allow simple identifiers as references
        // In JSON-LD @graph context, references can be simple identifiers (not full IRIs)
        // that point to other objects in the graph. This applies when validating against IRI pattern.
        // BUT: Don't apply this to the 'type' field, which should match enum values, not IRI pattern
        // Special case for SPDX 3.0.1 JSON-LD: Allow simple identifiers as references
        // In JSON-LD @graph context, when validating against IRI pattern, allow simple identifiers
        // that reference other objects in the graph. Exclude:
        // - The 'type' field (should match enum, not IRI)
        // - Blank nodes (starting with _:) which have their own pattern
        // - Values that already contain a colon (they should match IRI pattern naturally)
        //   EXCEPT for values with single colon which are likely namespaced identifiers
        let colonCount = value.filter { $0 == ":" }.count
        let allowSimpleId = colonCount <= 1 // Allow identifiers with 0 or 1 colon (e.g., "pkg:name" or "name")

        if pattern == "^(?!_:).+:.+" && path.contains("[@graph][") && !path.hasSuffix(".type") && !value
            .hasPrefix("_:") && allowSimpleId
        {
            // Allow plain identifiers (like "swift-package-manager-fork") or UUIDs without colons
            // These are valid references in JSON-LD even if they don't match strict IRI patterns
            let simpleIdPattern = "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$"
            let uuidPattern = "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"

            if let idRegex = try? NSRegularExpression(pattern: simpleIdPattern),
               idRegex
               .firstMatch(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)) != nil
            {
                return // Valid simple identifier reference
            }

            if let uuidRegex = try? NSRegularExpression(pattern: uuidPattern),
               uuidRegex
               .firstMatch(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)) != nil
            {
                return // Valid UUID reference
            }
        }

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
            // Skip unknown formats
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
                try self.validateValue(value, against: referencedSchema, path: path)
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
                try self.validateValue(value, against: schema, path: path)

                // Handles SPDX schema validation error: "Value at $ matches multiple oneOf schemas (expected exactly
                // one). Matched 2 schemas at indices: 0, 1"
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
            let valueDesc = self.describeValue(value, maxLength: 200)
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
                try self.validateValue(value, against: schema, path: path)
                return // Successfully validated against one schema, we're done
            } catch {
                // Extract just the schema name/type for concise error reporting
                let schemaName = self.extractSchemaName(from: schema, index: index)
                schemaNames.append(schemaName)

                // For specific schemas, capture the detailed error
                if schemaName == "CreationInfo" || schemaName == "ExternalIdentifier" || schemaName == "Relationship" {
                    detailedErrors[schemaName] = error.localizedDescription
                }
            }
        }

        // None of the schemas matched
        let valueDesc = self.describeValue(value, maxLength: 200)

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
                try self.validateValue(value, against: schema, path: path)
            } catch {
                errors.append("Schema \(index): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            let valueDesc = self.describeValue(value, maxLength: 200)
            let allErrors = errors.joined(separator: "\n  ")
            throw StringError(
                "Value at \(path) does not match all allOf schemas.\nValue: \(valueDesc)\nErrors:\n  \(allErrors)"
            )
        }
    }

    private func validateConst(_ value: Any, expectedValue: Any, path: String) throws {
        if !self.areEqual(value, expectedValue) {
            let valueDesc = self.describeValue(value)
            let expectedDesc = self.describeValue(expectedValue)
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
            try self.validateUniqueItems(array, path: path)
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
                let itemDesc = self.describeValue(item, maxLength: 100)
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
            let objCType = String(cString: number.objCType)
            if objCType == "c" || objCType == "B" {
                if number === kCFBooleanTrue as NSNumber || number === kCFBooleanFalse as NSNumber {
                    return number.boolValue ? "true" : "false"
                }
            }
            return "\(number)"
        } else if value is NSNull {
            return "null"
        }
        return "\(value)"
    }

    private func validateAdditionalProperties(_ object: [String: Any], schema: [String: Any], path: String) throws {
        guard let additionalProps = schema[SchemaKeys.additionalProperties] else { return }

        let allowedProperties = self.collectAllAllowedProperties(from: schema)
        let extraProperties = Set(object.keys).subtracting(allowedProperties)

        if let isFalse = additionalProps as? Bool, !isFalse {
            guard extraProperties.isEmpty else {
                let extraList = extraProperties.sorted().joined(separator: ", ")
                throw StringError("Additional properties not allowed at \(path): \(extraList)")
            }
        } else if let additionalPropsSchema = additionalProps as? [String: Any] {
            for key in extraProperties {
                if let value = object[key] {
                    try self.validateValue(value, against: additionalPropsSchema, path: "\(path).\(key)")
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
                    self.collectAllowedProperties(from: subSchema, into: &allowedProperties)
                }
            }
        }

        return allowedProperties
    }

    private func collectAllowedProperties(from schema: [String: Any], into allowedProperties: inout Set<String>) {
        self.collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: Any]) in
            allowedProperties.formUnion(properties.keys)
        }
    }

    private func validateNot(_ value: Any, schema: [String: Any], path: String) throws {
        do {
            try self.validateValue(value, against: schema, path: path)
            // If validation succeeds, it means the value matches the schema, which violates "not"
            let valueDesc = self.describeValue(value, maxLength: 200)
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
              !unevaluatedProps
        else {
            return
        }

        let evaluatedProperties = self.collectAllEvaluatedProperties(from: schema)
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
                    self.collectEvaluatedProperties(from: subSchema, into: &evaluatedProperties)
                }
            }
        }

        return evaluatedProperties
    }

    private func collectRequiredProperties(from schema: [String: Any], into allRequired: inout [String]) {
        self.collectFromSchema(schema, key: SchemaKeys.required) { (required: [String]) in
            allRequired.append(contentsOf: required)
        }
    }

    private func collectProperties(from schema: [String: Any], into allProperties: inout [String: [String: Any]]) {
        self.collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: [String: Any]]) in
            allProperties.merge(properties) { _, new in new }
        }
    }

    private func collectEvaluatedProperties(from schema: [String: Any], into evaluatedProperties: inout Set<String>) {
        self.collectFromSchema(schema, key: SchemaKeys.properties) { (properties: [String: Any]) in
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
                self.collectFromSchema(referencedSchema, key: key, collector: collector)
            }
        }

        // Recursively collect from allOf
        if let allOf = schema[SchemaKeys.allOf] as? [[String: Any]] {
            for subSchema in allOf {
                self.collectFromSchema(subSchema, key: key, collector: collector)
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
    private func describeValue(_ value: Any, maxLength: Int = 100) -> String {
        let description: String

        switch value {
        case let str as String:
            description = "\"\(str)\""
        case let num as NSNumber:
            let objCType = String(cString: num.objCType)
            if objCType == "c" || objCType == "B" {
                if num === kCFBooleanTrue as NSNumber || num === kCFBooleanFalse as NSNumber {
                    description = "\(num.boolValue) (boolean)"
                } else {
                    description = "\(num.intValue) (integer)"
                }
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
