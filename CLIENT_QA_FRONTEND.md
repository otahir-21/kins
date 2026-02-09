# KINS App — Client Q&A (Frontend)

Answers for client questions, **frontend only**. Backend-specific questions are listed at the end for your backend team/Cursor.

---

## Frontend answers

### What is the current tech stack (frontend)?

- **Framework:** Flutter (Dart)
- **State management:** Riverpod (`flutter_riverpod`)
- **Navigation:** GoRouter (`go_router`)
- **UI:** Material Design 3, custom theme
- **Local storage:** SharedPreferences (`shared_preferences`)

*Backend, database, and hosting are covered in the backend Q&A.*

---

### Is the app native, hybrid, or cross-platform (iOS/Android)?

**Cross-platform.** One codebase runs on:

- iOS  
- Android  
- Web (supported, not primary)

Same app, same features, on both major mobile platforms.

---

### What framework did you choose (React Native, Flutter, Swift/Kotlin, etc.) and why?

**Flutter (Dart).**

Reasons:

- **Single codebase** for iOS and Android — faster delivery and one team.
- **Native performance** — compiles to native ARM code, no JS bridge.
- **Consistent UI** — same look and behavior on both platforms.
- **Strong ecosystem** — good support for Firebase, maps, auth, push, file handling.
- **Faster iteration** — hot reload for quick UI and logic changes.

---

### How modular is the architecture — can features be added without major rewrites?

**Yes. The frontend is built to be modular.**

- **Clean Architecture–style** structure:
  - **Screens** — UI only
  - **Providers** — state and business logic
  - **Repositories** — data access (Firebase, local, APIs)
  - **Models** — data structures
  - **Routes** — centralized navigation

- **Adding a feature** = add screen(s) + provider(s) + repository (if new data). No need to rewrite existing flows.
- **Clear separation** so changes in one area (e.g. auth, profile, posts) don’t force rewrites elsewhere.

---

### What parts are custom-built vs third-party (frontend)?

**Custom-built (our code):**

- All app screens and flows (splash, onboarding, auth, profile, home, discover, map, chat, notifications, etc.)
- Navigation and routing
- State management (providers and logic)
- Repository layer (how we call backend/APIs)
- Theme and UI components
- Form validation and error handling

**Third-party (packages/services we use):**

- **Firebase** — Auth, Firestore, FCM (we integrate via SDKs)
- **Google Maps** — `google_maps_flutter`, `geolocator`, `geocoding`
- **UI/UX** — `intl_phone_field`, `pin_code_fields`, `file_picker`, `share_plus`, `flutter_svg`, `intl`
- **Storage** — `shared_preferences` (local key-value)

*Backend services (e.g. database, cloud storage, image/video processing, hosting) are listed in the backend Q&A.*

---

### How are environments handled (dev / staging / production) on the frontend?

- **Build:** Standard Flutter debug vs release; we can add **flavors** (e.g. dev, staging, prod) for different API endpoints and configs.
- **Config:** Sensitive values (e.g. CDN) can use:
  - **Compile-time:** `--dart-define` / `String.fromEnvironment` for production.
  - **Dev:** Config file or defaults (e.g. `bunny_cdn_config.dart`).
- **Firebase:** We can point to different Firebase projects per flavor (dev/staging/prod) when needed.

*Backend environment setup (servers, DB, env vars) is in the backend Q&A.*

---

### Frontend and scalability (user count)

- **Frontend** doesn’t “crash” by user count; it runs on each user’s device.
- **To support many users**, frontend focuses on:
  - **Efficient data usage** — pagination, lazy loading, minimal large payloads.
  - **Caching** — avoid repeated same requests where appropriate.
  - **Handling loading and errors** — so the app stays usable under slow or heavy backend load.

*Actual limits (e.g. “how many users before the system crashes”) and backend scaling are in the backend Q&A.*

---

## Questions for backend (give these to backend Cursor)

Use the answers from your backend doc for the client. These are **not** frontend-owned:

1. **What is the backend tech stack (language, framework)?**
2. **Describe the database (SQL / NoSQL)?**
3. **Describe the hosting structure (AWS, GCP, Azure, etc.)?**
4. **What are all the third-party backend tools (cloud storage, image/video processing, notifications, logins, etc.)?**
5. **Is the backend monolithic or modular/microservices?**
6. **How many users can the current tech handle before crashing? (e.g. 1k / 100k / 1M)?**
7. **What needs to change to allow the platform to handle 100k+ or 1M+ users?**

You can paste the backend answers into a separate **CLIENT_QA_BACKEND.md** or merge them with this file for one client-facing doc.
