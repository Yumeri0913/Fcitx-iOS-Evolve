#pragma once

#include <string>

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath);
void startKeyboardFcitx(const char *appBundlePath, const char *xdgDataDirs,
                        const char *appGroupPath);
void setLocale(const char *locale);

void focusIn(const char *program, const char *documentIdentifier);
void focusOut(const char *program, const char *documentIdentifier);
void destroyInputContext(const char *program);
void processKey(const char *program, const char *documentIdentifier,
                const char *key, const char *code, unsigned int modifiers,
                const char *surroundingText, unsigned int cursor,
                unsigned int anchor, bool reset);
void resetInput(const char *program, const char *documentIdentifier);
void triggerUnicode(const char *program, const char *documentIdentifier);
void triggerQuickPhrase(const char *program, const char *documentIdentifier);
bool isClipboardMonitoringEnabled();
void setClipboardMonitoringEnabled(bool enabled);
bool isClipboardReturnAfterPasteEnabled();
bool isClipboardMaskSensitiveEnabled();
bool isClipboardSuggestionEnabled();
int getClipboardSuggestionTimeout();
std::string filterClipboardEntry(const char *text);
void reload();
void toggle();

void setCurrentInputMethod(const char *inputMethod);
void setInputMethods(const char *json);
std::string getAllInputMethods();
std::string getInputMethods();

std::string getConfig(const char *uri);
void setConfig(const char *uri, const char *value);
std::string getAddons();
bool isRegexValid(const char *regex);

// Google Pinyin user words <-> fcitx pinyin user data (user.dict and
// user.history under <dataHome>/pinyin). TSV is "word\tpin'yin\tcount" lines.
struct GooglePinyinMergeResult {
    bool ok;
    int added;
    int existing;
    int invalid;
};
// Only when the pinyin engine is not running, e.g. before startKeyboardFcitx.
GooglePinyinMergeResult mergeGooglePinyinWords(const char *tsvPath,
                                               const char *dataHome);
// Read only, safe while the keyboard is running.
bool exportGooglePinyinWords(const char *dataHome, const char *tsvOut);
// Keyboard with fcitx running: save, merge, then reload pinyin user data.
GooglePinyinMergeResult importGooglePinyinWordsLive(const char *tsvPath);
// Keyboard with fcitx running: save, then export current user words.
bool snapshotGooglePinyinWords(const char *tsvOut);
void saveUserData();
// Keyboard: clear words learned while typing (pinyin user.dict).
bool clearPinyinUserDictLive();
