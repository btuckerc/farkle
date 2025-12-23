# App Store Listing — Farkle Scorer

Use this document to prepare your App Store Connect submission. Fill in the blanks and copy/paste into App Store Connect.

---

## App Identity

| Field | Value |
|------|-------|
| **App Name** (30 chars max) | `Farkle Scorer` |
| **Subtitle** (30 chars max) | `Scorekeeper for Farkle dice` |
| **Bundle ID** | `com.tcraig.FarkleScorer` |
| **SKU** | `farklescorer` |
| **Primary Language** | English (U.S.) |

---

## Category

| Field | Recommendation |
|------|----------------|
| **Primary Category** | Utilities |
| **Secondary Category** | Games → Board |

> Tip: “Utilities” often has less competition than “Games” and fits a scorekeeper app well.

---

## Keywords (100 characters max, comma-separated)

```
scorecard,scoreboard,turntracker,points,banking,manual,houserules,offline,nearby,multipeer,dicegame
```

*(98 characters — adjust as needed)*

---

## Description

### Short Promotional Text (170 chars max, can be updated without review)

```
Fast Farkle scorekeeping with tap-to-score dice, manual mode for real dice, and optional nearby multiplayer. No ads, no accounts, no internet required.
```

### Full Description (4000 chars max)

```
Farkle Scorer is a fast, flexible scorekeeper for the classic dice game. Track turns, bank points, and keep everyone’s totals clear—whether you share one device or connect nearby devices for multiplayer.

WHY YOU’LL LIKE IT
• Score fast — tap dice to calculate points and keep turns moving
• Manual mode — enter scores when you’re rolling physical dice
• Clear scoreboard — always know who’s leading and how close they are
• Undo friendly — fix accidental taps without slowing the game down
• House rules — customize scoring and key rule options for your table
• Nearby multiplayer — connect nearby devices (optional) for multi-device play
• Offline-first — no internet required
• No ads, no accounts — just scorekeeping

HOW IT WORKS
1. Add players and choose your winning score and rule options.
2. Score a turn by selecting dice (or use Manual Mode for physical dice).
3. Bank points, handle Farkles, and keep playing.
4. View the scoreboard anytime and crown the winner.

PRIVACY
Farkle Scorer collects no personal data. Game data and preferences stay on your device.

NEARBY MULTIPLAYER
If you enable multiplayer, the app uses your local network to find and connect nearby devices. This is optional and not used for tracking.

Disclaimer: Farkle Scorer is an unofficial companion app and is not affiliated with or endorsed by any publisher or trademark holder.
```

---

## What’s New (Release Notes)

Use for each new version submitted.

### Version 1.0

```
Initial release:
- Fast Farkle scorekeeping (tap-to-score)
- Manual mode for physical dice
- House rules customization
- Optional nearby multiplayer
```

---

## Privacy Policy

Apple requires a privacy policy URL even for apps that collect no data.

**Option A — Host your own**
Host the contents of `PRIVACY_POLICY.md` on a simple page (GitHub Pages, Notion, personal site).

| Field | Your Value |
|------|------------|
| **Privacy Policy URL** | `https://___________` |

---

## Support Information

| Field | Value |
|------|-------|
| **Support URL** | `https://btuckerc.dev/contact` |
| **Marketing URL** (optional) | |
| **Contact Email** | `btuckerc.dev@gmail.com` |

---

## App Review Information

| Field | Value |
|------|-------|
| **Demo Account Required?** | No |
| **Notes for Reviewer** | Farkle Scorer is a scorekeeping utility for the Farkle dice game. Launch the app, add players, and score turns. No login. Multiplayer uses local network connections to nearby devices when enabled. |

---

## Age Rating Questionnaire

Answer **No** to all content questions (violence, gambling, etc.) unless you’ve added something beyond basic scorekeeping.

| Content Type | Answer |
|--------------|--------|
| Cartoon or Fantasy Violence | No |
| Realistic Violence | No |
| Gambling | No |
| Contests | No |
| Alcohol, Tobacco, Drugs | No |
| Sexual Content | No |
| Profanity | No |
| Horror/Fear | No |
| Medical/Treatment Info | No |
| Mature/Suggestive Themes | No |
| Simulated Gambling | No |
| Unrestricted Web Access | No |

**Expected Rating:** 4+ (suitable for all ages)

---

## App Privacy (App Store Connect Data Collection)

When asked “Does this app collect any user data?”, select:

**☑ No, we do not collect data from this app**

This sets the App Privacy label to “Data Not Collected”.

---

## Screenshots Checklist

App Store Connect requires screenshots for each device class you support. Since `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad), you need both.

### iPhone (required sizes — provide at least one)

| Size | Device Examples | Resolution |
|------|-----------------|------------|
| 6.7" | iPhone 15 Pro Max, 14 Pro Max | 1290 × 2796 |
| 6.5" | iPhone 14 Plus, 11 Pro Max | 1284 × 2778 |
| 5.5" | iPhone 8 Plus, 7 Plus | 1242 × 2208 |

### iPad (required if supporting iPad)

| Size | Device Examples | Resolution |
|------|-----------------|------------|
| 12.9" (6th gen) | iPad Pro 12.9" | 2048 × 2732 |
| 12.9" (2nd gen) | iPad Pro 12.9" (older) | 2048 × 2732 |

### Screenshot Suggestions

1. **Game Setup** — player entry + rule options
2. **Dice Scoring** — selecting dice with turn score visible
3. **Manual Mode** — physical dice tracker / manual entry
4. **Scoreboard** — standings / end-of-game winner
5. **Multiplayer** — join/host flow or round status screen
6. **Settings** — themes, haptics, and house rules customization

> Tip: Use Xcode Simulator or a real device to capture. Consider adding device frames via tools like Screenshots.pro or Rotato.

---

## iPhone Screenshot Plan (recommended order + captions)

Apple users often decide in the first 2–3 screenshots. Lead with speed + clarity + trust.

### Recommended order (iPhone first)

1. **Tap-to-score dice** — show dice selection + turn score + “Bank Score”
2. **Scoreboard clarity** — show standings and “Race to ___”
3. **Manual mode** — show “Calculator” / manual scoring for physical dice
4. **House rules** — show scoring customization / rules editor
5. **Nearby multiplayer (optional)** — show host/join or round status
6. **Polish** — themes + player colors + haptics (optional screenshot 6–8)

### Caption Set A (direct + feature-led)

1. **Score in seconds** — tap dice, bank points, next turn.
2. **See who’s winning** — clear scoreboard for every player.
3. **Use real dice** — manual mode keeps totals accurate.
4. **House rules ready** — customize scoring your way.
5. **Nearby multiplayer** — connect devices on the same Wi‑Fi.
6. **No ads. No accounts.** Offline-first scorekeeping.

### Caption Set B (benefit-led + trust)

1. **Keep the game moving** — fast scoring, fewer arguments.
2. **Always know the leader** — totals at a glance.
3. **Bring your own dice** — we’ll handle the math.
4. **Play your rules** — flexible scoring options.
5. **Optional multiplayer** — sync nearby devices.
6. **Private by design** — data stays on your device.

### Optional App Preview (10–15s) script

Keep it silent-friendly: show UI, add short on-screen captions, end with the scoreboard.

- 0–3s: “Farkle scorekeeping in seconds” + tap-to-score dice
- 3–7s: Bank + next player + quick turn flow
- 7–11s: Manual mode for physical dice (“Bring your own dice”)
- 11–15s: Scoreboard + “No ads • No accounts • Offline”

---

## App Icon Checklist

Ensure:
- [ ] No alpha channel / transparency
- [ ] No rounded corners (iOS applies them automatically)
- [ ] sRGB color space recommended

---

## Pre-Submission Checklist

- [ ] Bundle ID matches App Store Connect app record (`com.tcraig.FarkleScorer`)
- [ ] Version number (`MARKETING_VERSION`) is correct (currently `1.0`)
- [ ] Build number (`CURRENT_PROJECT_VERSION`) increments with each upload
- [ ] Archive built with **Release** configuration
- [ ] Tested on real device (not just Simulator)
- [ ] Privacy Policy URL is live and accessible
- [ ] Support URL is live and accessible
- [ ] All required screenshots uploaded
- [ ] App Review notes filled in
- [ ] Export compliance answered (typically “No” for a scorekeeper app)

---

## Notes

- **Local Network**: Multiplayer uses local network discovery (Bonjour) to connect nearby devices.
- **Trademark disclaimer**: The description includes an “unofficial companion” note. Adjust wording if you obtain explicit permission.


