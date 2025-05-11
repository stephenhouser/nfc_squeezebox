# NFC Jukebox for Lyrion Music Server (LMS)

Play albums, playlists, and otherwise control a Lyrion Music Server (LMS) with RFID cards. Simply preset an RFID card or tag to an RFID reader and have LMS play your music.

There are three parts to the system:

1. RFID Reader (using ESPHome)
2. MQTT/LMS Bridge
3. LMS running somewhere (not part of this project)

The reader simply posts when a tag is read and when removed to an MQTT topic. For simplicity, an ESP32-based reader can programmed and configured with ESPHome. It simply needs to publish any presented tags to MQTT and to publish `None` when no tags are present and/or when a tag is removed. This could easily be done without ESPHome in custom firmware or a different microcontroller, or even a PC/Raspberry Pi. The reader could also have additional buttons or functions that could go to other topics or be tied into something like HomeAssistant (not required).

The MQTT/LMS bridge monitors the RFID topic(s) for presented tags. When a tag is presented, the command associated with it is sent to the LMS.

Tags and their associated commands are configured in a simple Comma Separated Value (CSV) file. The fields are (in order), the tag ID value in hexadecimal format as sent by the reader, a command type, and any command parameters. `None` as a tag refers to when no tag is present, e.g. a tag was removed.

An example CSV configuration file:

```
tag,command,parameters,notes
None,command,"playlist clear","stop playing and clear playlist"
86:75:30:09,url,"http://opml.radiotime.com/Tune.ashx?id=s24232&formats=aac,ogg,mp3&partnerId=15&serial=59bf631fddda17f8c19e2bc4914096f1","WHOOPIE 100.9 Radio"
1987,year,1987,"Songs from 1987"
65:78:98:ab,album,"Prince/Prince (1979)"
23:67:fb:45,album,"Prince/1999 (1982)"
45:67:56:23:ab:cd:ef,year,2010,"Random items from 2010"
34:67:56:23:ab:cd:ef,year,1967,"Random items from 1967"
56:78:ac:bc,album,"Compilations/Like, Omigod! The '80s Pop Culture Box (Totally) (2002)"
```

Commands are
    - 'album': play the files in an album, in order, relative to the /music directory
    - 'url': play the "Internet radio" station given by the URL
    - 'year': play a dynamic playlist (preconfigured) to play songs from a year
    - 'command': send the given command directly to the LMS.

### Random

Could add more features to the "box" the cards go in. Not sure I want them.

- skip button - skips to next item on playlist or album
- back button - skips backwards to previous item
- volume control - adjust volume
- play/pause button - play pause
- display - show selection?
- LED - show status, RGB, Green playing, Red stopped, Blue paused?

Maybe the single LED would be nice to show things are working.
