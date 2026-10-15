ALTER TABLE sl_clothing_curator_session
  ADD COLUMN IF NOT EXISTS phase ENUM('top','bottom','mix') NOT NULL DEFAULT 'top';

ALTER TABLE sl_clothing_outfit_votes
  ADD COLUMN IF NOT EXISTS phase ENUM('top','bottom','mix') NULL,
  ADD INDEX IF NOT EXISTS idx_phase (sex, phase, vote);
