#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx-config/enum.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/candidatelist.h>
#include <fcitx/instance.h>

namespace fcitx {

// Google Pinyin style skin settings: light / dark palette and key border.
enum class ThemeMode { FollowSystem, Light, Dark };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(ThemeMode, N_("Follow system"), N_("Light"),
                                 N_("Dark"));

// Google Pinyin: fixed key area height per screen size, like InsightKey's
// KeyboardHeightMode. Percent keeps the percentage of screen height.
enum class HeightMode { GooglePinyin, Percent };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(HeightMode, N_("Same as Google Pinyin"),
                                 N_("Percentage of screen height"));

enum class VibrationStrength { Weak, Medium, Strong };
FCITX_CONFIG_ENUM_NAME_WITH_I18N(VibrationStrength, N_("Weak"), N_("Medium"),
                                 N_("Strong"));

FCITX_CONFIGURATION(
    UIPanelConfig,
    OptionWithAnnotation<ThemeMode, ThemeModeI18NAnnotation> theme{
        this, "Theme", _("Theme"), ThemeMode::FollowSystem};
    Option<bool> keyBorder{this, "KeyBorder", _("Key border"), false};
    OptionWithAnnotation<HeightMode, HeightModeI18NAnnotation> heightMode{
        this, "HeightMode", _("Keyboard height"), HeightMode::GooglePinyin};
    Option<bool> vibrate{this, "Vibrate", _("Vibrate on keypress"), true};
    OptionWithAnnotation<VibrationStrength, VibrationStrengthI18NAnnotation>
        vibrationStrength{this, "VibrationStrength", _("Vibration strength"),
                          VibrationStrength::Weak};);

class UIPanel final : public VirtualKeyboardUserInterface {
  public:
    UIPanel(Instance *);
    virtual ~UIPanel() = default;

    void reloadConfig() override;
    const Configuration *getConfig() const override { return &config_; }
    void setConfig(const RawConfig &config) override;
    void setSubConfig(const std::string &path,
                      const RawConfig &config) override {}

    Instance *instance() { return instance_; }

    bool available() override { return true; }
    void suspend() override {}
    void resume() override {}
    void update(UserInterfaceComponent component,
                InputContext *inputContext) override;
    bool isVirtualKeyboardVisible() const override { return true; }
    void showVirtualKeyboard() override {}
    void hideVirtualKeyboard() override {}
    void scroll(const std::string &inputContext, int start, int count);
    void page(const std::string &inputContext, bool next);

  private:
    Instance *instance_;
    UIPanelConfig config_;
    void applyConfig();
    std::unique_ptr<HandlerTableEntry<EventHandler>> eventHandler_;

    void updateStatusArea(InputContext &ic);
    void expand(InputContext &ic, const std::string &auxUp,
                const std::string &preedit, int caret, bool hasClientPreedit,
                std::shared_ptr<CandidateList> list);
};

class UIPanelFactory : public AddonFactory {
  public:
    AddonInstance *create(AddonManager *manager) override {
        return new UIPanel(manager->instance());
    }
};

} // namespace fcitx
