import os
import re

files = [
    "EarlyOtter/DesignSystem.swift",
    "EarlyOtter/UI/Dashboard/DayAlarmEditView.swift",
    "EarlyOtter/UI/Dashboard/EarlyOtterDetailsView.swift",
    "EarlyOtter/UI/Onboarding/OnboardingView.swift",
    "EarlyOtter/UI/Permissions/PermissionsView.swift",
    "EarlyOtter/UI/Rules/DaySettingsView.swift",
    "EarlyOtter/UI/Rules/RulesView.swift",
    "EarlyOtter/UI/Schedule/ScheduleView.swift",
    "EarlyOtter/UI/Settings/SettingsView.swift"
]

for file in files:
    if not os.path.exists(file):
        continue
    with open(file, 'r') as f:
        content = f.read()

    # multiline overlay removal for DesignSystem.swift and others
    content = re.sub(r'\s*\.overlay\(\s*RoundedRectangle[^)]+\)\s*\.stroke\(WPStyles\.cardBorder,\s*lineWidth:\s*1\)\s*\)', '', content)
    
    # single line overlay removal
    content = re.sub(r'\.overlay\(RoundedRectangle[^)]+\)\.stroke\(WPStyles\.cardBorder,\s*lineWidth:\s*1\)\)', '', content)
    
    # RoundedRectangle..stroke on its own line (e.g. background layers)
    # wait, if it's "RoundedRectangle(...).stroke(WPStyles.cardBorder, lineWidth: 1)" as a standalone view, removing it might leave an empty space or compile error if in a ZStack/overlay.
    content = re.sub(r'RoundedRectangle[^)]+\)\.stroke\(WPStyles\.cardBorder,\s*lineWidth:\s*1\)', 'EmptyView()', content)
    
    # remove just the stroke modifier if attached
    content = re.sub(r'\s*\.stroke\(WPStyles\.cardBorder,\s*lineWidth:\s*1\)', '', content)

    # for dividers: replace Divider().overlay(WPStyles.cardBorder) with Divider()
    content = content.replace('Divider().overlay(WPStyles.cardBorder)', 'Divider()')

    with open(file, 'w') as f:
        f.write(content)

