-- Proprietes immobilieres
CREATE TABLE IF NOT EXISTS sl_properties (
  id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  label                VARCHAR(128)    NOT NULL,
  type                 VARCHAR(32)     NOT NULL DEFAULT 'apartment',
  price                INT UNSIGNED    NOT NULL DEFAULT 0,
  owner_character_id   BIGINT UNSIGNED NULL DEFAULT NULL,
  enter_pos            JSON            NOT NULL,
  ipl                  VARCHAR(128)    NULL DEFAULT NULL,
  interior_pos         JSON            NOT NULL,
  FOREIGN KEY (owner_character_id) REFERENCES sl_characters(id) ON DELETE SET NULL
);

-- Acces partages (cle donnee a un tiers)
CREATE TABLE IF NOT EXISTS sl_property_access (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  property_id  BIGINT UNSIGNED NOT NULL,
  character_id BIGINT UNSIGNED NOT NULL,
  UNIQUE KEY uq_prop_char (property_id, character_id),
  FOREIGN KEY (property_id)  REFERENCES sl_properties(id) ON DELETE CASCADE,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);

-- Coffre personnel par propriete
CREATE TABLE IF NOT EXISTS sl_property_stash (
  id           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
  property_id  BIGINT UNSIGNED  NOT NULL,
  slot         SMALLINT UNSIGNED NOT NULL,
  item         VARCHAR(64)      NOT NULL,
  count        INT UNSIGNED     NOT NULL DEFAULT 1,
  metadata     JSON             NULL DEFAULT NULL,
  UNIQUE KEY uq_prop_slot (property_id, slot),
  FOREIGN KEY (property_id) REFERENCES sl_properties(id) ON DELETE CASCADE
);
