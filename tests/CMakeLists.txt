find_program(XCRUN xcrun REQUIRED NO_CMAKE_FIND_ROOT_PATH)

set(UNDO_REDO_TEST "${CMAKE_CURRENT_BINARY_DIR}/UndoRedoSwift")
set(UNDO_REDO_TEST_SOURCES
    "${PROJECT_SOURCE_DIR}/keyboard/util.swift"
    "${PROJECT_SOURCE_DIR}/keyboard/UndoRedo.swift"
    "${CMAKE_CURRENT_SOURCE_DIR}/testundoredo.swift"
)
add_custom_command(
    OUTPUT "${UNDO_REDO_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache"
        ${UNDO_REDO_TEST_SOURCES}
        -o "${UNDO_REDO_TEST}"
    DEPENDS ${UNDO_REDO_TEST_SOURCES}
    VERBATIM
)
add_custom_target(UndoRedoSwiftTest ALL DEPENDS "${UNDO_REDO_TEST}")
add_test(NAME UndoRedoSwift COMMAND "${UNDO_REDO_TEST}")

set(GOOGLE_PINYIN_TEST "${CMAKE_CURRENT_BINARY_DIR}/GooglePinyinSwift")
set(GOOGLE_PINYIN_TEST_SOURCES
    "${PROJECT_SOURCE_DIR}/src/GooglePinyinUserDict.swift"
    "${CMAKE_CURRENT_SOURCE_DIR}/testgooglepinyin.swift"
)
add_custom_command(
    OUTPUT "${GOOGLE_PINYIN_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache"
        -parse-as-library
        ${GOOGLE_PINYIN_TEST_SOURCES}
        -o "${GOOGLE_PINYIN_TEST}"
    DEPENDS ${GOOGLE_PINYIN_TEST_SOURCES}
    VERBATIM
)
add_custom_target(GooglePinyinSwiftTest ALL DEPENDS "${GOOGLE_PINYIN_TEST}")
add_test(NAME GooglePinyinSwift COMMAND "${GOOGLE_PINYIN_TEST}")

set(SPATIAL_MODEL_TEST "${CMAKE_CURRENT_BINARY_DIR}/SpatialModelSwift")
set(SPATIAL_MODEL_TEST_SOURCES
    "${PROJECT_SOURCE_DIR}/uipanel/SpatialModel.swift"
    "${CMAKE_CURRENT_SOURCE_DIR}/testspatialmodel.swift"
)
add_custom_command(
    OUTPUT "${SPATIAL_MODEL_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache"
        -parse-as-library
        ${SPATIAL_MODEL_TEST_SOURCES}
        -o "${SPATIAL_MODEL_TEST}"
    DEPENDS ${SPATIAL_MODEL_TEST_SOURCES}
    VERBATIM
)
add_custom_target(SpatialModelSwiftTest ALL DEPENDS "${SPATIAL_MODEL_TEST}")
add_test(NAME SpatialModelSwift COMMAND "${SPATIAL_MODEL_TEST}")

set(EMOJI_SEARCH_TEST "${CMAKE_CURRENT_BINARY_DIR}/EmojiSearchSwift")
set(EMOJI_SEARCH_TEST_SOURCES
    "${PROJECT_SOURCE_DIR}/uipanel/EmojiSearch.swift"
    "${CMAKE_CURRENT_SOURCE_DIR}/testemojisearch.swift"
)
add_custom_command(
    OUTPUT "${EMOJI_SEARCH_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache"
        -parse-as-library
        ${EMOJI_SEARCH_TEST_SOURCES}
        -o "${EMOJI_SEARCH_TEST}"
    DEPENDS ${EMOJI_SEARCH_TEST_SOURCES}
    VERBATIM
)
add_custom_target(EmojiSearchSwiftTest ALL DEPENDS "${EMOJI_SEARCH_TEST}")
add_test(NAME EmojiSearchSwift COMMAND "${EMOJI_SEARCH_TEST}"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/emoji/data/zh.dict"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/emoji/data/en.dict")

add_subdirectory(backup)
