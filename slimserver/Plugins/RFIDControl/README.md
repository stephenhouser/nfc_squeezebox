# RFID Control for Lyrion Music Server (LMS)

Adds the ability to execute LMS commands via the CLI (socket) based on RFID
tags. Adds commands to the system

- `rfid tag <tag id>` will execute the LMS commands associated with `tag id`
- `rfid player <reader id> ?` will reply with the LMS Player (client) that is associated with the RFID reader.

Install `RFIDControl` in `.../cache/Plugins/RFIDControl` of LMS.

TODO:
RFID Reader to Player associations are configured in `readers.csv`
Tag to LMS commands are configured in `tags.csv`