Curator = Curator or {}

Curator.NeutralBase = {
  ['component:1']  = { drawable = 0,  texture = 0 },
  ['component:2']  = { drawable = 0,  texture = 0 },
  ['component:3']  = { drawable = 0,  texture = 0 },
  ['component:4']  = { drawable = 0,  texture = 0 },
  ['component:5']  = { drawable = 0,  texture = 0 },
  ['component:6']  = { drawable = 0,  texture = 0 },
  ['component:7']  = { drawable = 0,  texture = 0 },
  ['component:8']  = { drawable = 15, texture = 0 },
  ['component:9']  = { drawable = 0,  texture = 0 },
  ['component:10'] = { drawable = 0,  texture = 0 },
  ['component:11'] = { drawable = 15, texture = 0 },
  ['prop:0']       = { drawable = -1, texture = 0 },
  ['prop:1']       = { drawable = -1, texture = 0 },
  ['prop:2']       = { drawable = -1, texture = 0 },
  ['prop:6']       = { drawable = -1, texture = 0 },
  ['prop:7']       = { drawable = -1, texture = 0 },
}

Curator.Phases = {
  p1 = {
    label = 'Phase 1',
    title = 'Trio haut : Bras + T-shirt + Torse',
    desc = 'Le reste est neutre pour isoler le jugement',
    testSlots = {
      { kind = 'component', id = 3,  label = 'Bras' },
      { kind = 'component', id = 8,  label = 'T-shirt' },
      { kind = 'component', id = 11, label = 'Torse' },
    },
    requiresPrev = nil,
    extraSlot = nil,
  },
  p2 = {
    label = 'Phase 2',
    title = '+ Gilet',
    desc = 'Combine un trio validé avec un gilet',
    testSlots = {
      { kind = 'component', id = 3,  label = 'Bras' },
      { kind = 'component', id = 8,  label = 'T-shirt' },
      { kind = 'component', id = 11, label = 'Torse' },
      { kind = 'component', id = 9,  label = 'Gilet' },
    },
    requiresPrev = 'p1',
    extraSlot = { kind = 'component', id = 9, label = 'Gilet' },
  },
  p3 = {
    label = 'Phase 3',
    title = '+ Chaîne',
    desc = 'Combine un 4-tuple validé avec une chaîne',
    testSlots = {
      { kind = 'component', id = 3,  label = 'Bras' },
      { kind = 'component', id = 8,  label = 'T-shirt' },
      { kind = 'component', id = 11, label = 'Torse' },
      { kind = 'component', id = 9,  label = 'Gilet' },
      { kind = 'component', id = 7,  label = 'Chaîne' },
    },
    requiresPrev = 'p2',
    extraSlot = { kind = 'component', id = 7, label = 'Chaîne' },
  },
  p4 = {
    label = 'Phase 4',
    title = 'Bas : Pantalon + Chaussures',
    desc = 'Indépendant du haut',
    testSlots = {
      { kind = 'component', id = 4, label = 'Pantalon' },
      { kind = 'component', id = 6, label = 'Chaussures' },
    },
    requiresPrev = nil,
    extraSlot = nil,
  },
}

Curator.PhaseOrder = { 'p1', 'p2', 'p3', 'p4' }

Curator.SessionDedupSize = 200
