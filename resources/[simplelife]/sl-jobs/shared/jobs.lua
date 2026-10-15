Jobs = Jobs or {}

Jobs.Catalog = {
  unemployed = {
    label = 'Sans emploi',
    isPublic = true,
    grades = {
      [0] = { label = 'Sans emploi', payCheck = 0 },
    },
  },
  police = {
    label = 'Police de Los Santos',
    isPublic = false,
    grades = {
      [0] = { label = 'Cadet', payCheck = 200 },
      [1] = { label = 'Officier', payCheck = 350 },
      [2] = { label = 'Sergent', payCheck = 500 },
      [3] = { label = 'Lieutenant', payCheck = 700 },
      [4] = { label = 'Capitaine', payCheck = 900 },
      [5] = { label = 'Chef', payCheck = 1200, isBoss = true },
    },
  },
  ambulance = {
    label = 'EMS Sandy',
    isPublic = false,
    grades = {
      [0] = { label = 'Stagiaire', payCheck = 180 },
      [1] = { label = 'Ambulancier', payCheck = 320 },
      [2] = { label = 'Médecin', payCheck = 500 },
      [3] = { label = 'Sénior', payCheck = 700 },
      [4] = { label = 'Chef de service', payCheck = 1000, isBoss = true },
    },
  },
  mechanic = {
    label = 'LS Customs',
    isPublic = false,
    grades = {
      [0] = { label = 'Apprenti', payCheck = 150 },
      [1] = { label = 'Mécano', payCheck = 280 },
      [2] = { label = 'Sénior', payCheck = 450 },
      [3] = { label = 'Patron', payCheck = 700, isBoss = true },
    },
  },
  taxi = {
    label = 'Downtown Cab Co.',
    isPublic = true,
    grades = {
      [0] = { label = 'Chauffeur', payCheck = 120 },
      [1] = { label = 'Sénior', payCheck = 220 },
      [2] = { label = 'Patron', payCheck = 400, isBoss = true },
    },
  },
  farmer = {
    label = 'Ranch Grapeseed',
    isPublic = true,
    grades = {
      [0] = { label = 'Ouvrier', payCheck = 100 },
      [1] = { label = 'Fermier', payCheck = 200 },
      [2] = { label = 'Régisseur', payCheck = 350 },
      [3] = { label = 'Patron', payCheck = 550, isBoss = true },
    },
  },
  trucker = {
    label = 'Trucker Co.',
    isPublic = true,
    grades = {
      [0] = { label = 'Livreur', payCheck = 130 },
      [1] = { label = 'Routier', payCheck = 230 },
      [2] = { label = 'Sénior', payCheck = 380 },
    },
  },
}

function Jobs.GetJob(name)
  return Jobs.Catalog[name]
end

function Jobs.GetGrade(jobName, gradeId)
  local job = Jobs.Catalog[jobName]
  if not job then return nil end
  return job.grades[gradeId]
end

function Jobs.IsValid(jobName, gradeId)
  local job = Jobs.Catalog[jobName]
  if not job then return false end
  return job.grades[gradeId or 0] ~= nil
end

function Jobs.PublicList()
  local out = {}
  for name, job in pairs(Jobs.Catalog) do
    if job.isPublic then
      table.insert(out, { name = name, label = job.label })
    end
  end
  table.sort(out, function(a, b) return a.label < b.label end)
  return out
end
