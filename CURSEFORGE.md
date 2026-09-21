# CurseForge project setup (not shipped in the zip)

## Project fields

- **Name:** ForeverVoice
- **Summary** (short line under the title):
  Proximity voice chat for your guild: hear the players near you, their voice fades as they walk away.
- **Main category:** Chat & Communication
- **Other categories:** Guild, Audio & Video
- **Game version:** WoW Forever 1.60 (Interface 16001)
- **Release type for 1.0:** Beta (the Forever client itself is a beta)
- **Upload:** `ForeverVoice1.0.zip`
- **Changelog for the file:** copy the 1.0 section below.

---

## Description (paste into the CurseForge editor)

# ForeverVoice

**Proximity voice chat for your guild in World of Warcraft: Forever.**

Walk into a zone, cross a guildmate on the road, and just **talk to them**. ForeverVoice turns
Blizzard's built-in voice chat into **proximity voice**: you hear the players close to you, their
voice fades as they walk away, and they go silent once they are out of range.

No external program, no Discord, no server to host. ForeverVoice uses the game's own voice chat.
No libraries, no dependencies.

## How it works

1. ForeverVoice joins your **guild voice channel** (or your group's) when you log in.
2. Every player with the addon shares their position with the guild through a small hidden
   addon message.
3. Your addon sets the volume of **each player** based on their distance: full voice up close,
   a smooth fade, then silence.

**Everyone needs the addon.** A guildmate without ForeverVoice doesn't share their position,
and hears the whole channel at normal volume.

## Features

- **Proximity volume**: full voice up to a distance you choose, then a fade (linear, natural or
  smooth), silence past the maximum range. A live graph shows the curve.
- **"X is in voice range" alert**: a sound and a message when a guildmate comes within earshot.
- **Group audible in dungeons**: positions are hidden in dungeons and battlegrounds, so your
  group stays audible there.
- **Always hear someone**: right-click a player in the window to hear them at any distance.
- **Voice window**: who is talking, how far each player is, how loud you hear them, and your
  own line with your push-to-talk key.
- **Minimap button** with the list of players in range and a halo while someone talks.
- **Join and leave voice** in one click.
- **English and French**, switched in one click.
- **Settings that stick**, even with the Forever beta bug that resets addon settings.
- **Safe**: only volumes are changed, never the Blizzard mute. Everyone is put back to full
  volume when you turn it off, leave voice or log out.

## Controls

| Minimap button | Effect |
| --- | --- |
| Left-click | Options menu |
| Right-click | Proximity on / off |
| Middle-click | Join / leave voice |
| Shift + click | Show / hide the window |

| Command | Description |
| --- | --- |
| `/fv` | Show / hide the window |
| `/fv options` | Options menu |
| `/fv on` / `/fv off` | Proximity on / off |
| `/fv join` / `/fv leave` | Join / leave voice |
| `/fv range 40 8` | Silent from 40 yards, full voice up to 8 yards |
| `/fv debug` | Status, for bug reports |

## Installation

1. Extract the `ForeverVoice` folder into `World of Warcraft\<Forever folder>\Interface\AddOns`.
2. In the game settings, turn on **Voice Chat** and set your microphone and talk mode.
3. Log in: ForeverVoice joins guild voice by itself. Ask your guild to install it too!

## Note about settings

Because of a Forever beta bug, addon settings are not read back after a relog. ForeverVoice keeps
a backup in one account macro named **ForeverVoice**. Keep it: it does nothing when clicked, and
it is recreated if deleted.

---

### Français

**Chat vocal de proximité pour ta guilde sur WoW Forever.** Tu croises un membre de ta guilde :
tu lui parles directement. Plus il s'éloigne, moins tu l'entends, puis il devient muet hors de
portée. ForeverVoice utilise le vocal intégré de Blizzard, sans logiciel externe.
**Toute la guilde doit avoir l'addon.**

Bouton minimap ou `/fv` pour tout régler. Le menu est entièrement disponible en français.

*Made by Polarz141*

---

## File changelog (1.0)

First public release.
- Proximity voice on top of Blizzard's voice chat: volume follows distance.
- Guild voice joined automatically (group channel otherwise).
- Options menu with range sliders, fade curve and live graph, English / French.
- Minimap button: options, on / off, join / leave voice, players in range.
- Voice window: who talks, distance and volume per player, your talk key.
- Right-click a player to always hear them.
- "X is in voice range" alert.
- Group audible in dungeons and battlegrounds.
- Settings survive relogs and restarts on the Forever beta.
