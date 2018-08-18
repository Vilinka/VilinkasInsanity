--if select(2, UnitClass("player")) ~= "PRIEST" then return end

local name, addon = ...
_G[name] = addon

local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local VilinkasInsanityVer = GetAddOnMetadata("VilinkasInsanity", "Version")
local vilinsFrame, oocFadeAnim = VilinkasInsanityBar, VilinkasInsanityBar.FadeoutAnim

local title = VilinkasInsanityBar.title

local isVisible
local db

local frame = CreateFrame("Frame", name .. "MainFrame", UIParent)
frame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
local moverFrame = CreateFrame("Frame", name .. "MainFrame", frame)
local moverFontString = moverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local container, window

addon.frame = frame

addon.optionsTable = {
	type = "group",
	args = {
		versionHeader = {
			order = 1,
			type = "header",
			name = VilinkasInsanityVer,
			width = "full",
		},
		defaults = {
			order = 2,
			type = 'execute',
			name = "Reset Defaults",
			func = function() 
				VilinkasInsanityBar.db:ResetProfile()
				VilinkasInsanityBar:UpdateSettings()
			end,
		}
	}
}	

local function CreateOptions()
	options.args.general = addon.optionsTable.general
	
	return options
end

local function GetPositionRelToCenter(point, xOffset, yOffset)
	local halfWidth = UIParent:GetWidth() / 2
	local halfHeight = UIParent:GetHeight() / 2
	if point == "BOTTOMLEFT" then
		xOffset = xOffset - halfWidth
		yOffset = yOffset - halfHeight
	elseif point == "BOTTOM" then
		--xOffset = xOffset
		yOffset = yOffset - halfHeight
	elseif point == "BOTTOMRIGHT" then
		xOffset = halfWidth - xOffset
		yOffset = yOffset - halfHeight
	elseif point == "RIGHT" then
		xOffset = halfWidth - xOffset
		--yOffset = yOffset
	elseif point == "TOPRIGHT" then
		xOffset = halfWidth - xOffset
		yOffset = halfHeight - yOffset
	elseif point == "TOP" then
		--xOffset = xOffset
		yOffset = halfHeight - yOffset
	elseif point == "TOPLEFT" then
		xOffset = xOffset - halfWidth
		yOffset = halfHeight - yOffset
	elseif point == "LEFT" then
		xOffset = xOffset - halfWidth
		--yOffset = yOffset
	end
	
	return xOffset, yOffset
end

local function UnlockFrame()
	VilinkasInsanityBar:SetMovable(true)
	VilinkasInsanityBar:UnregisterEvent("PLAYER_REGEN_ENABLED")
	VilinkasInsanityBar:UnregisterEvent("PLAYER_REGEN_DISABLED")
	VilinkasInsanityBar:Show()
	VilinkasInsanityBar:SetAlpha(1)
end

local function LockFrame()
	VilinkasInsanityBar:SetMovable(false)
	VilinkasInsanityBar:Setup()
	--VilinkasInsanityBar:RegisterEvent("PLAYER_REGEN_ENABLED")
	--VilinkasInsanityBar:RegisterEvent("PLAYER_REGEN_DISABLED")
	VilinkasInsanityBar:UpdatePlayerState()
end

local function OnMouseDown()
	VilinkasInsanityBar:StartMoving()
end

local function OnMouseUp()
	VilinkasInsanityBar:StopMovingOrSizing()
	local point, _, _, xOffset, yOffset = VilinkasInsanityBar:GetPoint(1)
	xOffset, yOffset = GetPositionRelToCenter(point, xOffset, yOffset)
	VilinkasInsanityBar.db.profile.general.x = xOffset
	VilinkasInsanityBar.db.profile.general.y = yOffset
	AceConfigDialog:Open("VilinkasInsanityOptions", container)
end

local function OnClose()
	addon:Hide()
end

function addon:ReloadWindow()
	AceConfigDialog:Open("VilinkasInsanityOptions", container)
end

local function InitFrames()
	container = AceGUI:Create("SimpleGroup")
	
	window = AceGUI:Create("Frame")
	window:SetTitle("Vilinka's Insanity")
	window:SetLayout("Fill")
	window:SetCallback("OnClose", OnClose)

	window:AddChild(container)
	
	moverFrame:ClearAllPoints()
	moverFrame:SetPoint("TOPLEFT", vilinsFrame, "TOPLEFT")
	moverFrame:SetPoint("BOTTOMRIGHT", vilinsFrame, "BOTTOMRIGHT")
	moverFontString:SetText("Drag to move")
	moverFontString:SetPoint("CENTER", moverFrame, "TOP", 0, 10)
end

function addon:RegisterOptions(options)
	local order = #self.options
	self.options[#options + 1] = options:CreateOptions(order)
end

frame:RegisterEvent("ADDON_LOADED")
function frame:ADDON_LOADED(...)
	if name == ...	then
		local yOffset = UIParent:GetHeight()
		default = {
			profile = {
				width = 635,
				top = yOffset - 50,
				left = 50,
			}
		}
		self.db = LibStub("AceDB-3.0"):New("VilinkasInsanityOptionsDB", default, true)
		db = self.db.profile
		
		InitFrames()
		
		window:SetStatusTable(db)
		
		AceConfig:RegisterOptionsTable("VilinkasInsanityOptions", addon.optionsTable)
		AceConfigDialog:Open("VilinkasInsanityOptions", container)
		
		self:ACTIVE_TALENT_GROUP_CHANGED()
		self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		
		addon:Hide()
	end
end

function frame:PLAYER_REGEN_ENABLED()
	--if addon.showWhenOutOfCombat then
	--addon:Show()
	--oocFadeAnim:Stop()
		--addon.showWhenOutOfCombat = false
	--end
end

function frame:PLAYER_REGEN_DISABLED()
	--if isVisible then
		--print(title .. ": Options will open when you leave comat.")
		--addon:Hide()
	--oocFadeAnim:Stop()
	--addon.showWhenOutOfCombat = true
	--isVisible = false
	--end
end

function frame:ACTIVE_TALENT_GROUP_CHANGED()
	if GetSpecialization() == SPEC_PRIEST_SHADOW then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		
		moverFrame:SetScript("OnMouseDown", OnMouseDown)
		moverFrame:SetScript("OnMouseUp", OnMouseUp)
		
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		
		moverFrame:SetScript("OnMouseDown", nil)
		moverFrame:SetScript("OnMouseUp", nil)
		
		addon:Hide()
	end
end

function addon:Show()
	UnlockFrame()
	window:Show()
	moverFrame:Show()
	AceConfigDialog:Open("VilinkasInsanityOptions", container)
	isVisible = true
end

function addon:Hide()
	LockFrame()
	window:Hide()
	moverFrame:Hide()
	isVisible = false
end
