# Password Reset Feature Documentation

## Overview
The forgot password feature allows officers to reset their passwords via email when they forget their credentials. This uses Supabase Auth's built-in password recovery flow.

## User Flow

### 1. Requesting Password Reset
1. Officer navigates to the login screen
2. Clicks "Forgot Password?" link below the login button
3. Enters their registered email address
4. Clicks "Send Reset Link" button
5. System sends a password reset email via Supabase
6. Officer sees confirmation that email was sent

### 2. Resetting Password
1. Officer checks their email inbox
2. Clicks the password reset link in the email
3. App opens automatically (via deep link) to the reset password screen
4. Officer enters and confirms new password (minimum 6 characters)
5. Clicks "Update Password" button
6. System updates password in Supabase
7. Officer is automatically redirected to login screen
8. Officer can now log in with new password

## Implementation Details

### Screens Added

#### 1. ForgotPasswordScreen (`forgot_password_screen.dart`)
- **Route**: `/forgot-password`
- **Purpose**: Allows officers to request password reset link
- **Features**:
  - Email input field
  - Sends reset link via `Supabase.instance.client.auth.resetPasswordForEmail()`
  - Success confirmation with instructions
  - Option to resend email
  - Back to login button

#### 2. ResetPasswordScreen (`reset_password_screen.dart`)
- **Route**: `/reset-password`
- **Purpose**: Allows officers to set new password after clicking email link
- **Features**:
  - New password input field (with visibility toggle)
  - Confirm password input field (with visibility toggle)
  - Password validation (minimum 6 characters, passwords must match)
  - Updates password via `Supabase.instance.client.auth.updateUser()`
  - Success confirmation
  - Auto-redirect to login after success

### Modified Files

#### 1. login_screen.dart
- Added navigation to `/forgot-password` route when "Forgot Password?" is clicked
- Removed placeholder "Password recovery coming soon" message

#### 2. main.dart
- Added imports for `forgot_password_screen.dart` and `reset_password_screen.dart`
- Added routes:
  - `/forgot-password` → `ForgotPasswordScreen()`
  - `/reset-password` → `ResetPasswordScreen()`

#### 3. splash_screen.dart
- Added auth state change listener to detect password recovery events
- When `AuthChangeEvent.passwordRecovery` is detected, navigates to `/reset-password`
- Handles deep link from password reset email

## Supabase Configuration

### Email Templates
Supabase automatically sends password reset emails using the default template. The email contains a link with format:
```
io.supabase.nbrofieldapp://reset-password#access_token=...&type=recovery
```

### Deep Link Configuration
The app is configured to handle deep links with scheme:
```
io.supabase.nbrofieldapp://
```

When the user clicks the reset link, the app:
1. Opens automatically (if installed)
2. Detects `AuthChangeEvent.passwordRecovery` in splash screen
3. Navigates to reset password screen
4. User is authenticated temporarily to allow password update

### Security
- Reset links expire after 1 hour (Supabase default)
- Links are single-use only
- Password must be at least 6 characters
- User must confirm new password to prevent typos

## Testing

### Test Forgot Password Flow
1. Run the app: `flutter run`
2. Go to login screen
3. Click "Forgot Password?"
4. Enter a valid officer email (e.g., test@example.com)
5. Click "Send Reset Link"
6. Verify success message appears
7. Check email inbox for reset link

### Test Password Reset Flow
1. Open reset email
2. Click the password reset link
3. App should open automatically to reset screen
4. Enter new password (e.g., "newpassword123")
5. Confirm new password
6. Click "Update Password"
7. Verify success message and auto-redirect
8. Try logging in with new password

### Edge Cases to Test
- Invalid email address → should show error
- Email not in system → Supabase sends email anyway (security: don't reveal which emails exist)
- Password too short (<6 chars) → should show validation error
- Passwords don't match → should show validation error
- Expired reset link → should show error when trying to update password
- Using reset link twice → second attempt should fail

## Error Handling

### Common Errors
1. **Network Error**: Cannot send email
   - Display: "Error sending reset email: [error message]"
   - Action: User can try again

2. **Invalid Email**: Email format invalid
   - Display: Via Supabase AuthException
   - Action: User corrects email

3. **Password Too Short**: Less than 6 characters
   - Display: "Password must be at least 6 characters"
   - Action: User enters longer password

4. **Passwords Don't Match**: Confirmation doesn't match
   - Display: "Passwords do not match"
   - Action: User re-enters correctly

5. **Expired Link**: Reset link has expired
   - Display: Via Supabase AuthException
   - Action: User requests new reset link

6. **Link Already Used**: Reset link already used
   - Display: Via Supabase AuthException
   - Action: User requests new reset link

## UI/UX Features

### Forgot Password Screen
- Gradient header with lock reset icon
- Clear instructions
- Email input with validation
- Loading indicator during API call
- Success view with:
  - Check mark icon
  - Confirmation message showing email
  - Info box with expiration notice
  - Resend option
  - Back to login button

### Reset Password Screen
- Gradient header with key icon
- Password requirements displayed
- Password fields with show/hide toggle
- Real-time validation feedback
- Success view with:
  - Check mark icon
  - Confirmation message
  - Auto-redirect notice

### Accessibility
- Large tap targets for all buttons
- Clear visual feedback for actions
- Password fields support screen readers
- Error messages are descriptive

## Future Enhancements
1. Add password strength meter
2. Require uppercase/lowercase/numbers
3. Add rate limiting on reset requests
4. Custom email templates in Supabase
5. SMS-based password reset as alternative
6. Password reset analytics for admins

## Troubleshooting

### Email Not Received
1. Check spam/junk folder
2. Verify email address is correct
3. Check Supabase email settings
4. Verify SMTP configuration in Supabase

### App Doesn't Open from Link
1. Verify deep link configuration
2. Check AndroidManifest.xml for intent-filter
3. Check Info.plist for iOS URL schemes
4. Test deep link manually: `adb shell am start -a android.intent.action.VIEW -d "io.supabase.nbrofieldapp://reset-password"`

### Password Update Fails
1. Check Supabase logs
2. Verify user session is valid
3. Ensure link hasn't expired
4. Check password meets requirements

## Related Files
- `/lib/presentation/screens/login_screen.dart`
- `/lib/presentation/screens/forgot_password_screen.dart`
- `/lib/presentation/screens/reset_password_screen.dart`
- `/lib/presentation/screens/splash_screen.dart`
- `/lib/main.dart`
