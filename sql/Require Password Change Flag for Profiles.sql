ALTER TABLE profile
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT false;

COMMENT ON COLUMN profile.must_change_password IS 'Flag to force password change on first login for officers created with auto-generated passwords';

CREATE INDEX IF NOT EXISTS idx_profile_must_change_password
ON profile(must_change_password)
WHERE must_change_password = true;