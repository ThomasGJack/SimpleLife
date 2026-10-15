-- Table principale des gangs
CREATE TABLE IF NOT EXISTS sl_gangs (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(48)     NOT NULL UNIQUE,
  color           VARCHAR(12)     NOT NULL DEFAULT 'red',
  boss_citizen_id VARCHAR(10)     NOT NULL DEFAULT '',
  created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Membres d un gang (un personnage ne peut etre que dans un seul gang)
CREATE TABLE IF NOT EXISTS sl_gang_members (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  gang_id      BIGINT UNSIGNED NOT NULL,
  character_id BIGINT UNSIGNED NOT NULL,
  grade        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  UNIQUE KEY uq_character (character_id),
  FOREIGN KEY (gang_id)      REFERENCES sl_gangs(id)       ON DELETE CASCADE,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id)  ON DELETE CASCADE
);

-- Territoires de la carte (seedes au boot depuis config)
CREATE TABLE IF NOT EXISTS sl_gang_territories (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  zone      VARCHAR(48)     NOT NULL UNIQUE,
  gang_id   BIGINT UNSIGNED NULL DEFAULT NULL,
  influence INT UNSIGNED    NOT NULL DEFAULT 0,
  FOREIGN KEY (gang_id) REFERENCES sl_gangs(id) ON DELETE SET NULL
);
