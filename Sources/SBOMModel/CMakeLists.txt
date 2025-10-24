# This source file is part of the Swift open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(SBOMModel
  Core/SBOMCommit.swift
  Core/SBOMComponent.swift
  Core/SBOMDependency.swift
  Core/SBOMDocument.swift
  Core/SBOMLicense.swift
  Core/SBOMMetadata.swift
  Core/SBOMOriginator.swift
  Core/SBOMPerson.swift
  Core/SBOMTool.swift)
target_link_libraries(SBOMModel PUBLIC
  TSCBasic
  TSCUtility
  Basics)
# NOTE(compnerd) workaround for CMake not setting up include flags yet
set_target_properties(SBOMModel PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

install(TARGETS SBOMModel
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
set_property(GLOBAL APPEND PROPERTY SwiftPM_EXPORTS SBOMModel)