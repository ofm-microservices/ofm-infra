INSERT INTO users (user_id, username, first_name, last_name, created_at, updated_at)
SELECT user_id, username, first_name, surname, created_at, updated_at
FROM monolith_users_snapshot
ON CONFLICT (user_id) DO UPDATE SET username=EXCLUDED.username,
  first_name=EXCLUDED.first_name, last_name=EXCLUDED.last_name,
  updated_at=EXCLUDED.updated_at;
