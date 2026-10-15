DLC = DLC or {}

-- ===========================================================================
-- sl-dlc v0.2 : chargement EXHAUSTIF de tous les IPLs DLC connus jusqu'à
-- build 3751 (A Safehouse in the Hills - décembre 2025).
--
-- Comportement :
--   - LoadMpDlcMaps + OnEnteringMpMaps + SetMpDlcMapsEnabled(true)
--   - SetIslandHopperEnabled('HeistIsland', true)  → Cayo Perico
--   - RequestIpl pour chaque entrée ci-dessous
--
-- Certains IPLs sont conditionnels au gamebuild — si l'IPL n'existe pas dans
-- ta version actuelle, RequestIpl échoue silencieusement (loggué en "skipped").
-- ===========================================================================

DLC.EnableMpDlcMaps   = true
-- ⚠️ Island Hopper Cayo Perico : DÉSACTIVÉ par défaut.
-- Activer `SetIslandHopperEnabled('HeistIsland', true)` au boot fait disparaître
-- Los Santos sur la plupart des builds FiveM (bug connu, l'engine swap la zone
-- active). À activer UNIQUEMENT à la demande via `/cayo_on`.
-- Quand on revient sur le continent → `/cayo_off`.
DLC.EnableIslandHopper = false
DLC.LogProgress       = true
DLC.AllowFutureUpdate = true

DLC.IPLs = {

  -- =========================================================================
  -- Diamond Casino & Resort (mp_casino, juillet 2019)
  -- =========================================================================
  'vw_casino_main',
  'vw_casino_carpark',
  'vw_casino_door',
  'vw_dlc_casino_door',
  'vw_dlc_casino_apart',
  'vw_dlc_casino_garage',
  'vw_casino_penthouse',
  'vw_casino_init',

  -- =========================================================================
  -- Diamond Casino Heist (mpheist3, décembre 2019)
  -- =========================================================================
  'ch_anim_casino_b_door',
  'ch_dlc_casino_heist',
  'ch_dlc_metro_tunnel',
  'ch_dlc_security_tunnel',
  'ch_dlc_int_01',
  'ch_dlc_int_02',
  'ch_dlc_int_03',
  'ch_dlc_int_04',
  'ch_dlc_arcade_int',
  'ch_dlc_planning_board',
  'ch_dlc_finalefoyer',

  -- =========================================================================
  -- Cayo Perico Heist (mpheist4, décembre 2020)
  -- IPLs DÉSACTIVÉS par défaut : sans l'island hopper actif, ces IPLs n'ont
  -- aucune utilité (l'île reste invisible). Le toggle /cayo_on les chargera
  -- à la demande, /cayo_off les déchargera.
  -- =========================================================================
  -- 'h4_islandx',
  -- 'h4_islandxmissions',
  -- 'h4_islandx_ext',
  -- 'h4_islandx_props',
  -- 'h4_islandx_terrain',
  -- 'h4_beach_party_2',
  -- 'h4_mph4_pi_int',
  -- 'h4_mph4_kos_carpark',
  -- 'h4_islandx_lod_blockers',
  -- 'h4_islandx_lod',

  -- =========================================================================
  -- Los Santos Tuners (mptuner, juillet 2021)
  -- =========================================================================
  'shr_int',
  'shr_int_placement_shr_int_interior_0_shr_int_milo_',
  'tr_dlc_tuner_carmeet_carwash',
  'tr_dlc_tuner_carmeet_props',
  'tr_dlc_tuner_methlab',

  -- =========================================================================
  -- The Contract / Dr Dre / Franklin's Agency (mpsecurity, décembre 2021)
  -- =========================================================================
  'fp_dlc_fixer_hub',
  'fp_dlc_franklin_t_house',
  'fp_dlc_studio',
  'fp_dlc_studio_back_area',
  'fp_dlc_studio_lounge',
  'fp_dlc_studio_office_floor',
  'fp_dlc_security_recovery',
  'fp_dlc_security_recovery_office',
  'hei_dlc_windows_casino',

  -- =========================================================================
  -- The Criminal Enterprises (mpsum2, juillet 2022)
  -- =========================================================================
  'su2_15',
  'su2_16',
  'su20_burger',
  -- (très peu d'IPLs nommés pour ce DLC, contenu surtout véhicules)

  -- =========================================================================
  -- Los Santos Drug Wars (mpchristmas3, décembre 2022)
  -- =========================================================================
  'xm3_lab_props',
  'xm3_lab_int',
  'xm3_lab_int2',
  'xm3_dlc_int_acid_lab',

  -- =========================================================================
  -- San Andreas Mercenaries (mp2023_01, juin 2023)
  -- =========================================================================
  'cs1_05_dlc_avenger_milo',
  'mp2023_01_avenger_interior',

  -- =========================================================================
  -- The Chop Shop (mp2023_02, décembre 2023)
  -- =========================================================================
  'mp2023_02_chop_shop_int',
  'mp2023_02_chopshop_storage_int',
  'mp2023_02_lago_zancudo_drone_strip',

  -- =========================================================================
  -- Bottom Dollar Bounties (mp2024_01, juin 2024)
  -- =========================================================================
  'mp2024_01_office_int',
  'mp2024_01_bail_office',

  -- =========================================================================
  -- Agents of Sabotage (mp2024_02, décembre 2024)
  -- =========================================================================
  'mp2024_02_int_agency',
  'mp2024_02_agency_lounge',

  -- =========================================================================
  -- Money Fronts (mp2025_01, juin 2025)
  -- =========================================================================
  'mp2025_01_warehouse_int',
  'mp2025_01_planning_room',

  -- =========================================================================
  -- A Safehouse in the Hills (mp2025_02, décembre 2025) — dernier en date
  -- =========================================================================
  'mp2025_02_safehouse',
  'mp2025_02_safehouse_int',
  'mp2025_02_hills_garage',

  -- =========================================================================
  -- After Hours / Nightclubs (mpbusiness2, 2018)
  -- =========================================================================
  'ch_dlc_nightclub',
  'ba_dlc_int_placement_strip_club',

  -- =========================================================================
  -- Arena War (xm18, décembre 2018)
  -- =========================================================================
  'arena_main',
  'arena_void',
  'arena_init',
  'arena_props',

  -- =========================================================================
  -- The Doomsday Heist (mpchristmas2017, décembre 2017)
  -- =========================================================================
  'xm_x17dlc_int_01',
  'xm_x17dlc_int_02',
  'xm_x17dlc_int_placement',
  'xm_x17dlc_int_facility',
  'xm_silo_01',
  'xm_silo_02',
  'xm_silo_03',
  'xm_silo_04',
  'xm_siloentranceclosed',

  -- =========================================================================
  -- Smuggler's Run (mpsmuggler, août 2017) — Hangars
  -- =========================================================================
  'sm_smugdlc_hanger_a',
  'sm_smugdlc_hanger_b',
  'sm_smugdlc_hanger_c',
  'sm_smugdlc_int_01',
  'sm_smugdlc_int_02',
  'sm_smugdlc_int_03',
  'sm_smugdlc_int_04',
  'sm_smugdlc_int_05',

  -- =========================================================================
  -- Gunrunning (mpgunrunning, juin 2017) — Bunkers
  -- =========================================================================
  'gr_case0_bunkerclosed',
  'gr_case0_bunkeropened',
  'gr_case1_bunkerclosed',
  'gr_case1_bunkeropened',
  'gr_case2_bunkerclosed',
  'gr_case2_bunkeropened',
  'gr_case3_bunkerclosed',
  'gr_case3_bunkeropened',

  -- =========================================================================
  -- Import/Export (mpimportexport, décembre 2016) — CEO Office, Warehouse
  -- =========================================================================
  'imp_dt1_02_cargarage_a',
  'imp_dt1_02_cargarage_b',
  'imp_dt1_02_cargarage_c',
  'imp_impexp_intwaremed_milo_',
  'imp_impexp_intwarelrg_milo_',
  'imp_impexp_intwaresml_milo_',

  -- =========================================================================
  -- Bikers (mpbiker, octobre 2016) — Clubhouses
  -- =========================================================================
  'bkr_bi_hw1_13_door',
  'bkr_biker_interior_placement_interior_0_biker_dlc_int_01_milo_',
  'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo_',
  'bkr_biker_interior_placement_interior_2_biker_dlc_int_ware01_milo_',
  'bkr_biker_interior_placement_interior_3_biker_dlc_int_ware02_milo_',
  'bkr_biker_interior_placement_interior_4_biker_dlc_int_ware03_milo_',
  'bkr_biker_interior_placement_interior_5_biker_dlc_int_ware04_milo_',

  -- =========================================================================
  -- Heists originaux (Pacific Standard, Humane Labs, etc.)
  -- =========================================================================
  'fbi5_dlc_pl_int',           -- FIB office
  'docks2b_dlc',                -- Docks
  'paleto_score_setup',         -- Paleto bay heist
  'cs3_07_mpchasebridge_dlc',
  'fbi_int',
  'fbi_int_b',
  'fbihq_intplacement',
  'sp1_10_fake_interior',
  'sp1_10_real_interior',
  'sp1_10_fake_interior_lod',

  -- =========================================================================
  -- High Life Update (mp_apartment) — Apartments Heist style
  -- =========================================================================
  'apa_v_mp_h_01_a', 'apa_v_mp_h_01_b', 'apa_v_mp_h_01_c',
  'apa_v_mp_h_02_a', 'apa_v_mp_h_02_b', 'apa_v_mp_h_02_c',
  'apa_v_mp_h_03_a', 'apa_v_mp_h_03_b', 'apa_v_mp_h_03_c',
  'apa_v_mp_h_04_a', 'apa_v_mp_h_04_b', 'apa_v_mp_h_04_c',
  'apa_v_mp_h_05_a', 'apa_v_mp_h_05_b', 'apa_v_mp_h_05_c',
  'apa_v_mp_h_06_a', 'apa_v_mp_h_06_b', 'apa_v_mp_h_06_c',
  'apa_v_mp_h_07_a', 'apa_v_mp_h_07_b', 'apa_v_mp_h_07_c',
  'apa_v_mp_h_08_a', 'apa_v_mp_h_08_b', 'apa_v_mp_h_08_c',

  -- =========================================================================
  -- Yacht (executives)
  -- =========================================================================
  'smboat',
  'smboat_distantlights_blockers',
  'smboat_dock',

  -- =========================================================================
  -- The Contract Yacht
  -- =========================================================================
  'hei_yacht_heist',
  'hei_yacht_heist_bar',
  'hei_yacht_heist_bedrm',
  'hei_yacht_heist_bridge',
  'hei_yacht_heist_dinrm',
  'hei_yacht_heist_enginrm',
  'hei_yacht_heist_lounge',
  'hei_carrier',
  'hei_carrier_int1',
  'hei_carrier_int2',
  'hei_carrier_int3',
  'hei_carrier_int4',
  'hei_carrier_int5',
  'hei_carrier_int6',

  -- =========================================================================
  -- Stunt Race / Cunning Stunts
  -- =========================================================================
  'stt_dlc_stunt_01',
  'stt_dlc_stunt_02',
  'stt_dlc_stunt_03',
  'stt_dlc_stunt_05',
  'stt_dlc_stunt_06',
  'stt_dlc_stunt_07',
  'stt_dlc_stunt_08',
  'stt_dlc_stunt_09',

  -- =========================================================================
  -- Lowriders / Lowriders 2
  -- =========================================================================
  'lr_int_1',
  'lr_int_2',
  'lr_int_3',
  'lr_int_4',
  'lr_int_5',
  'lr_int_6',

  -- =========================================================================
  -- Finance and Felony — Executive offices
  -- =========================================================================
  'ex_dt1_02_office_02a',
  'ex_dt1_02_office_02b',
  'ex_dt1_02_office_02c',
  'ex_dt1_11_office_01a',
  'ex_dt1_11_office_01b',
  'ex_dt1_11_office_01c',
  'ex_dt1_11_office_02a',
  'ex_dt1_11_office_02b',
  'ex_dt1_11_office_02c',
  'ex_dt1_11_office_03a',
  'ex_dt1_11_office_03b',
  'ex_dt1_11_office_03c',
  'ex_sm_13_office_01a',
  'ex_sm_13_office_01b',
  'ex_sm_13_office_01c',
  'ex_sm_13_office_02a',
  'ex_sm_13_office_02b',
  'ex_sm_13_office_02c',
  'ex_sm_13_office_03a',
  'ex_sm_13_office_03b',
  'ex_sm_13_office_03c',
  'ex_sm_15_office_01a',
  'ex_sm_15_office_01b',
  'ex_sm_15_office_01c',
  'ex_sm_15_office_02a',
  'ex_sm_15_office_02b',
  'ex_sm_15_office_02c',
  'ex_sm_15_office_03a',
  'ex_sm_15_office_03b',
  'ex_sm_15_office_03c',

  -- =========================================================================
  -- IAA / NOOSE facilities
  -- =========================================================================
  'iaa_int',
  'iaa_int_placement_interior_0_iaa_dlc_int_01_milo_',
  'cs_paletobay_05_int_01',

  -- =========================================================================
  -- Misc / scattered interiors
  -- =========================================================================
  'TrevorsTrailer',
  'TrevorsTrailerTidy',
  'farm',
  'farmint',
  'farm_props',
  'facelobby',
  'methtrailer',
  'meth_lab',
  'cs1_02_cf_onmission1',
  'cs1_02_cf_onmission2',
  'cs1_02_cf_onmission3',
  'cs1_02_cf_onmission4',
}

-- ===========================================================================
-- IPLs à DÉSACTIVER (rendre la map "propre" : virer fenêtres cassées vanilla,
-- événements scriptés, etc.). Optionnel — décommenter si besoin.
-- ===========================================================================
DLC.IPLsToRemove = {
  -- 'FIBlobby',   -- ex : retirer le hall de la tour FIB (mais bloque la mission Pacific Standard)
}
