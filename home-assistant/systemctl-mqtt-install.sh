#!/bin/bash
# ============================================================
# Run this via SSH on the printer's Raspberry Pi (NOT on the
# Home Assistant host).
#
# Installs systemctl-mqtt and sets up a systemd service that
# publishes an MQTT message the instant a real shutdown/reboot
# is triggered (systemd's PrepareForShutdown signal) - whether
# initiated via `sudo shutdown`, the Mainsail "Host Shutdown"
# button, or a touchscreen display. This is independent of
# network reachability, so a Wi-Fi hiccup can never trigger it.
#
# Broker: the SAME broker your Home Assistant MQTT integration
# uses (commonly the "core-mosquitto" HA add-on, reachable at
# your HA host's address, e.g. homeassistant.local). If your
# printer's own local Mosquitto instance is a SEPARATE broker
# from the one HA is connected to, you MUST point this at the
# HA broker, not at localhost - otherwise HA will never see the
# discovery messages.
#
# Reference: https://github.com/fphammerle/systemctl-mqtt
# ============================================================

set -e

MQTT_HOST="homeassistant.local"      # <-- adjust to your HA host
MQTT_USERNAME="systemctl-mqtt"        # <-- dedicated MQTT login (see guide)
MQTT_PASSWORD="CHANGE_ME"             # <-- set this before running

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

