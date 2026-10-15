-- Vehicules possedes par les personnages
CREATE TABLE IF NOT EXISTS sl_vehicles (
  id             BIGINT UNSIGNED      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  character_id   BIGINT UNSIGNED      NOT NULL,
  plate          VARCHAR(12)          NOT NULL,
  model          VARCHAR(48)          NOT NULL,
  props          JSON                 NULL,
  fuel           TINYINT UNSIGNED     NOT NULL DEFAULT 100,
  body_health    FLOAT                NOT NULL DEFAULT 1000,
  engine_health  FLOAT                NOT NULL DEFAULT 1000,
  state          VARCHAR(12)          NOT NULL DEFAULT 'garage',
  garage         VARCHAR(48)          NOT NULL DEFAULT 'central',
  position       JSON                 NULL,
  created_at     TIMESTAMP            NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE  KEY uq_plate        (plate),
  INDEX   ix_character_id     (character_id),
  INDEX   ix_plate            (plate),
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);
