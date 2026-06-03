#!/bin/bash
cat << 'INNER_EOF' > process.py
import re

with open("EarlyOtter/UI/Rules/DaySettingsView.swift", "r") as f:
    text = f.read()

# 1. Update Auto-Pilot Toggle
old_autopilot_toggle = """Toggle("Event Alarm", isOn: activeBinding)
                            .tint(WPStyles.primaryOrange)
                            .foregroundStyle(WPStyles.primaryText)
                        
                        Text("Use calendar events to set this day's alarm.")
                            .font(.caption)
                            .foregroundStyle(WPStyles.secondaryText)"""
new_autopilot_toggle = """Toggle(isOn: activeBinding) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title3)
                                    .foregroundStyle(WPStyles.primaryOrange)
                                Text("Autopilot Event Alarm")
                                    .font(.headline)
                            }
                        }
                        .tint(WPStyles.primaryOrange)
                        .foregroundStyle(WPStyles.primaryText)"""
text = text.replace(old_autopilot_toggle, new_autopilot_toggle)

# 2. Update Fixed Alarm Toggle & Picker
old_fixed_alarm = """Toggle("Enable Fixed Alarm", isOn: fallbackEnabledBinding)
                            .tint(WPStyles.primaryOrange)
                            .foregroundStyle(WPStyles.primaryText)
                        
                        if appState.preferences.fallbackEnabledDays.contains(weekdayOption.weekday) {
                            DatePicker(
                                "Wake Time",
                                selection: fallbackTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .foregroundStyle(WPStyles.primaryText)
                        }
                        
                        Text("Use a fixed alarm when you want a guaranteed wake-up.")
                            .font(.caption)
                            .foregroundStyle(WPStyles.secondaryText)"""
new_fixed_alarm = """Toggle(isOn: fallbackEnabledBinding) {
                            HStack(spacing: 12) {
                                Image(systemName: "alarm.fill")
                                    .font(.title3)
                                    .foregroundStyle(WPStyles.secondaryBlue)
                                Text("Fixed Alarm")
                                    .font(.headline)
                            }
                        }
                        .tint(WPStyles.primaryOrange)
                        .foregroundStyle(WPStyles.primaryText)
                        
                        if appState.preferences.fallbackEnabledDays.contains(weekdayOption.weekday) {
                            DatePicker(
                                "Wake Time",
                                selection: fallbackTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .center)
                        }"""
text = text.replace(old_fixed_alarm, new_fixed_alarm)

with open("EarlyOtter/UI/Rules/DaySettingsView.swift", "w") as f:
    f.write(text)
INNER_EOF
python3 process.py
