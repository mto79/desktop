# Voice

Four separate things, each with its own key and its own reason for being separate.

| | Does | Key |
|---|---|---|
| Dictation | Types what you say | Right Alt, held |
| Voice command | Does what you say, from a fixed list | `SUPER + C` |
| Speech | Says a line out loud | none; other commands call it |
| Meeting capture | Records and transcribes a call | `SUPER + CTRL + M` |

Transcription is done on this machine, by voxtype (Whisper).

## Dictation

The hotkey belongs to **voxtype**, not Hyprland. Voxtype reads the key device directly, so
press and release are seen whatever the compositor is doing. A Hyprland `bindr` did this
before and dropped about one release in three, leaving the microphone open.

`desktop-dictate watch`, autostarted, follows voxtype's state and ducks the music while it
records. `desktop-dictation-details` reports how it is set up and what was dictated lately,
for the dictation panel.

## Voice commands

    desktop-voice toggle        # listen, and act when you stop talking
    desktop-voice run "text"    # act on a sentence as if it had been said
    desktop-voice list          # what it understands

It matches against a list on purpose. Speech is misheard, and here a misheard sentence can
only become one of the listed things or nothing: there is no path from what was heard to a
shell. Restart, shut down and log out are not on the list. What is said to an agent is
typed into its prompt and left for you to read and send.

`desktop-voice-endpoint` decides when somebody has finished speaking.

## Speech

    desktop-say "the backup finished"
    desktop-say --hush                        # stop now, drop the queue
    desktop-say --toggle | --mute | --unmute
    desktop-say --setup                       # install the voice, once, no sudo
    desktop-say --voices
    desktop-say --test

It stays quiet when switched off, when do-not-disturb is on, and whenever a microphone is
in use, which is a call or a dictation.

`~/.config/desktop/say.dict` holds pronunciations, one `pattern<TAB>how to say it` a line,
for names the voice gets wrong.

`desktop-brief --say` is the short spoken summary of what needs you; `--welcome` is the
one said at login.

## Meeting capture

    desktop-meeting-capture start [name]
    desktop-meeting-capture stop           # end, transcribe
    desktop-meeting-capture toggle
    desktop-meeting-capture status

It records **both** sides: the output monitor carries the other participants, the
microphone carries you, and neither carries both. The two are kept as separate channels
and transcribed separately, which is both more accurate than a mix and labels who said
what.

A recording of a call holds other people's voices. Tell them it is running.
