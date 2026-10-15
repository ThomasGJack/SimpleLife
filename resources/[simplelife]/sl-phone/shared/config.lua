Phone = Phone or {}

-- Touche d'ouverture / commande
Phone.OpenKey   = 'F1'
Phone.UICommand = 'phone'

-- Item requis pour ouvrir le téléphone (depuis sl-inventory)
Phone.RequireItem = 'telephone'

-- Format de numéro US : (XXX) XXX-XXXX
-- - area code : 3 chiffres, commence par 2-9 (jamais 0/1, codes invalides)
-- - exchange code (NXX) : 3 chiffres, commence par 2-9
-- - subscriber : 4 chiffres
-- On force area=555 pour le côté "fictif GTA-like" (configurable).
Phone.NumberAreaCode = nil   -- nil = random 2xx-9xx, "555" = toujours 555, etc.

-- Limites
Phone.MaxContacts        = 200
Phone.MaxMessageLength   = 500
Phone.SmsHistoryLimit    = 100   -- nombre de messages chargés par conversation

-- Apps disponibles en v1 (ordre d'affichage dans la home).
-- Pour ajouter une app : étendre cette liste + créer la screen côté NUI.
Phone.Apps = {
  { key = 'messages',  label = 'Messages',   icon = '💬', color = '#34c759' },
  { key = 'contacts',  label = 'Contacts',   icon = '👥', color = '#5856d6' },
  { key = 'phone',     label = 'Téléphone',  icon = '📞', color = '#34c759' },
  { key = 'bank',      label = 'Banque',     icon = '🏦', color = '#0a84ff' },
  { key = 'social',    label = 'Social',     icon = '🌐', color = '#ff9f0a' },
  { key = 'market',    label = 'Annonces',   icon = '🛒', color = '#30d158' },
  { key = 'emergency', label = 'Urgences',   icon = '🚨', color = '#ff453a' },
  { key = 'settings',  label = 'Réglages',   icon = '⚙️', color = '#8e8e93' },
}

-- Durée max d'un "appel sortant" en attente avant de timeout (s).
Phone.CallTimeoutSec = 30

-- Helpers ---------------------------------------------------------------

-- Format US affichable depuis un raw "5551234567" → "(555) 123-4567"
function Phone.FormatNumber(raw)
  if not raw or #raw < 7 then return raw or '' end
  local digits = tostring(raw):gsub('%D', '')
  if #digits == 10 then
    return ('(%s) %s-%s'):format(digits:sub(1,3), digits:sub(4,6), digits:sub(7,10))
  elseif #digits == 7 then
    return ('%s-%s'):format(digits:sub(1,3), digits:sub(4,7))
  end
  return digits
end

-- Strip tout sauf chiffres
function Phone.NormalizeNumber(input)
  if not input then return '' end
  return tostring(input):gsub('%D', '')
end
