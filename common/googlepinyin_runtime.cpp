#include "common.h"
#include "googlepinyin/userdata.h"
#include "runtime-api.h"
#include "util.h"

#include <fcitx-utils/log.h>
#include <fcitx-utils/standardpaths.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputcontext.h>
#include <fstream>
#include <sstream>

// Google Pinyin user words are merged into fcitx pinyin user data (user.dict
// and user.history), the same way as InsightKey for Android, so that imported
// words keep learning like words fcitx learned itself.

namespace {

std::string pinyinDir(const char *dataHome) {
    return std::string(dataHome) + "/pinyin";
}

bool readFile(const char *path, std::string &content) {
    std::ifstream in(path, std::ios::in | std::ios::binary);
    if (!in) {
        return false;
    }
    std::stringstream ss;
    ss << in.rdbuf();
    content = ss.str();
    return true;
}

bool writeFile(const char *path, const std::string &content) {
    std::ofstream out(path, std::ios::out | std::ios::binary | std::ios::trunc);
    out << content;
    return static_cast<bool>(out);
}

GooglePinyinMergeResult merge(const char *tsvPath, const std::string &dir) {
    GooglePinyinMergeResult result{};
    std::string tsv;
    if (!readFile(tsvPath, tsv)) {
        FCITX_ERROR() << "Cannot read " << tsvPath;
        return result;
    }
    try {
        std::filesystem::create_directories(dir);
        auto merged = googlepinyin::mergeIntoUserData(
            dir + "/user.dict", dir + "/user.history",
            googlepinyin::fromTsv(tsv));
        result.ok = true;
        result.added = static_cast<int>(merged.added);
        result.existing = static_cast<int>(merged.existing);
        result.invalid = static_cast<int>(merged.invalid);
    } catch (const std::exception &e) {
        FCITX_ERROR() << "Failed to merge Google Pinyin words: " << e.what();
    }
    return result;
}

bool exportWords(const std::string &dir, const char *tsvOut) {
    try {
        auto words = googlepinyin::readUserWords(dir + "/user.dict",
                                                 dir + "/user.history");
        return writeFile(tsvOut, googlepinyin::toTsv(words));
    } catch (const std::exception &e) {
        FCITX_ERROR() << "Failed to read pinyin user words: " << e.what();
        return false;
    }
}

std::string runtimePinyinDir() {
    return fcitx::StandardPaths::global().userDirectory(
               fcitx::StandardPathsType::PkgData) /
           "pinyin";
}

} // namespace

GooglePinyinMergeResult mergeGooglePinyinWords(const char *tsvPath,
                                               const char *dataHome) {
    return merge(tsvPath, pinyinDir(dataHome));
}

bool exportGooglePinyinWords(const char *dataHome, const char *tsvOut) {
    return exportWords(pinyinDir(dataHome), tsvOut);
}

void saveUserData() {
    dispatcher->schedule([] { instance->save(); });
}

GooglePinyinMergeResult importGooglePinyinWordsLive(const char *tsvPath) {
    std::string path = tsvPath;
    return with_fcitx([path] {
        // Write words learned in memory first, then merge on disk and let the
        // engine read the merged files back.
        instance->save();
        auto result = merge(path.c_str(), runtimePinyinDir());
        if (result.ok) {
            if (auto *pinyin = instance->addonManager().addon("pinyin")) {
                pinyin->setSubConfig("reloaduserdata", fcitx::RawConfig{});
            }
            if (auto *ic = instance->mostRecentInputContext()) {
                ic->reset();
            }
        }
        return result;
    });
}

bool snapshotGooglePinyinWords(const char *tsvOut) {
    std::string out = tsvOut;
    return with_fcitx([out] {
        instance->save();
        return exportWords(runtimePinyinDir(), out.c_str());
    });
}
