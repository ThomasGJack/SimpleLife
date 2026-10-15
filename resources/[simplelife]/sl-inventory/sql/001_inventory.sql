-- Catalogue d items synchronise depuis shared/items.lua au boot du serveur.
-- Le catalogue cote Lua reste la source de verite. Cette table sert d audit
-- et facilite les jointures pour les modules tiers et requetes d exploration.
CREATE TABLE IF NOT EXISTS sl_items (
  name        VARCHAR(64)   NOT NULL PRIMARY KEY,
  label       VARCHAR(128)  NOT NULL,
  weight      INT UNSIGNED  NOT NULL DEFAULT 0,
  max_stack   INT UNSIGNED  NOT NULL DEFAULT 1,
  category    VARCHAR(32)   NOT NULL DEFAULT 'misc',
  is_usable   TINYINT(1)    NOT NULL DEFAULT 0,
  is_unique   TINYINT(1)    NOT NULL DEFAULT 0,
  icon        VARCHAR(16)   NULL,
  description VARCHAR(255)  NULL,
  updated_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Inventaire d un personnage. Une ligne = un slot occupe.
-- Si l item est unique, le slot porte un metadata propre (cle voiture liee a
-- un plate, telephone avec son numero, licence avec son ID, etc.).
CREATE TABLE IF NOT EXISTS sl_inventory_items (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id  BIGINT UNSIGNED NOT NULL,
  slot          SMALLINT UNSIGNED NOT NULL,
  item          VARCHAR(64)   NOT NULL,
  count         INT UNSIGNED  NOT NULL DEFAULT 1,
  metadata      JSON          NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_slot (character_id, slot),
  INDEX idx_character (character_id),
  INDEX idx_item (item)
);

-- Drops au sol (sac ou cadavre).
CREATE TABLE IF NOT EXISTS sl_inventory_drops (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pos_x       DOUBLE NOT NULL,
  pos_y       DOUBLE NOT NULL,
  pos_z       DOUBLE NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_touch  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_last_touch (last_touch)
);

CREATE TABLE IF NOT EXISTS sl_inventory_drop_items (
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  drop_id   BIGINT UNSIGNED NOT NULL,
  slot      SMALLINT UNSIGNED NOT NULL,
  item      VARCHAR(64) NOT NULL,
  count     INT UNSIGNED NOT NULL DEFAULT 1,
  metadata  JSON NULL,
  FOREIGN KEY (drop_id) REFERENCES sl_inventory_drops(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_drop_slot (drop_id, slot)
);
