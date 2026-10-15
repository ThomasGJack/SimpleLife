-- Social network posts
CREATE TABLE IF NOT EXISTS sl_phone_social_posts (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  character_id BIGINT UNSIGNED NOT NULL,
  author_number VARCHAR(15)   NOT NULL,
  body         VARCHAR(280)   NOT NULL,
  image        VARCHAR(255)   NULL DEFAULT NULL,
  likes        INT            NOT NULL DEFAULT 0,
  created_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);

-- Marketplace listings
CREATE TABLE IF NOT EXISTS sl_phone_market_listings (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  character_id BIGINT UNSIGNED NOT NULL,
  title        VARCHAR(80)    NOT NULL,
  price        INT            NOT NULL DEFAULT 0,
  body         VARCHAR(280)   NOT NULL,
  number       VARCHAR(15)    NOT NULL,
  created_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (character_id) REFERENCES sl_characters(id) ON DELETE CASCADE
);

-- Emergency calls log
CREATE TABLE IF NOT EXISTS sl_phone_emergency_calls (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  from_number  VARCHAR(15)    NOT NULL,
  service      VARCHAR(12)    NOT NULL,
  coords       JSON           NOT NULL,
  message      VARCHAR(255)   NOT NULL,
  created_at   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
