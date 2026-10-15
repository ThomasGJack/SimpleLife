ALTER TABLE sl_clothing_outfit_votes
  ADD COLUMN IF NOT EXISTS pass_count INT NOT NULL DEFAULT 1,
  ADD INDEX IF NOT EXISTS idx_pass (sex, phase, pass_count);
