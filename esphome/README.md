# Lyrion Music Server Connection for ESPHome

This is a limited external component for ESPHome that provides a connection to a Lyrion Music Servier (LMS), formerly Logitech Music Server. It is designed to work with an RFID reader and transmit unique RFID tags to LMS via the `RFIDControl` plugin. The associated plugin is responsible to perform actions on the LMS to queue up music or other actions.

An ESPHome configuration like the following connects a `PM532` RFID reader to the `lms` component connected to an LMS. When an RFID tag is presented, the unique ID is sent to LMS. When a tag is removed, that is also sent to the LMS.

```
# use components from a local folder
external_components:
  - source:
      type: local
      path: components

# The LMS Connection Configuration (external component)
lms:
  id: slimserver
  server: slimserver
  client_id: b8:27:eb:4f:71:11

# I2C for RFID Reader
i2c:
  sda: GPIO21
  scl: GPIO22
  scan: true
  id: bus_a

# RFID Reader Actions
pn532_i2c:
  update_interval: 1s
  on_tag:
    then:
    - lambda: |-
        auto lms = id(slimserver);
        lms->send_tag(x.c_str());
  on_tag_removed:
      then:
      - lambda: |-
          auto lms = id(slimserver);
          lms->send_tag_removed();
```

A more complete example is provided in the `components/lms/example` directory.

