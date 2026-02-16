# Why "Invalid JWT" Error & How It's Fixed

## The Problem You Were Having

```
Response status: 401
Response body: {"code":401,"message":"Invalid JWT"}
```

This error means the platform-level JWT validation (before your function even runs) rejected the request.

---

## Why It Happened

### ❌ WRONG Approach (What You Had Before)

```dart
// Getting JWT from current session
final currentSession = supabase.auth.currentSession;
final jwtToken = currentSession.accessToken;

// Calling with direct HTTP
final response = await http.post(
  Uri.parse('https://bazelkzuwxcrmapbuzyp.supabase.co/functions/v1/create-officer'),
  headers: {
    'Authorization': 'Bearer $jwtToken',  // ❌ PROBLEM HERE
  },
  body: jsonEncode({...}),
);
```

**Why this fails:**

1. **Session token might be expired** - Tokens have expiration times
2. **CORS not pre-handled** - Browser/app makes raw HTTP request with CORS headers
3. **Anon Key confusion** - Easy to accidentally use Anon Key as JWT
4. **Platform validation** - Supabase platform validates the JWT token format BEFORE your function runs
5. **SDK not used properly** - The Supabase SDK has built-in logic to handle all of this

### ✅ CORRECT Approach (What We Fixed To)

```dart
// Using Supabase SDK's official method
final response = await supabase.functions.invoke(
  'create-officer',
  body: {
    'email': email,
    'fullName': fullName,
    'password': password,
  },
);
```

**Why this works:**

1. ✅ **SDK manages tokens** - Automatically uses fresh, valid tokens
2. ✅ **Token refresh** - Automatically refreshes expired tokens
3. ✅ **CORS handled** - SDK sets correct headers internally
4. ✅ **Type safety** - Returns properly typed `FunctionResponse`
5. ✅ **Error handling** - SDK includes retry logic and proper error handling
6. ✅ **Platform compatible** - Built specifically for Supabase functions

---

## Understanding Supabase Authentication

### Layer 1: Client Authentication (Flutter App)
```
User logs in with email/password
         ↓
Supabase Auth creates JWT token
         ↓
Token stored in currentSession
         ↓
Token valid for 1 hour
         ↓
SDK automatically refreshes when needed
```

### Layer 2: Function Call (Through SDK)
```
supabase.functions.invoke('create-officer', body: {...})
         ↓
SDK gets token from currentSession
         ↓
SDK adds token to request headers
         ↓
Request sent to Supabase platform
         ↓
Platform validates JWT signature
         ↓
If valid → route to function
If invalid → return 401
```

### Layer 3: Function Execution (Edge Function)
```
receive request with valid JWT
         ↓
Get SERVICE_ROLE_KEY from environment variables
         ↓
Use SERVICE_ROLE_KEY to call Admin API
         ↓
Service role key is more powerful than user token
         ↓
Can create new users
         ↓
Returns result to client
```

---

## Key Concepts

### JWT Tokens
- **What:** JSON Web Token - signed, encoded auth credential
- **Who uses:** Client apps, external services
- **Lifespan:** Usually 1 hour
- **Example:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### Anon Key
- **What:** Plain text API key string
- **Who uses:** Client SDK to authenticate requests
- **Lifespan:** Permanent (never expires)
- **Example:** `sb_publishable_5Bnp_FgN1eleESr03wE6tg_ZqrRqptl`
- **Not a JWT:** Plain string, not signed

### Service Role Key
- **What:** Admin API key with elevated permissions
- **Who uses:** Server-side code only (Edge Functions, backend)
- **Lifespan:** Permanent
- **Danger:** Can do anything to your database - NEVER expose to client
- **Storage:** Environment variables in functions only

---

## The Authentication Flow in Your App

### Step 1: User Logs In (Once)
```dart
// In login screen
await supabase.auth.signInWithPassword(
  email: 'admin@gmail.com',
  password: 'password',
);

// Supabase creates session with JWT token
// Token is stored in supabase.auth.currentSession
```

### Step 2: Creating an Officer (Using Auth)
```dart
// (Automatically uses the token from Step 1)
final response = await supabase.functions.invoke(
  'create-officer',
  body: {...},
);

// SDK sends request with:
// - JWT from currentSession (User is authenticated)
// - Content-Type and CORS headers (Proper format)
// - Body with officer details
```

### Step 3: Edge Function Handles Request
```typescript
// Function receives request
// - Has access to valid JWT (user identity)
// - Has access to SUPABASE_SERVICE_ROLE_KEY (admin power)
// - Has access to request body (officer details)

// Uses service role key to create new user
const createUserRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${serviceRoleKey}`,  // Admin power
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    email: email,
    password: password,
  }),
});

// Returns success/error to Flutter app
```

### Step 4: Database Trigger Auto-Creates Profile
```sql
-- Trigger fires when new user added to auth.users
CREATE TRIGGER handle_new_user
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_new_user();

-- Function creates entry in profiles table
INSERT INTO profiles (id, email, role)
VALUES (new.id, new.email, 'officer');
```

---

## Why Each Part is Important

| Component | Purpose | What Happens If Missing |
|-----------|---------|------------------------|
| `supabase.functions.invoke()` | Official SDK method for calling functions | Manual HTTP causes token/CORS issues |
| `currentSession.accessToken` | User's JWT (automatically used by SDK) | 401: Invalid JWT errors |
| Edge Function | Server-side code to create users | Can't create users from client (security) |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin permission token in function | 403: Unauthorized error from Auth API |
| Database trigger | Auto-creates profile for new user | Officer created but can't log in |

---

## Comparison: Before vs After

### BEFORE (Broken)
```
User logs in (gets JWT token)
    ↓
Manual HTTP.post() call
    ↓
Try to add Bearer token manually
    ↓
CORS headers might be wrong
    ↓
Token validation fails (401)
    ❌ Invalid JWT error
```

### AFTER (Fixed)
```
User logs in (SDK stores JWT)
    ↓
supabase.functions.invoke() call
    ↓
SDK automatically adds token
    ↓
CORS headers properly set by SDK
    ↓
Token validation passes
    ↓
Function executes
    ↓
Uses SERVICE_ROLE_KEY for admin operation
    ↓
Creates new user in auth.users
    ↓
Trigger creates profile entry
    ↓
Return success to Flutter
    ✅ Officer created successfully
```

---

## Test Verify

### Before Making a Change
```bash
# These should work now:
flutter analyze    # No errors
flutter pub get    # No errors

# Deploy function
supabase functions deploy create-officer
```

### After Testing
```dart
// This should work:
final response = await supabase.functions.invoke(
  'create-officer',
  body: {...},
);

// Response should be:
{
  "success": true,
  "message": "Officer created: email@example.com",
  "user": {
    "id": "uuid",
    "email": "email@example.com"
  }
}
```

---

## Common Mistakes to Avoid

❌ **DON'T:** Try to use Anon Key as Bearer token
```dart
// WRONG:
'Authorization': 'Bearer $supabaseAnonKey'  // Not a JWT!
```

❌ **DON'T:** Call functions with manual HTTP
```dart
// WRONG:
http.post(Uri.parse(url), body: json)  // No SDK magic
```

❌ **DON'T:** Expose SERVICE_ROLE_KEY to client
```typescript
// WRONG:
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Send it to client somehow
```

❌ **DON'T:** Forget to set environment variables
```bash
# Function needs this set in Supabase dashboard:
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

✅ **DO:** Use SDK functions
```dart
// RIGHT:
final response = await supabase.functions.invoke('create-officer', body: {...});
```

✅ **DO:** Let SDK manage tokens
```dart
// RIGHT:
// SDK automatically uses token from currentSession
```

✅ **DO:** Keep SERVICE_ROLE_KEY on server only
```typescript
// RIGHT:
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Use only server-side, never send to client
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Method** | Direct HTTP | `supabase.functions.invoke()` |
| **Auth** | Manual JWT from session | SDK-handled auto-auth |
| **Error** | 401 Invalid JWT | Works correctly |
| **Token Refresh** | Manual (broken) | Automatic |
| **CORS** | Manual headers (buggy) | SDK handles |
| **Code Quality** | Error-prone | Type-safe, idiomatic |

This fix applies the **standard Supabase pattern** that's documented and recommended for all client-to-function communication.
