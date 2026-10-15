-- Stats survival par personnage. Stamina n est PAS persistee (regen rapide).
CREATE TABLE IF NOT EXISTS sl_hunger_stats (
  character_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  hunger       TINYINT UNSIGNED NOT NULL DEFAULT 100,
  thirst       TINYINT UNSIGNED NOT NULL DEFAULT 100,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);
