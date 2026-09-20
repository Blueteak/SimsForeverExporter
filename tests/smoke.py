"""Focused export checks against mocked WoW APIs. Requires test-only lupa."""
import json
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
CORE = (ROOT / "SimsForeverExporter" / "Core.lua").read_text()
UI = (ROOT / "SimsForeverExporter" / "UI.lua").read_text()

MOCK = r'''
_G = _G or _ENV
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetBuildInfo() return "16.0.1", "12345", "test", 16001 end
function UnitClass() return "Warlock", "WARLOCK", 9 end
function UnitRace() return "Human", "Human", 1 end
function UnitLevel(unit) return unit == "pet" and 16 or 17 end
function UnitHealth() return 350 end
function UnitHealthMax() return 400 end
function UnitPower(_, power) assert(power == 0); return 500 end
function UnitPowerMax(_, power) assert(power == 0); return 600 end
function UnitStat(_, index) return 20, 20 + index end
function UnitArmor() return 100, 150 end
function GetSpellBonusDamage() return 0 end
function GetSpellCritChance() return 5 end
function GetManaRegen() return 6, 0 end
function date() return "2026-01-01T00:00:00Z" end
function GetLocale() return "enUS" end
function UnitExists() return false end
function UnitCreatureFamily() return "Imp" end
function UnitCreatureType() return "Demon" end
function UnitDamage() return 10, 15 end
function UnitAttackSpeed() return 2 end
function UnitName() error("identity API must not be called") end
function UnitGUID() error("identity API must not be called") end
function GetInventoryItemLink(_, slot)
  if slot == 18 then return "|Hitem:11288:0:0|h[Synthetic wand]|h" end
end
function GetInventoryItemID(_, slot) if slot == 18 then return 11288 end end
C_Item = { GetItemInfoInstant = function() return 11288, "Weapon", "Wands", "INVTYPE_RANGEDRIGHT", 1, 2, 19 end }
function UnitRangedDamage() return 1.5, 20, 30, 0, 0, 1 end
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 2 end,
  GetSpellBookSkillLineInfo = function(index)
    return { itemIndexOffset = index == 1 and 0 or 3, numSpellBookItems = 3, offSpecID = index == 2 and 777 or nil }
  end,
  GetSpellBookItemInfo = function(index, bank)
    if bank == 1 then return { itemType = 1, spellID = 3110, name = "Firebolt", subName = "Rank 1" } end
    if index == 1 then return { itemType = 1, spellID = 705, name = "Shadow Bolt", subName = "Rank 3" } end
    if index == 2 then return { itemType = 2, spellID = 999, name = "Future spell" } end
    if index == 3 then return { itemType = 1, spellID = 686, name = "Shadow Bolt", subName = "Rank 1" } end
    error("off-spec skill line must not be enumerated")
  end,
  HasPetSpells = function() return 1 end
}
C_Spell = {
  GetSpellInfo = function(id) return { name = "Shadow Bolt", castTime = 2500 } end,
  GetSpellPowerCost = function(id) return {
    { type = 0, name = "MANA", cost = 45, minCost = 45, costPercent = 0, costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false }
  } end
}
C_TooltipInfo = { GetSpellBookItem = function()
  return { lines = { { leftText = 'Shadow "Bolt"', rightText = "Rank 3" }, { leftText = "Damage\nTabbed\tcontrol\001" } } }
end }
C_ClassTalents = { GetActiveConfigID = function() return 99 end }
C_Traits = {
  GetConfigInfo = function() return { name = "PRIVATE LOADOUT NAME", treeIDs = {1} } end,
  GetTreeNodes = function() return {10, 20} end,
  GetNodeInfo = function(_, id) return { activeRank = id == 10 and 2 or 0, maxRanks = 5, activeEntry = { entryID = 100 } } end,
  GetEntryInfo = function() return { definitionID = 1000 } end,
  GetDefinitionInfo = function() return { spellID = 17793 } end
}
C_UnitAuras = { GetAuraDataByIndex = function(_, index)
  if index == 1 then return { spellId = 687, name = "Demon Skin", applications = 0, duration = 1800, sourceUnit = "PRIVATE CASTER" } end
end }
'''


def setup():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    addon = lua.table()
    loader = lua.eval("function(code, addon) assert(loadstring(code))('SimsForeverExporter', addon) end")
    loader(CORE, addon)
    # Syntax-check UI as well, without assuming a renderer exists.
    assert lua.eval("function(code) return loadstring(code) ~= nil end")(UI)
    return lua, addon, loader


def capture(addon):
    result = addon.Export()
    assert isinstance(result, str), result
    return json.loads(result)


lua, addon, loader = setup()
data = capture(addon)
assert data["schemaVersion"] == 1
assert data["character"]["class"] == "WARLOCK"
assert data["wand"]["minDamage"] == 20
assert "school" not in data["wand"]
assert [spell["id"] for spell in data["spells"]] == [686, 705]
assert data["spells"][1]["costs"][0]["cost"] == 45
assert data["spells"][0]["tooltip"][0] == 'Shadow "Bolt"'
assert data["spells"][0]["tooltip"][2] == "Damage\nTabbed\tcontrol\001"
assert data["talents"][0]["rank"] == 2
assert "PRIVATE" not in json.dumps(data)
assert isinstance(data["buffs"], list)
assert data["pet"] is None

lua.execute("function UnitExists() return true end")
data = capture(addon)
assert data["pet"]["family"] == "Imp"
assert data["pet"]["spells"][0]["id"] == 3110
lua.execute("C_Traits.ConfigHasStagedChanges = function() return true end")
data = capture(addon)
assert data["talents"] == []
assert any("changes are pending" in warning for warning in data["warnings"])
lua.execute("function InCombatLockdown() return true end")
assert addon.Export() == (None, "Leave combat before exporting.")
lua.execute("InCombatLockdown = nil; UnitAffectingCombat = nil")
assert addon.Export() == (None, "Cannot verify that you are outside combat.")

# Secret values are represented by a table that fails if stringified.
# The fake predicate mirrors the API boundary; this is not a live secret-value test.
lua, addon, loader = setup()
lua.execute(r'''
SECRET = setmetatable({}, { __tostring = function() error("secret was stringified") end })
function issecretvalue(value) return rawequal(value, SECRET) end
function UnitHealth() return SECRET end
C_Spell.GetSpellPowerCost = function()
  return { { type = 0, name = "MANA", cost = SECRET, minCost = 45 } }
end
C_TooltipInfo.GetSpellBookItem = function() return { lines = {{ leftText = SECRET, rightText = "Visible" }} } end
''')
data = capture(addon)
assert "current" not in data["character"]["health"]
assert "cost" not in data["spells"][0]["costs"][0]
assert data["spells"][0]["tooltip"] == ["Visible"]
assert any("protected data" in warning for warning in data["warnings"])

# Legacy spellbooks/talents work with modern APIs absent.
lua, addon, loader = setup()
lua.execute(r'''
C_SpellBook = nil; C_Spell = nil; C_ClassTalents = nil; C_Traits = nil; C_TooltipInfo = nil
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "Warlock", 1, 0, 1 end
function GetSpellBookItemInfo() return "SPELL", 705 end
function GetSpellBookItemName() return "Shadow Bolt", "Rank 3" end
function GetSpellInfo() return "Shadow Bolt", "Rank 3", 1, 2500 end
function GetSpellPowerCost() return {{ type = 0, cost = 45 }} end
function GetNumTalentTabs() return 1 end
function GetNumTalents() return 1 end
function GetTalentInfo() return "Improved Shadow Bolt", 1, 1, 1, 2, 5 end
''')
data = capture(addon)
assert data["spells"][0]["id"] == 705
assert data["talents"][0]["system"] == "classic"
assert any("tooltips" in warning for warning in data["warnings"])

# Missing, throwing, and non-finite data stay explicit and JSON remains valid.
lua, addon, loader = setup()
lua.execute(r'''
UnitClass = nil; UnitRace = nil; GetInventoryItemLink = nil; GetInventoryItemID = nil
UnitRangedDamage = nil; C_SpellBook = nil; C_ClassTalents = nil; C_Traits = nil
C_UnitAuras = nil
function UnitStat() error("PRIVATE ERROR DETAILS") end
function GetSpellCritChance() return 0/0 end
''')
data = capture(addon)
assert data["character"]["class"] is None
assert data["character"]["race"] is None
assert data["wand"] is None
assert data["spells"] == [] and data["equipment"] == [] and data["talents"] == []
assert data["character"]["stats"]["spellCritBySchool"] == {}
assert "PRIVATE" not in json.dumps(data)
assert len(data["warnings"]) >= 5

# Exercise slash commands, copy UI, optional persistence, and combat rejection.
lua, addon, loader = setup()
lua.execute(r'''
SlashCmdList = {}; UIParent = {}; ChatFontNormal = {}; UISpecialFrames = {}; DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local methods = {}
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:CreateFontString() return setmetatable({scripts={}}, {__index=methods}) end
function methods:GetFont() return "font", 12 end
function methods:GetNumLines() return 4 end
function methods:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
setmetatable(methods, { __index = function() return function() end end })
function CreateFrame(_, name)
  local frame = setmetatable({scripts={}}, {__index=methods})
  if name then _G[name] = frame end
  return frame
end
''')
loader(UI, addon)
command = lua.globals().SlashCmdList.SIMFOREVEREXPORTER
command("")
assert lua.globals().SimsForeverExporterDB is None
assert lua.globals().SimsForeverExporterWindow.shown is True
command("save")
assert json.loads(lua.globals().SimsForeverExporterDB.lastExport)["schemaVersion"] == 1
command("clear")
assert lua.globals().SimsForeverExporterDB is None
lua.execute("function InCombatLockdown() return true end")
command("save")
assert lua.globals().SimsForeverExporterDB is None

fixture = json.loads((ROOT / "examples" / "synthetic-warlock-17.json").read_text())
assert fixture["build"]["version"] == "synthetic"
assert fixture["character"]["level"] == 17
print("PASS: Lua 5.1 syntax, capture, modern/legacy APIs, learned-only spells, pet, JSON escaping, secret/missing values, combat guard, UI commands, synthetic fixture")
