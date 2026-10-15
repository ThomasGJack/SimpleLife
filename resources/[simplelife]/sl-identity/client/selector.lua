-- Legacy : la logique de sélection est désormais dans client/main.lua avec NUI custom.
-- Ce fichier reste pour préserver l'ordre de chargement et exposer les fonctions
-- attendues par les anciens hooks.

function OpenCharacterSelector()
  -- Délégué à la nouvelle implementation NUI
  if openSelectorUI then openSelectorUI() end
end
