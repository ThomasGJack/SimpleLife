-- Numero de telephone par personnage (1 par perso, persistant).
CREATE TABLE IF NOT EXISTS sl_phone_numbers (
  character_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  number       VARCHAR(15)     NOT NULL UNIQUE,
  created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE,
  INDEX idx_number (number)
);

-- Repertoire de contacts d un personnage.
CREATE TABLE IF NOT EXISTS sl_phone_contacts (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id BIGINT UNSIGNED NOT NULL,
  name         VARCHAR(64)     NOT NULL,
  number       VARCHAR(15)     NOT NULL,
  favorite     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE,
  INDEX idx_character (character_id),
  INDEX idx_number (number)
);

-- Historique SMS (1 ligne par message). from/to en double : id perso + numero
-- pour retrouver meme si l interlocuteur n a plus de numero.
CREATE TABLE IF NOT EXISTS sl_phone_messages (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  from_character_id BIGINT UNSIGNED NOT NULL,
  to_character_id   BIGINT UNSIGNED NOT NULL,
  from_number       VARCHAR(15)     NOT NULL,
  to_number         VARCHAR(15)     NOT NULL,
  body              VARCHAR(500)    NOT NULL,
  is_read           TINYINT(1)      NOT NULL DEFAULT 0,
  created_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_from (from_character_id),
  INDEX idx_to (to_character_id),
  INDEX idx_pair (from_character_id, to_character_id, created_at),
  INDEX idx_created (created_at)
);

-- Historique des appels (UI only en v1, pas de routing audio).
-- status : outgoing | incoming | missed | declined | ended
CREATE TABLE IF NOT EXISTS sl_phone_calls (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  from_character_id BIGINT UNSIGNED NOT NULL,
  to_character_id   BIGINT UNSIGNED NULL,
  from_number       VARCHAR(15)     NOT NULL,
  to_number         VARCHAR(15)     NOT NULL,
  duration_sec      INT UNSIGNED    NOT NULL DEFAULT 0,
  status            VARCHAR(16)     NOT NULL,
  created_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_from (from_character_id),
  INDEX idx_to (to_character_id),
  INDEX idx_created (created_at)
);
