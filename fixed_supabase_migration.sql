-- Drop existing tables and policies if needed
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP TRIGGER IF EXISTS set_timestamp ON profiles;
DROP FUNCTION IF EXISTS trigger_set_timestamp();
DROP TABLE IF EXISTS profiles;

-- Create profiles table for storing user profile information
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows users to see all profiles
-- This is more permissive for testing purposes - you can restrict it later
CREATE POLICY "Anyone can view profiles" ON profiles
    FOR SELECT USING (true);

-- Users can update only their own profile
CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Enable inserts for authenticated users and service role
CREATE POLICY "Users can insert profiles" ON profiles
    FOR INSERT WITH CHECK (true);

-- Create index on email for faster lookups
CREATE INDEX idx_profiles_email ON profiles (email); 