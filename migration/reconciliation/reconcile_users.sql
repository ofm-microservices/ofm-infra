-- Run with connections to both databases and compare the exported result sets.
-- The script intentionally reports mismatches; it never repairs data.
WITH service_users AS (
    SELECT user_id, username, first_name, last_name FROM service_users_snapshot
), legacy_users AS (
    SELECT user_id, username, first_name, surname AS last_name FROM monolith_users_snapshot
)
SELECT 'missing_in_service' AS mismatch, l.user_id
FROM legacy_users l LEFT JOIN service_users s USING (user_id) WHERE s.user_id IS NULL
UNION ALL
SELECT 'missing_in_monolith', s.user_id
FROM service_users s LEFT JOIN legacy_users l USING (user_id) WHERE l.user_id IS NULL
UNION ALL
SELECT 'different_profile', s.user_id
FROM service_users s JOIN legacy_users l USING (user_id)
WHERE (s.username, s.first_name, s.last_name) IS DISTINCT FROM (l.username, l.first_name, l.last_name);
