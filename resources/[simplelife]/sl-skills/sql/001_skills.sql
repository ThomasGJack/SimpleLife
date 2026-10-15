-- XP et niveaux de competences par personnage
CREATE TABLE IF NOT EXISTS sl_skills (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  character_id BIGINT UNSIGNED NOT NULL,
  skill        VARCHAR(24) NOT NULL,
  xp           INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_char_skill (character_id, skill),
  INDEX idx_character_id (character_id),
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);
