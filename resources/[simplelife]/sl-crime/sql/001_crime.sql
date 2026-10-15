-- Table des cooldowns de crimes (braquages et deals)
CREATE TABLE IF NOT EXISTS sl_crime_cooldowns (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  kind      VARCHAR(32)     NOT NULL,
  target    VARCHAR(64)     NOT NULL,
  until_ts  BIGINT          NOT NULL,
  INDEX idx_crime_cd_kind_target (kind, target)
);
