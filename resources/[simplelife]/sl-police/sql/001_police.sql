-- Casier judiciaire par citoyen (citizen_id = code alphanum, pas FK numerique)
CREATE TABLE IF NOT EXISTS sl_police_records (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  citizen_id  VARCHAR(20)  NOT NULL,
  charges     JSON         NOT NULL,
  total_fine  INT          NOT NULL DEFAULT 0,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by  VARCHAR(20)  NOT NULL DEFAULT '',
  INDEX idx_police_records_citizen (citizen_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- BOLOs actifs (Be On the Look Out)
CREATE TABLE IF NOT EXISTS sl_police_bolos (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  citizen_id  VARCHAR(20)  NOT NULL,
  reason      VARCHAR(255) NOT NULL DEFAULT '',
  created_by  VARCHAR(20)  NOT NULL DEFAULT '',
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_police_bolos_citizen (citizen_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
