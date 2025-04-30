# Deep Linking Setup for Authentication

This guide explains how to set up deep linking for authentication in your मनन (Manan) Mental Health App.

## What's been configured

1. **Custom URL Scheme**: The app now uses `manan://` as its custom URL scheme.
2. **Deep Link Handling**: The app can handle deep links from Supabase authentication.
3. **Authentication Flow**: The app is set up to handle auth redirects.

## How to Set Up Supabase

1. Go to your Supabase dashboard: https://app.supabase.com/project/cqfwjwrhhcctazigevno
2. Navigate to Authentication → URL Configuration
3. Update the following settings:
   - **Site URL**: Set this to `https://cqfwjwrhhcctazigevno.supabase.co` (use your actual project URL)
   - **Redirect URLs**: Add `manan://auth-callback/`
4. Save changes

## How Authentication Works Now

1. User signs up in the app
2. An email is sent to their address with a verification link
3. When they click the link, it will:
   - Open in their browser
   - Verify their account
   - Redirect to your app using the `manan://` scheme with auth tokens
4. The app receives this deep link and:
   - Extracts authentication tokens from the URL
   - Updates the user's session
   - Automatically logs them in

## Testing the Flow

1. Run the app on a real device (deep linking can be tricky in simulators)
2. Sign up with a real email address
3. Check your email for the verification link
4. Click the link on the same device where the app is installed
5. The app should open and handle the authentication

## Troubleshooting

If you encounter issues:

1. **Email not working**: Check your spam folder
2. **Link not opening app**:

   - Make sure you're using the same device for signup and clicking the link
   - If using an emulator, ensure it supports deep linking
   - Try adding both `manan://` and `manan://auth-callback/` to your Supabase redirect URLs

3. **Debug logs**: Check the Flutter console for debug logs - we've added extensive logging
4. **Manual verification**: You can always manually verify users in the Supabase dashboard (Authentication → Users → Select user → Actions → Verify)
5. **Supabase Configuration**:
   - Double-check the Site URL and Redirect URLs in Supabase Authentication settings
   - Try both `manan://` and your app's actual Supabase URL for the Site URL setting

## Additional Resources

- [Supabase Authentication Documentation](https://supabase.io/docs/guides/auth)
- [Flutter Deep Linking Guide](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [App Links Package Documentation](https://pub.dev/packages/app_links)
