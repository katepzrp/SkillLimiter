---
--- Created by Max
--- Initial help from: Konijima#9279
--- Profession bugfix by: ladyinkateing
--- Created on: 10/07/2022 21:23
---

-- Mod info class
---@class SkillLimiter
SkillLimiter = {}

-- Mod info
SkillLimiter.modName = "SkillLimiter"
SkillLimiter.modVersion = "1.1.1"
SkillLimiter.modAuthor = "Max"
SkillLimiter.modDescription = "Limits the maximum skill level of a character based on their traits and profession."

-- Fetch sandbox vars

---@return number
local function getAgilityBonus()
    local bonus = SandboxVars.SkillLimiter.AgilityBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

---@return number
local function getCombatBonus()
    local bonus = SandboxVars.SkillLimiter.CombatBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

---@return number
local function getCraftingBonus()
    local bonus = SandboxVars.SkillLimiter.CraftingBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

---@return number
local function getFirearmBonus()
    local bonus = SandboxVars.SkillLimiter.FirearmBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

---@return number
local function getSurvivalistBonus()
    local bonus = SandboxVars.SkillLimiter.SurvivalistBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

---@return number
local function getPassivesBonus()
    local bonus = SandboxVars.SkillLimiter.PassivesBonus
    if bonus == nil then
        bonus = 0
    end
    return bonus
end

--- Get the custom bonus for a perk from the SandboxVars.SkillLimiter.PerkBonuses setting.
---@return number
---@param perk PerkFactory.Perk
local function getCustomPerkBonus(perk)
    local perkBonuses = SandboxVars.SkillLimiter.PerkBonuses
    if perkBonuses == nil then
        perkBonuses = ""
    end
    -- parse perk bonuses. Semicolon separated list of perk id:bonus pairs
    for perkBonus in perkBonuses:gmatch("[^;]+") do

        local split_perk_bonus = {}

        for perk_bonus_value in perkBonus:gmatch("[^:]+") do
            table.insert(split_perk_bonus, perk_bonus_value)
        end

        -- The first value is the perk id, the second is the bonus
        local perk_name = split_perk_bonus[1]:lower()
        local perk_bonus_value = tonumber(split_perk_bonus[2])

        if perk_name == perk:getId():lower() then
            if perk_bonus_value == nil then
                print("SkillLimiter: Invalid perk bonus value for perk " .. perk:getId() .. ". Please check your sandbox settings.")
                return 0
            end

            return perk_bonus_value
        end
    end

    return 0
end

-- Mod methods

--- Get the bonus for a perk based on the SandboxVars settings.
---@return number
---@param perk PerkFactory.Perk
SkillLimiter.getPerkBonus = function(perk)
    local perk_category = perk:getParent():getId():lower()
    local perk_found = false
    local bonus = 0

    -- If perk is part of the Agility category, add the relevant bonus.
    if perk_category == "agility" then
        bonus = getAgilityBonus()
        perk_found = true
    end

    -- If perk is part of the Combat category, add the relevant bonus.
    if perk_category == "combat" then
        bonus = getCombatBonus()
        perk_found = true
    end

    -- If perk is part of the Crafting category, add the relevant bonus.
    if perk_category == "crafting" then
        bonus = getCraftingBonus()
        perk_found = true
    end

    -- If perk is part of the Firearm category, add the relevant bonus.
    if perk_category == "firearm" then
        bonus = getFirearmBonus()
        perk_found = true
    end

    -- If perk is part of the Survivalist category, add the relevant bonus.
    if perk_category == "survivalist" then
        bonus = getSurvivalistBonus()
        perk_found = true
    end

    -- If perk is part of the Passiv category, add the relevant bonus.
    if perk_category == "passiv" then
        bonus = getPassivesBonus()
        perk_found = true
    end

    -- If perk is not found, then we do not need to limit the skill. This is to provide compatibility (aka: don't cause errors) with other mods that add skills.
    if not perk_found then
        return nil
    end

    -- If the perk is in the perk bonus list, add the bonus to the total.
    local success, perk_bonus = pcall(getCustomPerkBonus, perk)
    if success then
        bonus = bonus + perk_bonus
    else
        print("SkillLimiter: Error. Could not get custom perk bonus for perk " .. perk:getId() .. ". Please check your sandbox settings.")
    end

    return bonus
end

--- Get the maximum skill level for a character based on their traits and profession.
---@return number
---@param character IsoGameCharacter
---@param perk PerkFactory.Perk
SkillLimiter.getMaxSkill = function(character, perk)
    local character_traits = character:getTraits()
    local character_profession_str = character:getDescriptor():getProfession()
    local trait_perk_level = 0

    local bonus = SkillLimiter.getPerkBonus(perk)

    if not bonus then
        print("SkillLimiter: Limiting to max cap since perk was not found: " .. perk:getId() .. ".")
        return SandboxVars.SkillLimiter.PerkLvl3Cap
    end

    -- If bonus is 3 or more, we do not need to check whether or not we should cap the skill. Return.
    if bonus >= 3 then
        print("SkillLimiter: Limiting to max cap since bonus >= 3: (" .. bonus .. ")")
        return SandboxVars.SkillLimiter.PerkLvl3Cap
    end

    -- Go through all traits and add their relevant perk level to the total
    for i=0, character_traits:size()-1 do
        local trait_str = character_traits:get(i);
        local trait = TraitFactory.getTrait(trait_str)
        local map = trait:getXPBoostMap();
        if map then
            local mapTable = transformIntoKahluaTable(map)
            for trait_perk, level in pairs(mapTable) do
                if trait_perk:getId() == perk:getId() then
                    trait_perk_level = trait_perk_level + level:intValue()
                end
            end
        end
    end

    local character_profession = ProfessionFactory.getProfession(character_profession_str)

    -- Go through the XPBoostMap of the profession and add the relevant perk level to the total
    if character_profession then
        local profession_xp_boost_map = character_profession:getXPBoostMap()
        if profession_xp_boost_map then
            local mapTable = transformIntoKahluaTable(profession_xp_boost_map)
            for prof_perk, level in pairs(mapTable) do
                if prof_perk:getId() == perk:getId() then
                    trait_perk_level = trait_perk_level + level:intValue()
                end
            end
        end
    end

    if bonus then
        trait_perk_level = trait_perk_level + bonus
    end

    if trait_perk_level <= 0 then
        return SandboxVars.SkillLimiter.PerkLvl0Cap
    end
    if trait_perk_level == 1 then
        return SandboxVars.SkillLimiter.PerkLvl1Cap
    end
    if trait_perk_level == 2 then
        return SandboxVars.SkillLimiter.PerkLvl2Cap
    end
    if trait_perk_level >= 3 then
        return SandboxVars.SkillLimiter.PerkLvl3Cap
    end
end

---@param character IsoGameCharacter
---@param perk PerkFactory.Perk
---@param level Integer
SkillLimiter.limitSkill = function(character, perk, level)
    -- Get the maximum skill level for this perk, based on the character's traits & profession.
    local max_skill = SkillLimiter.getMaxSkill(character, perk)
    if max_skill == nil then
        print("SkillLimiter: Error. Max Skill is nil.")
        return
    end

    if level > max_skill then
        -- Cap the skill level.
        character:getXp():setXPToLevel(perk, max_skill)
        character:setPerkLevelDebug(perk, max_skill)
        SyncXp(character)

        print("SkillLimiter: " .. character:getFullName() .. " leveled up " .. perk:getId() .. " and was capped to level " .. max_skill .. ".")
        HaloTextHelper.addText(character, "The " .. perk:getId() .. " skill was capped to level " .. max_skill .. ".", HaloTextHelper.getColorWhite())
    end
end

-- Mod event variables

SkillLimiter.ticks_since_check = 0
SkillLimiter.perks_leveled_up = {}

-- Mod events

---@param character IsoGameCharacter
---@param perk PerkFactory.Perk
---@param level Integer
---@param levelUp Boolean
local function add_to_table(character, perk, level, levelUp)
    -- If not levelUp, then we do not need to check whether or not we should cap the skill.
    -- This also prevents some infinite loops, since this function can cause a LevelPerk event to be fired.
    if not levelUp then
        return
    end

    table.insert(SkillLimiter.perks_leveled_up, {
        character = character,
        perk = perk,
        level = level
    })
end

local function check_table()
    if (SkillLimiter.ticks_since_check < 30) then
        SkillLimiter.ticks_since_check = SkillLimiter.ticks_since_check + 1
        return
    end

    SkillLimiter.ticks_since_check = 0

    for i, v in ipairs(SkillLimiter.perks_leveled_up) do
        SkillLimiter.limitSkill(v.character, v.perk, v.level)
    end
    SkillLimiter.perks_leveled_up = {}
end

local function check_table_10m()
    for i, v in ipairs(SkillLimiter.perks_leveled_up) do
        SkillLimiter.limitSkill(v.character, v.perk, v.level)
    end
    SkillLimiter.perks_leveled_up = {}
end

local function init_check()
    local character = getPlayer()

    if character then
        for j=0, Perks.getMaxIndex() - 1 do
            local perk = PerkFactory.getPerk(Perks.fromIndex(j))
            local level = character:getPerkLevel(perk)
            SkillLimiter.limitSkill(character, perk, level)
        end
    end
end

local function init()
    Events.OnTick.Remove(init)

    print(SkillLimiter.modName .. " " .. SkillLimiter.modVersion .. " initialized.")

    init_check()
end

Events.LevelPerk.Add(add_to_table)

local checkEveryTenMins = SandboxVars.SkillLimiter.EveryTenMins
if checkEveryTenMins then 
    Events.EveryTenMinutes.Add(check_table_10m)
else
    Events.OnTick.Add(check_table)
end

Events.OnTick.Add(init);
