# ForeverVoice - Changelog

## 1.3
- Speaker icon above the head of players who are talking, so you see who
  speaks. Needs friendly nameplates (Shift + V by default). Can be turned
  off in the options.
- The join button (window, and middle-click on the minimap button) now asks
  "Guild or Group?". Unavailable choices are greyed out with the reason,
  and your choice is used for the automatic join too.
- The same icon shows above your own character while you talk. Open the
  options menu to drag it right above your head. Can be turned off.

## 1.2
- Fixed: players right next to you were too loud and saturated. Full voice
  used the top of Blizzard's volume slider, which boosts the sound.
- New "Volume up close" slider (default 50%) to set how loud full voice is.
- Group voice: the join request now really asks to activate the channel,
  with a second request when activating the existing channel isn't enough.
- Blizzard voice errors are shown in the chat, with a message when a
  channel can't be joined.

## 1.1
- Choose your voice channel in the options: Auto (guild, else group),
  Guild or Group. Switching while in voice moves you to the new channel
  right away.
- In Group mode, you join group voice as soon as a group forms.
- /fv join guild and /fv join group switch channel from the chat.
- Leaving voice by hand is respected: you are not joined back
  automatically until you join again yourself.

## 1.0
First public release.
- Proximity voice on top of Blizzard's voice chat. Each player's volume
  follows their distance: full voice up close, then a fade, then silence.
- Guild voice joined automatically at login. The group channel is used when
  there is no guild voice.
- Positions shared between ForeverVoice users through hidden addon messages.
- Options menu: range sliders, fade curve (linear, natural, smooth) with a
  live graph, behavior and window settings, English / French.
- Minimap button: options, proximity on / off, join / leave voice,
  show / hide the window, tooltip with the players in range.
- Voice window: your own line with your talk key, speaking players, distance
  and volume of each player, "too far" / "elsewhere" / "no addon" states,
  compact mode, collapse.
- Right-click a player to always hear them.
- "X is in voice range" alert.
- Group audible in dungeons and battlegrounds, where positions are hidden.
- Settings survive relogs and restarts on the Forever beta (CVar copy plus
  an account macro).
