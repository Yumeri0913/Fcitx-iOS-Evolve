[中文](README.md)
|
English

# Fcitx iOS Evolve

A pinyin keyboard for iOS ≥ 16.3 built on [Fcitx5](https://github.com/fcitx/fcitx5),
focused on the hand-typed input experience in the AI era: getting the typing feel right.

It is a fork of [fcitx5-ios](https://github.com/fcitx-contrib/fcitx5-ios).

> Status: personal project, in daily use but not released. There is no prebuilt
> IPA yet; build it yourself (see below).

## What's different from fcitx5-ios

### Look
- iOS style by default: system colors, translucent background and rounded keys
  that match the stock keyboard; a classic style is also available
- Optional key borders in both styles, light/dark following the system
- Retuned key gaps, keyboard height and candidate bar spacing

### Typing feel
- Touch-aware correction: a 2D Gaussian key model scores the keys around each
  touch, and the pinyin engine tries the likely neighbors (`nihqo` → 你好 only
  when q was hit near a)
- Tuned gestures: swipe distance, long press delay, space bar cursor scrubbing,
  backspace repeat, sliding between keys with hysteresis
- Taps on the top row don't pick candidates; only the upper edge of the gap
  above the keys selects a candidate
- Haptic feedback (weak / medium / strong) and key previews

### Pinyin and dictionaries
- Better dictionary import
- More efficient ranking by typed code
- Much better mixed Chinese and English input

### Symbols and emoji
- Symbol keyboard with categories
- Emoji panel (long press comma) with recents and categories, and emoji search
  in Chinese or English (猫 / cat)

### Settings
- Theme switching from the keyboard's ... panel
- With an App Group, config and user data are shared between the app and the
  keyboard directly; no manual sync needed

## Build

This project is NOT managed by Xcode, but Xcode 27.1 is needed for the iOS SDK.
Below assumes Apple Silicon; for Intel, replace `SIMULATORARM64` with `SIMULATOR64`.

### Dependencies and patches
```sh
git clone --recursive https://github.com/Yumeri0913/Fcitx-iOS-Evolve.git && cd Fcitx-iOS-Evolve
brew install cmake ninja gettext pkg-config
./scripts/install-deps.sh SIMULATORARM64
./scripts/patch.sh
```

### Simulator
```sh
cmake -B build/SIMULATORARM64 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPLATFORM=SIMULATORARM64 \
  -DPINYIN_ONLY=ON -DHALLELUJAH=OFF -DMOZC=OFF -DRIME=OFF
cmake --build build/SIMULATORARM64 && ./scripts/code-sign.sh SIMULATORARM64
xcrun simctl install booted build/SIMULATORARM64/src/Fcitx5.app
```
Then add the keyboard in Settings → General → Keyboard → Keyboards → Add New Keyboard.

### Device
```sh
./scripts/install-deps.sh OS64
cmake -B build/OS64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DPLATFORM=OS64 \
  -DPINYIN_ONLY=ON -DHALLELUJAH=OFF -DMOZC=OFF -DRIME=OFF
cmake --build build/OS64
cd build/OS64/src && rm -rf Payload Fcitx5.ipa && mkdir Payload
cp -r Fcitx5.app Payload && zip -r Fcitx5.ipa Payload
```

**With a paid developer account** (recommended): register your own bundle IDs
and an App Group, then configure with
```sh
cmake -DBUNDLE_IDENTIFIER=com.example.fcitx5 -DAPP_GROUP_IDENTIFIER=group.com.example.fcitx5 build/OS64
```
Keyboards get `<bundle>.Chinese` etc. Sign each bundle with its own provisioning
profile and entitlements including `com.apple.security.application-groups`.

**Without one**: install the unsigned IPA with
[SideStore](https://github.com/SideStore/SideStore). App Group isn't available,
so grant the keyboard full access and tap `Sync config` in the app after
changing settings or data.

## Test
```sh
cd build/SIMULATORARM64 && ctest
```
E2E tests use Appium, see [appium](appium).

## Debugging on device

- **Memory**: keyboard extensions are killed above 77 MB, see
  [docs/memory.md](docs/memory.md).
- **Crashes**: Settings → Privacy & Security → Analytics & Improvements →
  Analytics Data; open the reports with Console.app on a Mac.

## Upstream

Generic fixes are welcome upstream at
[fcitx5-ios](https://github.com/fcitx-contrib/fcitx5-ios). Thanks to its
authors and to the [Fcitx](https://github.com/fcitx) project.

## License

[GPL-3.0](LICENSE). Third-party projects are listed in [CREDITS.md](CREDITS.md).
