#!/usr/bin/env bash

# Runs once per version, before anything reads state.
#
# 0.10.0 reads settings.json, where the lists are set item by item. The
# person's old `KEY = value` file is converted by the SDK, and the keys only
# this plugin had are moved onto the lists here: the words added and allowed
# onto ABBREVIATIONS, and the quiet commands onto SKIPPED_COMMANDS. A quiet
# list set whole replaced the shipped one, so it comes across with the shipped
# commands left out.
settings_converted
if [ -f "$PLUGIN_SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  jq '
    def items($value; $held): $value | split(" ") | map(select(. != "")) | map({key: ., value: $held}) | from_entries;
    (if .ABBREVIATIONS_ADDED then .ABBREVIATIONS = ((.ABBREVIATIONS // {}) + items(.ABBREVIATIONS_ADDED; true)) else . end)
    | (if .ABBREVIATIONS_ALLOWED then .ABBREVIATIONS = ((.ABBREVIATIONS // {}) + items(.ABBREVIATIONS_ALLOWED; false)) else . end)
    | (if .COMMANDS_QUIET then .SKIPPED_COMMANDS = items(.COMMANDS_QUIET; true) | .SKIPPED_COMMANDS_SHIPPED = "off" else . end)
    | (if .COMMANDS_QUIET_ADDED then .SKIPPED_COMMANDS = ((.SKIPPED_COMMANDS // {}) + items(.COMMANDS_QUIET_ADDED; true)) else . end)
    | del(.ABBREVIATIONS_ADDED, .ABBREVIATIONS_ALLOWED, .COMMANDS_QUIET, .COMMANDS_QUIET_ADDED)
  ' "$PLUGIN_SETTINGS" > "$PLUGIN_SETTINGS.moving" && mv "$PLUGIN_SETTINGS.moving" "$PLUGIN_SETTINGS"
fi
