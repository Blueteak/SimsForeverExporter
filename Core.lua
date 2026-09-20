local _, addon = ...
addon = addon or {}
addon.VERSION = "0.1.2"

local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
local arrayTag = {}
local function array() return setmetatable({}, arrayTag) end
local NULL = {}
local warnings, warned
local function warn(message)
    if not warned[message] then
        warned[message] = true
        warnings[#warnings + 1] = message
    end
end

-- Never inspect, compare, stringify, or serialize a restricted value.
local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok or not accessible then return false end
    end
    return true
end

local function clean(value, label, depth)
    if not readable(value) then
        warn(label .. ": protected data omitted; export again outside combat.")
        return nil
    end
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value == value and value ~= math.huge and value ~= -math.huge then return value end
        warn(label .. ": invalid number omitted.")
    elseif kind == "table" and depth < 8 then
        local result, count = {}, 0
        for key, item in pairs(value) do
            count = count + 1
            if count > 4096 then warn(label .. ": oversized API table truncated."); break end
            if readable(key) and (type(key) == "number" or type(key) == "string") then
                result[key] = clean(item, label, depth + 1)
            else
                warn(label .. ": protected key omitted.")
            end
        end
        return result
    end
    return nil
end

local function call(label, fn, ...)
    if type(fn) ~= "function" then return nil end
    local values = pack(pcall(fn, ...))
    if not values[1] then warn(label .. ": API call failed; data omitted."); return nil end
    for index = 2, values.n do values[index] = clean(values[index], label, 0) end
    return unpack(values, 2, values.n)
end

local function namespace(name, member)
    return type(_G[name]) == "table" and _G[name][member] or nil
end
local function number(value) return type(value) == "number" and value or nil end
local function stringValue(value) return type(value) == "string" and value or nil end
local function required(value, label)
    if value == nil then warn(label .. ": unavailable."); return NULL end
    return value
end
local function pick(source, keys)
    local result = {}
    if type(source) == "table" then
        for _, key in ipairs(keys) do
            local value = source[key]
            if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
                result[key] = value
            end
        end
    end
    return result
end

local function jsonString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        -- Unicode escapes avoid copy-window interpretation of short escapes.
        return string.format("\\u%04x", string.byte(char))
    end) .. '"'
end
local function encode(value)
    if value == NULL or value == nil then return "null" end
    local kind = type(value)
    if kind == "string" then return jsonString(value) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then return string.format("%.15g", value) end
    assert(kind == "table", "Unsupported export value")
    local entries = {}
    if getmetatable(value) == arrayTag then
        for index = 1, #value do entries[index] = encode(value[index]) end
        return "[" .. table.concat(entries, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do entries[#entries + 1] = jsonString(key) .. ":" .. encode(value[key]) end
    return "{" .. table.concat(entries, ",") .. "}"
end

local function spellTooltip(id, slot, bank)
    local tooltip
    if slot then tooltip = call("Spell tooltip", namespace("C_TooltipInfo", "GetSpellBookItem"), slot, bank) end
    if not tooltip then tooltip = call("Spell tooltip", namespace("C_TooltipInfo", "GetSpellByID"), id) end
    local lines = array()
    if tooltip and type(tooltip.lines) == "table" then
        for _, line in ipairs(tooltip.lines) do
            if type(line) == "table" then
                if type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
                if type(line.rightText) == "string" then lines[#lines + 1] = line.rightText end
            end
        end
    end
    if #lines == 0 then warn("Some spell tooltips are unavailable; raw spell damage needs manual verification.") end
    return lines
end

local function spellDetails(id, name, rank, slot, bank)
    if type(id) ~= "number" or id <= 0 then return nil end
    local info = call("Spell info", namespace("C_Spell", "GetSpellInfo"), id)
    local castTime
    if type(info) == "table" then
        name = name or stringValue(info.name)
        castTime = number(info.castTime)
    else
        local legacyName, legacyRank, _, legacyTime = call("Spell info", GetSpellInfo, id)
        name, rank, castTime = name or legacyName, rank or legacyRank, number(legacyTime)
    end
    if type(name) ~= "string" then warn("A learned spell has no readable name; entry omitted."); return nil end
    local result = { id = id, name = name, rank = stringValue(rank), castTimeMs = castTime }
    if castTime == nil then warn("Some spell cast times are unavailable; missing times do not mean instant casts.") end
    if not rank then result.rank = call("Spell rank", namespace("C_Spell", "GetSpellSubtext"), id) end
    if result.rank == "" then result.rank = nil end
    local costs = call("Spell cost", namespace("C_Spell", "GetSpellPowerCost") or GetSpellPowerCost, id)
    if costs == nil and slot then costs = call("Spell cost", namespace("C_SpellBook", "GetSpellBookItemPowerCost"), slot, bank) end
    if type(costs) == "table" then
        result.costs = array()
        for _, cost in ipairs(costs) do
            local item = pick(cost, {"type", "name", "cost", "minCost", "costPercent", "costPerSec", "requiredAuraID", "hasRequiredAura"})
            if type(item.type) == "number" then result.costs[#result.costs + 1] = item end
        end
    else
        warn("Some spell costs are unavailable; missing costs do not mean free spells.")
    end
    result.tooltip = spellTooltip(id, slot, bank)
    return result
end

local function spells(isPet)
    local result, seen = array(), {}
    local modern = namespace("C_SpellBook", "GetSpellBookItemInfo")
    if modern and not isPet and (not namespace("C_SpellBook", "GetNumSpellBookSkillLines") or not namespace("C_SpellBook", "GetSpellBookSkillLineInfo")) then
        modern = nil
    end
    local bank = isPet and 1 or 0 -- SpellBookSpellBank, verified for interface 16001.
    local function add(id, name, rank, slot)
        if type(id) == "number" and not seen[id] then
            local item = spellDetails(id, name, rank, modern and slot or nil, bank)
            if item then seen[id] = true; result[#result + 1] = item end
        end
    end
    local function visit(index)
        if modern then
            local info = call("Spellbook item", modern, index, bank)
            if type(info) == "table" and info.itemType == 1 and info.isOffSpec ~= true then
                -- FutureSpell (2), PetAction (3), and flyouts (4) are not learned spells.
                add(info.spellID or info.actionID, info.name, info.subName, index)
            elseif type(info) == "table" and info.itemType == 4 then
                local _, _, count = call("Spell flyout", GetFlyoutInfo, info.actionID)
                for flyoutSlot = 1, math.min(number(count) or 0, 200) do
                    local id, override, known = call("Spell flyout", GetFlyoutSlotInfo, info.actionID, flyoutSlot)
                    if known == true then add(override or id) end
                end
            end
        else
            local book = isPet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell")
            local kind, id = call("Spellbook item", GetSpellBookItemInfo, index, book)
            if kind == "SPELL" then
                local name, rank = call("Spellbook name", GetSpellBookItemName, index, book)
                add(id, name, rank)
            end
        end
    end
    if isPet then
        local count = call("Pet spellbook", namespace("C_SpellBook", "HasPetSpells") or HasPetSpells)
        for index = 1, math.min(number(count) or 0, 500) do visit(index) end
    elseif modern then
        local count = call("Spellbook skill lines", namespace("C_SpellBook", "GetNumSpellBookSkillLines"))
        for index = 1, math.min(number(count) or 0, 100) do
            local line = call("Spellbook skill line", namespace("C_SpellBook", "GetSpellBookSkillLineInfo"), index)
            if type(line) == "table" and not line.offSpecID then
                local offset, size = number(line.itemIndexOffset), number(line.numSpellBookItems)
                if offset and size then for slot = offset + 1, offset + math.min(size, 1000) do visit(slot) end end
            end
        end
    else
        local count = call("Spellbook tabs", GetNumSpellTabs)
        for index = 1, math.min(number(count) or 0, 100) do
            local _, _, offset, size = call("Spellbook tab", GetSpellTabInfo, index)
            if number(offset) and number(size) then for slot = offset + 1, offset + math.min(size, 1000) do visit(slot) end end
        end
    end
    if #result == 0 then warn(isPet and "Pet spells unavailable or none learned." or "Learned spells unavailable; do not infer spell availability from level.") end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

local function talents()
    local result = array()
    local config = call("Active talents", namespace("C_ClassTalents", "GetActiveConfigID"))
    if type(config) == "number" and namespace("C_Traits", "GetConfigInfo") then
        if call("Pending talents", namespace("C_Traits", "ConfigHasStagedChanges"), config) == true then
            warn("Talents omitted because changes are pending; apply or discard them before exporting.")
            return result
        end
        local info = call("Talent config", namespace("C_Traits", "GetConfigInfo"), config)
        if type(info) == "table" and type(info.treeIDs) == "table" then
            for _, tree in ipairs(info.treeIDs) do
                local nodes = call("Talent tree", namespace("C_Traits", "GetTreeNodes"), tree)
                for _, id in ipairs(type(nodes) == "table" and nodes or {}) do
                    local node = call("Talent node", namespace("C_Traits", "GetNodeInfo"), config, id)
                    if type(node) == "table" and number(node.activeRank) and node.activeRank > 0 then
                        local entryId = type(node.activeEntry) == "table" and node.activeEntry.entryID
                        local entry = entryId and call("Talent entry", namespace("C_Traits", "GetEntryInfo"), config, entryId)
                        local definition = type(entry) == "table" and entry.definitionID and call("Talent definition", namespace("C_Traits", "GetDefinitionInfo"), entry.definitionID)
                        local spellId = type(definition) == "table" and number(definition.spellID) or nil
                        result[#result + 1] = { system = "traits", treeId = tree, nodeId = id, entryId = entryId or nil,
                            rank = node.activeRank, maxRank = number(node.maxRanks), spellId = spellId }
                    end
                end
            end
            return result
        end
    end
    if type(GetNumTalentTabs) == "function" and type(GetTalentInfo) == "function" then
        local count = call("Talent tabs", GetNumTalentTabs)
        for tab = 1, math.min(number(count) or 0, 20) do
            local size = call("Talent count", GetNumTalents, tab)
            for index = 1, math.min(number(size) or 0, 200) do
                local name, _, tier, column, rank, maxRank = call("Talent", GetTalentInfo, tab, index)
                if number(rank) and rank > 0 then
                    result[#result + 1] = { system = "classic", tab = tab, index = index, name = name,
                        tier = tier, column = column, rank = rank, maxRank = maxRank }
                end
            end
        end
        return result
    end
    warn("Talents unavailable; an empty list does not confirm zero talent points.")
    return result
end

local function equipment()
    local result, wand = array(), NULL
    if type(GetInventoryItemLink) ~= "function" then warn("Equipment API unavailable.") end
    for slot = 1, 19 do
        local link = call("Equipment link", GetInventoryItemLink, "player", slot)
        local itemId = call("Equipment ID", GetInventoryItemID, "player", slot)
        if type(link) == "string" or type(itemId) == "number" then
            local id, _, _, equipLoc, _, classId, subClassId = call("Item type", namespace("C_Item", "GetItemInfoInstant") or GetItemInfoInstant, link or itemId)
            local item = { slot = slot, itemId = number(itemId) or number(id), link = stringValue(link), equipLoc = equipLoc,
                classId = number(classId), subClassId = number(subClassId) }
            result[#result + 1] = item
            if not link then warn("Some equipped item links are not cached; export again after opening your character panel.") end
            if classId == 2 and subClassId == 19 then
                local speed, minDamage, maxDamage, positive, negative, multiplier = call("Wand damage", UnitRangedDamage, "player")
                wand = { slot = slot, itemId = item.itemId, link = item.link, speed = number(speed),
                    minDamage = number(minDamage), maxDamage = number(maxDamage), positiveBonus = number(positive),
                    negativeBonus = number(negative), damageMultiplier = number(multiplier), source = "UnitRangedDamage" }
                if not number(speed) or speed <= 0 or not number(minDamage) or not number(maxDamage) then
                    warn("Wand damage or speed unavailable; enter observed values in the simulator.")
                end
                warn("Wand school unavailable as structured data; verify the item tooltip in game.")
            elseif slot == 18 and (classId == nil or subClassId == nil) then
                warn("Ranged item type unavailable; wand could not be confirmed.")
            end
        end
    end
    return result, wand
end

local function resources(unit)
    return {
        current = number(call("Health", UnitHealth, unit)), max = number(call("Maximum health", UnitHealthMax, unit))
    }, {
        current = number(call("Mana", UnitPower, unit, 0)), max = number(call("Maximum mana", UnitPowerMax, unit, 0))
    }
end
local function stats()
    local result = {}
    for index, key in ipairs({"strength", "agility", "stamina", "intellect", "spirit"}) do
        local _, effective = call("Primary stats", UnitStat, "player", index)
        result[key] = number(effective)
    end
    local _, effectiveArmor = call("Armor", UnitArmor, "player")
    result.armor = number(effectiveArmor)
    local baseAP, positiveAP, negativeAP = call("Attack power", UnitAttackPower, "player")
    if number(baseAP) and number(positiveAP) and number(negativeAP) then
        result.attackPower = math.max(0, baseAP + positiveAP + negativeAP)
    else
        warn("Attack power unavailable; export again outside combat.")
    end
    result.spellDamageBySchool, result.spellCritBySchool = {}, {}
    for school = 1, 7 do
        result.spellDamageBySchool[tostring(school)] = number(call("Spell damage", GetSpellBonusDamage, school))
        result.spellCritBySchool[tostring(school)] = number(call("Spell critical chance", GetSpellCritChance, school))
    end
    local base, casting = call("Mana regeneration", GetManaRegen)
    result.manaRegen = { base = number(base), casting = number(casting) }
    if result.intellect == nil then warn("Primary stats unavailable.") end
    return result
end

local function buffs()
    local result = array()
    local modern = namespace("C_UnitAuras", "GetAuraDataByIndex")
    if not modern and type(UnitBuff) ~= "function" then warn("Buff data unavailable."); return result end
    for index = 1, 255 do
        if modern then
            local data = call("Buff", modern, "player", index, "HELPFUL")
            if type(data) ~= "table" then break end
            local buff = pick(data, {"spellId", "name", "applications", "duration", "expirationTime"})
            if buff.spellId or buff.name then result[#result + 1] = buff end
        else
            local name, _, count, _, duration, expirationTime, _, _, _, id = call("Buff", UnitBuff, "player", index)
            if not name then break end
            result[#result + 1] = { spellId = id, name = name, applications = count, duration = duration, expirationTime = expirationTime }
        end
    end
    return result
end

function addon.Capture()
    warnings, warned = array(), {}
    local inCombat = call("Combat status", InCombatLockdown)
    local affectingCombat = call("Combat status", UnitAffectingCombat, "player")
    if inCombat == true or affectingCombat == true then return nil, "Leave combat before exporting." end
    if inCombat == nil and affectingCombat == nil then return nil, "Cannot verify that you are outside combat." end
    local version, build, _, interface = call("Build", GetBuildInfo)
    local _, class, classId = call("Class", UnitClass, "player")
    local _, race = call("Race", UnitRace, "player")
    local health, mana = resources("player")
    if not health.max or not mana.max then warn("Player resources incomplete; export again outside combat.") end
    local gear, wand = equipment()
    local pet = NULL
    local exists = call("Pet presence", UnitExists, "pet")
    if exists == true then
        local petHealth, petMana = resources("pet")
        local minDamage, maxDamage = call("Pet damage", UnitDamage, "pet")
        pet = { family = call("Pet family", UnitCreatureFamily, "pet"), creatureType = call("Pet type", UnitCreatureType, "pet"),
            level = number(call("Pet level", UnitLevel, "pet")), health = petHealth, mana = petMana,
            minDamage = number(minDamage), maxDamage = number(maxDamage),
            attackSpeed = number(call("Pet attack speed", UnitAttackSpeed, "pet")), spells = spells(true) }
    elseif exists == nil then warn("Pet presence unavailable.") end
    local capturedAt = call("Timestamp", date, "!%Y-%m-%dT%H:%M:%SZ")
    local result = {
        schemaVersion = 1, addonVersion = addon.VERSION,
        capturedAt = required(capturedAt, "Capture timestamp"),
        build = { version = required(version, "Game version"), build = required(build, "Game build"), interface = required(interface, "Game interface") },
        locale = call("Locale", GetLocale),
        character = { class = required(class, "Class"), classId = required(classId, "Class ID"), race = required(race, "Race"),
            level = required(number(call("Level", UnitLevel, "player")), "Level"), health = health, mana = mana, stats = stats() },
        equipment = gear, wand = wand, spells = spells(false), talents = talents(), pet = pet, buffs = buffs(), warnings = warnings
    }
    return result
end

function addon.Export()
    local result, errorMessage = addon.Capture()
    if not result then return nil, errorMessage end
    return encode(result)
end
