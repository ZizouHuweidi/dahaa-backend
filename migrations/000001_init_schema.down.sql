-- Drop comments
COMMENT ON TABLE games IS NULL;
COMMENT ON TABLE questions IS NULL;
COMMENT ON COLUMN games.players IS NULL;
COMMENT ON COLUMN games.rounds IS NULL;
COMMENT ON COLUMN questions.image_path IS NULL;
COMMENT ON COLUMN questions.image_alt IS NULL;
-- Drop constraints
ALTER TABLE games DROP CONSTRAINT IF EXISTS games_status_check;
ALTER TABLE questions DROP CONSTRAINT IF EXISTS questions_category_length_check;
ALTER TABLE questions DROP CONSTRAINT IF EXISTS category_length;
-- Drop indexes
DROP INDEX IF EXISTS idx_games_code;
DROP INDEX IF EXISTS idx_questions_category;
-- Drop tables
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS questions;