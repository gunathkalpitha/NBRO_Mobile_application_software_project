# Gmail OAuth Setup Guide for NBRO App

## Overview
Admins will add officers using their Gmail accounts. Officers will receive an invitation email and sign in with Google OAuth.

---

## STEP 1: Set Up Google Cloud Console

### 1.1 Create a Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click **Select a Project** → **New Project**
3. Name it: `NBRO Field Surveyor`
4. Click **Create**

### 1.2 Enable Google+ API
1. In the left sidebar, go to **APIs & Services** → **Library**
2. Search for **Google+ API**
3. Click it and press **Enable**

### 1.3 Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. Choose **Web Application**
4. Configure consent screen if prompted:
   - **User Type**: External
   - **App name**: NBRO Field Surveyor
   - **User support email**: your-email@gmail.com
   - **Scopes**: Add `openid`, `email`, `profile`
5. For **Authorized redirect URIs**, add:
   ```
   https://<YOUR-SUPABASE-PROJECT>.supabase.co/auth/v1/callback
   https://localhost:3000/auth/v1/callback (for testing)
   ```
   *(You'll get your Supabase project URL in Step 2)*

6. Click **Create**
7. Copy your **Client ID** and **Client Secret** (save these!)

---

## STEP 2: Configure Supabase

### 2.1 Add Google OAuth Provider
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Find **Google** and click it
5. Toggle **Enabled** to ON
6. Paste your **Client ID** and **Client Secret** from Google Cloud
7. Click **Save**

### 2.2 Restrict New User Signups (IMPORTANT!)
1. Go to **Authentication** → **Policies**
2. Under **User Signups**, set:
   - **Allow new user signups**: OFF (so random people can't sign up)
3. Click **Save**

### 2.3 Get Your Supabase Callback URL
1. In **Authentication** → **Providers** → **Google**
2. You'll see: `https://<your-project>.supabase.co/auth/v1/callback`
3. Add this to your Google Cloud OAuth redirect URIs (if not already added)

---

## STEP 3: Create Edge Function for Admin Invite

The admin sends an invite email using Supabase's Service Role Key.

### 3.1 Create Edge Function
```bash
cd supabase/functions
supabase functions new invite-officer
```

### 3.2 Edit `supabase/functions/invite-officer/index.ts`
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { email, fullName } = await req.json()

    if (!email || !fullName) {
      return new Response(
        JSON.stringify({ error: 'Email and fullName are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Invite user via email
    const { data, error } = await supabase.auth.admin.inviteUserByEmail(
      email,
      {
        redirectTo: 'https://yourapp.com/welcome', // UPDATE THIS
        data: {
          full_name: fullName,
          role: 'officer',
        }
      }
    )

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create profile record
    const { error: profileError } = await supabase
      .from('profiles')
      .insert({
        id: data.user.id,
        email: email,
        full_name: fullName,
        role: 'officer',
        is_active: true,
      })

    if (profileError) {
      return new Response(
        JSON.stringify({ error: profileError.message }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Invitation email sent',
        userId: data.user.id 
      }),
      { 
        status: 200, 
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### 3.3 Deploy the Function
```bash
supabase functions deploy invite-officer
```

---

## STEP 4: Update Admin Officers Screen

Replace the manual password creation with Gmail invite flow.

### 4.1 Update Add Officer Dialog
Remove the password field and auto-generate option. Keep only email and full name.

### 4.2 Update `_addOfficer()` Function
```dart
Future<void> _addOfficer() async {
  final email = _emailController.text.trim();
  final fullName = _nameController.text.trim();

  if (email.isEmpty || fullName.isEmpty) {
    _showSnackBar('Please enter email and name', isWarning: true);
    return;
  }

  if (mounted) Navigator.pop(context);
  if (!mounted) return;

  // Show loading dialog
  BuildContext? loadingCtx;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      loadingCtx = ctx;
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sending invitation...'),
              ],
            ),
          ),
        ),
      );
    },
  );

  void dismissLoading() {
    final ctx = loadingCtx;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pop();
    }
  }

  try {
    final response = await Supabase.instance.client.functions.invoke(
      'invite-officer',
      body: {
        'email': email,
        'fullName': fullName,
      },
    );

    debugPrint('[AddOfficer] Status: ${response.status}');
    debugPrint('[AddOfficer] Data: ${response.data}');

    dismissLoading();

    if (response.status == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        _emailController.clear();
        _nameController.clear();
        _showInvitationSentDialog(email);
        await _loadOfficers();
      } else {
        throw Exception(data['error'] ?? 'Unknown error');
      }
    } else {
      final errData = response.data;
      final errMsg = errData is Map
          ? errData['error'] ?? 'HTTP ${response.status}'
          : 'HTTP ${response.status}';
      throw Exception(errMsg);
    }
  } catch (e) {
    debugPrint('[AddOfficer] Error: $e');
    dismissLoading();
    if (!mounted) return;

    final msg = e.toString();
    if (msg.contains('404') ||
        msg.contains('not found') ||
        msg.contains('FunctionsRelayError')) {
      _showEdgeFunctionSetupDialog();
    } else if (msg.contains('already exists') || msg.contains('409')) {
      _showSnackBar('Officer with this email already exists.',
          isError: true);
    } else {
      _showSnackBar('Error: $msg', isError: true);
    }
  }
}

void _showInvitationSentDialog(String email) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NBROColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.check_circle, color: NBROColors.success),
          ),
          const SizedBox(width: 12),
          const Text('Invitation Sent'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invitation email sent successfully!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NBROColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Steps:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NBROColors.info,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Officer receives email at: $email\n'
                  '2. They click the invitation link\n'
                  '3. They sign in with their Google account\n'
                  '4. Account is automatically activated',
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## STEP 5: Update Login Screen for Google OAuth

### 5.1 Add Google Sign-In Button
```dart
import 'package:google_sign_in/google_sign_in.dart';

Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);

  try {
    final googleSignIn = GoogleSignIn(
      serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', // From Google Cloud
      scopes: ['email', 'profile'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null || idToken == null) {
      throw Exception('Failed to get tokens from Google');
    }

    // Sign in to Supabase with Google OAuth
    final response = await Supabase.instance.client.auth.signInWithIdToken(
      provider: 'google',
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user != null) {
      // Check if account is active
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('is_active, role')
          .eq('id', response.user!.id)
          .single();

      final isActive = profileResponse['is_active'] as bool? ?? true;

      if (!isActive) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been disabled.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        _navigateToDashboard();
      }
    }
  } on AuthException catch (e) {
    debugPrint('Auth error: ${e.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    }
  } catch (e) {
    debugPrint('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}
```

Add the button to your login UI:
```dart
ElevatedButton.icon(
  onPressed: _handleGoogleSignIn,
  icon: const Icon(Icons.login),
  label: const Text('Sign in with Google'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
  ),
)
```

---

## STEP 6: Add Dependencies

Update `pubspec.yaml`:
```yaml
dependencies:
  google_sign_in: ^6.1.0
  supabase_flutter: ^1.10.0
```

Run:
```bash
flutter pub get
```

---

## STEP 7: Database - Ensure is_active Column Exists

Check your Supabase schema already has:
```sql
ALTER TABLE profiles ADD COLUMN is_active BOOLEAN DEFAULT true;
```

---

## Testing Workflow

### For Admin:
1. Admin goes to Manage Officers
2. Enters officer's Gmail (e.g., `officer@gmail.com`)
3. Enters officer's full name
4. Clicks "Send Invitation"
5. System shows "Invitation sent successfully"

### For Officer:
1. Officer receives email with invitation link
2. Clicks link → redirected to app
3. Taps "Sign in with Google"
4. Selects their Gmail account
5. Automatically logged in and account activated

### When Officer is Disabled:
1. Admin deletes officer from list
2. Officer tries to log in → "Your account has been disabled"
3. Cannot access app

---

## Security Checklist

✅ Google Cloud: Only your app URLs in redirect URIs
✅ Supabase: New signups disabled
✅ Service Role Key: Only used in Edge Functions (never exposed)
✅ Client ID: Can be public (it's for the browser/app)
✅ is_active check: On login to prevent disabled users
✅ RLS Policies: Still active on database tables

---

## FAQ

**Q: What if an officer loses their device?**
A: They sign in with Google again on a new device using the same Gmail account.

**Q: Can admins manage officer passwords?**
A: No, they're handled by Google. Admins only manage emails and active status.

**Q: What if Gmail is already used?**
A: Supabase prevents duplicate emails automatically.

**Q: Do I need email verification?**
A: No, Google handles it. Gmail accounts are pre-verified.
