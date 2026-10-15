Economy = Economy or {}

Economy.Accounts = { 'cash', 'bank', 'crypto' }

Economy.IsValidAccount = function(name)
  for _, a in ipairs(Economy.Accounts) do if a == name then return true end end
  return false
end

Economy.Starting = {
  cash = 500,
  bank = 5000,
  crypto = 0,
}

Economy.Currency = {
  symbol = '$',
  position = 'suffix',
}

Economy.FormatMoney = function(amount, account)
  local n = math.floor(tonumber(amount) or 0)
  local sign = n < 0 and '-' or ''
  local abs = math.abs(n)
  local str = tostring(abs)
  local formatted = str:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ +', '')
  return sign .. formatted .. Economy.Currency.symbol
end

Economy.ATM = {
  models = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm',
  },
  withdrawFee = 0,
  blip = {
    sprite = 277,
    color = 2,
    scale = 0.7,
    name = 'Distributeur',
  },
  showBlips = true,
  locations = {
    { x = 146.61, y = -1035.43, z = 29.34 },
    { x = 146.32, y = -1037.18, z = 29.34 },
    { x = 145.99, y = -1035.16, z = 29.34 },
    { x = 155.65, y = 233.10, z = 106.59 },
    { x = 155.83, y = 234.78, z = 106.59 },
    { x = -846.40, y = -340.96, z = 38.69 },
    { x = -848.84, y = -337.99, z = 38.69 },
    { x = -1409.69, y = -98.85, z = 52.21 },
    { x = -1410.91, y = -98.96, z = 52.21 },
    { x = -1212.98, y = -330.84, z = 37.78 },
    { x = -1207.99, y = -325.84, z = 37.78 },
    { x = -2962.58, y = 482.62, z = 15.70 },
    { x = -2962.06, y = 481.62, z = 15.70 },
    { x = -2072.21, y = -317.36, z = 13.31 },
    { x = -1820.65, y = 792.99, z = 138.20 },
    { x = -870.10, y = -1366.66, z = 5.27 },
    { x = -1199.31, y = -893.20, z = 13.99 },
    { x = 314.18, y = -278.62, z = 54.17 },
    { x = 315.46, y = -279.36, z = 54.17 },
    { x = -351.53, y = -49.52, z = 49.04 },
    { x = -354.42, y = -47.62, z = 49.04 },
    { x = 1138.43, y = -468.93, z = 66.74 },
    { x = 1153.05, y = -326.36, z = 69.21 },
    { x = -721.13, y = -415.55, z = 35.04 },
    { x = -526.93, y = -1222.51, z = 18.45 },
    { x = -255.97, y = -716.30, z = 33.49 },
    { x = -3144.13, y = 1127.41, z = 21.06 },
    { x = -111.95, y = 6467.04, z = 31.49 },
    { x = -108.43, y = 6477.91, z = 31.46 },
    { x = 174.06, y = 6637.49, z = 31.50 },
    { x = 174.71, y = 6635.62, z = 31.50 },
    { x = 1734.20, y = 6411.30, z = 35.04 },
    { x = 1822.13, y = 3683.34, z = 34.27 },
    { x = 1701.66, y = 4924.39, z = 42.06 },
    { x = 1968.40, y = 3744.31, z = 32.34 },
    { x = -263.49, y = -2009.62, z = 30.12 },
    { x = 289.16, y = -1256.50, z = 29.44 },
    { x = 285.07, y = 143.21, z = 104.34 },
    { x = 24.32, y = -946.27, z = 29.36 },
    { x = -3241.84, y = 996.66, z = 12.69 },
    { x = 1077.65, y = -776.49, z = 58.22 },
    { x = 1153.65, y = -326.96, z = 69.21 },
    { x = -3144.16, y = 1129.30, z = 21.07 },
  },
}

Economy.Bank = {
  blip = {
    sprite = 108,
    color = 2,
    scale = 0.9,
    name = 'Banque Fleeca',
  },
  locations = {
    { x = 150.27, y = -1040.20, z = 29.37, h = 340.0 },
    { x = -1212.98, y = -330.84, z = 37.78, h = 25.0 },
    { x = -2962.58, y = 482.62, z = 15.70, h = 88.0 },
    { x = -112.20, y = 6469.95, z = 31.63, h = 135.0 },
    { x = 314.18, y = -278.62, z = 54.17, h = 340.0 },
    { x = -351.53, y = -49.52, z = 49.04, h = 340.0 },
  },
}

Economy.Limits = {
  maxCashOnPerson = 50000,
  maxTransfer = 1000000,
}
