#!/bin/bash
# Restart mute LED service after suspend/resume so HDA codec state is re-initialized
case "$1" in
    post) systemctl restart hp-mute-leds.service ;;
esac
