CREATE TABLE IF NOT EXISTS sl_clothing_outfit_votes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sex ENUM('m','f') NOT NULL,
  outfit_hash CHAR(40) NOT NULL,
  outfit_json JSON NOT NULL,
  vote ENUM('yes','no') NOT NULL,
  voted_by VARCHAR(64) NULL,
  voted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_outfit (sex, outfit_hash),
  INDEX idx_sex_vote (sex, vote)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sl_clothing_pair_compat (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sex ENUM('m','f') NOT NULL,
  a_kind ENUM('component','prop') NOT NULL,
  a_id TINYINT UNSIGNED NOT NULL,
  a_drawable SMALLINT NOT NULL,
  b_kind ENUM('component','prop') NOT NULL,
  b_id TINYINT UNSIGNED NOT NULL,
  b_drawable SMALLINT NOT NULL,
  yes_count INT UNSIGNED NOT NULL DEFAULT 0,
  no_count INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_pair (sex, a_kind, a_id, a_drawable, b_kind, b_id, b_drawable),
  INDEX idx_lookup_a (sex, a_kind, a_id, a_drawable)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sl_clothing_curator_session (
  account_id BIGINT UNSIGNED PRIMARY KEY,
  last_outfit JSON NULL,
  votes_yes INT UNSIGNED NOT NULL DEFAULT 0,
  votes_no INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (account_id) REFERENCES sl_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
