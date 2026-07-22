# SIGNAL FLOW Show Time — v1.0.0 RC2 Checklist

## Project validation

- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `dart format lib test`
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `flutter test` passes
- [ ] `flutter run -d macos` starts successfully

## Core timer

- [ ] START begins counting from 00:00:00
- [ ] PAUSE stops elapsed time
- [ ] RESUME continues from the paused value
- [ ] Hold RESET returns the timer to zero
- [ ] Space performs Start / Pause / Resume
- [ ] Controls hide while running and return with pointer movement

## Title and display

- [ ] Show title can contain spaces
- [ ] Enter saves the title
- [ ] Escape cancels title editing
- [ ] Current time display can be enabled and disabled
- [ ] Current seconds can be enabled and disabled
- [ ] 12-hour and 24-hour formats work
- [ ] Japanese and English labels switch correctly

## Desktop behavior

- [ ] Always on Top works
- [ ] Command-Comma opens Preferences
- [ ] Escape closes Preferences
- [ ] About menu opens the About dialog
- [ ] Escape closes the About dialog
- [ ] Command-Q quits the app
- [ ] Settings persist after restart

## Release preparation

- [ ] Version displays `1.0.0-rc.2`
- [ ] README, CHANGELOG, LICENSE are present
- [ ] GitHub Issues URL is correct
- [ ] Release build succeeds with `flutter build macos --release`
- [ ] Release `.app` launches outside VS Code
