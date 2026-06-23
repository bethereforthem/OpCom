-- Add phone_number to users table for registration
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone_number TEXT UNIQUE;
