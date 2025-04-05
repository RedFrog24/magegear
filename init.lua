--[[ Mage Gear by RedFrog v2.3.17 (DoN EMU Adjusted) Started: March 29, 2025
    Styled: Custom colors, GUI tooltips, toggles and themes, animated summon
    Updated: Pets auto-equip from bags, order: Weapons > Belt > Mask > Armor > Jewelry, fixed secondary weapon bug
    Fixed: Distance check, pet validation, casting/cursor issues, loop control, nav delay, hover colors, "Select a spell" crash, RGMercs crash, typo in getHoverColor, syntax error in Jewelry block
    Changed: Added pet weapons in Create Item > Misc, improved group summoning, excluded wizard familiars, added RGMercs pause/unpause (simplified), fixed spellbook stuck issue, removed weapon debug spam and hover color output
]]

local mq = require('mq')
local imgui = require('ImGui')
local Icons = require('mq.ICONS')
local Themes = require('theme_loader')
local ThemeData = require('themes')
local Utils = require('mq.Utils')

local doRun = false
local doSummonPet = false
local openGUI = true
local GearTarget = 'Self'
local lastPriWep = -1
local lastFocus = -1
local lastPlayerItem = -1
local lastSecWep = -1
local lastPet = -1
local lastBelt = -1
local lastMask = -1
local lastArmor = -1
local lastJewelry = -1
local lastComboChange = {}
local tradePetName = ''
local MyName = mq.TLO.Me.CleanName()
local settings = {}
local settingsFile = string.format("%s/mage_gear_%s.lua", mq.configDir, MyName)

local defaults = {
    currentTheme = "Grape",
    petPriWep = 1,
    petSecWep = 1,
    selectedPet = 1,
    selectedBelt = 1,
    selectedMask = 1,
    selectedArmor = 1,
    selectedJewelry = 1,
    selectedFocus = 1,
    selectedPlayerItem = 1,
    doFocus = false,
    doPC = false,
    doWeapons = true,
    doBelt = false,
    doMask = false,
    doArmor = false,
    doJewelry = false,
    keepBags = false,
}

-- Full Weapons Table
local petWeps = {}

-- Full Pet Spells Table
local petSpells = {}

-- Full Belt Spells Table
local beltSpells = {}

-- Full Mask Spells Table
local maskSpells = {}

-- Full Armor Spells Table
local armorSpells = {}

local focusSpells = {}

local playerItems = {}

-- Full Jewelry Spells Table
local jewelrySpells = {}

-- Blacklist for wizard familiars
local familiarSpells = {
    "Familiar",
    "Greater Familiar",
    "Improved Familiar",
    "Lesser Familiar",
    -- Add more as needed based on your EMU
}

local function getSpells()
    petSpells = {}
    beltSpells = {}
    maskSpells = {}
    armorSpells = {}
    jewelrySpells = {}
    focusSpells = {}
    playerItems = {}
    petWeps = {}
    for i = 1, 1000 do
        local bookSpell = mq.TLO.Me.Book(i)
        if bookSpell() then
            local spellName = bookSpell.Name()
            local spellCat = bookSpell.Category() or 'None'
            local spellSubCat = bookSpell.Subcategory() or 'None'
            local spellLvl = bookSpell.Level() or 0
            local spellDesc = bookSpell.Description() or 'None'
            local lowerName = spellName:lower()

            if spellCat == 'Pet' then
                if spellSubCat:find('Sum:') or lowerName:find('monster summoning') or lowerName:find('zomm') then
                    table.insert(petSpells, { spell = spellName, level = spellLvl, desc = spellDesc })
                end
                goto next_spell
            end

            if spellCat == "Create Item" then
                if spellSubCat == "Misc" then
                    if lowerName:find('belt') or lowerName:find('girdle') then
                        table.insert(beltSpells, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                    elseif lowerName:find('mask') or lowerName:find('muzzle') then
                        table.insert(maskSpells, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                    elseif lowerName:find('blade') or lowerName:find('staff') or lowerName:find('dagger') or 
                           lowerName:find('spear') or lowerName:find('fist') or lowerName:find('sword') or 
                           lowerName:find('walnan') or lowerName:find('ixiblat') then
                        table.insert(petWeps, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                    end
                elseif spellSubCat == "Summon Armor" then
                    table.insert(armorSpells, { spell = spellName, bag = "Phantom Satchel", items = {}, level = spellLvl, desc = spellDesc })
                elseif spellSubCat == "Summon Weapon" then
                    if lowerName:find('quiver') or lowerName:find('pouch') or lowerName:find('bandoleer') or lowerName:find('arrow') then
                        table.insert(playerItems, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                    else
                        table.insert(petWeps, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                    end
                elseif spellSubCat == "Summon Focus" then
                    table.insert(focusSpells, { spell = spellName, item = spellName, level = spellLvl, desc = spellDesc })
                elseif lowerName:find("jewelry bag") or lowerName:find("pouch of jerikor") then
                    table.insert(jewelrySpells, { spell = spellName, item = spellName, bag = "Phantom Satchel", level = spellLvl, desc = spellDesc })
                end
            end
        end
        ::next_spell::
    end
    table.sort(petSpells, function(a, b) return a.level > b.level end)
    table.sort(beltSpells, function(a, b) return a.level > b.level end)
    table.sort(maskSpells, function(a, b) return a.level > b.level end)
    table.sort(armorSpells, function(a, b) return a.level > b.level end)
    table.sort(petWeps, function(a, b) return a.level > b.level end)
    table.sort(jewelrySpells, function(a, b) return a.level > b.level end)
    table.sort(focusSpells, function(a, b) return a.level > b.level end)
    table.sort(playerItems, function(a, b) return a.level > b.level end)

    MGear(string.format('\aySpell counts - Pets: %d, Weapons: %d, Belts: %d, Masks: %d, Armor: %d, Jewelry: %d, Focus: %d, Player: %d',
        #petSpells, #petWeps, #beltSpells, #maskSpells, #armorSpells, #jewelrySpells, #focusSpells, #playerItems))
end

local function GetThemeNames()
    local names = {}
    for _, theme in ipairs(ThemeData.Theme) do
        table.insert(names, theme.Name)
    end
    return names
end
local themeNames = GetThemeNames()

function MGear(msg)
    mq.cmdf('/echo \aw[\agMageGear\aw] %s', msg)
end

local function setBestDefault(table)
    local bestIdx = 1
    local highestLevel = 0
    for i, entry in ipairs(table) do
        local bookCheck = mq.TLO.Me.Book(entry.spell)()
        if bookCheck and bookCheck > 0 and entry.level > highestLevel then
            highestLevel = entry.level
            bestIdx = i
        end
    end
    return bestIdx
end

local function loadSettings()
    if Utils.File.Exists(settingsFile) then
        settings = dofile(settingsFile)
    else
        settings = defaults
        mq.pickle(settingsFile, settings)
    end
    for k, v in pairs(defaults) do
        if settings[k] == nil then
            settings[k] = v
        end
    end
end

local function saveSettings()
    mq.pickle(settingsFile, settings)
end

local function EventHandler(line, who, what)
    if who == nil then return end
    if what ~= nil then
        mq.cmdf("/multiline ; /target %s; /tell %s Summoning %s", who, who, what)
        mq.delay(500)
        local targetPet = mq.TLO.Target.Pet.ID() or 0
        if targetPet == 0 then
            MGear('\arError\ax: Target has No pet summoned')
            return
        end
        if what == 'all' then
            settings.doWeapons = true
            settings.doBelt = true
            settings.doMask = true
            settings.doArmor = true
            settings.doJewelry = true
            settings.doFocus = true
            settings.doPlayer = false
        elseif what == "weapons" then
            settings.doWeapons = true
            settings.doBelt = false
            settings.doMask = false
            settings.doArmor = false
            settings.doJewelry = false
            settings.doFocus = false
            settings.doPlayer = false
        elseif what == "belt" then
            settings.doWeapons = false
            settings.doBelt = true
            settings.doMask = false
            settings.doArmor = false
            settings.doJewelry = false
            settings.doFocus = false
            settings.doPlayer = false
        elseif what == "mask" then
            settings.doWeapons = false
            settings.doBelt = false
            settings.doMask = true
            settings.doArmor = false
            settings.doJewelry = false
            settings.doFocus = false
            settings.doPlayer = false
        elseif what == "armor" then
            settings.doArmor = true
            settings.doWeapons = false
            settings.doBelt = false
            settings.doMask = false
            settings.doJewelry = false
            settings.doFocus = false
            settings.doPlayer = false
        elseif what == "jewelry" then
            settings.doWeapons = false
            settings.doBelt = false
            settings.doMask = false
            settings.doArmor = false
            settings.doJewelry = true
            settings.doFocus = false
            settings.doPlayer = false
        elseif what == "focus" then
            settings.doWeapons = false
            settings.doBelt = false
            settings.doMask = false
            settings.doArmor = false
            settings.doJewelry = false
            settings.doPlayer = false
            settings.doFocus = true
        elseif what == "player" then
            settings.doWeapons = false
            settings.doBelt = false
            settings.doMask = false
            settings.doArmor = false
            settings.doJewelry = false
            settings.doFocus = false
            settings.doPlayer = true
        else
            MGear('\arError\ax: Invalid option. Use weapons, belt, mask, armor, or jewelry.')
            return
        end

        if mq.TLO.Target.ID() > 0 then
            doRun = true
        else
            MGear('\arError\ax: No target')
        end
    else
        local reply = string.format("/tell %s Summon Toys Key words [weapons, belt, mask, armor, jewelry] or [all]", who)
        mq.cmdf(reply)
    end
end

local function ListItems(line, who)
    if not who then return end

    local category = {}
    local catName = ''
    local args = {}
    local subLine = ''
    if line:find("weapons") then
        catName = 'weapons'
        category = petWeps
        subLine = line:sub(line:find("weapons") + 9)
    elseif line:find("belt") then
        catName = 'belt'
        category = beltSpells
        subLine = line:sub(line:find("belt") + 5)
    elseif line:find("mask") then
        catName = 'mask'
        category = maskSpells
        subLine = line:sub(line:find("mask") + 5)
    elseif line:find("armor") then
        catName = 'armor'
        category = armorSpells
        subLine = line:sub(line:find("armor") + 6)
    elseif line:find("jewelry") then
        catName = 'jewelry'
        category = jewelrySpells
        subLine = line:sub(line:find("jewelry") + 8)
    elseif line:find('focus') then
        catName = 'focus'
        category = focusSpells
        subLine = line:sub(line:find("focus") + 6)
    elseif line:find('player') then
        catName = 'player'
        category = playerItems
        subLine = line:sub(line:find("player") + 7)
    else
        MGear('\arError\ax: Invalid option. Use weapons, belt, mask, armor, focus, player, or jewelry.')
        return
    end
    if not category or #category == 0 then
        MGear('\arError\ax: No items found in this category')
        return
    end
    args = Utils.String.Split(subLine, ",")
    local itemList = {}
    for _, item in ipairs(args) do
        local itemName = item:match("%s*(.-)%s*$")
        for index, spell in ipairs(category) do
            if spell.spell:lower():find(itemName:lower()) then
                table.insert(itemList, string.format("[%s]=%s", index, spell.spell))
            end
        end
    end

    if #itemList == 0 then
        MGear('\arError\ax: No items found matching your search')
        return
    end

    local itemListStr = table.concat(itemList, ", ")
    local itemCount = #itemList
    local itemListMsg = string.format("/tell %s %s %s", who, catName, itemListStr)
    mq.cmdf(itemListMsg)
    mq.delay(1000)
    local reply = string.format("/tell %s Send me a tell %s [#][#,#] where # is the item number from the list.", who, catName)
    mq.cmdf(reply)
end

local function properCase(str)
    return str:gsub("^%l", string.upper)
end

local function setCategories(cat)
    if cat == 'all' then
        settings.doWeapons = true
        settings.doBelt = true
        settings.doMask = true
        settings.doArmor = true
        settings.doJewelry = true
        settings.doFocus = true
        settings.doPlayer = false
    elseif cat == 'none' then
        settings.doWeapons = false
        settings.doBelt = false
        settings.doMask = false
        settings.doArmor = false
        settings.doJewelry = false
        settings.doFocus = false
        settings.doPlayer = false
    else
        settings.doWeapons = false
        settings.doBelt = false
        settings.doMask = false
        settings.doArmor = false
        settings.doJewelry = false
        settings.doFocus = false
        settings.doPlayer = false
        settings['do' .. properCase(cat)] = true
    end
end

local function ItemHandler(line, who, cat)
    if who == nil then return end
    local what = line:sub(line:find(cat) + #cat + 1)
    mq.cmdf("/multiline ; /target %s; /tell %s Summoning %s", who, who, cat)
    mq.delay(500)
    local targetPet = mq.TLO.Target.Pet.ID() or 0
    if targetPet == 0 and cat ~= 'player' and cat ~= 'focus' then
        MGear('\arError\ax: Target has No pet summoned')
        return
    end
    local indexes = {}
    indexes = Utils.String.Split(what, ",")

    for k, v in pairs(indexes) do
        if v:find("'") then
            indexes[k] = v:gsub("'", "")
        end
    end
    if cat == 'weapons' then
        settings.petPriWep = tonumber(indexes[1]) or lastPriWep
        settings.petSecWep = tonumber(indexes[2]) or 0
        settings.doWeapons = true
        setCategories(cat)
    elseif cat == 'belt' then
        settings.selectedBelt = tonumber(indexes[1]) or lastBelt
        settings.doBelt = true
        setCategories(cat)
    elseif cat == 'mask' then
        settings.selectedMask = tonumber(indexes[1]) or lastMask
        settings.doMask = true
        setCategories(cat)
    elseif cat == 'armor' then
        settings.selectedArmor = tonumber(indexes[1]) or lastArmor
        settings.doArmor = true
        setCategories(cat)
    elseif cat == 'jewelry' then
        settings.selectedJewelry = tonumber(indexes[1]) or lastJewelry
        settings.doJewelry = true
        setCategories(cat)
    elseif cat == 'focus' then
        settings.selectedFocus = tonumber(indexes[1]) or lastFocus
        settings.doFocus = true
        setCategories(cat)
    elseif cat == 'player' then
        settings.selectedPlayerItem = tonumber(indexes[1]) or lastPlayerItem
        settings.doPlayer = true
        setCategories(cat)
    else
        MGear('\arError\ax: Invalid option. Use weapons, belt, mask, armor, focus, player, or jewelry.')
        return
    end

    if mq.TLO.Target.ID() > 0 then
        GearTarget = settings.doFocus or settings.doPlayer and 'Player' or 'Target'
        doRun = true
    else
        MGear('\arError\ax: No target')
    end
end

local function hailed(line, who)
    if not who then return end
    local reply = string.format("/tell %s Send me a tell for toys /tell %s toys 'type' : or /tell %s list toys for a list of categories", who, MyName, MyName)
    mq.cmdf(reply)
    mq.delay(1000)
    reply = string.format("/tell %s Send me a tell for items /tell %s list weapons, belt, mask, armor, focus, player, or jewelry", who, MyName)
    mq.cmdf(reply)
end

local function BuildEvents()
    mq.event('mage_toys', "#1# tells you, 'toys #2#'#*#", EventHandler)
    mq.event("list_toys", "#1# tells you, 'list toys'#*#", EventHandler)
    local hailMsg = string.format("#1# says, 'Hail, %s'", MyName)
    mq.event("mage_hailed", hailMsg, hailed)
    mq.event("list_items2", "#1# tells you, 'list weapons'#*#", ListItems)
    mq.event("list_items3", "#1# tells you, 'list belt'#*#", ListItems)
    mq.event("list_items4", "#1# tells you, 'list mask'#*#", ListItems)
    mq.event("list_items5", "#1# tells you, 'list armor'#*#", ListItems)
    mq.event("list_items6", "#1# tells you, 'list jewelry'#*#", ListItems)
    mq.event("list_items7", "#1# tells you, 'list focus'#*#", ListItems)
    mq.event("list_items8", "#1# tells you, 'list player'#*#", ListItems)
    mq.event('mage_weapons', "#1# tells you, 'weapons #*#'#*#", function(line, who, what) ItemHandler(line, who, "weapons") end)
    mq.event('mage_armor', "#1# tells you, 'armor #*#'#*#", function(line, who, what) ItemHandler(line, who, "armor") end)
    mq.event('mage_mask', "#1# tells you, 'mask #*#'#*#", function(line, who, what) ItemHandler(line, who, "mask") end)
    mq.event('mage_jewelry', "#1# tells you, 'jewelry #*#'#*#", function(line, who, what) ItemHandler(line, who, "jewelry") end)
    mq.event('mage_jewlery', "#1# tells you, 'jewlery #*#'#*#", function(line, who, what) ItemHandler(line, who, "jewelry") end)
    mq.event('mage_focus', "#1# tells you, 'focus #*#'#*#", function(line, who, what) ItemHandler(line, who, "focus") end)
    mq.event('mage_belt', "#1# tells you, 'belt #2#'#*#", function(line, who, what) ItemHandler(line, who, "belt") end)
    mq.event('mage_player', "#1# tells you, 'player #2#'#*#", function(line, who, what) ItemHandler(line, who, "player") end)
end

local function init()
    if mq.TLO.Me.Class() ~= 'Magician' then
        MGear('\arError\ax: You are not a Magician! Program ending!')
        return false
    end
    getSpells()
    loadSettings()
    lastPriWep = settings.petPriWep
    lastSecWep = settings.petSecWep
    lastPet = settings.selectedPet
    lastBelt = settings.selectedBelt
    lastMask = settings.selectedMask
    lastArmor = settings.selectedArmor
    lastJewelry = settings.selectedJewelry
    lastFocus = settings.selectedFocus
    lastPlayerItem = settings.selectedPlayerItem

    MGear('\apGreetings Mage! What would you like to Summon?')
    return true
end

BuildEvents()
openGUI = init()

local function drawCombo(label, current, items, isPet)
    local comboValue = current
    imgui.PushID(label)

    local displayText = "Select a spell"
    if current > 0 and items[current] then
        displayText = string.format("%s (Level %d)", items[current].spell, items[current].level)
    end

    if imgui.BeginCombo(label, displayText) then
        imgui.PushStyleColor(ImGuiCol.Text, ImVec4(0.7, 0.7, 0.7, 1))
        local isSelectedPlaceholder = (comboValue == 0)
        if imgui.Selectable("Select a spell", isSelectedPlaceholder) then
            -- Do nothing; keep comboValue as is
        end
        imgui.PopStyleColor()

        for i, item in ipairs(items) do
            local bookCheck = mq.TLO.Me.Book(item.spell)()
            local inBook = bookCheck and bookCheck > 0
            local color = inBook and ImVec4(0, 1, 0, 1) or ImVec4(0.5, 0.5, 0.5, 1)
            local isSelected = (comboValue == i)
            local itemText = string.format("%s (Level %d)", item.spell, item.level)

            imgui.PushStyleColor(ImGuiCol.Text, color)
            if imgui.Selectable(itemText, isSelected) and inBook then
                local lastChange = lastComboChange[label] or -1
                if comboValue ~= i and os.clock() - lastChange > 0.5 then
                    comboValue = i
                    lastComboChange[label] = os.clock()
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text(item.spell or "")
                ImGui.SameLine()
                ImGui.TextColored(ImVec4(1, 1, 0, 1), string.format(" (Level %d)", item.level or 0))
                ImGui.PushTextWrapPos(200)
                imgui.TextColored(ImVec4(1, 1, 1, 0.8), item.desc or "")
                imgui.PopTextWrapPos()
                imgui.EndTooltip()
            end
            if isSelected then imgui.SetItemDefaultFocus() end
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
    if settings.currentTheme == "Water Mage" then
        return ImVec4(0.3, 0.6, 0.9, 1)
    elseif settings.currentTheme == "Fire Mage" then
        return ImVec4(0.9, 0.5, 0.3, 1)
    else
        return ImVec4(0.3, 0.8, 0.3, 1)
    end
end

local function mageGear(open)
    local main_viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(main_viewport.WorkPos.x + 600, main_viewport.WorkPos.y + 20, ImGuiCond.FirstUseEver)
    imgui.SetNextWindowSize(350, 400, ImGuiCond.FirstUseEver)

    local ColorCount, StyleCount = Themes.StartTheme(settings.currentTheme, ThemeData)
    local show = false
    open, show = imgui.Begin("Mage Gear (DoN EMU) v2.3.17", open)

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
    if imgui.BeginCombo("##Theme", settings.currentTheme) then
        for _, themeName in ipairs(themeNames) do
            local isSelected = (themeName == settings.currentTheme)
            if imgui.Selectable(themeName, isSelected) then
                settings.currentTheme = themeName
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

    local newSelectedPet = drawCombo("", settings.selectedPet, petSpells, true)
    if newSelectedPet ~= settings.selectedPet then
        settings.selectedPet = newSelectedPet
        if settings.selectedPet > 0 then
            MGear('\aySelected: ' .. petSpells[settings.selectedPet].spell .. ' (Index ' .. settings.selectedPet .. ')')
        end
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
    settings.doWeapons = drawToggle("Weapons", settings.doWeapons)
    imgui.SameLine()
    settings.doBelt = drawToggle("Belt", settings.doBelt)

    settings.doMask = drawToggle("Mask", settings.doMask)
    imgui.SameLine()
    settings.doArmor = drawToggle("Armor", settings.doArmor)

    settings.doJewelry = drawToggle("Jewelry", settings.doJewelry)
    imgui.SameLine()
    settings.doFocus = drawToggle("Focus", settings.doFocus)

    settings.doPlayer = drawToggle("Player", settings.doPlayer)
    ImGui.SameLine()
    settings.keepBags = drawToggle("Keep Bags", settings.keepBags)

    imgui.SeparatorText('Pet Items')

    if settings.doWeapons and #petWeps > 0 then
        local newPetPriWep = drawCombo("Primary", settings.petPriWep, petWeps, false)
        if newPetPriWep ~= settings.petPriWep then
            settings.petPriWep = newPetPriWep
            if settings.petPriWep > 0 then
                MGear('\aySelected Primary: ' .. petWeps[settings.petPriWep].spell .. ' (Index ' .. settings.petPriWep .. ')')
            end
        end
        local newPetSecWep = drawCombo("Secondary", settings.petSecWep, petWeps, false)
        if newPetSecWep ~= settings.petSecWep then
            settings.petSecWep = newPetSecWep
            if settings.petSecWep > 0 then
                MGear('\aySelected Secondary: ' .. petWeps[settings.petSecWep].spell .. ' (Index ' .. settings.petSecWep .. ')')
            end
        end
    end

    if settings.doBelt and #beltSpells > 0 then
        local newSelectedBelt = drawCombo("Belt", settings.selectedBelt, beltSpells, false)
        if newSelectedBelt ~= settings.selectedBelt then
            settings.selectedBelt = newSelectedBelt
            if settings.selectedBelt > 0 then
                MGear('\aySelected Belt: ' .. beltSpells[settings.selectedBelt].spell .. ' (Index ' .. settings.selectedBelt .. ')')
            end
        end
    end

    if settings.doMask and #maskSpells > 0 then
        local newSelectedMask = drawCombo("Mask", settings.selectedMask, maskSpells, false)
        if newSelectedMask ~= settings.selectedMask then
            settings.selectedMask = newSelectedMask
            if settings.selectedMask > 0 then
                MGear('\aySelected Mask: ' .. maskSpells[settings.selectedMask].spell .. ' (Index ' .. settings.selectedMask .. ')')
            end
        end
    end

    if settings.doArmor and #armorSpells > 0 then
        local newSelectedArmor = drawCombo("Armor", settings.selectedArmor, armorSpells, false)
        if newSelectedArmor ~= settings.selectedArmor then
            settings.selectedArmor = newSelectedArmor
            if settings.selectedArmor > 0 then
                MGear('\aySelected Armor: ' .. armorSpells[settings.selectedArmor].spell .. ' (Index ' .. settings.selectedArmor .. ')')
            end
        end
    end

    if settings.doJewelry and #jewelrySpells > 0 then
        local newSelectedJewelry = drawCombo("Jewelry", settings.selectedJewelry, jewelrySpells, false)
        if newSelectedJewelry ~= settings.selectedJewelry then
            settings.selectedJewelry = newSelectedJewelry
            if settings.selectedJewelry > 0 then
                MGear('\aySelected Jewelry: ' .. jewelrySpells[settings.selectedJewelry].spell .. ' (Index ' .. settings.selectedJewelry .. ')')
            end
        end
    end

    if settings.doFocus or settings.doPlayer then
        ImGui.SeparatorText("Player Items")

        if settings.doFocus and #focusSpells > 0 then
            local newSelectedFocus = drawCombo("Focus", settings.selectedFocus, focusSpells, false)
            if newSelectedFocus ~= settings.selectedFocus then
                settings.selectedFocus = newSelectedFocus
                if settings.selectedFocus > 0 then
                    MGear('\aySelected Focus: ' .. focusSpells[settings.selectedFocus].spell .. ' (Index ' .. settings.selectedFocus .. ')')
                end
            end
        end

        if settings.doPlayer and #playerItems > 0 then
            local newSelectedPlayerItem = drawCombo("Player Item", settings.selectedPlayerItem, playerItems, false)
            if newSelectedPlayerItem ~= settings.selectedPlayerItem then
                settings.selectedPlayerItem = newSelectedPlayerItem
                if settings.selectedPlayerItem > 0 then
                    MGear('\aySelected Player Item: ' .. playerItems[settings.selectedPlayerItem].spell .. ' (Index ' .. settings.selectedPlayerItem .. ')')
                end
            end
        end
    end

    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button('Self') then
        GearTarget = 'Self'
        doRun = true
    end
    imgui.PopStyleColor(2)
    imgui.SameLine()

    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button('Target') then
        if mq.TLO.Target.ID() > 0 then
            GearTarget = 'Target'
            doRun = true
        else
            MGear('\arError\ax: No target')
        end
    end
    imgui.PopStyleColor(2)
    imgui.SameLine()

    imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 1, 0, 1))
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, getHoverColor())
    if imgui.Button('Group') then
        if mq.TLO.Group() then
            GearTarget = 'Group'
            doRun = true
        else
            MGear('\arError\ax: Not in a group')
        end
    end
    imgui.PopStyleColor(2)

    lastPriWep = settings.petPriWep
    lastSecWep = settings.petSecWep
    lastPet = settings.selectedPet
    lastBelt = settings.selectedBelt
    lastMask = settings.selectedMask
    lastArmor = settings.selectedArmor
    lastJewelry = settings.selectedJewelry
    lastFocus = settings.selectedFocus
    lastPlayerItem = settings.selectedPlayerItem

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

    -- Check if spellbook is stuck open and close it
    if mq.TLO.Window("SpellBookWnd").Open() then
        MGear('\ayWarning\ax: Spellbook is open, closing it')
        mq.cmd('/book')
        mq.delay(500, function() return not mq.TLO.Window("SpellBookWnd").Open() end)
    end

    if curGem > 0 then
        flag = true
    elseif curGem == 0 then
        local command = string.format("/memspell %s \"%s\"", lastGem, spell)
        local attempts = 0
        while attempts < 3 and not flag do
            mq.cmdf("%s", command)
            mq.delay(50)
            MGear('\amMemorizing \ax' .. spell .. ' in gem ' .. lastGem)
            mq.delay(7000, function() return mq.TLO.Me.Gem(lastGem).Name() == spell end)
            if ((mq.TLO.Me.Gem(spell)() or 0) == 0) then
                MGear('\ayWarning\ax: Failed to memorize ' .. spell .. ' in gem Slot: ' .. lastGem .. ', attempt ' .. (attempts + 1))
                attempts = attempts + 1
                mq.delay(1000) -- Give UI time to recover
                if mq.TLO.Window("SpellBookWnd").Open() then
                    mq.cmd('/book')
                    mq.delay(500)
                end
            else
                MGear('\agMemorized \ax' .. spell)
                flag = true
            end
        end
        if not flag then
            MGear('\arError\ax: Could not memorize ' .. spell .. ' after 3 attempts')
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
    local timeout = os.clock() + mq.TLO.Spell(pet.spell).MyCastTime.TotalSeconds() + 2
    while not mq.TLO.Me.SpellReady(pet.spell)() and os.clock() < timeout do
        mq.delay(500)
    end
    if not mq.TLO.Me.SpellReady(pet.spell)() then
        MGear('\arError\ax: Gem not ready for ' .. pet.spell)
        return false
    end

    mq.cmdf('/cast "%s"', pet.spell)
    mq.delay(3000)

    timeout = os.clock() + mq.TLO.Spell(pet.spell).MyCastTime.TotalSeconds() + 2
    local castAttempts = 0
    while not mq.TLO.Me.Casting() and os.clock() < timeout do
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

    timeout = os.clock() + mq.TLO.Spell(pet.spell).MyCastTime.TotalSeconds() + 2
    while mq.TLO.Me.Casting() and os.clock() < timeout do mq.delay(500) end

    timeout = os.clock() + mq.TLO.Spell(pet.spell).MyCastTime.TotalSeconds() + 2
    while not mq.TLO.Me.Pet.ID() and os.clock() < timeout do mq.delay(500) end
    if not mq.TLO.Me.Pet.ID() then
        MGear('\arError\ax: No pet summoned after casting ' .. pet.spell)
        return false
    end

    MGear('\agPet summoned: \ax' .. pet.spell)
    return true
end

local function summonItem(spellData)
    if not spellData then return false end
    if not mq.TLO.Me.Book(spellData.spell)() then
        MGear('\arError\ax: ' .. spellData.spell .. ' not in your spellbook')
        return false
    end

    local spellMana = mq.TLO.Spell(spellData.spell).Mana() or 0
    if mq.TLO.Me.CurrentMana() < spellMana then
        MGear('\arError\ax: Not enough mana for ' .. spellData.spell)
        return false
    end

    if not memorizeSpell(spellData.spell) then return false end

    MGear('\amCasting \ax' .. spellData.spell)
    local timeout = os.clock() + 12
    while not mq.TLO.Me.SpellReady(spellData.spell)() and os.clock() < timeout do
        mq.delay(500)
    end
    if not mq.TLO.Me.SpellReady(spellData.spell)() then
        MGear('\arError\ax: Gem not ready for ' .. spellData.spell)
        return false
    end

    mq.cmdf('/cast "%s"', spellData.spell)
    mq.delay(4000)
    local castTime = mq.TLO.Spell(spellData.spell) ~= nil and mq.TLO.Spell(spellData.spell).CastTime.TotalSeconds() or 0
    local castAttempts = 0
    while not mq.TLO.Me.Casting() and castAttempts < 4 do
        if mq.TLO.Me.SpellReady(spellData.spell)() and castAttempts < 3 then
            castAttempts = castAttempts + 1
            MGear('\ayRetrying cast attempt ' .. castAttempts .. ' for ' .. spellData.spell)
            mq.cmdf('/cast "%s"', spellData.spell)
        end
        mq.delay(2000, function() return mq.TLO.Me.Casting() end)
    end

    while mq.TLO.Me.Casting() do
        mq.delay(500)
    end

    local cursorAttempts = 0
    while not mq.TLO.Cursor() and cursorAttempts < 5 do
        cursorAttempts = cursorAttempts + 1
        MGear('\ayWaiting for cursor, attempt ' .. cursorAttempts)
        mq.delay(1500, function() return mq.TLO.Cursor() end)
    end

    if not mq.TLO.Cursor() then
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
        if mq.TLO.Window("GiveWnd/GVW_MyItemSlot3").Tooltip() and mq.TLO.Window("GiveWnd/GVW_MyItemSlot3").Tooltip() ~= '' then
            mq.cmd('/notify GiveWnd GVW_Give_Button leftmouseup')
            mq.delay(500)
        end
    end

    if mq.TLO.Window("GiveWnd").Open() then
        mq.cmd('/notify GiveWnd GVW_Give_Button leftmouseup')
        mq.delay(500)
        local timeout = os.clock() + 5
        while mq.TLO.Window("GiveWnd").Open() and os.clock() < timeout do
            mq.delay(100)
        end
        if mq.TLO.Window("GiveWnd").Open() then
            MGear('\ayWarning\ax: Give window still open, closing manually')
            mq.cmd('/notify GiveWnd GVW_Cancel_Button leftmouseup')
        end
    end
end

local function handCursorToPlayer()
    while mq.TLO.Cursor.ID() do
        mq.cmd('/click left target')
        mq.delay(700)
        if mq.TLO.Window("TradeWnd/TRDW_TradeSlot7").Tooltip() and mq.TLO.Window("TradeWnd/TRDW_TradeSlot7").Tooltip() ~= '' then
            mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
            mq.delay(500)
        end
    end
    if mq.TLO.Window("TradeWnd").Open() and not mq.TLO.Cursor() then
        mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
        mq.delay(500)
        local timeout = os.clock() + 50
        while mq.TLO.Window("TradeWnd").Open() and os.clock() < timeout do
            mq.delay(100)
        end
        if mq.TLO.Window("TradeWnd").Open() then
            MGear('\ayWarning\ax: Give window still open, closing manually')
            mq.cmd('/notify TradeWnd TRDW_Cancel_Button leftmouseup')
        end
    end
end

local function moveToPet(target)
    if not target then
        MGear('\arError\ax: No pet name provided')
        return false
    end
    mq.cmdf('/tar %s', target)
    mq.delay(500)
    if not mq.TLO.Target.ID() then
        MGear('\arError\ax: Could not target ' .. target)
        return false
    end
    local distance = mq.TLO.Target.Distance() or 999
    MGear('\ayDistance to ' .. target .. ': ' .. distance)
    if distance <= 20 then
        return true
    else
        MGear('\ayNavigating to \ax' .. target)
        mq.cmd('/nav target')
        local timeout = os.clock() + 15
        while mq.TLO.Navigation.Active() and os.clock() < timeout do
            mq.delay(500)
            distance = mq.TLO.Target.Distance() or 999
            MGear('\ayCurrent distance: ' .. distance)
            if distance <= 20 then break end
        end
        if distance <= 20 then
            MGear('\ayReached ' .. target .. ', pausing...')
            mq.delay(1000)
            return true
        else
            MGear('\arError\ax: Too far from ' .. target .. ' (Distance: ' .. distance .. ')')
            return false
        end
    end
end

local needMove = false

local function giveItemToPet(targetPet, isPet)
    if not targetPet then
        MGear('\arError\ax: Invalid pet name')
        return false
    end

    if not moveToPet(targetPet) then
        needMove = true
        return false
    end

    local success = true
    if not isPet then
        if settings.doFocus and settings.selectedFocus > 0 then
            success = summonItem(focusSpells[settings.selectedFocus]) and success
            if success then
                handCursorToPlayer()
                needMove = false
            end
        end

        if settings.doPlayer and settings.selectedPlayerItem > 0 then
            success = summonItem(playerItems[settings.selectedPlayerItem]) and success
            if success then
                handCursorToPlayer()
                needMove = false
            end
        end
    else
        if settings.doWeapons and settings.petPriWep > 0 then
            success = summonItem(petWeps[settings.petPriWep]) and success
            if success then handCursorToPet() end
            if success and settings.petSecWep > 0 then 
                success = summonItem(petWeps[settings.petSecWep]) and success
                if success then handCursorToPet() end
            end
        end

        if settings.doBelt and settings.selectedBelt > 0 then
            success = summonItem(beltSpells[settings.selectedBelt]) and success
            if success then handCursorToPet() end
        end

        if settings.doMask and settings.selectedMask > 0 then
            success = summonItem(maskSpells[settings.selectedMask]) and success
            if success then handCursorToPet() end
        end

        if settings.doArmor and settings.selectedArmor > 0 then
            success = summonItem(armorSpells[settings.selectedArmor]) and success
            if success then handCursorToPet() end
        end

        if settings.doJewelry and settings.selectedJewelry > 0 then
            success = summonItem(jewelrySpells[settings.selectedJewelry]) and success
            if success then handCursorToPet() end
        end
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

-- RGMercs control functions
local wasRGMercsRunning = false
local function pauseRGMercs()
    MGear('\ayPausing RGMercs...')
    mq.cmd('/rgl pauseall')
    mq.delay(1000) -- Wait for pause to take effect
    wasRGMercsRunning = true
    MGear('\ayRGMercs paused')
end

local function unpauseRGMercs()
    if wasRGMercsRunning then
        MGear('\ayUnpausing RGMercs...')
        mq.cmd('/rgl unpauseall')
        mq.delay(1000) -- Wait for unpause to take effect
        wasRGMercsRunning = false
        MGear('\ayRGMercs unpaused')
    end
end

-- Check if pet is a wizard familiar
local function isWizardFamiliar(pet)
    if not pet or not pet.ID() then return false end
    local petSpell = pet.Casting.Spell.Name() or pet.Name() -- Fallback to name if spell not available
    for _, familiar in ipairs(familiarSpells) do
        if petSpell:lower():find(familiar:lower()) then
            return true
        end
    end
    return false
end

while openGUI do
    mq.doevents()
    mq.delay(500)

    while doSummonPet do
        pauseRGMercs()
        local petSpell = petSpells[settings.selectedPet]
        summonPet(petSpell)
        doSummonPet = false
        unpauseRGMercs()
    end

    while doRun do
        pauseRGMercs()
        local itemsToSummon = {}
        if settings.doWeapons and #petWeps > 0 then
            if settings.petPriWep > 0 then
                itemsToSummon[#itemsToSummon + 1] = 'Primary=' .. petWeps[settings.petPriWep].spell
            end
            if settings.petSecWep > 0 then
                itemsToSummon[#itemsToSummon + 1] = 'Secondary=' .. petWeps[settings.petSecWep].spell
            end
        end
        if settings.doBelt and #beltSpells > 0 and settings.selectedBelt > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Belt=' .. beltSpells[settings.selectedBelt].spell
        end
        if settings.doMask and #maskSpells > 0 and settings.selectedMask > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Mask=' .. maskSpells[settings.selectedMask].spell
        end
        if settings.doArmor and #armorSpells > 0 and settings.selectedArmor > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Armor=' .. armorSpells[settings.selectedArmor].spell
        end
        if settings.doJewelry and #jewelrySpells > 0 and settings.selectedJewelry > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Jewelry=' .. jewelrySpells[settings.selectedJewelry].spell
        end
        if settings.doFocus and #focusSpells > 0 and settings.selectedFocus > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Focus=' .. focusSpells[settings.selectedFocus].spell
        end
        if settings.doPlayer and #playerItems > 0 and settings.selectedPlayerItem > 0 then
            itemsToSummon[#itemsToSummon + 1] = 'Player=' .. playerItems[settings.selectedPlayerItem].spell
        end

        local success = false
        local playerTrades = (settings.doFocus or settings.doPlayer)
        if playerTrades then
            local tradePlayer = mq.TLO.Target
            if not tradePlayer() then
                MGear('\arError\ax: Invalid target')
            else
                success = giveItemToPet(tradePlayer.CleanName(), false)
                if success then
                    MGear('\agSummoning Player Items complete')
                end
            end
        end

        if GearTarget == 'Self' then
            if not mq.TLO.Me.Pet.ID() then
                MGear('\arError\ax: You do not have a pet')
            else
                tradePetName = mq.TLO.Me.Pet.CleanName()
                success = giveItemToPet(tradePetName, true)
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
                    success = giveItemToPet(tradePetName, true)
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
                local allSuccess = true
                local failedMembers = {}
                for i = 0, groupSize do
                    local member = mq.TLO.Group.Member(i)
                    if member() then
                        local pet = member.Pet
                        if pet.ID() > 0 then
                            if isWizardFamiliar(pet) then
                                MGear('\aySkipping \ax' .. member.Name() .. ' - wizard familiar')
                            else
                                tradePetName = pet.CleanName()
                                local memberSuccess = giveItemToPet(tradePetName, true)
                                allSuccess = allSuccess and memberSuccess
                                if not memberSuccess then
                                    table.insert(failedMembers, member.Name())
                                end
                            end
                        else
                            MGear('\aySkipping \ax' .. member.Name() .. ' - no pet')
                        end
                    end
                end
                if #failedMembers > 0 then
                    MGear('\ayWarning\ax: Failed to summon for: ' .. table.concat(failedMembers, ', '))
                end
                if allSuccess then
                    MGear('\agGroup summoning complete')
                else
                    MGear('\ayGroup summoning finished with some failures')
                end
                success = true -- Ensure loop continues
            end
        end

        if needMove then
            MGear('\ayWaiting to reach pet, retrying...')
        else
            doRun = false
        end
        unpauseRGMercs()
    end
end
saveSettings()
mq.unevent('mage_toys')
mq.unevent('list_toys')
mq.unevent("mage_hailed")
mq.unevent("list_items2")
mq.unevent("list_items3")
mq.unevent("list_items4")
mq.unevent("list_items5")
mq.unevent("list_items6")
mq.unevent("list_items7")
mq.unevent("list_items8")
mq.unevent('mage_weapons')
mq.unevent('mage_armor')
mq.unevent('mage_mask')
mq.unevent('mage_jewelry')
mq.unevent('mage_jewlery')
mq.unevent('mage_belt')
mq.unevent('mage_toys')
mq.unevent('mage_focus')
mq.unevent('mage_player')
mq.cmd('/echo \aw[\agMageGear\aw] \arProgram terminated')