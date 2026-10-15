-- Audit log des achats en magasin. Pas de stock persiste (tout illimite v1).
CREATE TABLE IF NOT EXISTS sl_shop_transactions (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id  BIGINT UNSIGNED NOT NULL,
  shop_key      VARCHAR(64)     NOT NULL,
  item          VARCHAR(64)     NOT NULL,
  qty           INT UNSIGNED    NOT NULL,
  price_unit    INT UNSIGNED    NOT NULL,
  total         INT UNSIGNED    NOT NULL,
  payment       VARCHAR(16)     NOT NULL,
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_character (character_id),
  INDEX idx_shop (shop_key),
  INDEX idx_created (created_at)
);
