# Fix: Invitation Email "No API Key Found" Error

## Problem
When users click the invitation link from email, they see: **"No API key found in request"**

This happens because Supabase's default invitation email doesn't include the API key in the confirmation URL.

---

## Solution 1: Update Email Template (Recommended)

### Step 1: Access Email Templates
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `elxzuwxcrmapbuzyp`
3. Navigate to: **Authentication** → **Email Templates**
4. Find: **"Invite user"** template

### Step 2: Get Your API Key
1. In Supabase Dashboard, go to: **Project Settings** → **API**
2. Copy the **`anon` `public`** key (starts with `eyJhbGci...`)

### Step 3: Update Template
Replace the email template with this:

```html
<h2>You have been invited to NBRO Field Surveyor</h2>

<p>Hello {{ .Data.full_name }},</p>

<p>You have been invited to join NBRO Field Surveyor as an officer. Click the link below to accept the invitation and set your password:</p>

<p><a href="{{ .ConfirmationURL }}&apikey=YOUR_ANON_KEY_HERE">Accept Invitation</a></p>

<p>If the button doesn't work, copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}&apikey=YOUR_ANON_KEY_HERE</p>

<p>This link will expire in 24 hours.</p>

<p>If you did not request this invitation, please ignore this email.</p>

<p>Thanks,<br>NBRO Field Surveyor Team</p>
```

**Important:** Replace `YOUR_ANON_KEY_HERE` with your actual anon key from Step 2.

---

## Solution 2: Use Deep Link with Web Redirect

If you can't modify the email template, create a web redirect page:

### Step 1: Update Edge Function
Modify the `redirectTo` in [supabase/functions/invite-officer/index.ts](supabase/functions/invite-officer/index.ts):

```typescript
const { data, error } = await supabase.auth.admin.inviteUserByEmail(
  email,
  {
    // Change this:
    redirectTo: 'https://your-domain.com/auth/redirect?redirect=nbro-app',
    data: {
      full_name: fullName,
      role: 'officer',
    }
  }
)
```

### Step 2: Create Web Redirect Page
Create a simple HTML page at `https://your-domain.com/auth/redirect.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>NBRO - Redirecting...</title>
    <script>
        function redirect() {
            // Extract the token from URL
            const hash = window.location.hash.substring(1);
            const params = new URLSearchParams(hash);
            
            // Redirect to mobile app deep link with token
            window.location.href = 'com.example.nbro_mobile_application://auth-callback?' + hash;
            
            // Fallback message
            setTimeout(() => {
                document.getElementById('status').innerHTML = 
                    'If the app did not open automatically, please open the NBRO app manually.';
            }, 2000);
        }
        
        window.onload = redirect;
    </script>
</head>
<body>
    <h2 id="status">Redirecting to NBRO app...</h2>
</body>
</html>
```

---

## Solution 3: Quick Test with Manual API Key

For immediate testing, you can send the user a direct link with the API key included:

1. After calling the invite function, manually construct the URL
2. Send it via a different channel (SMS, messaging app)

Example URL format:
```
https://elxzuwxcrmapbuzyp.supabase.co/auth/v1/verify?token=TOKEN_HERE&type=invite&apikey=YOUR_ANON_KEY
```

---

## Verification Steps

After applying the fix:

1. **Test the invitation flow:**
   - Send a new invitation from the admin panel
   - Check the email received
   - Click the invitation link
   - Verify it redirects properly without "No API key" error

2. **Check the URL includes:**
   - `token=...`
   - `type=invite`
   - `apikey=...`

---

## Production Checklist

✅ Update email template with anon key  
✅ Test invitation on a test email  
✅ Verify deep link redirects to app  
✅ Ensure auth callback screen works  
✅ Test with both Gmail and other email providers  

---

## Additional Notes

- The anon (public) API key is safe to include in emails—it's meant to be public
- Make sure your RLS (Row Level Security) policies are properly configured
- The invitation link expires in 24 hours by default
- Users must have the mobile app installed for deep links to work
