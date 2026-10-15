ALTER TABLE sl_clothing_outfit_votes MODIFY COLUMN phase VARCHAR(16) NULL;
ALTER TABLE sl_clothing_curator_session MODIFY COLUMN phase VARCHAR(16) NOT NULL DEFAULT 'p1';
