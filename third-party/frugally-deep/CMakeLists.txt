therock_subproject_fetch(therock-frugally-deep-sources
  CMAKE_PROJECT
  # Originally mirrored from: https://github.com/Dobiasd/frugally-deep/archive/refs/tags/v0.16.2.tar.gz
  URL https://github.com/Dobiasd/frugally-deep/archive/refs/tags/v0.15.20-p0.tar.gz
)

therock_cmake_subproject_declare(therock-frugally-deep
  BACKGROUND_BUILD
  EXCLUDE_FROM_ALL
  NO_MERGE_COMPILE_COMMANDS
  OUTPUT_ON_FAILURE
  EXTERNAL_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/source"
  BUILD_DEPS
    therock-eigen
    therock-nlohmann-json
    therock-FunctionalPlus
)
therock_cmake_subproject_provide_package(
  therock-frugally-deep frugally-deep lib/cmake/frugally-deep)
therock_cmake_subproject_activate(therock-frugally-deep)

add_dependencies(therock-third-party therock-frugally-deep)
