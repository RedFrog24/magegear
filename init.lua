--[[ Mage Gear by RedFrog v2.3.5 (DoN EMU Adjusted) Started: March 29, 2025
    Styled: Custom colors, GUI tooltips, toggles and themes, animated summon
    Updated: Pets auto-equip from bags, order: Weapons > Belt > Mask > Armor > Jewelry, fixed secondary weapon bug
    Fixed: Distance check before casting, pet validation, casting/cursor issues, loop control, added nav delay, fixed hover colors
]]

local mq = require('mq')
local imgui = require('ImGui')
local Icons = require('mq.ICONS')
local Themes = require('theme_loader')
local ThemeData = require('themes')

local doRun = false
local doSummonPet = false
local openGUI = true
local GearTarget = 'Self'
local petPriWep = 0
local petSecWep = 0
local selectedPet = 0
local selectedBelt = 0
local selectedMask = 0
local selectedArmor = 0
local selectedJewelry = 0
local lastPriWep = -1
local lastSecWep = -1
local lastPet = -1
local lastBelt = -1
local lastMask = -1
local lastArmor = -1
local lastJewelry = -1
local doWeapons = true
local doBelt = false
local doMask = false
local doArmor = false
local doJewelry = false
local keepBags = false
local lastComboChange = {}
local currentTheme = "Grape"

-- Full Weapons Table
local petWeps = {
    { spell = "Summon Fireblade",               item = "Summoned: Fireblade",               level = 66, desc = "A blazing magical blade" },
    { spell = "Summon Staff of the North Wind", item = "Summoned: Staff of the North Wind", level = 67, desc = "A staff imbued with icy winds" },
    { spell = "Blade of the Kedge",             item = "Summoned: Blade of the Kedge",      level = 63, desc = "A sharp aquatic blade" },
    { spell = "Fist of Ixiblat",                item = "Summoned: Hand of Ixiblat",         level = 62, desc = "A fiery fist weapon" },
    { spell = "Blade of Walnan",                item = "Summoned: Blade of Walnan",         level = 61, desc = "A sturdy enchanted sword" },
    { spell = "Dagger of Symbols",              item = "Summoned: Dagger of Symbols",       level = 35, desc = "A rune-etched dagger" },
    { spell = "Staff of Symbols",               item = "Summoned: Staff of Symbols",        level = 33, desc = "A staff covered in runes" },
    { spell = "Sword of Runes",                 item = "Summoned: Sword of Runes",          level = 26, desc = "A sword with mystical runes" },
    { spell = "Staff of Runes",                 item = "Summoned: Staff of Runes",          level = 24, desc = "A rune-carved staff" },
    { spell = "Spear of Warding",               item = "Summoned: Spear of Warding",        level = 20, desc = "A protective spear" },
    { spell = "Staff of Warding",               item = "Summoned: Staff of Warding",        level = 14, desc = "A staff of defense" },
    { spell = "Summon Fang",                    item = "Summoned: Fang",                    level = 9,  desc = "A sharp summoned tooth" },
    { spell = "Staff of Tracing",               item = "Summoned: Staff of Tracing",        level = 8,  desc = "A basic magical staff" },
    { spell = "Summon Dagger",                  item = "Summoned: Dagger",                  level = 1,  desc = "A simple conjured dagger" },
}

-- Full Pet Spells Table
local petSpells = {
    { spell = "Call of the Arch Mage",      level = 70, desc = "Summons a powerful elemental servant" },
    { spell = "Greater Conjuration: Water", level = 66, desc = "Summons a strong water elemental" },
    { spell = "Greater Conjuration: Fire",  level = 65, desc = "Summons a strong fire elemental" },
    { spell = "Greater Conjuration: Air",   level = 64, desc = "Summons a strong air elemental" },
    { spell = "Greater Conjuration: Earth", level = 63, desc = "Summons a strong earth elemental" },
    { spell = "Servant of Marr",            level = 62, desc = "Summons a devoted servant of Marr" },
    { spell = "Conjuration: Water",         level = 54, desc = "Summons a water elemental" },
    { spell = "Conjuration: Fire",          level = 53, desc = "Summons a fire elemental" },
    { spell = "Conjuration: Air",           level = 52, desc = "Summons an air elemental" },
    { spell = "Conjuration: Earth",         level = 51, desc = "Summons an earth elemental" },
    { spell = "Lesser Conjuration: Water",  level = 44, desc = "Summons a lesser water elemental" },
    { spell = "Lesser Conjuration: Fire",   level = 43, desc = "Summons a lesser fire elemental" },
    { spell = "Lesser Conjuration: Air",    level = 42, desc = "Summons a lesser air elemental" },
    { spell = "Lesser Conjuration: Earth",  level = 41, desc = "Summons a lesser earth elemental" },
    { spell = "Greater Summoning: Water",   level = 34, desc = "Summons a water elemental ally" },
    { spell = "Greater Summoning: Fire",    level = 33, desc = "Summons a fire elemental ally" },
    { spell = "Greater Summoning: Air",     level = 32, desc = "Summons an air elemental ally" },
    { spell = "Greater Summoning: Earth",   level = 31, desc = "Summons an earth elemental ally" },
    { spell = "Summoning: Water",           level = 24, desc = "Summons a basic water elemental" },
    { spell = "Summoning: Fire",            level = 23, desc = "Summons a basic fire elemental" },
    { spell = "Summoning: Air",             level = 22, desc = "Summons a basic air elemental" },
    { spell = "Summoning: Earth",           level = 21, desc = "Summons a basic earth elemental" },
    { spell = "Lesser Summoning: Water",    level = 16, desc = "Summons a weak water elemental" },
    { spell = "Lesser Summoning: Fire",     level = 15, desc = "Summons a weak fire elemental" },
    { spell = "Lesser Summoning: Air",      level = 14, desc = "Summons a weak air elemental" },
    { spell = "Lesser Summoning: Earth",    level = 13, desc = "Summons a weak earth elemental" },
    { spell = "Minor Summoning: Water",     level = 8,  desc = "Summons a minor water elemental" },
    { spell = "Minor Summoning: Fire",      level = 7,  desc = "Summons a minor fire elemental" },
    { spell = "Minor Summoning: Air",       level = 6,  desc = "Summons a minor air elemental" },
    { spell = "Minor Summoning: Earth",     level = 5,  desc = "Summons a minor earth elemental" },
    { spell = "Elemental: Water",           level = 4,  desc = "Summons a tiny water elemental" },
    { spell = "Elemental: Fire",            level = 3,  desc = "Summons a tiny fire elemental" },
    { spell = "Elemental: Air",             level = 2,  desc = "Summons a tiny air elemental" },
    { spell = "Elemental: Earth",           level = 1,  desc = "Summons a tiny earth elemental" },
}

-- Full Belt Spells Table
local beltSpells = {
    { spell = "Crystal Belt",       item = "Summoned: Crystal Belt",       level = 67, desc = "A shimmering crystal belt" },
    { spell = "Girdle of Magi`Kot", item = "Summoned: Girdle of Magi`Kot", level = 64, desc = "A sturdy magical girdle" },
    { spell = "Belt of Magi`Kot",   item = "Summoned: Belt of Magi`Kot",   level = 61, desc = "A simple mage's belt" },
}

-- Full Mask Spells Table
local maskSpells = {
    { spell = "Muzzle of Mardu", item = "Summoned: Muzzle of Mardu", level = 56, desc = "A mystical muzzle mask" },
}

-- Full Armor Spells Table
local armorSpells = {
    { spell = "Summon Phantom Leather", bag = "Phantom Satchel", items = { "Phantom Leather Skullcap", "Phantom Leather Tunic", "Phantom Leather Sleeves", "Phantom Leather Bracer", "Phantom Leather Bracer", "Phantom Leather Gloves", "Phantom Leather Leggings", "Phantom Leather Boots" }, level = 56, desc = "Summons a bag of leather armor" },
    { spell = "Summon Phantom Chain",   bag = "Phantom Satchel", items = { "Phantom Chain Coif", "Phantom Chain Coat", "Phantom Chain Sleeves", "Phantom Chain Bracer", "Phantom Chain Bracer", "Phantom Chain Gloves", "Phantom Chain Greaves", "Phantom Chain Boots" },                       level = 61, desc = "Summons a bag of chain armor" },
    { spell = "Summon Phantom Plate",   bag = "Phantom Satchel", items = { "Phantom Plate Helm", "Phantom Breastplate", "Phantom Plate Vambraces", "Phantom Plate Bracers", "Phantom Plate Bracers", "Phantom Plate Gauntlets", "Phantom Plate Greaves", "Phantom Plate Boots" },               level = 65, desc = "Summons a bag of plate armor" },
}

-- Full Jewelry Spells Table
local jewelrySpells = {
    { spell = "Summon Jewelry Bag",      bag = "Phantom Satchel", items = { "Jedah's Platinum Choker", "Tavee's Runed Mantle", "Gallenite's Sapphire Bracelet", "Naki's Spiked Ring", "Jolum's Glowing Bauble", "Rallican's Steel Bracelet" },      level = 63, desc = "Summons a bag of assorted jewelry" },
    { spell = "Summon Pouch of Jerikor", bag = "Phantom Satchel", items = { "Calliav's Platinum Choker", "Calliav's Runed Mantle", "Calliav's Jeweled Bracelet", "Calliav's Spiked Ring", "Calliav's Glowing Bauble", "Calliav's Steel Bracelet" }, level = 68, desc = "Summons a bag of fine jewelry" },
}

local function GetThemeNames()
    local names = {}
    for _, theme in ipairs(ThemeData.Theme) do
        table.insert(names, theme.Name)
    end
    return names
end
local themeNames = GetThemeNames()

local function MGear(msg)
    mq.cmdf('/echo \aw[\agMageGear\aw] %s', msg)
end

local function setBestDefault(table)
    local bestIdx = 0
    local highestLevel = 0
    for i, entry in ipairs(table) do
        local bookCheck = mq.TLO.Me.Book(entry.spell)()
        if bookCheck and bookCheck > 0 and entry.level > highestLevel then
            highestLevel = entry.level
            bestIdx = i - 1
        end
    end
    return bestIdx
end

local function loadSettings()
    local savedTheme = mq.TLO.Ini("magegear.ini", "Settings", "LastTheme", "Grape")()
    currentTheme = savedTheme
end

local function saveSettings()
    mq.cmdf('/ini "magegear.ini" "Settings" "LastTheme" "%s"', currentTheme)
end

local function init()
    if mq.TLO.Me.Class() ~= 'Magician' then
        MGear('\arError\ax: You are not a Magician! Program ending!')
        return false
    end
    petPriWep = setBestDefault(petWeps)
    petSecWep = petPriWep
    selectedPet = setBestDefault(petSpells)
    selectedBelt = setBestDefault(beltSpells)
    selectedMask = setBestDefault(maskSpells)
    selectedArmor = setBestDefault(armorSpells)
    selectedJewelry = setBestDefault(jewelrySpells)
    lastPriWep = petPriWep
    lastSecWep = petSecWep
    lastPet = selectedPet
    lastBelt = selectedBelt
    lastMask = selectedMask
    lastArmor = selectedArmor
    lastJewelry = selectedJewelry
    loadSettings()
    MGear('\apGreetings Mage! What would you like to Summon?')
    return true
end

openGUI = init()

local function drawCombo(label, current, items, isPet)
    local comboValue = current
    imgui.PushID(label)
    if not items[comboValue + 1] then
        MGear('\arError: Invalid index ' .. comboValue .. ' for ' .. label)
        comboValue = 0
    end
    local displayText = items[comboValue + 1].spell .. (isPet and (" (Level " .. items[comboValue + 1].level .. ")") or "")
    if imgui.BeginCombo(label, displayText) then
        for i, item in ipairs(items) do
            local bookCheck = mq.TLO.Me.Book(item.spell)()
            local inBook = bookCheck and bookCheck > 0
            local color = inBook and ImVec4(0, 1, 0, 1) or ImVec4(0.5, 0.5, 0.5, 1)
            imgui.PushStyleColor(ImGuiCol.Text, color)
            local itemText = item.spell .. (isPet and (" (Level " .. item.level .. ")") or "")
            local isSelected = (comboValue == i - 1)
            if imgui.Selectable(itemText, isSelected) and inBook then
                local lastChange = lastComboChange[label] or -1
                if comboValue ~= i - 1 and os.clock() - lastChange > 0.5 then
                    comboValue = i - 1
                    lastComboChange[label] = os.clock()
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text(item.spell .. " (Level " .. item.level .. ")")
                imgui.Text(item.desc)
                imgui.EndTooltip()
            end
            if isSelected then
                imgui.SetItemDefaultFocus()
            end
            imgui.PopStyleColor()
        end
        imgui.EndCombo()
    end
    imgui.PopID()
    return comboValue
end

local function drawToggle(label, value)
    imgui.Text(label .. ":")
    imgui.SameLine()
    imgui.PushID(label)
    if value then
        imgui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON)
    else
        imgui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF)
    end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(label .. ": " .. (value and "Enabled" or "Disabled"))
        imgui.EndTooltip()
        if imgui.IsMouseClicked(0) then
            value = not value
        end
    end
    imgui.PopID()
    return value
end

local function getHoverColor()
    if currentTheme == "Water Mage" then
        return ImVec4(0.3, 0.6, 0.9, 1)
    elseif currentTheme == "Fire Mage" then
        return ImVec4(0.9, 0.5, 0.3, 1)
    else
        return ImVec4(0.3, 0.8, 0.3, 1)
    end
end

local function mageGear(open)
    local main_viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(main_viewport.WorkPos.x + 600, main_viewport.WorkPos.y + 20, ImGuiCond.FirstUseEver)
    imgui.SetNextWindowSize(350, 400, ImGuiCond.FirstUseEver)

    local ColorCount, StyleCount = Themes.StartTheme(currentTheme, ThemeData)
    local show = false
    open, show = imgui.Begin("Mage Gear (DoN EMU) v2.3.5", open)

    if not open then
        openGUI = false
        imgui.End()
        Themes.EndTheme(ColorCount, StyleCount)
        return false
    end

    if not show then
        imgui.End()
        Themes.EndTheme(ColorCount, StyleCount)
        return open
    end

    imgui.Text("Theme:")
    imgui.SameLine()
    imgui.SetNextItemWidth(150)
    if imgui.BeginCombo("##Theme", currentTheme) then
        for _, themeName in ipairs(themeNames) do
            local isSelected = (themeName == currentTheme)
            if imgui.Selectable(themeName, isSelected) then
                currentTheme = themeName
                saveSettings()
            end
            if isSelected then imgui.SetItemDefaultFocus() end
        end
        imgui.EndCombo()
    end

    imgui.Separator()

    imgui.Text("Summon:")
    imgui.SameLine()
    local malachiteCount = mq.TLO.FindItemCount("Malachite")() or 0
    local color
    if malachiteCount > 15 then
        color = ImVec4(0, 1, 0, 1)
    elseif malachiteCount >= 6 then
        color = ImVec4(1, 1, 0, 1)
    else
        color = ImVec4(1, 0, 0, 1)
    end
    imgui.SetCursorPosX(imgui.GetWindowWidth() - imgui.CalcTextSize("Malachites: " .. malachiteCount) - 10)
    imgui.PushStyleColor(ImGuiCol.Text, color)
    imgui.Text("Malachites: " .. malachiteCount)
    imgui.PopStyleColor()

    local newSelectedPet = drawCombo("", selectedPet, petSpells, true)
    if newSelectedPet ~= selectedPet then
        selectedPet = newSelectedPet
        MGear('\aySelected: ' .. petSpells[selectedPet + 1].spell .. ' (Index ' .. selectedPet .. ')')
    end
    imgui.SameLine()
    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 0.8 + math.sin(os.clock() * 2) * 0.2))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button("Summon") then
        doSummonPet = true
    end
    imgui.PopStyleColor(2)

    imgui.Separator()

    imgui.Text("Summon Options:")
    doWeapons = drawToggle("Weapons", doWeapons)
    imgui.SameLine()
    doBelt = drawToggle("Belt", doBelt)
    imgui.SameLine()
    doMask = drawToggle("Mask", doMask)
    doArmor = drawToggle("Armor", doArmor)
    imgui.SameLine()
    doJewelry = drawToggle("Jewelry", doJewelry)
    imgui.SameLine()
    keepBags = drawToggle("Keep Bags", keepBags)
    imgui.Separator()

    if doWeapons then
        local newPetPriWep = drawCombo("Primary", petPriWep, petWeps, false)
        if newPetPriWep ~= petPriWep then
            petPriWep = newPetPriWep
            MGear('\aySelected Primary: ' .. petWeps[petPriWep + 1].spell .. ' (Index ' .. petPriWep .. ')')
        end
        local newPetSecWep = drawCombo("Secondary", petSecWep, petWeps, false)
        if newPetSecWep ~= petSecWep then
            petSecWep = newPetSecWep
            MGear('\aySelected Secondary: ' .. petWeps[petSecWep + 1].spell .. ' (Index ' .. petSecWep .. ')')
        end
    end

    if doBelt then
        local newSelectedBelt = drawCombo("Belt", selectedBelt, beltSpells, false)
        if newSelectedBelt ~= selectedBelt then
            selectedBelt = newSelectedBelt
            MGear('\aySelected Belt: ' .. beltSpells[selectedBelt + 1].spell .. ' (Index ' .. selectedBelt .. ')')
        end
    end

    if doMask then
        local newSelectedMask = drawCombo("Mask", selectedMask, maskSpells, false)
        if newSelectedMask ~= selectedMask then
            selectedMask = newSelectedMask
            MGear('\aySelected Mask: ' .. maskSpells[selectedMask + 1].spell .. ' (Index ' .. selectedMask .. ')')
        end
    end

    if doArmor then
        local newSelectedArmor = drawCombo("Armor", selectedArmor, armorSpells, false)
        if newSelectedArmor ~= selectedArmor then
            selectedArmor = newSelectedArmor
            MGear('\aySelected Armor: ' .. armorSpells[selectedArmor + 1].spell .. ' (Index ' .. selectedArmor .. ')')
        end
    end

    if doJewelry then
        local newSelectedJewelry = drawCombo("Jewelry", selectedJewelry, jewelrySpells, false)
        if newSelectedJewelry ~= selectedJewelry then
            selectedJewelry = newSelectedJewelry
            MGear('\aySelected Jewelry: ' .. jewelrySpells[selectedJewelry + 1].spell .. ' (Index ' .. selectedJewelry .. ')')
        end
    end

    -- Self Button
    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1)) -- Green base
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor()) -- Theme-based hover
    if imgui.Button('Self') then
        GearTarget = 'Self'
        doRun = true
        MGear('\aySelf button hovered color applied')
    end
    imgui.PopStyleColor(2)
    imgui.SameLine()

    -- Target Button
    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button('Target') then
        if mq.TLO.Target.ID() > 0 then
            GearTarget = 'Target'
            doRun = true
            MGear('\ayTarget button hovered color applied')
        else
            MGear('\arError\ax: No target')
        end
    end
    imgui.PopStyleColor(2)
    imgui.SameLine()

    -- Group Button
    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button('Group') then
        if mq.TLO.Group() then
            GearTarget = 'Group'
            doRun = true
            MGear('\ayGroup button hovered color applied')
        else
            MGear('\arError\ax: Not in a group')
        end
    end
    imgui.PopStyleColor(2)

    lastPriWep = petPriWep
    lastSecWep = petSecWep
    lastPet = selectedPet
    lastBelt = selectedBelt
    lastMask = selectedMask
    lastArmor = selectedArmor
    lastJewelry = selectedJewelry

    imgui.End()
    Themes.EndTheme(ColorCount, StyleCount)
    return open
end

ImGui.Register('Mage Gear', function()
    openGUI = mageGear(openGUI)
end)

local function getLastGem()
    local totalGems = mq.TLO.Me.NumGems() or 8
    for i = 1, totalGems do
        if not mq.TLO.Me.Gem(i)() then
            return i
        end
    end
    return totalGems
end

local function checkFreeMainSlot()
    local free = false
    local slotStatus = {}
    for i = 23, 32 do
        local slotItem = mq.TLO.Me.Inventory(i)()
        local itemName = "empty"
        if type(slotItem) == "string" then
            itemName = slotItem
        elseif slotItem and slotItem.Name then
            itemName = slotItem.Name() or "unknown"
        end
        table.insert(slotStatus, (i - 22) .. "=" .. itemName)
        if not slotItem then
            free = true
        end
    end
    MGear('\aySlots: ' .. table.concat(slotStatus, ", "))
    MGear('\ayFree main slot available: ' .. (free and "Yes" or "No"))
    return free
end

local function memorizeSpell(spell)
    if spell == nil then return false end
    local flag = false
    local lastGem = getLastGem()
    local curGem = mq.TLO.Me.Gem(spell)() or 0

    if curGem > 0 then
        flag = true
    elseif curGem == 0 then
        local command = string.format("/memspell %s \"%s\"", lastGem, spell)
        mq.cmdf("%s", command)
        mq.delay(20)
        MGear('\amMemorizing \ax' .. spell .. ' in gem ' .. lastGem)
        mq.delay(6000, function() return mq.TLO.Me.Gem(lastGem).Name() == spell end)
        if ((mq.TLO.Me.Gem(spell)() or 0) == 0) then
            MGear('\arError\ax: Failed to memorize ' .. spell .. ' in gem Slot: ' .. lastGem)
            flag = false
        else
            MGear('\agMemorized \ax' .. spell)
            flag = true
        end
    else
        flag = true
    end
    return flag
end

local function summonPet(pet)
    if not mq.TLO.Me.Book(pet.spell)() then
        MGear('\arError\ax: ' .. pet.spell .. ' not in your spellbook')
        return false
    end

    local spellMana = mq.TLO.Spell(pet.spell).Mana() or 0
    if mq.TLO.Me.CurrentMana() < spellMana then
        MGear('\arError\ax: Not enough mana for ' .. pet.spell)
        return false
    end

    if not memorizeSpell(pet.spell) then return false end

    MGear('\amCasting \ax' .. pet.spell)
    local timeout = os.time() + 10
    while not mq.TLO.Me.SpellReady(pet.spell)() and os.time() < timeout do
        mq.delay(500)
    end
    if not mq.TLO.Me.SpellReady(pet.spell)() then
        MGear('\arError\ax: Gem not ready for ' .. pet.spell)
        return false
    end

    mq.cmdf('/cast "%s"', pet.spell)
    mq.delay(3000)

    timeout = os.time() + 15
    local castAttempts = 0
    while not mq.TLO.Me.Casting() and os.time() < timeout do
        if mq.TLO.Me.SpellReady(pet.spell)() and castAttempts < 3 then
            castAttempts = castAttempts + 1
            MGear('\ayRetrying cast attempt ' .. castAttempts .. ' for ' .. pet.spell)
            mq.cmdf('/cast "%s"', pet.spell)
        end
        mq.delay(500)
    end

    if not mq.TLO.Me.Casting() then
        MGear('\arError\ax: Casting ' .. pet.spell .. ' failed after ' .. castAttempts .. ' attempts')
        return false
    end

    timeout = os.time() + 15
    while mq.TLO.Me.Casting() and os.time() < timeout do mq.delay(500) end

    timeout = os.time() + 10
    while not mq.TLO.Me.Pet.ID() and os.time() < timeout do mq.delay(500) end
    if not mq.TLO.Me.Pet.ID() then
        MGear('\arError\ax: No pet summoned after casting ' .. pet.spell)
        return false
    end

    MGear('\agPet summoned: \ax' .. pet.spell)
    return true
end

local function summonItem(spellData)
    if not mq.TLO.Me.Book(spellData.spell)() then
        MGear('\arError\ax: ' .. spellData.spell .. ' not in your spellbook')
        return false
    end

    local spellMana = mq.TLO.Spell(spellData.spell).Mana() or 0
    if mq.TLO.Me.CurrentMana() < spellMana then
        MGear('\arError\ax: Not enough mana for ' .. spellData.spell)
        return false
    end

    if spellData.bag and not checkFreeMainSlot() then
        MGear('\ayFree a main inventory slot to use ' .. spellData.spell)
        return false
    end

    if not memorizeSpell(spellData.spell) then return false end

    MGear('\amCasting \ax' .. spellData.spell)
    local timeout = os.time() + 10
    while not mq.TLO.Me.SpellReady(spellData.spell)() and os.time() < timeout do
        mq.delay(500)
    end
    if not mq.TLO.Me.SpellReady(spellData.spell)() then
        MGear('\arError\ax: Gem not ready for ' .. spellData.spell)
        return false
    end

    mq.cmdf('/cast "%s"', spellData.spell)
    mq.delay(3000)

    timeout = os.time() + 15
    local castAttempts = 0
    while not mq.TLO.Me.Casting() and os.time() < timeout do
        if mq.TLO.Me.SpellReady(spellData.spell)() and castAttempts < 3 then
            castAttempts = castAttempts + 1
            MGear('\ayRetrying cast attempt ' .. castAttempts .. ' for ' .. spellData.spell)
            mq.cmdf('/cast "%s"', spellData.spell)
        end
        mq.delay(500)
    end

    if not mq.TLO.Me.Casting() then
        MGear('\arError\ax: Casting ' .. spellData.spell .. ' failed after ' .. castAttempts .. ' attempts')
        return false
    end

    timeout = os.time() + 15
    while mq.TLO.Me.Casting() and os.time() < timeout do mq.delay(500) end

    timeout = os.time() + 10
    local cursorAttempts = 0
    while not mq.TLO.Cursor.ID() and os.time() < timeout do
        cursorAttempts = cursorAttempts + 1
        MGear('\ayWaiting for cursor, attempt ' .. cursorAttempts)
        mq.delay(1000)
    end
    if not mq.TLO.Cursor.ID() then
        MGear('\arError\ax: No item on cursor after casting ' .. spellData.spell)
        return false
    end

    MGear('\agSummoned: \ax' .. (spellData.item or spellData.bag or spellData.spell))
    return true
end

local function handCursorToPet()
    while mq.TLO.Cursor.ID() do
        mq.cmd('/click left target')
        mq.delay(700)
    end

    if mq.TLO.Window("GiveWnd").Open() then
        mq.cmd('/notify GiveWnd GVW_Give_Button leftmouseup')
        mq.delay(500)
        local timeout = os.time() + 5
        while mq.TLO.Window("GiveWnd").Open() and os.time() < timeout do
            mq.delay(100)
        end
        if mq.TLO.Window("GiveWnd").Open() then
            MGear('\ayWarning\ax: Give window still open, closing manually')
            mq.cmd('/notify GiveWnd GVW_Cancel_Button leftmouseup')
        end
    end
end

local function moveToPet(targetPet)
    if not targetPet then
        MGear('\arError\ax: No pet name provided')
        return false
    end
    mq.cmdf('/tar %s', targetPet)
    mq.delay(500)
    if not mq.TLO.Target.ID() then
        MGear('\arError\ax: Could not target ' .. targetPet)
        return false
    end
    local distance = mq.TLO.Target.Distance() or 999
    MGear('\ayDistance to ' .. targetPet .. ': ' .. distance)
    if distance <= 20 then
        return true
    else
        MGear('\ayNavigating to \ax' .. targetPet)
        mq.cmd('/nav target')
        local timeout = os.time() + 15
        while mq.TLO.Navigation.Active() and os.time() < timeout do
            mq.delay(500)
            distance = mq.TLO.Target.Distance() or 999
            MGear('\ayCurrent distance: ' .. distance)
            if distance <= 20 then break end
        end
        if distance <= 20 then
            MGear('\ayReached ' .. targetPet .. ', pausing...')
            mq.delay(1000)
            return true
        else
            MGear('\arError\ax: Too far from ' .. targetPet .. ' (Distance: ' .. distance .. ')')
            return false
        end
    end
end

local needMove = false

local function giveItemToPet(targetPet)
    if not targetPet then
        MGear('\arError\ax: Invalid pet name')
        return false
    end

    if not moveToPet(targetPet) then
        needMove = true
        return false
    end

    local success = true

    if doWeapons and success then
        success = summonItem(petWeps[petPriWep + 1])
        if success then handCursorToPet() end
        if success then success = summonItem(petWeps[petSecWep + 1]) end
        if success then handCursorToPet() end
    end

    if doBelt and success then
        success = summonItem(beltSpells[selectedBelt + 1])
        if success then handCursorToPet() end
    end

    if doMask and success then
        success = summonItem(maskSpells[selectedMask + 1])
        if success then handCursorToPet() end
    end

    if doArmor and success then
        success = summonItem(armorSpells[selectedArmor + 1])
        if success then handCursorToPet() end
    end

    if doJewelry and success then
        success = summonItem(jewelrySpells[selectedJewelry + 1])
        if success then handCursorToPet() end
    end

    needMove = false
    return success
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then return true end
    end
    return false
end

local tradePetName = ''

while openGUI do
    mq.delay(500)

    while doSummonPet do
        local petSpell = petSpells[selectedPet + 1]
        summonPet(petSpell)
        doSummonPet = false
    end

    while doRun do
        local itemsToSummon = {}
        if doWeapons then
            itemsToSummon[#itemsToSummon + 1] = 'Primary=' .. petWeps[petPriWep + 1].spell
            itemsToSummon[#itemsToSummon + 1] = 'Secondary=' .. petWeps[petSecWep + 1].spell
        end
        if doBelt then
            itemsToSummon[#itemsToSummon + 1] = 'Belt=' .. beltSpells[selectedBelt + 1].spell
        end
        if doMask then
            itemsToSummon[#itemsToSummon + 1] = 'Mask=' .. maskSpells[selectedMask + 1].spell
        end
        if doArmor then
            itemsToSummon[#itemsToSummon + 1] = 'Armor=' .. armorSpells[selectedArmor + 1].spell
        end
        if doJewelry then
            itemsToSummon[#itemsToSummon + 1] = 'Jewelry=' .. jewelrySpells[selectedJewelry + 1].spell
        end
        MGear('\amPreparing to summon: \ax' .. table.concat(itemsToSummon, ', '))

        local success = false
        if GearTarget == 'Self' then
            if not mq.TLO.Me.Pet.ID() then
                MGear('\arError\ax: You do not have a pet')
            else
                tradePetName = mq.TLO.Me.Pet.CleanName()
                success = giveItemToPet(tradePetName)
                if success then
                    MGear('\agSummoning complete')
                end
            end
        elseif GearTarget == 'Target' then
            if not mq.TLO.Target.ID() then
                MGear('\arError\ax: Invalid target')
            else
                tradePetName = mq.TLO.Target.Pet.CleanName()
                if not tradePetName then
                    MGear('\arError\ax: Target has no pet')
                else
                    success = giveItemToPet(tradePetName)
                    if success then
                        MGear('\agSummoning complete')
                    end
                end
            end
        elseif GearTarget == 'Group' then
            local groupSize = mq.TLO.Group.Members()
            if groupSize == 0 then
                MGear('\arError\ax: Not in a group')
            else
                success = true
                for i = 0, groupSize do
                    local member = mq.TLO.Group.Member(i)
                    if member() and member.Pet.ID() > 0 then
                        tradePetName = member.Pet.CleanName()
                        success = success and giveItemToPet(tradePetName)
                    elseif member() then
                        MGear('\aySkipping \ax' .. member.Name() .. ' - no pet')
                    end
                end
                if success then
                    MGear('\agGroup summoning complete')
                end
            end
        end

        if needMove then
            MGear('\ayWaiting to reach pet, retrying...')
        else
            doRun = false
        end
    end
end
saveSettings()