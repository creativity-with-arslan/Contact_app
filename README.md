# Personal Contacts App

A Flutter-based Android contacts application for managing phone contacts
through a simple, modern interface.

## Features

-   View contacts saved in the phone's address book
-   Search contacts by name or phone number
-   Add new contacts to the phone's address book
-   View contact details
-   Edit existing contacts
-   Delete contacts with confirmation
-   Mark contacts as favorites and filter favorites
-   Save favorites between app sessions
-   Block and unblock contacts within the app
-   Call contacts from the app
-   Open the SMS app to message contacts
-   Custom Android launcher icon

> **Important about blocking:** Blocking is an in-app feature. It
> disables calling and messaging actions from this app for contacts
> marked as blocked. It does not block incoming calls or SMS at the
> Android system level.

## Built With

-   [Flutter](https://flutter.dev/)
-   Dart
-   [`flutter_contacts`](https://pub.dev/packages/flutter_contacts) for
    device contacts
-   [`url_launcher`](https://pub.dev/packages/url_launcher) for call and
    messaging actions
-   [`shared_preferences`](https://pub.dev/packages/shared_preferences)
    for local app preferences

## Requirements

To build from source, install:

-   Flutter SDK (Dart is included)
-   Android SDK and Android build tools
-   Android Studio or another editor configured for Flutter

You can test on a physical Android device or an Android emulator.

## Getting Started

### 1. Clone the repository

``` bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
cd YOUR-REPOSITORY
```

Replace the URL and folder name with your actual GitHub repository
details.

### 2. Install dependencies

``` bash
flutter pub get
```

### 3. Run the app

Connect an Android device with USB debugging enabled, or start an
emulator, then run:

``` bash
flutter run
```

Grant contact permissions when prompted.

## Build a Release APK

From the project root, run:

``` bash
flutter build apk --release
```

The APK will be generated at:

``` text
build/app/outputs/flutter-apk/app-release.apk
```

Transfer the APK to a compatible Android phone and open it to install.
Android may ask you to allow installation from the app used to open the
APK.

## Android Permissions

The app requires contact permissions to read and modify the phone's
address book. Review:

``` text
android/app/src/main/AndroidManifest.xml
```

## Data and Privacy

-   Contacts are stored in the phone's address book.
-   Favorites and the app's blocked-contact list are saved locally on
    the device.
-   Installing the app on another phone does not automatically transfer
    contacts or app preferences from the original phone.
-   This project does not describe a cloud synchronization or account
    system.

## Project Structure

``` text
lib/
  main.dart                 # Main Flutter application code
android/
  app/src/main/             # Android configuration and manifest
pubspec.yaml                # Flutter dependencies and project configuration
```

## Development Notes

-   Run `flutter pub get` after changing dependencies.
-   Run `flutter analyze` to check for common Dart and Flutter issues.
-   Run `flutter build apk --release` to create a release APK.

## License

No license has been specified yet. If you make this repository public or
want others to reuse the code, add an appropriate license file.
