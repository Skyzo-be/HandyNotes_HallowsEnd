-- Addon declaration
HandyNotes_HallowsEnd = LibStub("AceAddon-3.0"):NewAddon("HandyNotes_HallowsEnd","AceEvent-3.0")
local HHE = HandyNotes_HallowsEnd
local L = LibStub("AceLocale-3.0"):GetLocale("HandyNotes_HallowsEnd")

---------------------------------------------------------
-- Our db upvalue and db defaults
local db
local defaults = {
	profile = {
		icon_scale				= 1.0,
		icon_alpha				= 1.0,
		completed 				= false,
		onlyActiveHallowsEnd 	= false,
	},
}

---------------------------------------------------------
-- Localize some globals
local next = next
local select = select
local string_find = string.find
local GameTooltip = GameTooltip
local WorldMapTooltip = WorldMapTooltip
local HandyNotes = HandyNotes
local CalendarGetDate = CalendarGetDate

local tonumber = tonumber
local strsplit = strsplit

---------------------------------------------------------
-- Constants and icons
local defkey = "default"
local iconDB = {
	["HallowsEnd"]   = "interface\\icons\\inv_misc_food_28",
	[defkey] = "Interface\\Icons\\INV_Misc_QuestionMark", -- default fallback icon
}

setmetatable(iconDB, {__index = function(t, k)
		local v = t[defkey]
		rawset(t, k, v)
		return v
	end
})

---------------------------------------------------------
local completedQuests = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_QUERY_COMPLETE")
frame:RegisterEvent("QUEST_FINISHED")
frame:SetScript("OnEvent", function(self, event)
    if event == "QUEST_FINISHED" then
        QueryQuestsCompleted()
        return
    end

    wipe(completedQuests)
    local t = {}
    GetQuestsCompleted(t)
    for questID, done in pairs(t) do
        if done then
            completedQuests[questID] = true
        end
    end
    HHE:SendMessage("HandyNotes_NotifyUpdate", "HallowsEnd")
end)

---------------------------------------------------------
-- Plugin Handlers to HandyNotes
local HHEHandler = {}

local function createWaypoint(button, mapFile, coord)
	local c, z = HandyNotes:GetCZ(mapFile)
	local x, y = HandyNotes:getXY(coord)
	local vType, vName, vGuild = strsplit(":", HHE_Data[mapFile][coord])
	
	if TomTom then
		TomTom:AddZWaypoint(c, z, x*100, y*100, vName)
	elseif Cartographer_Waypoints then
		Cartographer_Waypoints:AddWaypoint(NotePoint:new(HandyNotes:GetCZToZone(c, z), x, y, vName))
	end
end

local clickedNote, clickedNoteZone
local info = {}
local function generateMenu(button, level)
	if (not level) then return end
	for k in pairs(info) do info[k] = nil end
	if (level == 1) then
		info.isTitle      = 1
		info.text         = L["HandyNotes - HallowsEnd"]
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		if TomTom or Cartographer_Waypoints then
			info.disabled     = nil
			info.isTitle      = nil
			info.notCheckable = nil
			info.text = L["Create waypoint"]
			info.icon = nil
			info.func = createWaypoint
			info.arg1 = clickedNoteZone
			info.arg2 = clickedNote
			UIDropDownMenu_AddButton(info, level)
		end

		info.text         = L["Close"]
		info.icon         = nil
		info.func         = function() CloseDropDownMenus() end
		info.arg1         = nil
		info.arg2         = nil
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
	end
end

local HHE_Dropdown = CreateFrame("Frame", "HandyNotes_HallowsEndDropdownMenu")
HHE_Dropdown.displayMode = "MENU"
HHE_Dropdown.initialize = generateMenu

function HHEHandler:OnClick(button, down, mapFile, coord)
	if TomTom or Cartographer_Waypoints then
		if button == "RightButton" and not down then
			clickedNoteZone = mapFile
			clickedNote = coord
			ToggleDropDownMenu(1, nil, HHE_Dropdown, self, 0, 0)
		end
	end
end

function HHEHandler:OnEnter(mapFile, coord)
    local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip

    if self:GetCenter() > UIParent:GetCenter() then
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    local raw = HHE_Data[mapFile] and HHE_Data[mapFile][coord]
    if not raw then return end

    local vType, vName, vGuild, questID = string.match(raw, "([^:]+):([^:]+):([^:]*):?(%d*)")

    if vName then
        tooltip:AddLine("|cffe0e0e0" .. vName .. "|r")
    end
    if vGuild and vGuild ~= "" then
        tooltip:AddLine(vGuild)
    end

    if questID and questID ~= "" then
        local qID = tonumber(questID)
        if qID then
            local completed = completedQuests[qID] or false
            if completed then
                tooltip:AddLine("|cff00ff00Completed|r")
            else
                tooltip:AddLine("|cffff0000Not completed|r")
            end
        else
            tooltip:AddLine("|cffff0000Invalid quest ID|r")
        end
    end

    tooltip:Show()
end

function HHEHandler:OnLeave(mapFile, coord)
	if self:GetParent() == WorldMapButton then
		WorldMapTooltip:Hide()
	else
		GameTooltip:Hide()
	end
end

local function iter(t, prestate)
    if not t then return nil end
    local state, value = next(t, prestate)
    while state do
        if value then
            local vType, vName, vGuild, questID = strsplit(":", value)
            local isCompleted = false
            if questID and questID ~= "" then
                isCompleted = completedQuests[tonumber(questID)] or false
            end

            if db.profile.completed or not isCompleted then
                local icon = iconDB[vType]
                return state, nil, icon, db.profile.icon_scale, db.profile.icon_alpha
            end
        end
        state, value = next(t, state)
    end
    return nil, nil, nil, nil
end

----------
local function IsFestivalActive()
    local _, month, day = CalendarGetDate()
    return (month == 10 and day >= 18) or (month == 10 and day <= 31)
end

function HHEHandler:GetNodes(mapFile)
--print("HandyNotes SummerFestival GetNodes mapFile:", mapFile)
	--if not IsFestivalActive() then
	if db.profile.onlyActiveFestival and not IsFestivalActive() then
		return function() return nil end, nil, nil
	end
	return iter, HHE_Data[mapFile], nil
end

---------------------------------------------------------
-- Options table

local options = {
	type = "group",
	name = L["HallowsEnd"],
	desc = L["Hallow's End Candy Bucket locations"],
	get = function(info) return db.profile[info.arg] end,
	set = function(info, v)
		db.profile[info.arg] = v
		HHE:SendMessage("HandyNotes_NotifyUpdate", "HallowsEnd")
	end,
	args = {
		desc = {
			name = L["These settings control the look and feel of the icon"],
			type = "description",
			order = 0,
		},
		icon_scale = {
			type = "range",
			name = L["Icon Scale"],
			desc = L["The scale of the icons"],
			min = 0.25, max = 2, step = 0.01,
			arg = "icon_scale",
			order = 10,
		},
		icon_alpha = {
			type = "range",
			name = L["Icon Alpha"],
			desc = L["The alpha transparency of the icons"],
			min = 0, max = 1, step = 0.01,
			arg = "icon_alpha",
			order = 20,
		},
		show_on_continent = {
			type = "toggle",
			name = L["Show completed"],
			desc = L["Show icons for bonfires you have already visited"],
			arg = "completed",
			order = 30,			
		},
		onlyActiveFestival = {
			type = "toggle",
			name = L["Show only during the Summer Festival"],
			desc = L["Display bonfires only during the Fire Festival period"],
			arg = "onlyActiveFestival",
			order = 40,
		},	
	},
}

---------------------------------------------------------
-- Addon initialization

function HHE:OnInitialize()
	db = LibStub("AceDB-3.0"):New("HandyNotes_HallowsEndDB", defaults)
	self.db = db

	local faction = UnitFactionGroup("player")
	if faction == "Alliance" then
		HHE_Data = HHE_Alliance
	elseif faction == "Horde" then
		HHE_Data = HHE_Horde
	end

	HandyNotes:RegisterPluginDB("HallowsEnd", HHEHandler, options)
	QueryQuestsCompleted()
end

function HHE:OnEnable()
	HHE:SendMessage("HandyNotes_NotifyUpdate", "HallowsEnd")
end