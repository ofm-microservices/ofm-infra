-- Run against the monolith source and auth-service Yugabyte destination.
-- Password hashes are copied only over the secured snapshot channel.
INSERT INTO auth_credentials (user_id, email, username, password_hash, email_verified, status, created_at, updated_at)
SELECT user_id, email, username, password_hash, COALESCE(email_verified, false),
       CASE WHEN COALESCE(status, 'active') = 'active' THEN 'active' ELSE status END,
       created_at, updated_at
FROM monolith_users_snapshot
ON CONFLICT (user_id) DO UPDATE SET email=EXCLUDED.email, username=EXCLUDED.username,
  password_hash=EXCLUDED.password_hash, email_verified=EXCLUDED.email_verified,
  status=EXCLUDED.status, updated_at=EXCLUDED.updated_at;
