# Friday Night Lights — Developer Handoff Notes

## What this app does
iOS app that sends a time-sensitive push notification before Shabbat candle lighting each week, timed to the user's ZIP code. Shows a Shabbat mode screen (Hebrew + English "Shabbat Shalom") from candle lighting Friday night through havdalah Saturday night.

---

## Repo & infrastructure

- **GitHub:** `github.com/jtgoldner/friday-night-lights`
- **Bundle ID:** `com.jonathangoldner.fridaynightlights`
- **CI/CD:** Codemagic (connected via GitHub SSO)
- **Build workflow:** `codemagic.yaml` at repo root
- **Signing:** Apple Distribution cert + provisioning profile "FNL June 6" in Codemagic global code signing settings
- **App Store Connect API:** Key named "Codemagic FNL" connected via Codemagic integrations
- **No Mac required** — all builds run on Codemagic's Mac Mini M2

---

## Repo structure

```
friday-night-lights/
├── codemagic.yaml
├── FridayNightLights.xcodeproj/
│   ├── project.pbxproj
│   └── project.xcworkspace/
│       └── contents.xcworkspacedata
├── FridayNightLights/
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/   ← AppIcon-1024.png + Contents.json
│   │   ├── AccentColor.colorset/
│   │   └── Contents.json
│   ├── Info.plist
│   ├── FridayNightLightsApp.swift
│   ├── AppState.swift
│   ├── HebcalService.swift
│   ├── NotificationScheduler.swift
│   ├── OnboardingView.swift
│   ├── HomeView.swift
│   ├── SettingsView.swift
│   └── ShabbatView.swift
└── privacy-policy.txt
```

---

## How to ship a build

1. Make code changes directly in GitHub web UI (edit files in `FridayNightLights/` subfolder)
2. Go to Codemagic → friday-night-lights → Start new build
3. Codemagic auto-increments build number via `agvtool new-version -all 3` (update this number each release)
4. Build takes ~2 minutes; publishing to TestFlight takes ~15 minutes after Apple processes it
5. In App Store Connect → TestFlight → answer export compliance (No encryption) → build becomes available

**Important:** Each upload to Apple needs a higher build number. The `agvtool` line in `codemagic.yaml` sets this — bump it each release. Eventually automate with `agvtool next-version -all`.

---

## codemagic.yaml — current state

```yaml
workflows:
  ios-app-store:
    name: Friday Night Lights — App Store
    max_build_duration: 60
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: Codemagic FNL
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.jonathangoldner.fridaynightlights
      vars:
        XCODE_PROJECT: "FridayNightLights.xcodeproj"
        XCODE_SCHEME: "FridayNightLights"
    scripts:
      - name: Set build number
        script: agvtool new-version -all 3
      - name: Build iOS app
        script: |
          xcode-project use-profiles
          xcodebuild -project "$XCODE_PROJECT" \
            -scheme "$XCODE_SCHEME" \
            -configuration Release \
            -archivePath build/FridayNightLights.xcarchive \
            archive
      - name: Export IPA
        script: |
          xcode-project build-ipa \
            --project "$XCODE_PROJECT" \
            --scheme "$XCODE_SCHEME"
    artifacts:
      - "**/*.ipa"
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

---

## Apple Developer portal notes

- **App ID:** `com.jonathangoldner.fridaynightlights`
- **Capabilities enabled:** Push Notifications, Time Sensitive Notifications
- **Provisioning profile:** "FNL June 6" — if cert expires or capabilities change, regenerate profile at developer.apple.com → Profiles, re-download, re-upload to Codemagic global code signing
- **Certificate:** Apple Distribution, generated via Codemagic. Password stored in your password manager.
- **Team ID:** C934P2FJ9M

---

## Key files explained

### HebcalService.swift
Fetches candle lighting + havdalah times from `hebcal.com/shabbat` API. No API key required. Returns a `CandleLightingTime` struct with an `isApproximate` flag — set to `true` on Saturday night when the API still returns the current week's (past) time. In that case, 7 days are added to approximate next Friday.

### AppState.swift
Central state object. Persists ZIP code and minutes-before to UserDefaults. Also persists last known candle and havdalah dates so `isShabbat` works even without a fresh API fetch. The `isShabbat` computed property checks day of week: Friday after candle lighting = Shabbat, Saturday before havdalah = Shabbat.

### NotificationScheduler.swift
Schedules a single `UNCalendarNotificationTrigger` notification with `.timeSensitive` interruption level. Breaks through Focus modes. Requires Time Sensitive Notifications entitlement (enabled in Apple Developer portal).

### HomeView.swift
Routes to `ShabbatView` when `appState.isShabbat` is true. Otherwise shows `CandleTimeCard` with next Friday's time. Shows "Approximate" caveat when `isApproximate` is true.

### ShabbatView.swift
Shown Friday night through Saturday night. Hebrew + English "Shabbat Shalom", candle lighting time, havdalah time. Star field decoration.

---

## Known issues / future work

- **Widget:** Deliberately removed from v1.0 to simplify submission. Add back as Home Screen widget in a future version. Requires `WidgetKit` target added to the Xcode project.
- **Time Sensitive notifications:** Added in v1.1. Test next Friday to confirm the notification breaks through silent mode.
- **Saturday night edge case:** Fixed in current version — shows approximate next Friday time with caveat. Clears on Sunday when Hebcal returns correct data.
- **Light mode:** App is forced to dark mode via `.preferredColorScheme(.dark)` in `FridayNightLightsApp.swift`. This is intentional — candlelight aesthetic.
- **AccentGold color:** Named color never created in asset catalog. All gold colors are hardcoded as `Color(red: 0.8, green: 0.6, blue: 0.1)`. Do not use `Color("AccentGold")` anywhere.
- **Build number:** Currently set to 3 in `codemagic.yaml`. Bump each release. Eventually automate.

---

## Version history

| Version | Build | Notes |
|---------|-------|-------|
| 1.0 | 1 | First TestFlight build. Dark mode only. Basic candle lighting display + notification. |
| 1.1 | 3 | Time Sensitive notifications. Shabbat mode screen. Fixed Hebcal API for Saturday. Fixed button colors. Approximate Saturday night time display. |

