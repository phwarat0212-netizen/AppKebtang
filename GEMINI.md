# AppKebtang Development Standards

This document outlines the architectural patterns and development standards for the AppKebtang project.

## Architectural Patterns

### 1. State Management (Provider)
- Use `ChangeNotifier` and `Provider` for global and local state.
- `AppState` manages the core business logic and backend synchronization.

### 2. Error Handling & Feedback
- **Optimistic UI Updates:** UI state should change immediately upon user action.
- **Rollback Mechanism:** If a backend operation fails, the `AppState` must revert its internal list to match the server state (either by re-loading from backend or using local backups).
- **User Notification:** Errors are propagated via the `errorMessage` property in `AppState`. The `HomePage` listener captures these errors and displays them using `ScaffoldMessenger` (SnackBars).
- **Localized Errors:** Use localization keys (e.g., `'error_network'`, `'connection_error'`) instead of hardcoded strings to support Thai, English, and Chinese.

### 3. Real-time Synchronization
- **Socket.io:** The app listens for `data_changed` events from the backend to trigger silent data refreshes.
- **Pull-to-Refresh:** All transaction-related tabs (`DashboardTab`, `HistoryTab`, `SummaryPage`, `AdminPage`) must implement a `RefreshIndicator` wrapping a `CustomScrollView` or `SingleChildScrollView`.

### 4. Security Standards (OWASP/NIST)
- **Token Storage:** Always use `FlutterSecureStorage` (via `SecureTokenStorage`) for JWT tokens. Never store tokens in `SharedPreferences`.
- **API Headers:** Use `ApiConfig.getHeaders()` to ensure all requests include the proper `Authorization` token and `Content-Type`.
- **Auto-Logout:** The `ApiConfig.handleAuthError()` helper must be used on every API response to automatically handle token expiration (401/403) and redirect to the login screen.

## UI/UX Standards
- **Dark Mode Support:** All custom widgets must check `Theme.of(context).brightness` or use the `ThemeState` to ensure high contrast and readability.
- **Form Validation:** Input fields should use `TextEditingController` and provide clear error messages if validation fails (e.g., in `LoginPage` and `RegisterPage`).

## Testing
- **Unit Tests:** New data models must include JSON serialization tests in the `test/` directory.
- **Widget Tests:** Core flows (Login, Transaction Addition) should ideally be verified with widget tests.
