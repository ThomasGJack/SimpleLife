CREATE TABLE IF NOT EXISTS sl_transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  character_id BIGINT UNSIGNED NOT NULL,
  account ENUM('cash','bank','crypto') NOT NULL,
  delta BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  reason VARCHAR(128) NOT NULL DEFAULT '',
  counterparty_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_char_acc (character_id, account, created_at),
  INDEX idx_counterparty (counterparty_id),
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
