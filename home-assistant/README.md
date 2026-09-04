# systemctl-mqtt Installation

This installs [`systemctl-mqtt`](https://github.com/fphammerle/systemctl-mqtt)
on a printer's Raspberry Pi so that Home Assistant can detect a **real**
shutdown/reboot (systemd's `PrepareForShutdown` signal) and safely power off
the printer's smart plug afterwards — see
[`docs/02-home-assistant-dashboard-and-autoshutdown.md`](../docs/02-home-assistant-dashboard-and-autoshutdown.md)
for the full background.

Run these steps **via SSH on each printer's Pi** (not on the Home Assistant
host) — Trident, Voron 2 Mini, Voron 2.4 Tallboi, etc. The script and its
credentials are identical for every printer; only run it once per Pi.

> **Prerequisite:** the MQTT login `systemctl-mqtt` / `Vorons` must exist once
> in your Mosquitto broker (Home Assistant: **Settings → Add-ons → Mosquitto
> broker → Configuration → Logins**) before running this on any printer.

## 1. Create the script

Paste this whole block into the Pi's SSH session and press enter:

```bash
cat > ~/systemctl-mqtt-install.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

MQTT_HOST="homeassistant.local"
MQTT_USERNAME="systemctl-mqtt"
MQTT_PASSWORD="Vorons"

echo "1) Installing dependencies..."
sudo apt-get update
sudo apt-get install --no-install-recommends -y python3-dbus python3-gi python3-pip

echo "2) Installing systemctl-mqtt system-wide..."
sudo pip3 install --break-system-packages --upgrade systemctl-mqtt

echo "3) Creating systemd service..."
sudo tee /etc/systemd/system/systemctl-mqtt.service > /dev/null << UNIT
[Unit]
Description=systemctl-mqtt (reports shutdown/reboot to Home Assistant via MQTT)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/systemctl-mqtt --mqtt-host ${MQTT_HOST} --mqtt-disable-tls --mqtt-username ${MQTT_USERNAME} --mqtt-password ${MQTT_PASSWORD}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

echo "4) Enabling and starting the service..."
sudo systemctl daemon-reload
sudo systemctl enable --now systemctl-mqtt.service

echo "5) Status check:"
sudo systemctl status systemctl-mqtt.service --no-pager
SCRIPT_EOF
```

## 2. Make it executable

```bash
chmod +x ~/systemctl-mqtt-install.sh
```

## 3. Run it

```bash
bash ~/systemctl-mqtt-install.sh
```

The last line of output should show `Active: active (running)`.

## 4. Repeat per printer

Run the exact same three commands again in each other printer's SSH session
— nothing needs to change between printers. Each Pi reports under its own
hostname automatically, e.g.:

- `binary_sensor.voron2tb_logind_preparing_for_shutdown`
- `binary_sensor.trident_logind_preparing_for_shutdown`
- `binary_sensor.voron0_logind_preparing_for_shutdown`

## Troubleshooting

See the troubleshooting table in
[`docs/02-home-assistant-dashboard-and-autoshutdown.md`](../docs/02-home-assistant-dashboard-and-autoshutdown.md#7-troubleshooting-reference)
for common issues (TLS, wrong broker, `[code:135] Not authorized`, stale
discovery state, etc.).
