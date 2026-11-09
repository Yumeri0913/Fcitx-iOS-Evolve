#include "common.h"
#include "googlepinyin/userdata.h"
#include "runtime-api.h"
#include "util.h"

#include <algorithm>
#include <cstdlib>
#include <fcitx-utils/log.h>
#include <fcitx-utils/standardpaths.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputcontext.h>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <vector>

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

std::vector<std::string> splitTabs(const std::string &line) {
    std::vector<std::string> fields;
    size_t start = 0;
    while (true) {
        auto tab = line.find('\t', start);
        fields.push_back(line.substr(start, tab - start));
        if (tab == std::string::npos) {
            return fields;
        }
        start = tab + 1;
    }
}

std::string lowercase(std::string s) {
    for (auto &c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c - 'A' + 'a');
        }
    }
    return s;
}

// Merge "<key fields...>\t<count>" lines of [importPath] into a learned word
// file of fcitx pinyin ("<key fields...>\t<count>\t<stamp>": user.typed is
// code, word; user.english is word), keeping the larger count, the same as
// InsightKey for Android. keyOf maps the key fields to what identifies an
// entry. New entries get stamp 0 (never committed in fcitx, no boost as a
// recent commit in user.typed) unless recentImports.
template <typename KeyOf>
void mergeLearnedFile(const std::string &importPath,
                      const std::string &learnedPath, size_t keyFields,
                      bool recentImports, KeyOf keyOf) {
    std::string content;
    if (!readFile(importPath.c_str(), content)) {
        return;
    }
    struct Line {
        std::vector<std::string> fields;
        long long count;
        long long stamp;
    };
    std::vector<Line> lines;
    std::unordered_map<std::string, size_t> index;
    long long stamp = 0;
    std::string existing;
    if (readFile(learnedPath.c_str(), existing)) {
        std::istringstream in(existing);
        std::string line;
        while (std::getline(in, line)) {
            auto f = splitTabs(line);
            if (f.size() < keyFields + 2) {
                continue;
            }
            Line l{{f.begin(), f.begin() + static_cast<long>(keyFields)},
                   std::atoll(f[keyFields].c_str()),
                   std::atoll(f[keyFields + 1].c_str())};
            if (l.count <= 0) {
                continue;
            }
            stamp = std::max(stamp, l.stamp);
            index[keyOf(l.fields)] = lines.size();
            lines.push_back(std::move(l));
        }
    }
    std::vector<Line> imported;
    std::istringstream in(content);
    std::string line;
    while (std::getline(in, line)) {
        auto f = splitTabs(line);
        if (f.size() < keyFields + 1) {
            continue;
        }
        Line l{{f.begin(), f.begin() + static_cast<long>(keyFields)},
               std::atoll(f[keyFields].c_str()),
               0};
        if (l.count > 0) {
            imported.push_back(std::move(l));
        }
    }
    // more used entries count as more recent, like they were typed later
    std::stable_sort(
        imported.begin(), imported.end(),
        [](const Line &a, const Line &b) { return a.count < b.count; });
    for (auto &l : imported) {
        auto key = keyOf(l.fields);
        if (auto iter = index.find(key); iter != index.end()) {
            auto &old = lines[iter->second];
            old.count = std::max(old.count, l.count);
            continue;
        }
        l.stamp = recentImports ? ++stamp : 0;
        index[key] = lines.size();
        lines.push_back(std::move(l));
    }
    std::stable_sort(
        lines.begin(), lines.end(),
        [](const Line &a, const Line &b) { return a.stamp < b.stamp; });
    std::string out;
    for (const auto &l : lines) {
        for (const auto &f : l.fields) {
            out += f;
            out += '\t';
        }
        out += std::to_string(std::min(l.count, 0xffffffLL));
        out += '\t';
        out += std::to_string(l.stamp);
        out += '\n';
    }
    if (!writeFile(learnedPath.c_str(), out)) {
        FCITX_ERROR() << "Cannot write " << learnedPath;
    }
}

// import-<UUID>.typed and import-<UUID>.english next to import-<UUID>.tsv
void mergeLearnedWords(const std::string &tsvPath, const std::string &dir) {
    auto base = tsvPath.substr(0, tsvPath.rfind('.'));
    mergeLearnedFile(
        base + ".typed", dir + "/user.typed", 2, false,
        [](const std::vector<std::string> &f) { return f[0] + '\t' + f[1]; });
    mergeLearnedFile(
        base + ".english", dir + "/user.english", 1, true,
        [](const std::vector<std::string> &f) { return lowercase(f[0]); });
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
        mergeLearnedWords(tsvPath, dir);
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

// Only user.dict and user.history. Instance::save() would also write every
// addon config from memory, overwriting config just synced from the main app.
void savePinyinUserData() {
    if (auto *pinyin = instance->addonManager().addon("pinyin")) {
        pinyin->setSubConfig("saveuserdata", fcitx::RawConfig{});
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
    dispatcher->schedule([] { savePinyinUserData(); });
}

GooglePinyinMergeResult importGooglePinyinWordsLive(const char *tsvPath) {
    std::string path = tsvPath;
    return with_fcitx([path] {
        // Write words learned in memory first, then merge on disk and let the
        // engine read the merged files back.
        savePinyinUserData();
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
        savePinyinUserData();
        return exportWords(runtimePinyinDir(), out.c_str());
    });
}

bool clearPinyinUserDictLive() {
    return with_fcitx([] {
        auto *pinyin = instance->addonManager().addon("pinyin");
        if (!pinyin) {
            return false;
        }
        pinyin->setSubConfig("clearuserdict", fcitx::RawConfig{});
        savePinyinUserData();
        return true;
    });
}
