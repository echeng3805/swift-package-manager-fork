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

internal struct CDXValidator: SBOMValidatorProtocol {
    private let validator: SBOMValidator
    
    internal init(schema: [String: Any]) {
        self.validator = SBOMValidator(schema: schema)
    }
    
    internal func validate(_ jsonObject: Any) throws {
        try validator.validate(jsonObject)
    }
    
    internal func validateValue(_ value: Any, path: String) throws {
        try validator.validateValue(value, path: path)
    }
}
