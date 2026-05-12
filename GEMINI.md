# AppKebtang Development Standards

This document outlines the architectural patterns and development standards for the AppKebtang project.

## Architectural Patterns

### 1. State Management (Provider)
- Use `ChangeNotifier` and `Provider` for global and local state.
- `AppState` manages the core business logic and backend synchronization.

### 2. Error Handling & Feedback
- **Optimistic UI Updates:** UI state should change immediately upon user action.
- **Rollback Mechanism:** If a backend operation fails, the `AppState` must revert its internal list to match the server state.
- **User Notification:** Errors are propagated via the `errorMessage` property in `AppState`. The `HomePage` listener captures these errors and displays them using `ScaffoldMessenger` (SnackBars).
- **Async Feedback:** Long-running operations (Login, Register, Change Password) must show a loading indicator.

### 3. Scalability & Performance
- **Backend Pagination:** All transaction-related endpoints support `page` and `limit` parameters to handle large datasets efficiently.
- **Infinite Scroll:** Transaction lists in both the User and Admin panels implement `ScrollController` listeners to fetch data incrementally.
- **Environment Configuration:** Use `flutter_dotenv` for all environment-specific variables (API URLs, etc.). Never hardcode endpoints.

### 4. Features & Reporting
- **Filtering:** Support both real-time Search and Custom Date Range selection using native pickers.
- **Analytics:** The Summary page provides a visual Category Breakdown with percentage-based indicators.
- **Data Portability:** Users can export their financial data to CSV format and share it using native platform tools (`share_plus`).

### 5. Security Standards (OWASP/NIST)
- **Token Storage:** Always use `FlutterSecureStorage` (via `SecureTokenStorage`) for JWT tokens.
- **Password Safety:** New passwords must be at least 8 characters. Verifying the old password is mandatory for updates.
- **Auto-Logout:** The `ApiConfig.handleAuthError()` helper must be used on every API response to handle session expiration.

## UI/UX Standards
- **Dark Mode Support:** All custom widgets must respect `Theme.of(context).brightness`.
- **Branding Consistency:** Use the centralized `CategoryIcons` helper for all transaction-related iconography.
- **Empty States:** Provide professional "No Data" illustrations when lists are empty.

## Testing
- **Model Tests:** All data models must have serialization tests in the `test/` directory.
- **Functional Testing:** Core flows should be verified manually or through automated tests before release.
