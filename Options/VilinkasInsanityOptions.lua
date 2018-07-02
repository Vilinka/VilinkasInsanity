if select(2, UnitClass("player")) ~= "PRIEST" then return end
--if tonumber(select(4, GetBuildInfo())) < 80000 then return end

local name, addon = ...
_G[name] = addon

local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local VilinkasInsanity = _G["VilinkasInsanity"]
local VilinkasInsanityVer = GetAddOnMetadata("VilinkasInsanity", "Version")
local vilinsFrame, oocFadeAnim = VilinkasInsanity.frames.main, VilinkasInsanity.oocFadeAnim

local title = VilinkasInsanity.title

local isVisible
local db

local frame = CreateFrame("Frame", name .. "MainFrame", UIParent)
frame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
local moverFrame = CreateFrame("Frame", name .. "MainFrame", frame)
local moverFontString = moverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local container, window

addon.frame = frame

local function CreateOptions()
	local function Get(info)
		local category, option = string.split(".", info.arg)
		--print("Set: category: " .. category .. " option: ".. option)
		local val = VilinkasInsanity.db.profile[category][option]
		--print(category .. "/" .. option)
		if type(val) == "table" then
			--print(unpack(val))
			return unpack(val)
		else
			--print(val)
			return val
		end
	end
	
	local function Set(info, ...)
		local category, option = string.split(".", info.arg)
		--print("Set: category: " .. category .. " option: ".. option)
		if select(2, ...) then
			local value = {}
			value[1] = select(1, ...)
			value[2] = select(2, ...)
			value[3] = select(3, ...)
			value[4] = select(4, ...)
			VilinkasInsanity.db.profile[category][option] = value
		else
			VilinkasInsanity.db.profile[category][option] = select(1, ...)
		end
		
		if option == "orientation" then
			local width = VilinkasInsanity.db.profile.general.width
			local height = VilinkasInsanity.db.profile.general.height
			VilinkasInsanity.db.profile.general.width = height
			VilinkasInsanity.db.profile.general.height = width
		end
		
		VilinkasInsanity:UpdateSettings()
	end
	
	local function ClearVfReps()
		VilinkasInsanity:ClearSavedVfReps()
	end
	
	local options = {
		type = "group",
		childGroups = "tree",
		get = Get,
		set = Set,
		args = {
			displayGroup = {
				type = "group",
				name = "General",
				order = 1,
				args = {
					posheader = {
						type = "header",
						name = "Position",
						order = 4
					},
					--[[anchor = {
						type = 'select',
						name = "",
						order = 5,
						values = { 
							["SCREEN"] = "Screen",
							["PRD"] = "Personal resource display",
						},
						arg = "general.anchor"
					},]]--
					posx = {
						type = "range",
						name = "X",
						order = 5,
						softMin = -math.floor((UIParent:GetWidth() / 2) + 0.5),
						softMax = math.floor((UIParent:GetWidth() / 2) + 0.5),
						step = 1,
						arg = "general.posx"
					},
					posy = {
						type = "range",
						name = "Y",
						order = 5,
						softMin = -math.floor((UIParent:GetHeight() / 2) + 0.5),
						softMax = math.floor((UIParent:GetHeight() / 2)  + 0.5),
						step = 1,
						arg = "general.posy"
					},
					sizeheader = {
						type = "header",
						name = "Size",
						order = 6
					},
					width = {
						type = "range",
						name = "Width",
						order = 7,
						min=1,
						softMin = 10,
						softMax = 500,
						step = 1,
						arg = "general.width"
					},
					height = {
						type = "range",
						name = "Height",
						order = 7,
						min=1,
						softMin = 10,
						softMax = 500,
						step = 1,
						arg = "general.height"
					},
					oocheader = {
						type = "header",
						name = "Out of combat",
						order = 8
					},
					alphaooc = {
						type = "range",
						name = "Opacity out of combat",
						arg = "general.alphaooc",
						order = 9,
						min = 0,
						max = 1,
						step = 0.01,
						isPercent = true
					},
					backgroundheader = {
						type = "header",
						name = "Background",
						order = 10
					},
					backgroundcolor = {
						type = "color",
						name = "Color",
						order = 11,
						hasAlpha = true,
						arg = "background.color"
					},
					borderheader = {
						type = "header",
						name = "Border",
						order = 12
					},
					bordercolor = {
						type = "color",
						name = "Color",
						order = 13,
						hasAlpha = true,
						arg = "border.color"
					},
					borderthickness = {
						type = "range",
						name = "Thickness",
						order = 13,
						min = 1,
						softMax = 5,
						step = 1,
						arg = "border.thickness"
					},
					vfmarkheader = {
						type = "header",
						name = "Enter voidform mark",
						order = 14
					},
					vfmarkcolor = {
						type = "color",
						name = "Color",
						order = 15,
						hasAlpha = true,
						arg = "overlay.color"
					},
					vfmarkthickness = {
						type = "range",
						name = "Thickness",
						order = 15,
						min = 1,
						softMax = 5,
						step = 1,
						arg = "overlay.thickness"
					},
				}
			},
			bars = {
				type = "group",
				name = "Bars",
				order = 2,
				args = {
					textureselect = {
						type = 'select',
						dialogControl = 'LSM30_Statusbar',
						order = 1,
						name = "Bar texture",
						values = LSM:HashTable("statusbar"),
						arg = "bars.texture"
					},
					insanityheader = {
						type = "header",
						name = "Insanity bar",
						order = 2
					},
					containercolor = {
						type = "color",
						name = "Color",
						order = 3,
						hasAlpha = false,
						arg = "bars.insbarcolor"
					},
					castbarheader = {
						type = "header",
						name = "Cast bar",
						order = 4
					},
					castbarcolor = {
						type = "color",
						name = "Color",
						order = 5,
						hasAlpha = false,
						arg = "bars.castbarcolor"
					},
					asbarheader = {
						type = "header",
						name = "Auspicious spirits bar",
						order = 6
					},
					asbarcolor = {
						type = "color",
						name = "Color",
						order = 7,
						hasAlpha = false,
						arg = "bars.asbarcolor"
					}
				}
			},
			text = {
				type = "group",
				name = "Text",
				order = 3,
				args = {
					fontfile = {
						type = 'select',
						dialogControl = 'LSM30_Font',
						name = "Font",
						order = 1,
						values = LSM:HashTable("font"),
						arg = "text.file"
					},
					outline = {
						type = 'select',
						name = "Outline",
						order = 1,
						values = { 
							["OUTLINE, MONOCHROME"] = "Monochrome Outline",
							["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
							["NONE"] = "None",
							["OUTLINE"] = "Outline",
							["THICKOUTLINE"] = "Thick Outline",
						},
						arg = "text.flag"
					},
					insanitytextheader = {
						type = "header",
						name = "Insanity text",
						order = 2
					},
					insanitytextdisc = {
						type = "description",
						name = "Displays your current insanity value, predicted insanity generated by successful spell cast and insanity generated by auspicious spirits.\nFormat: auspicious spirits + sucessful cast + current insanity",
						order = 3
					},
					insanitytextcolor = {
						type = "color",
						name = "Insanity color",
						order = 4,
						hasAlpha = false,
						arg = "text.insanitycolor"
					},
					casttextcolor = {
						type = "color",
						name = "Cast color",
						order = 5,
						hasAlpha = false,
						arg = "text.castcolor"
					},
					astextcolor = {
						type = "color",
						name = "Auspicious spirits color",
						order = 6,
						hasAlpha = false,
						arg = "text.ascolor"
					},
					insanitytextsize = {
						type = "range",
						name = "Size",
						min = 6,
						max = 72,
						step = 1,
						order = 7,
						arg = "text.insanitysize"
					},
					vfstacktextheader = {
						type = "header",
						name = "Voidform stack and haste text",
						order = 8
					},
					vfstacktextdisc = {
						type = "description",
						name = "Displays current voidform stack and player haste.",
						order = 9
					},
					vfstacktextcolor = {
						type = "color",
						name = "Color",
						order = 10,
						hasAlpha = false,
						arg = "text.vfstackcolor"
					},
					vfstacktextsize = {
						type = "range",
						name = "Size",
						min = 6,
						max = 72,
						step = 1,
						order = 10,
						arg = "text.vfstacksize"
					},
					vftimetextheader = {
						type = "header",
						name = "Voidform time text",
						order = 11
					},
					vftimetextdisc = {
						type = "description",
						name = "Displays your remaining time in voidform.",
						order = 12
					},
					vftimetextcolor = {
						type = "color",
						name = "Color",
						order = 13,
						hasAlpha = false,
						arg = "text.vftimecolor"
					},
					vftimetextsize = {
						type = "range",
						name = "Size",
						min = 6,
						max = 72,
						step = 1,
						order = 13,
						arg = "text.vftimesize"
					},
				}
			},
			animations = {
				type = "group",
				name = "Animations",
				order = 4,
				args = {
					oocheader = {
						type = "header",
						name = "Out of combat animation",
						order = 1
					},
					oocduration = {
						type = "range",
						name = "Duration",
						min = 0,
						softMax = 5,
						step = 0.1,
						order = 2,
						arg = "animations.oocduration"
					},
					oocstartdelay = {
						type = "range",
						name = "Start Delay",
						min = 0,
						softMax = 5,
						step = 0.1,
						order = 2,
						arg = "animations.oocstartdelay"
					},
					pulseheader = {
						type = "header",
						name = "Ready to enter voidform animation",
						order = 3
					},
					pulsecolor = {
						type = "color",
						name = "Color",
						order = 4,
						hasAlpha = false,
						arg = "animations.bordercolor"
					},
					pulseduration = {
						type = "range",
						name = "Duration",
						min = 0,
						softMax = 5,
						step = 0.1,
						order = 4,
						arg = "animations.borderduration"
					},
				}
			},
			gcd = {
				type = "group",
				name = "Gcd",
				order = 5,
				args = {
					gcdtoggle = {
						type = 'toggle',
						name = "Enable",
						order = 1,
						arg = "gcd.enable"
					},
					gcdanchorheader = {
						type = "header",
						name = "Anchor point",
						order = 2
					},
					gcdanchordescription = {
						type = "description",
						name = "Anchor point relative to the bar.",
						order = 3
					},
					gcdanchorselect = {
						type = 'select',
						name = "Anchor point",
						order = 4,
						values = {
							["TOP"] = "Top",
							["BOTTOM"] = "Bottom",
						},
						arg = "gcd.pos"
					},
					gcdbarheader = {
						type = "header",
						name = "Gcd bar",
						order = 5
					},
					gcdheightrange = {
						type = "range",
						name = "Height",
						min = 1,
						softMin = 1,
						softMax = 25,
						step = 1,
						order = 6,
						arg = "gcd.height"
					},
					gcdcolor = {
						type = "color",
						name = "Color",
						order = 7,
						hasAlpha = false,
						arg = "gcd.barcolor"
					},
					depletetoggle = {
						type = 'toggle',
						name = "Deplete",
						order = 8,
						arg = "gcd.deplete"
					},
				},
			},
			mindbender = {
				type = "group",
				name = "Mindbender",
				order = 6,
				args = {
					toggle = {
						type = 'toggle',
						name = "Enable",
						order = 1,
						arg = "mindbender.enable"
					},
					anchorheader = {
						type = "header",
						name = "Anchor point",
						order = 2
					},
					anchordescription = {
						type = "description",
						name = "Anchor point relative to the bar.",
						order = 3
					},
					anchorselect = {
						type = 'select',
						name = "Anchor point",
						order = 4,
						values = {
							["TOP"] = "Top",
							["BOTTOM"] = "Bottom",
						},
						arg = "mindbender.pos"
					},
					barheader = {
						type = "header",
						name = "Mindbender bar",
						order = 5
					},
					heightrange = {
						type = "range",
						name = "Height",
						min = 1,
						softMin = 1,
						softMax = 25,
						step = 1,
						order = 6,
						arg = "mindbender.height"
					},
					color = {
						type = "color",
						name = "Color",
						order = 7,
						hasAlpha = false,
						arg = "mindbender.barcolor"
					},
					depletetoggle = {
						type = 'toggle',
						name = "Deplete",
						order = 8,
						arg = "mindbender.deplete"
					},
					markheader = {
						type = "header",
						name = "Mindbender next attack mark",
						order = 9
					},
					markcolor = {
						type = "color",
						name = "Color",
						order = 10,
						hasAlpha = true,
						arg = "mindbender.markcolor"
					},
					markthickness = {
						type = "range",
						name = "Thickness",
						order = 11,
						min = 1,
						softMax = 5,
						step = 1,
						arg = "mindbender.markthickness"
					},
				},
			},
			misc = {
				type = "group",
				name = "Misc",
				order = 7,
				args = {
					liheader = {
						type = "header",
						name = "Lingering Insanity",
						order = 1
					},
					lidescription = {
						type = "description",
						name = "Choose whether to display Lingering Insanity stacks when this talent is selected.",
						order = 2
					},
					litoggle = {
						type = 'toggle',
						name = "Show",
						order = 3,
						arg = "misc.lingeringinsanity"
					},
					lotvheader = {
						type = "header",
						name = "Legacy of The Void",
						order = 4
					},
					lotvdescription = {
						type = "description",
						name = "If Legacy of The Void telent is selected, change at which insanity value 'Ready to enter voidform animation' starts playing.",
						order = 5
					},
					lotvrange = {
						type = "range",
						name = "Insanity",
						min = 65,
						max = 100,
						step = 1,
						order = 6,
						arg = "misc.lotvthreshold"
					},
					vfreportheader = {
						type = "header",
						name = "Voidform reports",
						order = 7
					},
					vfreportdescription = {
						type = "description",
						name = "At the end of voidform optionally display and save a report. To access saved reports use command |cFF9370DB/vilins vf|r.",
						order = 8
					},
					vfdisreportselect = {
						type = 'select',
						name = "Dispaly options",
						order = 9,
						values = {
							[0] = "Disable",
							[1] = "Display only STM",
							[2] = "Always display",
						},
						arg = "misc.vfdisreportingenabled"
					},
					vfsavereportselect = {
						type = 'select',
						name = "Save options",
						order = 10,
						values = {
							[0] = "Disable",
							[1] = "Save only STM",
							[2] = "Always save",
						},
						arg = "misc.vfsavereportingenabled"
					},
					vfreportarchiverange = {
						type = 'range',
						name = "Maximum number of saved reports",
						--width = "full",
						min = 1,
						max = 7,
						step = 1,
						order = 11,
						arg = "misc.vfreportingmaxsaved"
					},
					vfreportcleararchivebutton = {
						type = "execute",
						name = "Clear saved reports",
						func = ClearVfReps,
						order = 12
					},
					--[[patchheader = {
						type = "header",
						name = "Patch 7.1.5",
						order = 12
					},
					patchdescription = {
						type = "description",
						name = "Enable patch 7.1.5 changes to shadow priest.",
						order = 13
					},
					patchtoggle = {
						type = "toggle",
						name = "Enable",
						order = 14,
						arg = "misc.patch70105enable"
					},]]--
				}
			}
		}
	}
	
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
	vilinsFrame:SetMovable(true)
	VilinkasInsanity:UnregisterEvent("PLAYER_REGEN_ENABLED")
	VilinkasInsanity:UnregisterEvent("PLAYER_REGEN_DISABLED")
	vilinsFrame:Show()
	vilinsFrame:SetAlpha(1)
end

local function LockFrame()
	vilinsFrame:SetMovable(false)
	VilinkasInsanity:ACTIVE_TALENT_GROUP_CHANGED()
end

local function OnMouseDown()
	vilinsFrame:StartMoving()
end

local function OnMouseUp()
	vilinsFrame:StopMovingOrSizing()
	local point, _, _, xOffset, yOffset = vilinsFrame:GetPoint(1)
	xOffset, yOffset = GetPositionRelToCenter(point, xOffset, yOffset)
	VilinkasInsanity.db.profile.general.posx = xOffset
	VilinkasInsanity.db.profile.general.posy = yOffset
	AceConfigDialog:Open("VilinkasInsanityOptions", container)
end

local function OnClose()
	addon:Hide()
end

local function InitFrames()
	container = AceGUI:Create("SimpleGroup")
	
	window = AceGUI:Create("Frame")
	window:SetTitle("Vilinka's Insanity Options (" .. VilinkasInsanityVer .. ")")
	window:SetLayout("Fill")
	window:SetCallback("OnClose", OnClose)
	window:AddChild(container)
	
	moverFrame:ClearAllPoints()
	moverFrame:SetPoint("TOPLEFT", vilinsFrame, "TOPLEFT")
	moverFrame:SetPoint("BOTTOMRIGHT", vilinsFrame, "BOTTOMRIGHT")
	moverFontString:SetText("Drag to move")
	moverFontString:SetPoint("CENTER", moverFrame, "TOP", 0, 10)
end

frame:RegisterEvent("ADDON_LOADED")
function frame:ADDON_LOADED(...)
	if name == ...	then
		local yOffset = UIParent:GetHeight()
		default = {
			profile = {
				width = 600,
				top = yOffset - 50,
				left = 50,
			}
		}
		self.db = LibStub("AceDB-3.0"):New("VilinkasInsanityOptionsDB", default, true)
		db = self.db.profile
		
		InitFrames()
		
		window:SetStatusTable(db)
		
		AceConfig:RegisterOptionsTable("VilinkasInsanityOptions", CreateOptions())
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
