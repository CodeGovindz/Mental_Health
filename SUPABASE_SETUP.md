# Supabase Setup for मनन (Manan) Mental Health App

This document explains how to set up Supabase for the मनन mental health app.

## Prerequisites

1. Supabase account (Sign up at [https://supabase.com](https://supabase.com) if you don't have one)
2. The mental health app Flutter project

## Setup Steps

### 1. Create a Supabase Project

- Log in to your Supabase account
- Click "New Project"
- Fill in the project details (Project name, database password, region)
- Wait for your project to be created

### 2. Run SQL Migration

1. Navigate to the SQL Editor in your Supabase dashboard
2. Copy and paste the contents of `supabase_migration.sql` from this project
3. Run the SQL script to create the necessary tables and security policies

### 3. Configure Authentication

1. In the Supabase dashboard, go to Authentication > Settings
2. Under "Email Auth", make sure "Enable Email Signup" is turned on
3. Configure email templates (optional but recommended)
4. Set minimum password strength as needed

### 4. Update App Configuration

The app is already configured with your Supabase URL and anon key. If you need to use a different Supabase project:

1. Open `lib/main.dart`
2. Update the Supabase initialization parameters:
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_ANON_KEY',
   );
   ```

## Testing Authentication

1. Run the app
2. Try to create a new account using the Sign Up page
3. Check in the Supabase dashboard under Authentication > Users to confirm the user was created
4. Try to sign in with the created account
5. Note: By default, new users will need to confirm their email. You can disable this in the Supabase dashboard settings.

## Table Structure

### Profiles Table

| Column     | Type                    | Description                       |
| ---------- | ----------------------- | --------------------------------- |
| id         | UUID (Primary Key)      | References auth.users id          |
| email      | TEXT (Unique)           | User's email address              |
| name       | TEXT                    | User's full name                  |
| created_at | TIMESTAMP WITH TIMEZONE | When the profile was created      |
| updated_at | TIMESTAMP WITH TIMEZONE | When the profile was last updated |

## Row Level Security

The profiles table has Row Level Security enabled with the following policies:

1. Users can only view their own profile
2. Users can only update their own profile
3. Users can insert their own profile during signup

## Troubleshooting

- If authentication isn't working, check the Supabase Authentication logs
- If you see errors with profiles, verify that the SQL migration ran successfully
- Check network connectivity if the app can't reach Supabase servers
