# Voron 2.4 Tallboi — 5-Toolhead AFC/EMU MMU + Home Assistant Integration

This repository documents two complete, working setups for a Voron 2.4 "Tallboi"
running **Klipper** with **Klipper Toolchanger** (5 independent toolheads) and a
5-lane **EMU** MMU driven by **AFC-Klipper-Add-On**:

1. **[AFC EMU MMU Setup](docs/01-afc-emu-toolchanger-setup.md)** — wiring, pin
   mapping, and Klipper configuration for a 5-lane EMU MMU in Direct Mode, one
   lane per toolhead, using a Mellow Fly D5 board for steppers/switches and a
   second board ("hexa") for the analog PFS buffer sensors.
2. **[Home Assistant Dashboard & Auto-Shutdown](docs/02-home-assistant-dashboard-and-autoshutdown.md)**
   — a Lovelace dashboard (status, temperatures, rotated camera feed, power
   control) plus an automation that safely powers down the printer's Shelly
   smart plug a fixed delay after a *real* shutdown is detected — never on a
   Wi-Fi hiccup.

## Repository structure

```
.
├── README.md
├── docs/
│   ├── 01-afc-emu-toolchanger-setup.md
│   ├── 02-home-assistant-dashboard-and-autoshutdown.md
│   └── images/
│       ├── afc/                     # screenshots for the AFC guide
│       └── homeassistant/           # screenshots for the HA guide
├── config/
│   └── AFC/                         # drop-in Klipper/AFC config (adjust to your printer)
│       ├── AFC.cfg
│       ├── AFC_Hardware.cfg
│       ├── AFC_EMU.cfg
│       ├── AFC_PFS_Test_Macros.cfg
│       └── mcu/
│           └── EMU_board.cfg
└── home-assistant/                  # drop-in Home Assistant config
    ├── voron2tb_dashboard.yaml      # full Lovelace view
    ├── configuration_snippet.yaml   # add to configuration.yaml
    ├── scripts_addition.yaml        # append to scripts.yaml
    ├── automations_addition.yaml    # append to automations.yaml
    └── systemctl-mqtt-install.sh    # run on the printer's Pi
```

## Hardware summary

| Component | Role |
|---|---|
| 5× toolhead (EBB-based) via Klipper Toolchanger | One dedicated extruder/hotend per lane, no shared hub |
| Mellow Fly D5 | Drives all 5 lane steppers + digital prep/load switches |
| Second board ("hexa") | 5× analog PFS (Proportional Sync-Feedback) buffer sensors |
| 5× Omron D2HW microswitches per lane | `prep` (before lane extruder) and `load` (after lane extruder) |
| Shelly plug | Mains power for the whole printer, controlled from Home Assistant |
| Raspberry Pi (Klipper host) | Runs Klipper, Moonraker, Mosquitto is *not* required locally — see HA guide |

## Credits / sources

- [AFC-Klipper-Add-On](https://github.com/AFCProject/AFC-Klipper-Add-On) and its
  [documentation](https://www.afcproject.dev/)
- [Klipper Toolchanger](https://github.com/viesturz/klipper-toolchanger)
- [Mellow Fly D5 pinout](https://mellow.klipper.cn/en/docs/ProductDoc/MainBoard/fly-d/fly-d5/pin)
- [Proportional Sync-Feedback Sensor by kashine6](https://github.com/kashine6/Proportional-Sync-Feedback-Sensor)
- [systemctl-mqtt by fphammerle](https://github.com/fphammerle/systemctl-mqtt)
- [Home Assistant MQTT integration docs](https://www.home-assistant.io/integrations/mqtt/)
- [Home Assistant Tile card docs](https://www.home-assistant.io/dashboards/tile/)
- [card-mod by thomasloven](https://github.com/thomasloven/lovelace-card-mod)

## License

Documentation and config in this repository are provided as-is, for reference.
Adjust every pin, IP address, and calibration value to your own hardware before use.
