# Smart Power Meter Flutter App

This Flutter mobile application displays real-time power meter data from Firebase Realtime Database.

## Features

- **Real-time Data Display**: Shows live power consumption data from your Arduino power meter
- **Beautiful UI**: Modern Material Design interface with cards and color-coded metrics
- **Device Status**: Shows online/offline status of the power meter device
- **Power Metrics**: Displays voltage, current, live power, and total power consumption
- **Battery Level**: Shows device battery level with visual indicators
- **Auto-refresh**: Automatically updates when new data is received

## Data Structure

The app expects data from Firebase Realtime Database at path `/002` with the following structure:

```json
{
  "voltage": 220.5,
  "current": 1.25,
  "livepower": 275.6,
  "totalpower": 15.8,
  "battery": 79,
  "device": "003",
  "key": 1234,
  "status": "ok"
}
```

## Setup Instructions

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Firebase Configuration**:
   - The app is configured to connect to Firebase project `power-meter-7d423`
   - Database URL: `https://power-meter-7d423-default-rtdb.asia-southeast1.firebasedatabase.app`
   - Make sure your Firebase project has Realtime Database enabled

3. **Run the App**:
   ```bash
   flutter run
   ```

## Firebase Configuration Files

- **Android**: `android/app/google-services.json` and `android/app/src/main/res/values/strings.xml`
- **iOS**: `ios/Runner/GoogleService-Info.plist`

## Arduino Integration

This app works with the Arduino code in `Arduino/for firebase.ino` which sends power meter data every second to Firebase.

## Troubleshooting

- **No Data**: Check if your Arduino device is connected and sending data to Firebase
- **Connection Issues**: Verify Firebase project configuration and network connectivity
- **Build Errors**: Run `flutter clean` and `flutter pub get` to refresh dependencies

## App Screenshots

The app displays:
- Device status (Online/Offline)
- Power consumption metrics (Live Power, Total Power)
- Electrical parameters (Voltage, Current)
- Battery level with progress indicator
- Device information and last update time

## Requirements

- Flutter SDK 3.9.2+
- Firebase project with Realtime Database enabled
- Android Studio or VS Code for development