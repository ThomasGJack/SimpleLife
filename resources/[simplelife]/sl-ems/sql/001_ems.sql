-- Factures medicales emises par les ambulanciers
CREATE TABLE IF NOT EXISTS sl_ems_bills (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  patient_citizen_id BIGINT UNSIGNED NOT NULL,
  medic_citizen_id   BIGINT UNSIGNED NOT NULL,
  amount             INT UNSIGNED NOT NULL DEFAULT 0,
  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_patient (patient_citizen_id),
  INDEX idx_medic   (medic_citizen_id)
);
