# App icon (Android & iOS)

The launcher icon is generated from **`assets/logo/Logo-KINS.png`** for both Android and iOS.

## Using `kins-App-Logo.svg` as the app icon

Android and iOS require **PNG** launcher icons (SVG is not supported). To use your **`assets/logo/kins-App-Logo.svg`** design:

1. **Export the SVG to PNG** at **1024×1024 px** (e.g. in Figma, Illustrator, Inkscape, or an online converter).
2. Save the file as **`assets/logo/app_icon.png`**.
3. In **`pubspec.yaml`**, under `flutter_launcher_icons`, set:
   ```yaml
   image_path: "assets/logo/app_icon.png"
   ```
4. Run:
   ```bash
   dart run flutter_launcher_icons
   ```

The SVG is already in your assets and can be used inside the app (e.g. with `flutter_svg`) for in-app branding; only the **home screen icon** must be PNG.
