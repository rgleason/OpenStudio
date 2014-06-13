if (USE_PCH)
else()
  macro(AddPCH TARGET_NAME)
  endmacro()
endif()

# Add google tests macro
macro(ADD_GOOGLE_TESTS executable)
  foreach ( source ${ARGN} )
    string(REGEX MATCH .*cpp source "${source}")
    if(source)
      file(READ "${source}" contents)
      string(REGEX MATCHALL "TEST_?F?\\(([A-Za-z_0-9 ,]+)\\)" found_tests ${contents})
      foreach(hit ${found_tests})
        string(REGEX REPLACE ".*\\(([A-Za-z_0-9]+)[, ]*([A-Za-z_0-9]+)\\).*" "\\1.\\2" test_name ${hit})
        add_test(${test_name} "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${executable}" --gtest_filter=${test_name})
      endforeach(hit)
    endif()
  endforeach()
endmacro()

# Create source groups automatically based on file path
MACRO( CREATE_SRC_GROUPS SRC )
  FOREACH( F ${SRC} )
    STRING( REGEX MATCH "(^.*)([/\\].*$)" M ${F} )
    IF(CMAKE_MATCH_1)
      STRING( REGEX REPLACE "[/\\]" "\\\\" DIR ${CMAKE_MATCH_1} )
      SOURCE_GROUP( ${DIR} FILES ${F} )
    ELSE()
      SOURCE_GROUP( \\ FILES ${F} )
    ENDIF()
  ENDFOREACH()
ENDMACRO()

# Create test targets
macro( CREATE_TEST_TARGETS BASE_NAME SRC DEPENDENCIES )
  IF( BUILD_TESTING )
    ADD_EXECUTABLE( ${BASE_NAME}_tests ${SRC} )

    LIST( APPEND ALL_TESTING_TARGETS "${BASE_NAME}_tests" )
    SET( ALL_TESTING_TARGETS "${ALL_TESTING_TARGETS}" PARENT_SCOPE)


    CREATE_SRC_GROUPS( "${SRC}" )
    
    GET_TARGET_PROPERTY(BASE_NAME_TYPE ${BASE_NAME} TYPE)
    IF ("${BASE_NAME_TYPE}" STREQUAL "EXECUTABLE")
      # don't link base name
      SET(ALL_DEPENDENCIES ${DEPENDENCIES} )
    ELSE()
      # also link base name
      SET(ALL_DEPENDENCIES ${BASE_NAME} ${DEPENDENCIES} )
    ENDIF()
      
    TARGET_LINK_LIBRARIES( ${BASE_NAME}_tests 
      ${ALL_DEPENDENCIES} 
      gtest 
      gtest_main
    )

    ADD_GOOGLE_TESTS( ${BASE_NAME}_tests ${SRC} )
    ADD_DEPENDENCIES("${BASE_NAME}_tests" "${BASE_NAME}_resources")
    
    IF(ENABLE_TEST_RUNNER_TARGETS)
      ADD_CUSTOM_TARGET( ${target_name}_run_tests
        COMMAND ${BASE_NAME}_tests
      DEPENDS ${target_name}_tests
      WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" )
    ENDIF()

    AddPCH( ${BASE_NAME}_tests )

    ## suppress deprecated warnings in unit tests
    IF(UNIX)
      SET_TARGET_PROPERTIES( ${ALL_TESTING_TARGETS} PROPERTIES COMPILE_FLAGS "-Wno-deprecated-declarations" )
    ELSEIF(MSVC)
      SET_TARGET_PROPERTIES( ${ALL_TESTING_TARGETS} PROPERTIES COMPILE_FLAGS "/wd4996" )
    ENDIF()

  ENDIF()
endmacro()


MACRO( MAKE_LITE_SQL_TARGET IN_FILE BASE_FILE )
SET(cmake_script
"
FILE(READ "\"${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.cpp\"" text)
STRING(REPLACE ${BASE_FILE}.hpp ${BASE_FILE}.hxx modified_text \"\${text}\")
FILE(WRITE "\"${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.cxx\"" \"\${modified_text}\")
"
)
FILE(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}fix.cmake" ${cmake_script})
ADD_CUSTOM_COMMAND(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.hxx" "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.cxx"
  COMMAND "${LITESQL_GEN_EXE}" --output-dir="${CMAKE_CURRENT_BINARY_DIR}" --target=c++ "${CMAKE_CURRENT_SOURCE_DIR}/${IN_FILE}"
  COMMAND "${CMAKE_COMMAND}" -E rename "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.hpp" "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.hxx"
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}fix.cmake"
  COMMAND "${CMAKE_COMMAND}" -E remove -f "${CMAKE_CURRENT_BINARY_DIR}/${BASE_FILE}.cpp"
  DEPENDS litesql-gen "${CMAKE_CURRENT_SOURCE_DIR}/${IN_FILE}"
)
ENDMACRO()


# add a swig target
# KEY_I_FILE should include path, see src/utilities/CMakeLists.txt.
MACRO( MAKE_SWIG_TARGET NAME SIMPLENAME KEY_I_FILE I_FILES PARENT_TARGET PARENT_SWIG_TARGETS)
  SET(DEPENDS "${PARENT_TARGET}")
  SET( SWIG_DEFINES "" )
  SET( SWIG_COMMON "" )

  ##
  ## Begin collection of requirements to reduce SWIG regenerations
  ## and fix parallel build issues
  ##

 
  # Get all of the source files for the parent target this SWIG library is wrapping 
  GET_TARGET_PROPERTY(target_files ${PARENT_TARGET} SOURCES)
  
  FOREACH(f ${target_files})
    # Get the extension of the source file
    GET_SOURCE_FILE_PROPERTY(p "${f}" LOCATION)
    GET_FILENAME_COMPONENT(extension "${p}" EXT)

    # If it's a header file ("*.h*") add it to the list of headers
    IF ("${extension}" MATCHES "\\.h.*")
      IF ("${extension}" MATCHES "\\..xx")
        LIST(APPEND GeneratedHeaders "${p}")
      ELSE()
        LIST(APPEND RequiredHeaders "${p}")
      ENDIF()
    ENDIF()
  ENDFOREACH()
  

  # Now, append all of the .i* files provided to the macro to the
  # list of required headers.
  FOREACH(i ${I_FILES})
    GET_SOURCE_FILE_PROPERTY(p "${i}" LOCATION)
    GET_FILENAME_COMPONENT(extension "${p}" EXT)
    IF ("${extension}" MATCHES "\\..xx")
      LIST(APPEND GeneratedHeaders "${p}")
    ELSE()
      LIST(APPEND RequiredHeaders "${p}")
    ENDIF()
  ENDFOREACH()

  # RequiredHeaders now represents all of the headers and .i files that all
  # of the SWIG targets generated by this macro call rely on.
  # And GeneratedHeaders contains all .ixx and .hxx files needed to make 
  # these SWIG targets

  SET(ParentSWIGWrappers "")
  # Now we loop through all of the parent swig targets and collect the requirements from them
  FOREACH(p ${PARENT_SWIG_TARGETS})
    GET_TARGET_PROPERTY(target_files "ruby_${p}" SOURCES)

    IF ("${target_files}" STREQUAL "target_files-NOTFOUND")
      MESSAGE(FATAL_ERROR "Unable to locate sources for ruby_${p}, there is probably an error in the build order for ${NAME} in the top level CMakeLists.txt or you have not properly specified the dependencies in MAKE_SWIG_TARGET for ${NAME}")
    ENDIF()

    #MESSAGE(STATUS "${target_files}")
    # This is the real data collection
    LIST(APPEND ParentSWIGWrappers ${${p}_SWIG_Depends})
  ENDFOREACH()


  # Reduce the size of the RequiredHeaders list
  LIST(REMOVE_DUPLICATES RequiredHeaders)
  
  IF (GeneratedHeaders)
    LIST(REMOVE_DUPLICATES GeneratedHeaders)
  ENDIF()
  
  # Here we now have:
  #  RequiredHeaders: flat list of all of the headers from the library we are currently wrapping and
  #                   all of the libraries that it depends on

  # Export the required headers variable up to the next level so that further SWIG targets can look it up
  #  SET( exportname "${NAME}RequiredHeaders")
  
  # Oh, and also export it to this level, for peers, like the Utilities breakouts and the Model breakouts
  SET( ${exportname} "${RequiredHeaders}")
  SET( ${exportname} "${RequiredHeaders}"  PARENT_SCOPE)

  IF(NOT TARGET ${PARENT_TARGET}_GeneratedHeaders)
    # Add a command to generate the generated headers discovered at this point.
    ADD_CUSTOM_COMMAND(
      OUTPUT "${CMAKE_BINARY_DIR}/${PARENT_TARGET}_HeadersGenerated_done.stamp"
      COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/${PARENT_TARGET}_HeadersGenerated_done.stamp"

      DEPENDS ${GeneratedHeaders}
    ) 

    # And a target that calls the above command
    ADD_CUSTOM_TARGET(${PARENT_TARGET}_GeneratedHeaders
      SOURCES "${CMAKE_BINARY_DIR}/${PARENT_TARGET}_HeadersGenerated_done.stamp"
      )

    # Now we say that our PARENT_TARGET depends on this new GeneratedHeaders
    # target. This is where the magic happens. By making both the parent
    # and this *_swig.cxx files below rely on this new target we force all
    # of the generated files to be generated before either the
    # PARENT_TARGET is built or the cxx files are generated. This solves the problems with
    # parallel builds trying to generate the same file multiple times while still
    # allowing files to compile in parallel
    ADD_DEPENDENCIES(${PARENT_TARGET} ${PARENT_TARGET}_GeneratedHeaders)
  ENDIF()

  ##
  ## Finish requirements gathering
  ##




  
  INCLUDE_DIRECTORIES( ${RUBY_INCLUDE_DIRS} )

  IF(WIN32)
    SET( SWIG_DEFINES "-D_WINDOWS" )
    SET( SWIG_COMMON "-Fmicrosoft" )
  ENDIF(WIN32)

  # Ruby bindings
  
  # check if this is the OpenStudioUtilities project
  STRING( REGEX MATCH "OpenStudioUtilities"  IS_UTILTIES "${NAME}")

  SET( swig_target "ruby_${NAME}" )

  # wrapper file output
  SET(SWIG_WRAPPER "ruby_${NAME}_wrap.cxx")    
  SET(SWIG_WRAPPER_FULL_PATH "${CMAKE_CURRENT_BINARY_DIR}/${SWIG_WRAPPER}") 
  # ruby dlls should be all lowercase
  STRING(TOLOWER "${NAME}" LOWER_NAME)

  # utilities goes into OpenStudio:: directly, everything else is nested
  IF(IS_UTILTIES)
    SET( MODULE "OpenStudio")
  ELSE()
    SET( MODULE "OpenStudio::${SIMPLENAME}" )
  ENDIF()    

  IF(DEFINED OpenStudioCore_SWIG_INCLUDE_DIR)
    SET(extra_includes "-I${OpenStudioCore_SWIG_INCLUDE_DIR}")
  ENDIF()

  IF(DEFINED OpenStudioCore_DIR)
    SET(extra_includes2 "-I${OpenStudioCore_DIR}/src")
  ENDIF()

  SET(this_depends ${ParentSWIGWrappers})
  LIST(APPEND this_depends ${PARENT_TARGET}_GeneratedHeaders)
  LIST(APPEND this_depends ${RequiredHeaders})
  LIST(REMOVE_DUPLICATES this_depends)
  SET(${NAME}_SWIG_Depends "${this_depends}")
  SET(${NAME}_SWIG_Depends "${this_depends}" PARENT_SCOPE)

  #MESSAGE(STATUS "${${NAME}_SWIG_Depends}")

  ADD_CUSTOM_COMMAND(
    OUTPUT "${SWIG_WRAPPER}" 
    COMMAND "${SWIG_EXECUTABLE}"
            "-ruby" "-c++" "-fvirtual" "-I${CMAKE_SOURCE_DIR}/src" "-I${CMAKE_BINARY_DIR}/src" "${extra_includes}" "${extra_includes2}"
            -features autodoc=1
            -module "${MODULE}" -initname "${LOWER_NAME}"
            -o "${SWIG_WRAPPER_FULL_PATH}"
            "${SWIG_DEFINES}" ${SWIG_COMMON} "${KEY_I_FILE}"
    DEPENDS ${this_depends}
  )


  ADD_LIBRARY(
    ${swig_target}
    MODULE
    ${SWIG_WRAPPER} 
  )

  
  AddPCH( ${swig_target} )

  # run rdoc
  if( BUILD_DOCUMENTATION )
    add_custom_target( ${swig_target}_rdoc
      ${CMAKE_COMMAND} -E chdir "${CMAKE_BINARY_DIR}/ruby/${CMAKE_CFG_INTDIR}" "${RUBY_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/../developer/ruby/SwigWrapToRDoc.rb" "${CMAKE_BINARY_DIR}/ruby/${CMAKE_CFG_INTDIR}/" "${SWIG_WRAPPER_FULL_PATH}" "${NAME}"
      DEPENDS ${SWIG_WRAPPER} 
    )

    # Add this documentation target to the list of all targets
    list( APPEND ALL_RDOC_TARGETS ${swig_target}_rdoc )
    set( ALL_RDOC_TARGETS "${ALL_RDOC_TARGETS}" PARENT_SCOPE )

  endif()

  SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES PREFIX "" )
  SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES OUTPUT_NAME "${LOWER_NAME}" )
  IF(APPLE)
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES SUFFIX ".bundle" )
    #      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LINK_FLAGS "-undefined dynamic_lookup")
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LINK_FLAGS "-undefined suppress -flat_namespace")
  ENDIF()

  ## suppress deprecated warnings in swig bindings
  IF(UNIX)
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-deprecated-declarations" )
  ELSEIF(MSVC)
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/wd4996" )
  ENDIF()

  IF(MSVC)
    # if visual studio 2010
    IF (${MSVC_VERSION} EQUAL 1600)
      # trouble with macro redefinition in win32.h of Ruby
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj /wd4005" )
    ELSE()
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj" )  
    ENDIF()
  ELSEIF(APPLE AND NOT CMAKE_COMPILER_IS_GNUCXX)
     SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-dynamic-class-memaccess" )
  ENDIF()

  IF (CMAKE_COMPILER_IS_GNUCXX)
    IF (GCC_VERSION VERSION_GREATER 4.6 OR GCC_VERSION VERSION_EQUAL 4.6)
      SET_SOURCE_FILES_PROPERTIES( ${SWIG_WRAPPER} PROPERTIES COMPILE_FLAGS "-Wno-uninitialized -Wno-unused-but-set-variable" )  
    else()
      SET_SOURCE_FILES_PROPERTIES( ${SWIG_WRAPPER} PROPERTIES COMPILE_FLAGS "-Wno-uninitialized" )  
    endif()
  ENDIF()
   
  SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/ruby/" )
  IF (RUBY_VERSION_MAJOR EQUAL "2" AND MSVC)
    # Ruby 2 requires modules to have a .so extension, even on windows
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES SUFFIX ".so" )
  ENDIF()
  SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/ruby/" )
  SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/ruby/" )
  TARGET_LINK_LIBRARIES( ${swig_target} ${PARENT_TARGET} ${DEPENDS} ${RUBY_LIBRARY} )

  IF(APPLE)
    SET( _NAME "${LOWER_NAME}.bundle" )
  ELSEIF(RUBY_VERSION_MAJOR EQUAL "2" AND MSVC)
    SET( _NAME "${LOWER_NAME}.so")
  ELSE()
    SET( _NAME "${LOWER_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
  ENDIF()

  IF( WIN32 OR APPLE )
    INSTALL( TARGETS ${swig_target} DESTINATION Ruby/openstudio/ )

    SET( Prereq_Dirs
      "${CMAKE_BINARY_DIR}/Products/"
      "${CMAKE_BINARY_DIR}/Products/Release"
      "${CMAKE_BINARY_DIR}/Products/Debug"
    )

    INSTALL(CODE "
      #MESSAGE( \"INSTALLING SWIG_TARGET: ${swig_target}  with NAME = ${_NAME}\" )
      INCLUDE(GetPrerequisites)
      GET_PREREQUISITES( \${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/${_NAME} PREREQUISITES 1 1 \"\" \"${Prereq_Dirs}\" )
      #MESSAGE( \"PREREQUISITES = \${PREREQUISITES}\" )


     IF(WIN32)
       LIST(REVERSE PREREQUISITES)
     ENDIF(WIN32)

     FOREACH( PREREQ IN LISTS PREREQUISITES )
       GP_RESOLVE_ITEM( \"\" \${PREREQ} \"\" \"${LIBRARY_SEARCH_DIRECTORY}\" resolved_item_var )
       EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/\")

       GET_FILENAME_COMPONENT( PREREQNAME \${resolved_item_var} NAME)

       IF(APPLE)
         EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PREREQ}\" \"@loader_path/\${PREREQNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/${_NAME}\")
         FOREACH( PR IN LISTS PREREQUISITES )
          GP_RESOLVE_ITEM( \"\" \${PR} \"\" \"\" PRPATH )
          GET_FILENAME_COMPONENT( PRNAME \${PRPATH} NAME)
          EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PR}\" \"@loader_path/\${PRNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/\${PREREQNAME}\")
         ENDFOREACH()
       ELSE()
         IF(EXISTS \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/thirdparty.rb\")
           file(READ \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/thirdparty.rb\" TEXT )
         ELSE()
           SET( TEXT \"\" )
         ENDIF()
         STRING( REGEX MATCH \${PREREQNAME} MATCHVAR \"\${TEXT}\" )
         IF( NOT (\"\${MATCHVAR}\" STREQUAL \"\${PREREQNAME}\") )
           file(APPEND \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/thirdparty.rb\" \"DL::dlopen \\\"\\\#{File.dirname(__FILE__)}/\${PREREQNAME}\\\"\n\" )
         ENDIF()
       ENDIF()
     ENDFOREACH( PREREQ IN LISTS PREREQUISITES )
     IF(APPLE)
       file(COPY \"${QT_LIBRARY_DIR}/QtGui.framework/Resources/qt_menu.nib\" 
        DESTINATION \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/Resources/\")
     ENDIF()
    " )
  ELSE(WIN32 OR APPLE)
    INSTALL(TARGETS ${swig_target} DESTINATION "${RUBY_MODULE_ARCH_DIR}")
  ENDIF()
  IF(UNIX)
  # do not write file on unix, existence of file is checked before it is loaded
  #INSTALL( CODE "
  #  file(WRITE \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/thirdparty.rb\" \"# Nothing to see here\" )
  #" )
  ENDIF()

  EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/Ruby/openstudio/\")

  # add this target to a "global" variable so ruby tests can require these
  LIST( APPEND ALL_RUBY_BINDING_TARGETS "${swig_target}" )
  SET( ALL_RUBY_BINDING_TARGETS "${ALL_RUBY_BINDING_TARGETS}" PARENT_SCOPE )

  # Doesn't look like this is used
  # add this target to a "global" variable so ruby tests can require these
  #LIST( APPEND ALL_RDOCIFY_FILES "${SWIG_WRAPPER}" )
  #SET( ALL_RDOCIFY_FILES "${ALL_RDOCIFY_FILES}" PARENT_SCOPE )

  # add this target to a "global" variable so ruby tests can require these
  LIST( APPEND ALL_RUBY_BINDING_WRAPPERS "${SWIG_WRAPPER}" )
  SET( ALL_RUBY_BINDING_WRAPPERS "${ALL_RUBY_BINDING_WRAPPERS}" PARENT_SCOPE )

  # add this target to a "global" variable so ruby tests can require these
  LIST( APPEND ALL_RUBY_BINDING_WRAPPERS_FULL_PATH "${SWIG_WRAPPER_FULL_PATH}" )
  SET( ALL_RUBY_BINDING_WRAPPERS_FULL_PATH "${ALL_RUBY_BINDING_WRAPPERS_FULL_PATH}" PARENT_SCOPE )
  
  # Python bindings    
  IF ( PYTHON_LIBRARY AND BUILD_PYTHON_BINDINGS )
    SET( swig_target "python_${NAME}" )
    
    # utilities goes into OpenStudio. directly, everything else is nested
    # DLM: SWIG generates a file ${MODULE}.py for each module, however we have several libraries in the same module
    # so these clobber each other.  Making these unique, e.g. MODULE = TOLOWER "${NAME}", generates unique .py wrappers
    # but the module names are unknown and the bindings fail to load.  I think we need to write our own custom OpenStudio.py
    # wrapper that imports all of the libraries/python wrappers into the appropriate modules.  
    # http://docs.python.org/2/tutorial/modules.html
    # http://docs.python.org/2/library/imp.html
 
    SET(MODULE ${LOWER_NAME})
      
    ADD_CUSTOM_COMMAND(
      OUTPUT "python_${NAME}_wrap.cxx"
      COMMAND "${SWIG_EXECUTABLE}"
               "-python" "-c++" 
               -features autodoc=1
               -outdir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/python "-I${CMAKE_SOURCE_DIR}/src" "-I${CMAKE_BINARY_DIR}/src"
               -module "${MODULE}"
               -o "${CMAKE_CURRENT_BINARY_DIR}/python_${NAME}_wrap.cxx"
               "${SWIG_DEFINES}" ${SWIG_COMMON} ${KEY_I_FILE}
      DEPENDS ${this_depends}
    )

    ADD_LIBRARY(
      ${swig_target}
      MODULE
      python_${NAME}_wrap.cxx 
    )

    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES OUTPUT_NAME _${LOWER_NAME} )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES PREFIX "" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/python/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/python/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/python/" )
    IF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj" )
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES SUFFIX ".pyd" )
    ELSEIF(APPLE AND NOT CMAKE_COMPILER_IS_GNUCXX)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-dynamic-class-memaccess" )
    ENDIF()

    ## suppress deprecated warnings in swig bindings
    IF(UNIX)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-deprecated-declarations" )
    ELSEIF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/wd4996" )
    ENDIF()

    TARGET_LINK_LIBRARIES( ${swig_target} ${PARENT_TARGET} ${DEPENDS} ${PYTHON_LIBRARY} )

    ADD_DEPENDENCIES("${swig_target}" "${PARENT_TARGET}_resources")

    IF(MSVC)
      SET( _NAME "_${LOWER_NAME}.pyd")
    ELSE()
      SET( _NAME "_${LOWER_NAME}.so")
    ENDIF()

    IF( WIN32 OR APPLE )
      INSTALL( TARGETS ${swig_target} DESTINATION Python/openstudio/ )

      SET( Prereq_Dirs
        "${CMAKE_BINARY_DIR}/Products/"
        "${CMAKE_BINARY_DIR}/Products/Release"
        "${CMAKE_BINARY_DIR}/Products/Debug"
      )

      INSTALL(CODE "
        INCLUDE(GetPrerequisites)
        GET_PREREQUISITES( \${CMAKE_INSTALL_PREFIX}/Python/openstudio/${_NAME} PREREQUISITES 1 1 \"\" \"${Prereq_Dirs}\" )

       IF(WIN32)
         LIST(REVERSE PREREQUISITES)
       ENDIF(WIN32)

       FOREACH( PREREQ IN LISTS PREREQUISITES )
         GP_RESOLVE_ITEM( \"\" \${PREREQ} \"\" \"${LIBRARY_SEARCH_DIRECTORY}\" resolved_item_var )
         EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/Python/openstudio/\")

         GET_FILENAME_COMPONENT( PREREQNAME \${resolved_item_var} NAME)

         IF(APPLE)
           EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PREREQ}\" \"@loader_path/\${PREREQNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Python/openstudio/${_NAME}\")
           FOREACH( PR IN LISTS PREREQUISITES )
            GP_RESOLVE_ITEM( \"\" \${PR} \"\" \"\" PRPATH )
            GET_FILENAME_COMPONENT( PRNAME \${PRPATH} NAME)
            EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PR}\" \"@loader_path/\${PRNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Python/openstudio/\${PREREQNAME}\")
           ENDFOREACH()
         ENDIF()
       ENDFOREACH( PREREQ IN LISTS PREREQUISITES )

       IF(APPLE)
         file(COPY \"${QT_LIBRARY_DIR}/QtGui.framework/Resources/qt_menu.nib\" 
          DESTINATION \"\${CMAKE_INSTALL_PREFIX}/Python/openstudio/Resources/\")
       ENDIF()
      " )
    ELSE(WIN32 OR APPLE)
      INSTALL(TARGETS ${swig_target} DESTINATION "lib/openstudio/python")
    ENDIF()

    INSTALL(FILES ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/python/${LOWER_NAME}.py DESTINATION Python/openstudio/)
    
    # add this target to a "global" variable so python tests can require these
    LIST( APPEND ALL_PYTHON_BINDING_TARGETS "${swig_target}" )
   
    SET( ALL_PYTHON_BINDING_TARGETS "${ALL_PYTHON_BINDING_TARGETS}" PARENT_SCOPE )
  ENDIF()

  # csharp
  IF ( BUILD_CSHARP_BINDINGS )
    SET( swig_target "csharp_${NAME}" )
    
    IF(IS_UTILTIES)
      SET( NAMESPACE "OpenStudio")
      SET( MODULE "${NAME}" )
    ELSE()
      #SET( NAMESPACE "OpenStudio.${NAME}" )
      SET( NAMESPACE "OpenStudio" )  
      SET( MODULE "${NAME}" )
    ENDIF()    

    SET(SWIG_WRAPPER "csharp_${NAME}_wrap.cxx")    
    SET(SWIG_WRAPPER_FULL_PATH "${CMAKE_CURRENT_BINARY_DIR}/${SWIG_WRAPPER}") 

    SET(CSHARP_OUTPUT_NAME "openstudio_${NAME}_csharp")
    SET(CSHARP_GENERATED_SRC_DIR "${CMAKE_BINARY_DIR}/csharp_wrapper/generated_sources/${NAME}" )
    FILE(MAKE_DIRECTORY ${CSHARP_GENERATED_SRC_DIR})

    ADD_CUSTOM_COMMAND(
    OUTPUT ${SWIG_WRAPPER}
    COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CSHARP_GENERATED_SRC_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CSHARP_GENERATED_SRC_DIR}"
    COMMAND "${SWIG_EXECUTABLE}"
            "-csharp" "-c++" -namespace ${NAMESPACE} 
            -features autodoc=1
            -outdir "${CSHARP_GENERATED_SRC_DIR}"  "-I${CMAKE_SOURCE_DIR}/src" "-I${CMAKE_BINARY_DIR}/src"
            -module "${MODULE}"
            -o "${SWIG_WRAPPER_FULL_PATH}"
            -dllimport "${CSHARP_OUTPUT_NAME}"
            "${SWIG_DEFINES}" ${SWIG_COMMON} ${KEY_I_FILE}  
     DEPENDS ${this_depends}

    )

    ADD_LIBRARY(
      ${swig_target}
      MODULE
      ${SWIG_WRAPPER}
    )

    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES OUTPUT_NAME "${CSHARP_OUTPUT_NAME}" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES PREFIX "" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/csharp/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/csharp/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/csharp/" )
    IF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj" )
      ## suppress deprecated warnings in swig bindings
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/wd4996" )
    ENDIF()
    TARGET_LINK_LIBRARIES( ${swig_target} ${PARENT_TARGET} ${DEPENDS} )

    #ADD_DEPENDENCIES("${swig_target}" "${PARENT_TARGET}_resources")
    
    # add this target to a "global" variable so csharp tests can require these
    LIST( APPEND ALL_CSHARP_BINDING_TARGETS "${swig_target}" )
    SET( ALL_CSHARP_BINDING_TARGETS "${ALL_CSHARP_BINDING_TARGETS}" PARENT_SCOPE )
  
  
  
    IF( WIN32 )
      INSTALL( TARGETS ${swig_target} DESTINATION CSharp/openstudio/ )

      INSTALL(CODE "
       INCLUDE(GetPrerequisites)
       GET_PREREQUISITES( \${CMAKE_INSTALL_PREFIX}/CSharp/openstudio/openstudio_${NAME}_csharp.dll PREREQUISITES 1 1 \"\" \"${CMAKE_BINARY_DIR}/Products/\" )
      
       IF(WIN32)
         LIST(REVERSE PREREQUISITES)
       ENDIF(WIN32)
       
       FOREACH( PREREQ IN LISTS PREREQUISITES )
         GP_RESOLVE_ITEM( \"\" \${PREREQ} \"\" \"${LIBRARY_SEARCH_DIRECTORY}\" resolved_item_var )
         EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/CSharp/openstudio/\") 

         GET_FILENAME_COMPONENT( PREREQNAME \${resolved_item_var} NAME)
       ENDFOREACH( PREREQ IN LISTS PREREQUISITES )  
      ")
    ENDIF()
  ENDIF()

  # java
  IF ( BUILD_JAVA_BINDINGS )
    SET( swig_target "java_${NAME}" )
    
    STRING(SUBSTRING ${NAME} 10 -1 SIMPLIFIED_NAME )
    STRING(TOLOWER ${SIMPLIFIED_NAME} SIMPLIFIED_NAME )

    IF(IS_UTILTIES)
      SET( NAMESPACE "gov.nrel.openstudio")
      SET( MODULE "${SIMPLIFIED_NAME}_global" )
    ELSE()
      #SET( NAMESPACE "OpenStudio.${NAME}" )
      SET( NAMESPACE "gov.nrel.openstudio" )  
      SET( MODULE "${SIMPLIFIED_NAME}_global" )
    ENDIF()    

    SET(SWIG_WRAPPER "java_${NAME}_wrap.cxx")    
    SET(SWIG_WRAPPER_FULL_PATH "${CMAKE_CURRENT_BINARY_DIR}/${SWIG_WRAPPER}") 

    SET(JAVA_OUTPUT_NAME "${NAME}_java")
    SET(JAVA_GENERATED_SRC_DIR "${CMAKE_BINARY_DIR}/java_wrapper/generated_sources/${NAME}" )
    FILE(MAKE_DIRECTORY ${JAVA_GENERATED_SRC_DIR})

    ADD_CUSTOM_COMMAND(
    OUTPUT ${SWIG_WRAPPER}
    COMMAND "${CMAKE_COMMAND}" -E remove_directory "${JAVA_GENERATED_SRC_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${JAVA_GENERATED_SRC_DIR}"
    COMMAND "${SWIG_EXECUTABLE}"
            "-java" "-c++" 
            -package ${NAMESPACE}
            #          -features autodoc=1
            -outdir "${JAVA_GENERATED_SRC_DIR}"  "-I${CMAKE_SOURCE_DIR}/src" "-I${CMAKE_BINARY_DIR}/src"
            -module "${MODULE}"
            -o "${SWIG_WRAPPER_FULL_PATH}"
            # -dllimport "${JAVA_OUTPUT_NAME}"
            "${SWIG_DEFINES}" ${SWIG_COMMON} ${KEY_I_FILE}  
     DEPENDS ${this_depends}

    )

    INCLUDE_DIRECTORIES("${JAVA_INCLUDE_PATH}" "${JAVA_INCLUDE_PATH2}")

    ADD_LIBRARY(
      ${swig_target}
      MODULE
      ${SWIG_WRAPPER}
    )

    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES OUTPUT_NAME "${JAVA_OUTPUT_NAME}" )
    #SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES PREFIX "" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/java/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/java/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/java/" )
    IF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj" )
      SET(final_name "${JAVA_OUTPUT_NAME}.dll")
    ENDIF()

    ## suppress deprecated warnings in swig bindings
    IF(UNIX)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-deprecated-declarations" )
    ELSEIF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/wd4996" )
    ENDIF()

    TARGET_LINK_LIBRARIES( ${swig_target} ${PARENT_TARGET} ${DEPENDS} ${JAVA_JVM_LIBRARY})
    IF(APPLE)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES SUFFIX ".dylib" )
      SET(final_name "lib${JAVA_OUTPUT_NAME}.dylib")
     ENDIF() 
    
    #ADD_DEPENDENCIES("${swig_target}" "${PARENT_TARGET}_resources")
    
    # add this target to a "global" variable so java tests can require these
    LIST( APPEND ALL_JAVA_BINDING_TARGETS "${swig_target}" )
    SET( ALL_JAVA_BINDING_TARGETS "${ALL_JAVA_BINDING_TARGETS}" PARENT_SCOPE )
  
    LIST( APPEND ALL_JAVA_SRC_DIRECTORIES "${JAVA_GENERATED_SRC_DIR}" )
    SET( ALL_JAVA_SRC_DIRECTORIES "${ALL_JAVA_SRC_DIRECTORIES}" PARENT_SCOPE )
  
  
    IF( WIN32 OR APPLE)
      INSTALL( TARGETS ${swig_target} DESTINATION Java/openstudio/ )

      INSTALL(CODE "
       INCLUDE(GetPrerequisites)
       GET_PREREQUISITES( \${CMAKE_INSTALL_PREFIX}/Java/openstudio/${final_name} PREREQUISITES 1 1 \"\" \"${CMAKE_BINARY_DIR}/Products/\" )
      
       IF(WIN32)
         LIST(REVERSE PREREQUISITES)
       ENDIF(WIN32)
       
       FOREACH( PREREQ IN LISTS PREREQUISITES )
         GP_RESOLVE_ITEM( \"\" \${PREREQ} \"\" \"${LIBRARY_SEARCH_DIRECTORY}\" resolved_item_var )
         EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/Java/openstudio/\") 

         GET_FILENAME_COMPONENT( PREREQNAME \${resolved_item_var} NAME)

         IF(APPLE)
           EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PREREQ}\" \"@loader_path/\${PREREQNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Java/openstudio/${final_name}\")
           FOREACH( PR IN LISTS PREREQUISITES )
             GP_RESOLVE_ITEM( \"\" \${PR} \"\" \"\" PRPATH )
             GET_FILENAME_COMPONENT( PRNAME \${PRPATH} NAME)
             EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PR}\" \"@loader_path/\${PRNAME}\" \"\${CMAKE_INSTALL_PREFIX}/Java/openstudio/\${PREREQNAME}\")
           ENDFOREACH()
         ENDIF()
       ENDFOREACH( PREREQ IN LISTS PREREQUISITES )  
      ")
    ELSE(WIN32 OR APPLE)
      INSTALL(TARGETS ${swig_target} DESTINATION "lib/openstudio-${OPENSTUDIO_VERSION}/java")
    ENDIF()
  ENDIF()


  # v8
  IF(BUILD_V8_BINDINGS)
    SET( swig_target "v8_${NAME}" )
    
    IF(IS_UTILTIES)
      SET( NAMESPACE "OpenStudio")
      SET( MODULE "${NAME}" )
    ELSE()
      #SET( NAMESPACE "OpenStudio.${NAME}" )
      SET( NAMESPACE "OpenStudio" )  
      SET( MODULE "${NAME}" )
    ENDIF()    

    SET(SWIG_WRAPPER "v8_${NAME}_wrap.cxx")    
    SET(SWIG_WRAPPER_FULL_PATH "${CMAKE_CURRENT_BINARY_DIR}/${SWIG_WRAPPER}") 

    SET(v8_OUTPUT_NAME "${NAME}")
    #SET(CSHARP_GENERATED_SRC_DIR "${CMAKE_BINARY_DIR}/csharp_wrapper/generated_sources/${NAME}" )
    #FILE(MAKE_DIRECTORY ${CSHARP_GENERATED_SRC_DIR})

    IF(BUILD_NODE_MODULES)
      SET(V8_DEFINES "-DBUILD_NODE_MODULE")
    ELSE()
      SET(V8_DEFINES "")
    ENDIF()

    ADD_CUSTOM_COMMAND(
    OUTPUT ${SWIG_WRAPPER}
    COMMAND "${SWIG_EXECUTABLE}"
            "-javascript" "-v8" "-c++" 
            # -namespace ${NAMESPACE} 
            #            -features autodoc=1
            #-outdir "${CSHARP_GENERATED_SRC_DIR}"  
            "-I${CMAKE_SOURCE_DIR}/src" "-I${CMAKE_BINARY_DIR}/src"
            -module "${MODULE}"
            -o "${SWIG_WRAPPER_FULL_PATH}"
            "${SWIG_DEFINES}" ${V8_DEFINES} ${SWIG_COMMON} ${KEY_I_FILE}  
            DEPENDS ${this_depends} 

    )

    IF(BUILD_NODE_MODULES)
      INCLUDE_DIRECTORIES("${NODE_INCLUDE_DIR}" "${NODE_INCLUDE_DIR}/deps/v8/include" "${NODE_INCLUDE_DIR}/deps/uv/include")
    ELSE()
      INCLUDE_DIRECTORIES(${V8_INCLUDE_DIR})
    ENDIF()

    ADD_LIBRARY(
      ${swig_target}
      MODULE 
      ${SWIG_WRAPPER}
    )

    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES OUTPUT_NAME ${v8_OUTPUT_NAME} )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES PREFIX "" )
    SET(_NAME "${v8_OUTPUT_NAME}.node")
    IF(BUILD_NODE_MODULES)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES SUFFIX ".node" )
    ENDIF()
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/v8/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/v8/" )
    SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/v8/" )

    IF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/bigobj" )
    ENDIF()

    ## suppress deprecated warnings in swig bindings
    IF(UNIX)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "-Wno-deprecated-declarations" )
    ELSEIF(MSVC)
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES COMPILE_FLAGS "/wd4996" )
    ENDIF()

    IF(APPLE)      
      SET_TARGET_PROPERTIES( ${swig_target} PROPERTIES LINK_FLAGS "-undefined suppress -flat_namespace")
    ENDIF()
    TARGET_LINK_LIBRARIES( ${swig_target} ${PARENT_TARGET} ${DEPENDS} )
    
    #ADD_DEPENDENCIES("${swig_target}" "${PARENT_TARGET}_resources")
    
    # add this target to a "global" variable so v8 tests can require these
    LIST( APPEND ALL_V8_BINDING_TARGETS "${swig_target}" )
    SET( ALL_V8_BINDING_TARGETS "${ALL_V8_BINDING_TARGETS}" PARENT_SCOPE )

    IF(BUILD_NODE_MODULES)
      SET(V8_TYPE "node")
    ELSE()
      SET(V8_TYPE "v8")
    ENDIF()

    IF( WIN32 OR APPLE )
      INSTALL( TARGETS ${swig_target} DESTINATION "${V8_TYPE}/openstudio/" )

      SET( Prereq_Dirs
        "${CMAKE_BINARY_DIR}/Products/"
        "${CMAKE_BINARY_DIR}/Products/Release"
        "${CMAKE_BINARY_DIR}/Products/Debug"
        )

      INSTALL(CODE "
      #MESSAGE( \"INSTALLING SWIG_TARGET: ${swig_target}  with NAME = ${_NAME}\" )
      INCLUDE(GetPrerequisites)
      GET_PREREQUISITES( \${CMAKE_INSTALL_PREFIX}/${V8_TYPE}/openstudio/${_NAME} PREREQUISITES 1 1 \"\" \"${Prereq_Dirs}\" )
      #MESSAGE( \"PREREQUISITES = \${PREREQUISITES}\" )


      IF(WIN32)
        LIST(REVERSE PREREQUISITES)
      ENDIF(WIN32)

      FOREACH( PREREQ IN LISTS PREREQUISITES )
        GP_RESOLVE_ITEM( \"\" \${PREREQ} \"\" \"${LIBRARY_SEARCH_DIRECTORY}\" resolved_item_var )
        #MESSAGE( \"prereq = ${PREREQ}  resolved = ${resolved_item_var} \")
        EXECUTE_PROCESS(COMMAND \"${CMAKE_COMMAND}\" -E copy \"\${resolved_item_var}\" \"\${CMAKE_INSTALL_PREFIX}/${V8_TYPE}/openstudio/\")

        GET_FILENAME_COMPONENT( PREREQNAME \${resolved_item_var} NAME)

        IF(APPLE)
          EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PREREQ}\" \"@loader_path/\${PREREQNAME}\" \"\${CMAKE_INSTALL_PREFIX}/${V8_TYPE}/openstudio/${_NAME}\")
          FOREACH( PR IN LISTS PREREQUISITES )
            GP_RESOLVE_ITEM( \"\" \${PR} \"\" \"\" PRPATH )
            GET_FILENAME_COMPONENT( PRNAME \${PRPATH} NAME)
            EXECUTE_PROCESS(COMMAND \"install_name_tool\" -change \"\${PR}\" \"@loader_path/\${PRNAME}\" \"\${CMAKE_INSTALL_PREFIX}/${V8_TYPE}/openstudio/\${PREREQNAME}\")
          ENDFOREACH()
        ENDIF()
      ENDFOREACH( PREREQ IN LISTS PREREQUISITES )
      IF(APPLE)
        file(COPY \"${QT_LIBRARY_DIR}/QtGui.framework/Resources/qt_menu.nib\" 
          DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${V8_TYPE}/openstudio/Resources/\")
      ENDIF()
      " )
    ELSE(WIN32 OR APPLE)
      INSTALL(TARGETS ${swig_target} DESTINATION "lib/openstudio-${OPENSTUDIO_VERSION}/${V8_TYPE}")
    ENDIF()
  ENDIF()


ENDMACRO( MAKE_SWIG_TARGET NAME I_FILE PARENT_TARGET DEPENDS )

# add target dependencies
# this will add targets to a "global" variable marking
# them to have their dependencies installed later.
MACRO( ADD_DEPENDENCIES_FOR_TARGET target )
  get_target_property( target_path ${target} LOCATION_DEBUG ) 
  LIST( APPEND DEPENDENCY_TARGETS ${target_path} )
  SET( DEPENDENCY_TARGETS "${DEPENDENCY_TARGETS}" PARENT_SCOPE )
ENDMACRO()

# install target dependencies
# this will actually install the dependencies of the marked targets
# this is called after all targets have been defined.  Dependencies are
# found for all targets and the duplicates are removed so to not try to 
# install twice.
MACRO( INSTALL_RUNTIME_DPENDENCIES targets )
  SET( install_code "
    include(GetPrerequisites)
    FOREACH( target \"${targets}\" )
      get_prerequisites( \"\${target}\" DEPENDS 1 0 \"\" \"\" )
      FOREACH( DEPEND \${DEPENDS} )
        SET( DEPEND_FULL_PATH \"DEPEND_FULL_PATH-NOTFOUND\" )
        FIND_PROGRAM( DEPEND_FULL_PATH \"\${DEPEND}\" )
        LIST( APPEND DEPEND_FULL_PATHS \"\${DEPEND_FULL_PATH}\" )
      ENDFOREACH()
    ENDFOREACH()
    LIST( REMOVE_DUPLICATES DEPEND_FULL_PATHS )
    FILE( INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}/bin\" 
      TYPE EXECUTABLE
      FILES \${DEPEND_FULL_PATHS}
    )
  ")
  INSTALL( CODE "${install_code}" )
ENDMACRO()


# run energyplus
# appends output (eplusout.err) to list ENERGYPLUS_OUTPUTS
MACRO(RUN_ENERGYPLUS FILENAME DIRECTORY WEATHERFILE)
  LIST(APPEND ENERGYPLUS_OUTPUTS "${DIRECTORY}/eplusout.err")
  ADD_CUSTOM_COMMAND(
    OUTPUT "${DIRECTORY}/eplusout.err"
    COMMAND ${CMAKE_COMMAND} -E copy "${DIRECTORY}/${FILENAME}" "${DIRECTORY}/in.idf"
    COMMAND ${CMAKE_COMMAND} -E copy "${ENERGYPLUS_IDD}" "${DIRECTORY}/Energy+.idd"
    COMMAND ${CMAKE_COMMAND} -E copy "${ENERGYPLUS_WEATHER_DIR}/${WEATHERFILE}" "${DIRECTORY}/in.epw"
    COMMAND ${CMAKE_COMMAND} -E chdir "${DIRECTORY}" "${ENERGYPLUS_EXE}" ">" "${DIRECTORY}/screen.out"
    DEPENDS "${ENERGYPLUS_IDD}" "${ENERGYPLUS_WEATHER_DIR}/${WEATHERFILE}" "${ENERGYPLUS_EXE}" "${CMAKE_CURRENT_BINARY_DIR}/${DIRECTORY}/${FILENAME}"
    COMMENT "Updating EnergyPlus simulation in ${CMAKE_CURRENT_BINARY_DIR}/${DIRECTORY}/, this may take a while"
  )
ENDMACRO(RUN_ENERGYPLUS DIRECTORY WEATHERFILE)

# run energyplus
# appends output (eplusout.err) to list ENERGYPLUS_OUTPUTS
MACRO(RUN_ENERGYPLUS_CUSTOMEPW FILENAMEANDPATH WEATHERFILENAMEANDPATH RUN_DIRECTORY)
  LIST(APPEND ENERGYPLUS_OUTPUTS "${RUN_DIRECTORY}/eplusout.err")
  ADD_CUSTOM_COMMAND(
    OUTPUT "${RUN_DIRECTORY}/eplusout.err"
    COMMAND ${CMAKE_COMMAND} -E copy "${FILENAMEANDPATH}" "${RUN_DIRECTORY}/in.idf"
    COMMAND ${CMAKE_COMMAND} -E copy "${ENERGYPLUS_IDD}" "${RUN_DIRECTORY}/Energy+.idd"
    COMMAND ${CMAKE_COMMAND} -E copy "${WEATHERFILENAMEANDPATH}" "${RUN_DIRECTORY}/in.epw"
    COMMAND ${CMAKE_COMMAND} -E chdir "${RUN_DIRECTORY}" "${ENERGYPLUS_EXE}" ">" "${RUN_DIRECTORY}/screen.out"
    DEPENDS "${ENERGYPLUS_IDD}" "${CMAKE_CURRENT_BINARY_DIR}/${WEATHERFILENAMEANDPATH}" "${ENERGYPLUS_EXE}" "${CMAKE_CURRENT_BINARY_DIR}/${FILENAMEANDPATH}"
    COMMENT "Updating EnergyPlus simulation in ${CMAKE_CURRENT_BINARY_DIR}/${RUN_DIRECTORY}/, this may take a while"
  )
ENDMACRO(RUN_ENERGYPLUS_CUSTOMEPW FILENAMEANDPATH WEATHERFILENAMEANDPATH RUN_DIRECTORY)

# adds custom command to update a resource
MACRO(UPDATE_RESOURCES SRCS)
  FOREACH( SRC ${SRCS} )
    ADD_CUSTOM_COMMAND(
      OUTPUT "${SRC}"
      COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}" "${SRC}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}"
    )
  ENDFOREACH()
ENDMACRO(UPDATE_RESOURCES SRCS)

# adds custom command to update a resource via configure
MACRO(CONFIGURE_RESOURCES SRCS)
  FOREACH(SRC ${SRCS} )
    # Would like to wrap this up in a custom command, but no luck thus far.
    # ADD_CUSTOM_COMMAND(
    #  OUTPUT "${SRC}"
    #  DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}"
    #  COMMAND ${CMAKE_COMMAND} 
    #  ARGS -Dfile_name=${SRC} -Dinclude_name=${include_name} -E 
      
      CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}" "${SRC}" )
      
    #)
  ENDFOREACH()
ENDMACRO(CONFIGURE_RESOURCES SRCS)

