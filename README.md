# MONIKA

An Intelligent Mobile HR Management System with Geo-Fenced Attendance Taking and Rule-Based Machine Learning Training Prediction

A Flutter app (Android and iOS) backed by Supabase. Setup of the backend is in
[supabase/README.md](supabase/README.md) and the training model in [ml/README.md](ml/README.md).

## Running locally

1. Copy `lib/core/config/supabase_config.example.dart` to `supabase_config.dart` and fill in the project URL and publishable key.
2. `flutter pub get`
3. `flutter run`

## Release builds

The app ID is `com.monikahr.app` on both platforms. Change it before the first store upload if you want a different one; it can't be changed afterwards.

### Android

1. Create an upload key once (keep the file and passwords safe; losing them means you can't update the app):

   ```
   keytool -genkey -v -keystore %USERPROFILE%\monika-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias monika
   ```

2. Create `android/key.properties` (never committed):

   ```
   storePassword=<the keystore password>
   keyPassword=<the key password>
   keyAlias=monika
   storeFile=C:\\Users\\<you>\\monika-upload.jks
   ```

3. `flutter build apk --release --split-per-abi` for smaller APKs to install directly, or
   `flutter build appbundle` for Google Play.

Without `key.properties`, release builds are signed with the debug key, which is fine for testing but not for publishing.

### iOS

iOS builds need a Mac with Xcode. Without one, run the **iOS build check** workflow from the GitHub Actions tab to confirm the app still compiles (unsigned, can't be installed).

On a Mac:

1. `flutter pub get`, then open `ios/Runner.xcworkspace` in Xcode.
2. Runner → Signing & Capabilities: choose your Team, and keep the **Access WiFi Information** capability (MONIKA needs it to read the office WiFi name; iOS returns nothing without it).
3. Connect an iPhone and run, or `flutter build ipa` for TestFlight / App Store.

A free Apple ID can install on your own iPhone for testing (it expires after 7 days). Distributing to other people through TestFlight or the App Store needs the paid Apple Developer Program. If a team can't use the WiFi capability, the WiFi check fails on iOS and clock-ins are flagged as a WiFi mismatch; the GPS and device checks still work.
