local LSM = LibStub("LibSharedMedia-3.0")
local pairs, ipairs, select, unpack = pairs, ipairs, select, unpack
local format, sqrt = format, sqrt
local GetTime, GetNetStats, GetSpellCooldown = GetTime, GetNetStats, GetSpellCooldown
local UnitAura, UnitPower, UnitAffectingCombat, UnitGUID = UnitAura, UnitPower, UnitAffectingCombat, UnitGUID
local GetSpellPowerCost = GetSpellPowerCost
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

local title = "|cFF9370DB" .. select(2, GetAddOnInfo(...)) .. "|r"
--VilinkasInsanity.title = title

-- Shadow priest
local player = {
	class = "PRIEST",
	shadowSpec=SPEC_PRIEST_SHADOW,
	insanityPowerType=Enum.PowerType.Insanity,
	manaPowerType=Enum.PowerType.Mana,
	guid=nil, inCombat=false,
	insanity=0, maxInsnaity=100, predictedCastPowerGain=0, predictedPassivePowerGain=0,
	mana=0, maxMana=0, currentCastManaCost=0,
	haste=0,
}
local auras = {
	vform = {id=194249, active=false, duration=0, expirationTime=0, 
		stacks=0, currentStackTime=0, drainStacks=0, drainMod=1,
		baseThreshold=90, thresholdOverride=0, threshold=0, 
		thresholdShow = true, thresholdHideInVoidform=true },
	vtorrent = {id=263165, active=false},
	stmbuff = {id=193223, active=false, imul=2},
	stmdebuff = {id=263406, active=false, duration=0, expirationTime=0, display=false},
	linsanity = {id=197937, active=false, stacks=0, display=false},
}
local sfiend = {id=254232, active=false, display=false, duration=0, expirationTime=0,
	lastAttackTime=0, baseAttackSpeed=1.5, guid=nil, igain=2, idLeech=262485}
local talents = {
	lotvoid={active=false, tier=7, column=1, threshold=60},
	aspirits={active=false, tier=5, column=1, count=0, targets={}, idSpawn=147193, idDespawn=148859, igain=2},
	fotmind={active=false, tier=1, column=1, imul=1.2},
	mbender={active=false, tier=1, column=1, id=200174, igain=6, idLeech=200010}
}
-- Traits
local traits = {}
-- Spell insnaity
local spellInsanityGain = {
	-- Mind blast
	[8092] = function() 
		local imul = 1
		if talents.fotmind.active then
			imul = imul * talents.fotmind.imul
		end
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 12 * imul
	end,
	-- Shadow Word: Void
	[205351] = function()
		local imul = 1
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 15 * imul
	end,
	-- Vampiric Touch
	[34914] = function()
		local imul = 1
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 6 * imul
	end,
	-- Mind flay
	[15407] = function()
		local imul = 1
		if talents.fotmind.active then
			imul = talents.fotmind.imul
		end
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 3 * imul
	end,
	-- Mind sear
	[48045] = function()
		local imul = 1
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 3 * imul 
	end,
	-- Dark void
	[263346] = function()
		local imul = 1
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 30 * imul
	end,
	-- Shadow crash
	[205385] = function()
		local imul = 1
		if auras.stmbuff.active then
			imul = imul * auras.stmbuff.imul
		end
		return 20 * imul
	end,
}
-- Spell mana cost
local spellManaCost = {
	-- Dispersion
	[32375] = function() return select(4, GetSpellPowerCost(32375)) end
}
local function returnZero()
	return 0
end
setmetatable(spellInsanityGain, {
	__index = function()
		return returnZero
	end})
setmetatable(spellManaCost, {
	__index = function()
		return returnZero
	end})
-- Text colors
local hexColors = { insnaity, cast, passive }
-- VF reports
local reports = { current={}, encounterName }
-- GCD
local gcd = { start=0, duration=0, enable=false }
-- DB
local db, defaults

local function GetPlayerAuraInfo(id, filter)
	for i = 1, 40 do
		local name, _, count, _, duration, expirationTime, _, _, _, spellId = UnitAura("player", i, filter);
		if (not name) then
			break;
		elseif (id == spellId) then
			return true, count, duration, expirationTime;
		end
	end
	return false, 0, 0, 0
end

local function GetPlayerBuffInfo(id)
	return GetPlayerAuraInfo(id, "HELPFUL")
end

local function IsPriest()
	local _, class = UnitClass("player");
	return (class == "PRIEST")
end

local function IsShadow()
	local spec = GetSpecialization()
	return (spec == SPEC_PRIEST_SHADOW)
end

VilinkasInsnaityBuilder = {}

function VilinkasInsnaityBuilder:OnLoad()
	self.tex = self:CreateTexture(nil, "BACKGROUND", nil, 1)
	self.Updater = CreateFrame("Frame", nil, self)
	self.offset = {
		["TOP"] = 0,
		["BOTTOM"] = 0
	}
end

local function GetBaseValueRecursion(self)
	local value = self:GetValue()
	local pBar = self.pBar
	if pBar then
		value = value + GetBaseValueRecursion(pBar)
	end
	return value
end

function VilinkasInsnaityBuilder:GetBaseValue()
	local value = 0
	local pBar = self.pBar
	if pBar then
		value = GetBaseValueRecursion(pBar)
	end
	return value
end

local function VilinkasInsnaityBuilder_OnUpdate(self)
	self:SetScript("OnUpdate", nil)
	local bar = self:GetParent();
	local tex = bar.tex;
	local totalWidth = bar:GetWidth();
	local _, maxValue = bar:GetMinMaxValues();

	local baseValue = bar:GetBaseValue()
	local value = bar:GetValue()

	if (baseValue + value) > maxValue then
		value = maxValue - baseValue
	end

	local leftPosition = baseValue / maxValue * totalWidth
	local width = value / maxValue * totalWidth;

	if (width < 0.5) then
		tex:Hide()
		return
	end

	local texMinX = Clamp(baseValue / maxValue, 0, 1.0);
	local texMaxX = Clamp((value + baseValue) / maxValue, 0, 1.0);

	local topOffset = bar.offset["TOP"]
	local bottomOffset = bar.offset["BOTTOM"]
	local totalHeight = bar:GetHeight()
	local texMinY = Clamp(1 - (topOffset / totalHeight), 0, 1.0)
	local texMaxY = Clamp((bottomOffset / totalHeight), 0, 1.0)

	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", leftPosition, -topOffset)
	tex:SetPoint("BOTTOMLEFT", leftPosition, bottomOffset)
	tex:SetWidth(width)
	tex:SetTexCoord(texMinX, texMaxX, texMinY, texMaxY)
	tex:Show()
end

function VilinkasInsnaityBuilder:OnChanged()
	self.Updater:SetScript("OnUpdate", VilinkasInsnaityBuilder_OnUpdate)
	local nBar = self.nBar
	if nBar then
		nBar:OnChanged()
	end
end

function VilinkasInsnaityBuilder:SetOffset(offset, point)
	self.offset[point] = offset

	local nBar = self.nBar
	if nBar then
		nBar:SetOffset(offset, point)
	end
	self:OnChanged()
end

function VilinkasInsnaityBuilder:GetOffset(point)
	return self.offset[point]
end

VilinkasInanityBackground = {}

function VilinkasInanityBackground:OnLoad()
	self.offset = {
		["TOP"] = 0,
		["BOTTOM"] = 0
	}
end

function VilinkasInanityBackground:SetOffset(offset, point)
	self.offset[point] = offset

	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", 0, -self.offset["TOP"])
	self:SetPoint("BOTTOMRIGHT", 0, self.offset["BOTTOM"])
end

function VilinkasInanityBackground:GetOffset(point)
	return self.offset[point]
end

VilinkasInanityBorder = {}

function VilinkasInanityBorder:OnLoad()
	self.offset = {
		["TOP"] = 0,
		["BOTTOM"] = 0
	}
end

function VilinkasInanityBorder:SetOffset(offset, point)
	self.offset[point] = offset

	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", 0, self.offset["TOP"])
	self:SetPoint("BOTTOMRIGHT", 0, -self.offset["BOTTOM"])
end

function VilinkasInanityBorder:GetOffset(point)
	return self.offset[point]
end

VilinkasInsnaityAnimatedBorder = {}

function VilinkasInsnaityAnimatedBorder:OnLoad()
	self.initialized = false
	self.insane = false
	self.madness = false
	self.voidformReady = false
	self.powerType = Enum.PowerType.Insanity
	self.powerToken = "INSANITY"
end

function VilinkasInsnaityAnimatedBorder:Initialize(voidformThreshold)
	self.voidformThreshold = voidformThreshold
	self.initialized = true
end

function VilinkasInsnaityAnimatedBorder:UpdatePower()
	if (not self.initialized) then
		return;
	end
	local power = UnitPower("player", self.powerType)
	if (not self.insane and not self.madness) then
		local voidformReady = (power >= self.voidformThreshold)
		if (voidformReady and not self.voidformReady) then
			self.Pulse:Play()
		elseif (not voidformReady and self.voidformReady) then
			self.Pulse:Finish()
		end
		self.voidformReady = voidformReady
	end
end

local function IsMad()
	for i = 1, 40 do
		local spellId = select(10, UnitAura("player", i, "HARMFUL"))
		if (not spellId) then
			break;
		elseif (spellId == 263406) then
			return true
		end
	end
end

function VilinkasInsnaityAnimatedBorder:UpdateAuras()
	if (not self.initialized) then
		return;
	end
	local insane, mad = IsInsane(), IsMad()
	if (mad and not self.mad) then
		self.Fadeout:Stop()
		self.Pulse:Stop()
		self:Show()
		self:SetBackdropBorderColor(unpack(self.stmdebuffColor))
	elseif (not mad and self.mad) then
		self.Fadeout:Play()
	elseif (insane and not self.insane) then
		self.Fadeout:Stop()
		self.Pulse:Stop()
		self:Show()
		self:SetAlpha(self.voidformColor[4])
	elseif (not insane and self.insane) then
		self.Fadeout:Play()
	end

	self.insane, self.madness = insane, madness
end

function VilinkasInsnaityAnimatedBorder:UpdateSettings(newSettings)
	local borderSettings = newSettings.general.border

	if borderSettings.animated.enable then
		local thickness = borderSettings.normal.thickness
		local offset = borderSettings.animated.offset

		local parent = self:GetParent()
		self:ClearAllPoints()
		self:SetPoint("LEFT", parent, "LEFT", -thickness - offset.left, 0)
		self:SetPoint("RIGHT", parent, "RIGHT", thickness + offset.right, 0)
		self:SetPoint("TOP", parent, "TOP", 0, thickness + offset.top)
		self:SetPoint("BOTTOM", parent, "BOTTOM", 0, -thickness - offset.bottom)

		self:SetBackdrop({
			edgeFile = LSM:Fetch("border", borderSettings.animated.texture),
			tile = true,
			edgeSize = thickness + offset.thickness,
			--alphaMode = "DISABLE",
			insets = {0, 0, 0, 0}
		})
		self.voidformColor = borderSettings.animated.colorvf
		self:SetBackdropBorderColor(unpack(self.voidformColor))
		self.stmdebuffColor = borderSettings.animated.colorstm

		-- Animations
		local animationSettings = newSettings.animations.animatedborder
		self.Pulse.AlphaOut:SetToAlpha(self.voidformColor[4])
		self.Pulse.AlphaIn:SetFromAlpha(self.voidformColor[4])
		self.Pulse.AlphaOut:SetDuration(animationSettings.pulseduration / 2)
		self.Pulse.AlphaIn:SetDuration(animationSettings.pulseduration / 2)
		self.Fadeout.Alpha:SetFromAlpha(self.voidformColor[4])

		if (borderSettings.animated.animatedontop) then
			self:SetFrameLevel(12)
		else
			self:SetFrameLevel(10)
		end
	else
		self:SetBackdrop(nil)
	end
end

VilinkasInsanityMark = {}

function VilinkasInsanityMark:SetOffset(offset)
	if offset > 1 then
		offset = 1
	elseif offset < 0 then
		offset = 0
	end

	local parent = self:GetParent()
	local parentWidth = parent:GetWidth()
	local markHalfWidth = self:GetWidth() / 2

	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", parent, "TOPLEFT", parentWidth * offset - markHalfWidth, 0)
	self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -parentWidth * (1 - offset) + markHalfWidth, 0)
end

VilinkasInsanityVoidformThresholdMark = {}

function VilinkasInsanityVoidformThresholdMark:OnVoidformStart()
	if auras.vform.thresholdHideInVoidform then
		self:Hide()
	end
end

function VilinkasInsanityVoidformThresholdMark:OnVoidformEnd()
	if auras.vform.thresholdShow then
		self:Show()
	end
end

VilinkasInsanityExtraFrame = {}

function VilinkasInsanityExtraFrame:OnLoad()
	local parent = self:GetParent()
	parent.ExtraBars[self:GetName()] = self
end

function VilinkasInsanityExtraFrame:OnSizeChanged(w, h)
	local parent = self:GetParent()
	parent:ExtraBarOnSizeChanged(self)
end

function VilinkasInsanityExtraFrame:UpdateSettings(height, active)
	self.height = height
	self.active = active
	if (not self.active) then
		self:Hide()
	end
end

VilinkasInsanityGcd = {}

function VilinkasInsanityGcd:OnLoad()
	VilinkasInsanityExtraFrame.OnLoad(self)

	self:SetMinMaxValues(0, 1);
end

local function VilinkasInsanityGcd_OnUpdate(self)
	local currTime = GetTime();
	local netTime = 0;--select(4, GetNetStats()) / 1000)
	local pct = (currTime - self.start - netTime) / self.duration;
	if (pct > 1) then
		self:SetScript("OnUpdate", nil);
		self:SetValue(0);
		self:Hide();
	else
		if (self.deplete) then
			self:SetValue(1-pct);
		else
			self:SetValue(pct);
		end
	end
end

function VilinkasInsanityGcd:StartGcd(spellID)
	local start, duration = GetSpellCooldown(spellID);
	if (self.active) and (start > 0) then
		self.start = start;
		self.duration = duration;
		self:Show();
		self:SetScript("OnUpdate", VilinkasInsanityGcd_OnUpdate);
	end
end

function VilinkasInsanityGcd:UpdateSettings(newSettings)
	local gcdSettings = newSettings.bars.gcd
	local height = gcdSettings.height
	local active = gcdSettings.enable
	VilinkasInsanityExtraFrame.UpdateSettings(self, height, active)

	self.deplete = gcdSettings.deplete

	if gcdSettings.background.enable then
		self:SetBackdrop({
			bgFile = LSM:Fetch("background", gcdSettings.background.texture),
			tile = true,
			tileSize=self:GetWidth(),
		})
		self:SetBackdropColor(unpack(gcdSettings.background.color))
	else
		self:SetBackdrop(nil)
	end

	local bartex
	if newSettings.bars.useMainTexture then
		bartex = LSM:Fetch("statusbar", newSettings.bars.main.texture)
	else
		bartex = LSM:Fetch("statusbar", gcdSettings.texture)
	end
	self:SetStatusBarTexture(bartex)
	self:SetStatusBarColor(unpack(gcdSettings.color))
end

VilinkasInsanityMana = {}

function VilinkasInsanityMana:OnLoad()
	VilinkasInsanityExtraFrame.OnLoad(self)

	self.unit = "player"
	self.powerType = Enum.PowerType.Mana
	self.powerToken = "MANA"
	self.visiblityThreshold = 1
	self.baseAttackSpeed = 1.5

	self:SetMinMaxValues(0, 1)
end

function VilinkasInsanityMana:Initialize(visiblityThreshold)
	self.visiblityThreshold = visiblityThreshold
end

function VilinkasInsanityMana:UpdateMaxPower()
	self.maxPower = UnitPowerMax("player", self.powerType)
end

function VilinkasInsanityMana:UpdatePower(powerToken)
	if (self.powerToken == powerToken) and (self.active) then
		local power = UnitPower("player", self.powerType)
		local ptc = power / self.maxPower
		if ptc >= self.visiblityThreshold then
			self:SetValue(0);
			self:Hide();
		else
			self:Show()
			self:SetValue(ptc)
		end
	end
end

function VilinkasInsanityMana:UpdateSettings(newSettings)
	local manaSettings = newSettings.bars.mana
	local height = manaSettings.height
	local active = manaSettings.enable
	VilinkasInsanityExtraFrame.UpdateSettings(self, height, active)

	if manaSettings.background.enable then
		self:SetBackdrop({
			bgFile = LSM:Fetch("background", manaSettings.background.texture),
			tile = true,
			tileSize=self:GetWidth(),
		})
		self:SetBackdropColor(unpack(manaSettings.background.color))
	else
		self:SetBackdrop(nil)
	end

	local bartex
	if newSettings.bars.useMainTexture then
		bartex = LSM:Fetch("statusbar", newSettings.bars.main.texture)
	else
		bartex = LSM:Fetch("statusbar", manaSettings.texture)
	end
	self:SetStatusBarTexture(bartex)
	self:SetStatusBarColor(unpack(manaSettings.color))

	self:Initialize(manaSettings.threshold)
end

VilinkasInsanityShadowfiend = {}

function VilinkasInsanityShadowfiend:OnLoad()
	VilinkasInsanityExtraFrame.OnLoad(self)
	VilinkasInsnaityGenerator.OnLoad(self)

	self.lastUpdateTime = 0

	self.shadowfiendId = 254232
	self.mindbenderTalentActive = false
	self.mindbenderId = 200174

	self.haveTotem = false
	self.guid = nil
	self.expirationTime = 0
	self.duration = 0
	self.lastAttackTime = 0
	self.baseAttackSpeed = 1.5

	self:SetMinMaxValues(0, 1)
end

local function VilinkasInsanityShadowfiend_OnUpdate(self)
	local currTime = GetTime();
	local timeLeft = self.expirationTime - currTime

	if (not self.haveTotem) or (timeLeft <= 0) then
		self.haveTotem = false
		self:Hide()
		self.insanityGain = 0
		return;
	end

	local pct = (self.expirationTime - currTime) / self.duration

	if (self.deplete) then
		self:SetValue(pct)
	else
		self:SetValue(1 - pct)
	end

	local elapsed = currTime - self.lastUpdateTime

	if (elapsed > 0.1) then
		-- Do stuff we dont need every frame
		self.lastUpdateTime = currTime

		self.TimeLeftText:SetText(format("%.1f", timeLeft))

		local attacksSpeed = self.baseAttackSpeed / (1 + (player.haste / 100))
		local predictedTimeNextAttack = self.lastAttackTime + attacksSpeed
		
		if (predictedTimeNextAttack - currTime) < -0.5 then
			-- Remove attack mark
			self.NextAttackMark:Hide()
			self.insanityGain = 0
		else
			-- Continue as normal
			local nextAttackPtc = (self.expirationTime - predictedTimeNextAttack) / self.duration

			if (self.deplete) then
				self.NextAttackMark:SetOffset(nextAttackPtc)
			else
				self.NextAttackMark:SetOffset(1 - nextAttackPtc)
			end

			self.NextAttackMark:Show()

			if talents.mbender.active then
				self.insanityGain = talents.mbender.igain
			else
				self.insanityGain = sfiend.igain
			end
		end
	end
end

function VilinkasInsanityShadowfiend:Setup()
	if (self.active) then
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:SetScript("OnUpdate", VilinkasInsanityShadowfiend_OnUpdate)
		self:UpdateTalents()
		self:Activate()
		self:SetPlayerGUID()
	else
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("PLAYER_TALENT_UPDATE")
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:SetScript("OnUpdate", nil)
	end

	self:Hide()
end

function VilinkasInsanityShadowfiend:SetPlayerGUID()
	self.playerGuid = UnitGUID("player")
end

function VilinkasInsanityShadowfiend:OnEvent(event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Activate()
		self:SetPlayerGUID()
	elseif (event == "PLAYER_TALENT_UPDATE") then
		self:UpdateTalents()
	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _, logEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
		if (sourceGUID == self.playerGuid) then
			if (spellId == sfiend.id) or (spellId == talents.mbender.id) then
				if logEvent == "SPELL_SUMMON" then
					self:Activate()
					self.guid = destGUID
				end
			elseif (logEvent == "UNIT_DIED") then
				self:Activate()
			end
		elseif (sourceGUID == self.guid) then
			if (logEvent == "SWING_DAMAGE") then
				self.lastAttackTime = GetTime()
			end
		-- Power Leech (Mindbender Power Leech spell (200010))
		elseif (destGUID == self.playerGuid) then
			if (logEvent == "SPELL_ENERGIZE") then
				if (spellId == sfiend.idLeech) or (spellId == talents.mbender.idLeech) then
					self.lastAttackTime = GetTime()
					self.guid = sourceGUID
				end
			elseif (event == "UNIT_DIED") then
				self:Activate()
			end
		elseif (destGUID == self.guid) then
			if (logEvent == "UNIT_DIED") then
				self:Activate()
			end
		end
	end
end

function VilinkasInsanityShadowfiend:UpdateTalents()
	talents.mbender.active = select(4, GetTalentInfo(talents.mbender.tier, talents.mbender.column, 1))
end

function VilinkasInsanityShadowfiend:Activate()
	local haveTotem, _, startTime, duration = GetTotemInfo(1)
	self.haveTotem = haveTotem
	if (self.haveTotem) then
		self.duration = duration
		self.expirationTime = startTime + duration
		self.guid = nil
		self:Show()
	end
end

function VilinkasInsanityShadowfiend:UpdateSettings(newSettings)
	local sfSettings = newSettings.bars.shadowfiend
	local height = sfSettings.height
	local active = sfSettings.enable
	VilinkasInsanityExtraFrame.UpdateSettings(self, height, active)

	self:Setup()

	self.deplete = sfSettings.deplete

	if sfSettings.background.enable then
		self:SetBackdrop({
			bgFile = LSM:Fetch("background", sfSettings.background.texture),
			tile = true,
			tileSize=self:GetWidth(),
		})
		self:SetBackdropColor(unpack(sfSettings.background.color))
	else
		self:SetBackdrop(nil)
	end

	local bartex
	if newSettings.bars.useMainTexture then
		bartex = LSM:Fetch("statusbar", newSettings.bars.main.texture)
	else
		bartex = LSM:Fetch("statusbar", sfSettings.texture)
	end
	self:SetStatusBarTexture(bartex)
	self:SetStatusBarColor(unpack(sfSettings.color))

	if sfSettings.nextattack.enable then
		self.NextAttackMark.Texture:SetVertexColor(unpack(sfSettings.nextattack.color))
		self.NextAttackMark:SetWidth(sfSettings.nextattack.thickness)
		self.NextAttackMark.Texture:Show()
	else
		self.NextAttackMark.Texture:Hide()
	end

	local sfTextSettings = newSettings.text.shadowfiend

	local file, flag
	if newSettings.text.useMainText then
		file = LSM:Fetch("font",  newSettings.text.file)
		flag =  newSettings.text.flag
	else
		file = LSM:Fetch("font",  sfTextSettings.file)
		flag =  sfTextSettings.flag
	end
	
	self.TimeLeftText:SetFont(file, sfTextSettings.size, flag)

	if (sfTextSettings.enable) then
		self.TimeLeftText:Show()
	else
		self.TimeLeftText:Hide()
	end
end

VilinkasInsanityAuspiciousSpiritsTracker = {}

function VilinkasInsanityAuspiciousSpiritsTracker:OnLoad()
	VilinkasInsnaityGenerator.OnLoad(self)

	self.lastUpdateTime = 0
	self.count = 0
	self.targets = {}

	self.iGain = 2
end

local function VilinkasInsanityAuspiciousSpiritsTracker_OnUpdate(self)
	local currTime = GetTime()
	local elapsed = currTime - self.lastUpdateTime

	if (elapsed > 1) then
		-- Do stuff we dont need every frame (Text, AS)
		local targets = self.targets
		for guid in pairs(targets) do
			if targets[guid] ~= nil then
				if (currTime - targets[guid].lastUpdateTime) > 10 then
					self.count = self.count - targets[guid].count
					targets[guid] = nil
				end
			end
		end
		if self.count < 0 then
			self.count = 0
		end
		self.lastUpdateTime = currTime
	end
end

function VilinkasInsanityAuspiciousSpiritsTracker:Setup(active)
	self.active = active
	if (self.active) then
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
	end
end

function VilinkasInsanityAuspiciousSpiritsTracker:UpdateTalents()
	if not (self.active) then
		return;
	end

	local hasTalent = select(4, GetTalentInfo(talents.aspirits.tier, talents.aspirits.column, 1))
	if (hasTalent) then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:SetScript("OnUpdate", VilinkasInsanityAuspiciousSpiritsTracker_OnUpdate)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:SetScript("OnUpdate", nil)
		self:DestroyAll()
	end
end

function VilinkasInsanityAuspiciousSpiritsTracker:OnEvent(event)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:DestroyAll()
		self.playerGuid = UnitGUID("player")
	elseif (event == "PLAYER_TALENT_UPDATE") then
		self:UpdateTalents()
	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _, event, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
		if (sourceGUID == self.playerGuid) and (self.active) then
			if (spellId == 147193) then
				if event == "SPELL_CAST_SUCCESS" then
					self:OnSpawn(destGUID)
				end
			elseif (spellId == 148859) then
				if event == "SPELL_DAMAGE" or event == "SPELL_MISSED" then
					self:OnDespawn(destGUID)
				end
			elseif (event == "UNIT_DIED") then
				print("UNIT_DIED: Source is player")
			end
		end
		if (event == "UNIT_DIED") then
			if (destGUID == self.playerGuid) then
				self:DestroyAll()
			elseif (self.targets[destGUID]) then
				local count = self.targets[destGUID].count
				if count > 0 then
					self.count = self.count - count
				end
				self.targets[destGUID] = nil
			end
		end
	end
end

function VilinkasInsanityAuspiciousSpiritsTracker:DestroyAll()
	self.count = 0
	self.targets = {}
end

function VilinkasInsanityAuspiciousSpiritsTracker:OnSpawn(guid)
	targets = self.targets
	if not targets[guid] then
		targets[guid] = { count = 0 }
	end
	targets[guid].count = targets[guid].count + 1
	targets[guid].lastUpdateTime = GetTime()
	self.count = self.count + 1
end

function VilinkasInsanityAuspiciousSpiritsTracker:OnDespawn(guid)
	targets = self.targets
	if targets[guid] then
		targets[guid].asCount = targets[guid].count - 1
		if targets[guid].count <= 0 then
			targets[guid] = nil
		else
			targets[guid].lastUpdateTime = GetTime()
		end
		self.count = self.count - 1
		if self.count < 0 then
			self.count = 0
		end
	end
end

function VilinkasInsanityAuspiciousSpiritsTracker:GetInsanityGain()
	self.insanityGain = self.count * self.iGain
	return VilinkasInsnaityGenerator.GetInsanityGain(self)
end

VilinkasInsnaityGenerator = {}

function VilinkasInsnaityGenerator:OnLoad()
	self.insanityGain = 0
end

function VilinkasInsnaityGenerator:GetInsanityGain()
	local mul = 1
	if (false) then
		mul = 2
	end
	return self.insanityGain * mul
end

VilinkasInsnaity = {}

local function GetInsanityDrain(stack)
	return 6 + ((stack - 1) * (0.68) * auras.vform.drainMod)
end

local function GetVoidformTime(currTime)
	local vform = auras.vform
	if player.insanity > 0 and vform.stacks > 0 then
		-- Drain current stack
		local vfCurrStackTimeLeft = 1.0 - (currTime - vform.currentStackTime)-- + select(4, GetNetStats()) / 1000
		local vfCurrStackDrain = GetInsanityDrain(vform.drainStacks)
		if ((vfCurrStackDrain * vfCurrStackTimeLeft) > player.insanity) then
			vfCurrStackTimeLeft = player.insanity / vfCurrStackDrain
			return vfCurrStackTimeLeft
		else
			local ins = player.insanity - (vfCurrStackDrain * vfCurrStackTimeLeft)
			-- Sum d+(x-1)*f*dm, Sum x=m to n => (-1/2)*(m-n-1)*(2*d+f*dm*(m+n-2))=ins => Solve for n, d=6, f=(0.68)
			local dm, m = vform.drainMod, vform.drainStacks + 1 -- We already drained current stack
			--local vfRemStacks = (sqrt(dm*dm*(2*m-3)*(2*m-3)+dm*10*(ins+6*m-9)+225)+dm-15) / (2*dm)
            local vfRemStacks = (10*sqrt(2.89*dm*dm*(3-2*m)*(3-2*m)+dm*(204*m-(306-34*ins))+900)+17*dm-300) / (34*dm)
			return vfCurrStackTimeLeft + (vfRemStacks - vform.drainStacks)
		end
	else
		return 0
	end
end

local function PrintVfRep(report, fromArchive)
	if (reports.display == 1 and report.stmduration ~= nil) or reports.display == 2 or fromArchive == true then
		print(format(title .. " VF report: %s", date("%X %x", report.time)))
		if report.encounter then
			print("Encounter: " .. report.encounter)
		end
		
		print(format("VF duration: %.1fs", report.duration))
		if report.stmduration ~= nil then
			print(format("STM duration: %.1fs", report.stmduration))
		end
		print(format("VF stacks: %d", report.vfstacks))
		print(format("VF drain stacks (drain): %d (%.1f)", report.vfdrainstacks,  GetInsanityDrain(report.vfdrainstacks)))
	end
end

local function PrintSavedVfReps()
	if #db.vfreportarchive == 0 then
		print(title .. " VF report:")
		print("You currently have no saved reports.")
		return
	end
	print("------------------------")
	for _,v in pairs(db.vfreportarchive) do
		PrintVfRep(v, true)
		print("------------------------")
	end
end

local function SaveVfRep(report)
	if (reports.save == 1 and report.stmduration ~= nil) or reports.save == 2 then
		local size = #db.vfreportarchive
		local copyRep = {}
		for orig_key, orig_value in pairs(report) do
            copyRep[orig_key] = orig_value
        end
		table.insert(db.vfreportarchive, copyRep)
		local d = size - reports.maxSaved
		if d >= 0 then
			for i = 1,(d+1) do
				table.remove(db.vfreportarchive, 1)
			end
		end
	end
end

local function CreateVfRep()
	reports.current.time = time()
	reports.current.duration = GetTime()
	reports.current.encounter = reports.encounterName
	reports.current.vfstacks = 0
	reports.current.vfdrainstacks = 0
	reports.current.vfdrain = 0
end

local function FinaliseVfRep()
	local currentTime = GetTime()
	reports.current.duration = currentTime - reports.current.duration
	if reports.current.stmduration then
		reports.current.stmduration = currentTime - reports.current.stmduration
	end
	reports.current.vfdrain = GetInsanityDrain(reports.current.vfdrainstacks)
	PrintVfRep(reports.current, false)
	SaveVfRep(reports.current)
	
	reports.current.stmduration = nil
end

function VilinkasInsnaity:ClearSavedVfReps()
	for i = 1,#db.vfreportarchive do
		table.remove(db.vfreportarchive)
	end
	print(title .. " VF report:")
	print("Saved reports cleared!")
end

function VilinkasInsnaity:UpdateMaxPower()
	local maxValue = UnitPowerMax("player", self.powerType)
	self:SetMinMaxValues(0, maxValue)

	local vform = auras.vform
	local thresholdOverride = vform.thresholdOverride
	if talents.lotvoid.active then
		vform.threshold = thresholdOverride
	else
		local baseThreshold = vform.baseThreshold
		vform.threshold = thresholdOverride > vform.baseThreshold and thresholdOverride or baseThreshold
	end

	if vform.threshold <= 99 then
		local offsetX = vform.threshold / maxValue
		self.VoidformTreshold:SetOffset(offsetX)
	end

	self.AnimatedBorderFrame:Initialize(vform.threshold)
end

function VilinkasInsnaity:UpdatePower()
	local power = UnitPower("player", self.powerType)
	self:SetValue(power)

	local predictedCastPowerGainText = ""

	player.insanity = power
end

function VilinkasInsnaity:UpdatePlayerState()
	player.guid = UnitGUID("player")
	player.haste = UnitSpellHaste("player")
	player.inCombat = UnitAffectingCombat("player")
	if not player.inCombat then
		local oocAlpha = self.FadeoutAnim.Alpha:GetToAlpha()
		self:SetAlpha(oocAlpha)
	end

	-- Check for auras
	auras.vform.active, auras.vform.stacks = GetPlayerBuffInfo(auras.vform.id)
	auras.vtorrent.active = GetPlayerBuffInfo(auras.vtorrent.id)
	auras.stmbuff.active = GetPlayerBuffInfo(auras.stmbuff.id)

	talents.aspirits.targets = {}
	self:UpdateAuras()
	
	self:UpdateMaxPower()
	self:UpdatePower()
end

VilinkasInsnaity.ExtraBars = {}

function VilinkasInsnaity:OnLoad()
	self.powerType = Enum.PowerType.Insanity
	self.powerToken = "INSANITY"
	self.lastUpdateTime = 0

	self.castGain = 0

	self.NormalBorderFrame = self.BorderFrame.NormalBorderFrame
	self.AnimatedBorderFrame = self.BorderFrame.AnimatedBorderFrame

	self.nBar = self.CastGainBar
	self.CastGainBar.pBar = self
	self.CastGainBar.nBar = self.PassiveGainBar
	self.PassiveGainBar.pBar = self.CastGainBar

	self.ExtraBarsDock = {
		["TOP_OUTSIDE"] = {},
		["TOP_INSIDE"] = {},
		["BOTTOM_OUTSIDE"] = {},
		["BOTTOM_INSIDE"] = {}
	}

	self.VoidformTreshold:SetParent(self.BackgroundFrame)

	VilinkasInsnaityBuilder.OnLoad(self)

	self:RegisterEvent("ADDON_LOADED")
	self:Setup()
end

local function VilinkasInsnaity_OnUpdate(self)
	local currTime = GetTime()
	local elapsed = currTime - self.lastUpdateTime

	if (elapsed > 0.1) then
		-- Do stuff we dont need every frame (Text)

		local castGain = self.castGain

		local passiveGain = self.ShadowfiendBar:GetInsanityGain()
		passiveGain = passiveGain + self.AuspiciousSpiritsTracker:GetInsanityGain()

		local castGainText = castGain > 0 and "|c" .. castHexColor .. castGain .. "|r + " or ""
		local passiveGainText = passiveGain > 0 and "|c" .. asHexColor .. passiveGain .. "|r + " or ""
		self.RightText:SetText(passiveGainText .. castGainText .. self:GetValue())

		local vform = auras.vform
		if (vform.stacks > 0) then
			self.CenterText:SetText(format("%d (%d%%)", vform.stacks, player.haste))
			self.LeftText:SetText(format("%.1f (%d)", GetVoidformTime(currTime), vform.drainStacks))
		elseif (auras.linsanity.stacks > 0) and auras.linsanity.display then
			self.CenterText:SetText(format("%d", auras.linsanity.stacks))
			self.LeftText:SetText("")
		else
			self.CenterText:SetText("")
			self.LeftText:SetText("")
		end

		self.PassiveGainBar:SetValue(passiveGain)

		self.lastUpdateTime = currTime
	end
end

function VilinkasInsnaity:Setup()
	local active = false
	if IsPriest() then
		if IsShadow() then
			active = true
			self:RegisterEvent("PLAYER_ENTERING_WORLD")
			self:RegisterEvent("PLAYER_TALENT_UPDATE")
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
			self:RegisterEvent("ENCOUNTER_START")
			self:RegisterEvent("ENCOUNTER_END")
			self:RegisterUnitEvent("UNIT_AURA", "player")
			self:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
			self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
			self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
			self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
			self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
			self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
			self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
			self:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
			--self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

			self:SetScript("OnUpdate", VilinkasInsnaity_OnUpdate)
		else
			self:UnregisterEvent("PLAYER_TALENT_UPDATE")
			self:UnregisterEvent("PLAYER_ENTERING_WORLD")
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
			self:UnregisterEvent("ENCOUNTER_START")
			self:UnregisterEvent("ENCOUNTER_END")
			self:UnregisterEvent("UNIT_AURA")
			self:UnregisterEvent("UNIT_SPELLCAST_START")
			self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
			self:UnregisterEvent("UNIT_SPELLCAST_STOP")
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			self:UnregisterEvent("UNIT_POWER_FREQUENT")
			self:UnregisterEvent("UNIT_MAXPOWER")
			self:UnregisterEvent("UNIT_SPELL_HASTE")
			--self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

			self:SetScript("OnUpdate", nil)
		end
		
		self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	end
	self:SetShown(active)

	self.ShadowfiendBar:Setup(active)
	self.AuspiciousSpiritsTracker:Setup(active)
end

function VilinkasInsnaity:UpdateAuras()
	auras.linsanity.active, auras.linsanity.stacks = GetPlayerBuffInfo(auras.linsanity.id)
end

function VilinkasInsnaity:OnEvent(event, ...)
	if (event == "ADDON_LOADED") then
		local addonName = ...;
		if ( not addonName or (addonName and addonName ~= "VilinkasInsanity") ) then
			return;
		end
		self:UpdateSettings()
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self:UpdatePlayerState()
		self.AnimatedBorderFrame:UpdatePower()
		self.AnimatedBorderFrame:UpdateAuras()
		self.ManaBar:UpdateMaxPower()
		self.ManaBar:UpdatePower("MANA")
	elseif (event == "PLAYER_REGEN_ENABLED") or (event == "PLAYER_REGEN_DISABLED") then
		player.inCombat = UnitAffectingCombat("player")
		if player.inCombat then
			self.FadeoutAnim:Stop()
			self:SetAlpha(1)
		else
			self.FadeoutAnim:Play()
		end
	elseif (event == "ACTIVE_TALENT_GROUP_CHANGED") then
		self:Setup()
		player.inCombat = UnitAffectingCombat("player")
		if player.inCombat then
			self.FadeoutAnim:Stop()
			self:SetAlpha(1)
		else
			self.FadeoutAnim:Play()
		end
	elseif (event == "PLAYER_TALENT_UPDATE") then
		if (GetSpecialization() == player.shadowSpec) then
			talents.lotvoid.active = select(4, GetTalentInfo(talents.lotvoid.tier, talents.lotvoid.column, 1))
			talents.fotmind.active = select(4, GetTalentInfo(talents.fotmind.tier, talents.fotmind.column, 1))
			if not talents.aspirits.active then
				talents.aspirits.targets = {}
				talents.aspirits.count = 0
			end
			self:UpdateMaxPower()
			self.ManaBar:UpdateMaxPower()
		end
	elseif (event == "UNIT_POWER_FREQUENT") then
		self:UpdatePower()
		self.AnimatedBorderFrame:UpdatePower()
		local _, powerToken = ...
		self.ManaBar:UpdatePower(powerToken)
	elseif (event == "UNIT_MAXPOWER") then
		self:UpdateMaxPower()
		self.ManaBar:UpdateMaxPower()
	elseif (event == "UNIT_SPELL_HASTE") then
		player.haste = UnitSpellHaste("player")
	elseif (event == "UNIT_AURA") then
		self:UpdateAuras()
		self.AnimatedBorderFrame:UpdateAuras()
	elseif (event == "UNIT_SPELLCAST_START") or (event == "UNIT_SPELLCAST_CHANNEL_START") then
		local _, _, spellId = ...
		local castGain = spellInsanityGain[spellId]()
		player.predictedCastPowerGain = castGain
		self.castGain = castGain
		if not player.inCombat and castGain > 0 then
			self.FadeoutAnim:Stop()
			self:SetAlpha(1)
		end
		self.CastGainBar:SetValue(castGain)
		self.GcdBar:StartGcd(spellId)
	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		local _, _, spellId = ...
		local castInsanityGain = spellInsanityGain[spellId]()
		if not player.inCombat and castInsanityGain > 0 then
			self:SetAlpha(1)
			self.FadeoutAnim:Play()
		end
		--StartGcd(spellId)
		self.GcdBar:StartGcd(spellId)
	elseif (event == "UNIT_SPELLCAST_STOP") or (event == "UNIT_SPELLCAST_CHANNEL_STOP") then
		if not player.inCombat and player.predictedCastPowerGain > 0 then
			self.FadeoutAnim:Play()
		end
		self.castGain = 0
		player.predictedCastPowerGain = 0
		self.CastGainBar:SetValue(0)
	elseif (event == "ENCOUNTER_START") then
			local _, encounterName = ...
			reports.encounterName = encounterName
	elseif (event == "ENCOUNTER_END") then
			reports.encounterName = nil
	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _, logEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
		if sourceGUID == player.guid then
			--print(format("Name: %s id: %s source: %s dest: %s event: %s", spellName, spellId, sourceGUID, destGUID, logEvent))
			-- Voidform --
			if spellId == auras.vform.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					local vform = auras.vform
					vform.currentStackTime = GetTime()
					vform.drainStacks = 1
					vform.active, vform.stacks = GetPlayerBuffInfo(vform.id)
					self.VoidformTreshold:OnVoidformStart()
					CreateVfRep()
				elseif logEvent == "SPELL_AURA_APPLIED_DOSE" then
					local vform = auras.vform
					vform.currentStackTime = GetTime()
					if not auras.vtorrent.active then
						vform.drainStacks = vform.drainStacks + 1
						reports.current.vfdrainstacks = vform.drainStacks
					end
					vform.stacks = vform.stacks + 1
					reports.current.vfstacks = vform.stacks
				elseif logEvent == "SPELL_AURA_REMOVED" then
					local vform = auras.vform
					vform.drainStacks = 0
					vform.stacks = 0
					vform.currentStackTime = 0
					self.VoidformTreshold:OnVoidformEnd()
					FinaliseVfRep()
				end
			-- Surrender to Madness --
			elseif spellId == auras.stmbuff.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.stmbuff.active = true
					reports.current.stmduration = GetTime()
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.stmbuff.active = false
				end
			-- Void Torrent --
			elseif spellId == auras.vtorrent.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.vtorrent.active = true
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.vtorrent.active = false
				end
			end
		end
		if logEvent == "UNIT_DIED" then
			if destGUID == UnitGUID("player") then
				self.VoidformTreshold:OnVoidformEnd()
				if auras.vform.stacks > 0 then
					FinaliseVfRep()
				end
				auras.vform.currentStackTime = 0
				auras.vform.drainStacks = 0
				auras.vform.stacks = 0
				auras.stmbuff.active = false
				auras.vtorrent.active = false
			end
		end
	end
end

function VilinkasInsnaity:ExtraBarOnSizeChanged(extraBar)
	local dock = extraBar.dock
	if dock == "TOP_OUTSIDE" then
		local borderFrame = self.BorderFrame
		if extraBar:IsVisible() then
			borderFrame:SetOffset(borderFrame:GetOffset("TOP") + extraBar.height, "TOP")
		else
			borderFrame:SetOffset(borderFrame:GetOffset("TOP") - extraBar.height, "TOP")
		end
	elseif dock == "TOP_INSIDE" then
		if extraBar:IsVisible() then
			local newOffset = self:GetOffset("TOP") + extraBar.height
			self:SetOffset(newOffset, "TOP")
			self.BackgroundFrame:SetOffset(newOffset, "TOP")
		else
			local newOffset = self:GetOffset("TOP") - extraBar.height
			self:SetOffset(newOffset, "TOP")
			self.BackgroundFrame:SetOffset(newOffset, "TOP")
		end
	elseif dock == "BOTTOM_OUTSIDE" then
		local borderFrame = self.BorderFrame
		if extraBar:IsVisible() then
			borderFrame:SetOffset(borderFrame:GetOffset("BOTTOM") + extraBar.height, "BOTTOM")
		else
			borderFrame:SetOffset(borderFrame:GetOffset("BOTTOM") - extraBar.height, "BOTTOM")
		end
	elseif dock == "BOTTOM_INSIDE" then
		if extraBar:IsVisible() then
			local newOffset = self:GetOffset("BOTTOM") + extraBar.height
			self:SetOffset(newOffset, "BOTTOM")
			self.BackgroundFrame:SetOffset(newOffset, "BOTTOM")
		else
			local newOffset = self:GetOffset("BOTTOM") - extraBar.height
			self:SetOffset(newOffset, "BOTTOM")
			self.BackgroundFrame:SetOffset(newOffset, "BOTTOM")
		end
	end
end

function VilinkasInsnaity:AddExtraBar(extraBar, dock)
	extraBar.dock = dock
	local extraBarsDock = self.ExtraBarsDock[dock]
	local relativeTo = extraBarsDock[#extraBarsDock]
	if (not relativeTo) then
		relativeTo = self
	end
	
	extraBar:ClearAllPoints()
	if dock == "TOP_OUTSIDE" then
		extraBar:SetPoint("BOTTOMLEFT", relativeTo, "TOPLEFT", 0, 0)
		extraBar:SetPoint("BOTTOMRIGHT", relativeTo, "TOPRIGHT", 0, 0)
	elseif dock == "TOP_INSIDE" then
		extraBar:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
		extraBar:SetPoint("TOPRIGHT", relativeTo, "TOPRIGHT", 0, 0)
	elseif dock == "BOTTOM_OUTSIDE" then
		extraBar:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, 0)
		extraBar:SetPoint("TOPRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
	elseif dock == "BOTTOM_INSIDE" then
		extraBar:SetPoint("BOTTOMLEFT", relativeTo, "BOTTOMLEFT", 0, 0)
		extraBar:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
	end

	tinsert(self.ExtraBarsDock[dock], extraBar)
end

function VilinkasInsnaity:ClearDocks()
	self.ExtraBarsDock = {
		["TOP_OUTSIDE"] = {},
		["TOP_INSIDE"] = {},
		["BOTTOM_OUTSIDE"] = {},
		["BOTTOM_INSIDE"] = {}
	}
end

-- Conversion function from RGBA to HEX, Credit: https://gist.github.com/marceloCodget/3862929
local function RGBAToHex(rgba)
	local hexadecimal = ''
	-- Convert to wow supported format AARRGGBB
	local argb = { rgba[4]*255, rgba[1]*255, rgba[2]*255, rgba[3]*255 }
	for key, value in pairs(argb) do
		local hex = ''
		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end
		if(string.len(hex) == 0) then 
			hex = '00'
		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end
		hexadecimal = hexadecimal .. hex
	end
	return hexadecimal
end

local default
function VilinkasInsnaity:UpdateSettings()
    if not db then
        default = {
            profile = {
                general = {
                    x = 0,
                    y = 0,
                    width = 300,
                    height = 40,
                    oocalpha = 0.3,
					anchor = "SCREEN",
					background = {
						enable = true,
						color = { 0.2, 0.2, 0.2, 0.5 },
						texture = "Solid"
					},
					border = {
						normal = {
							enable = true,
							color = { 0.0, 0.0, 0.0, 0.7 },
							texture = "1 Pixel",
							thickness = 2,
							offset = {
								left = 0,
								right = 0,
								top = 0,
								bottom = 0,
							}
						},
						animated = {
							enable = true,
							colorvf = { 0.7, 0.0, 1.0, 0.65 },
							colorstm = { 1, 0.0, 0.0, 0.65 },
							texture = "Vilinka's Insanity Glow",
							animatedontop = false,
							offset = {
								thickness = 6,
								left = 8,
								right = 8,
								top = 8,
								bottom = 8,
							}
						}
					},
                },
                bars = {
					useMainTexture = true,
					main = {
						color = { 0.4, 0, 0.8, 1 },
						castcolor = { 1, 1, 1, 1 },
						passivecolor = { 1, 0.31, 0.85, 1 },
						texture = "Blizzard Raid Bar",
						voidformthreshold = {
							enable = true,
							override = 60,
							color = { 1, 1, 1, 1 },
							thickness = 2,
							hideinvoidfrom = true,
						}
					},
					gcd = {
						enable = true,
						color = { 1, 1, 1, 1 },
						texture = "Blizzard Raid Bar",
						deplete = false,
						height = 5.0,
						background = {
							enable = true,
							color = { 0.15, 0.15, 0.15, 1 },
							texture = "Solid"
						},
					},
					mana = {
						enable = true,
						color = { 0.31, 0.45, 0.85, 1.0 },
						texture = "Blizzard Raid Bar",
						height = 5.0,
						threshold = 0.5,
						background = {
							enable = true,
							color = { 0.01, 0.05, 0.13, 1.0 },
							texture = "Solid"
						}
					},
					shadowfiend = {
						enable = true,
						color = { 1, 0.31, 0.85, 1 },
						texture = "Blizzard Raid Bar",
						height = 10.0,
						deplete = true,
						background = {
							enable = true,
							color = { 0.15, 0.15, 0.15, 1 },
							texture = "Solid",
						},
						nextattack = {
							enable = true,
							color = { 1, 1, 1, 1 },
							thickness = 1,
						}
					},
                },
                text = {
					useMainText = true,
					main = {
						file = "Friz Quadrata TT",
						flag = "OUTLINE",
						right = {
							enable = true,
							file = "Friz Quadrata TT",
							flag = "OUTLINE",
							size = 12,
							colorinsanity = { 1, 1, 1, 1 },
							colorcast = { 1, 1, 1, 1 },
							colorpassive = { 1, 0.31, 0.85, 1 },
							offset = {
								right = -2,
								top = 0,
							}
						},
						center = {
							enable = true,
							file = "Friz Quadrata TT",
							flag = "OUTLINE",
							size = 12,
							color = { 1, 1, 1, 1 },
							offset = {
								right = 0,
								top = 0,
							}
						},
						left = {
							enable = true,
							file = "Friz Quadrata TT",
							flag = "OUTLINE",
							size = 12,
							color = { 1, 1, 1, 1 },
							offset = {
								left = -2,
								top = 0,
							}
						},
					},
					shadowfiend = {
						enable = true,
						file = "Friz Quadrata TT",
						flag = "OUTLINE",
						size = 12,
						color = { 1, 1, 1, 1 },
						offset = {
							right = -2,
							top = 0,
						}
					},
				},
				animations = {
					ooc = {
						duration = 0.5,
						startdelay = 1,
					},
					animatedborder = {
						pulseduration = 1,
					},
				},
                misc = {
					voidfromreports = {
						enable = 2,
						save = 2,
						maxsaved = 3,
					}
                },
                vfreportarchive = {
                },
            },
        }
        self.db = LibStub("AceDB-3.0"):New("VilinkasInsanityDB", default, true)
        db = self.db.profile
	end
	
	topOffsetStack, bottomOffsetStack = nil, nil

    -- General
	self:ClearAllPoints()
	self:SetPoint("CENTER", db.general.x, db.general.y)
	self:SetSize(db.general.width, db.general.height)
	local bugFix = self:GetWidth() -- If I dont call this function on VilinkasInsanity I get wrong width later on when I need to update voidform mark. I know its weird :)
	
	-- Background --
	if db.general.background.enable then
		self.BackgroundFrame:SetBackdrop({
			bgFile = LSM:Fetch("background", db.general.background.texture),
			tile = true,
			tileSize=db.general.width,
		})
		self.BackgroundFrame:SetBackdropColor(unpack(db.general.background.color))
	else
		self.BackgroundFrame:SetBackdrop(nil)
	end

	-- Border --
	local borderThickness = db.general.border.normal.thickness
	if db.general.border.normal.enable then
		self.NormalBorderFrame:ClearAllPoints()
		self.NormalBorderFrame:SetPoint("LEFT", self.BorderFrame, "LEFT",
			-borderThickness - db.general.border.normal.offset.left, 0)
		self.NormalBorderFrame:SetPoint("RIGHT", self.BorderFrame, "RIGHT",
			borderThickness + db.general.border.normal.offset.right, 0)
		self.NormalBorderFrame:SetPoint("TOP", self.BorderFrame, "TOP", 0,
			borderThickness + db.general.border.normal.offset.top)
		self.NormalBorderFrame:SetPoint("BOTTOM", self.BorderFrame, "BOTTOM", 0,
			-borderThickness - db.general.border.normal.offset.bottom)

		self.NormalBorderFrame:SetBackdrop({
			edgeFile = LSM:Fetch("border", db.general.border.normal.texture),
			tile = true,
			edgeSize=borderThickness,
			insets = {0, 0, 0, 0}
		})
		self.NormalBorderFrame:SetBackdropBorderColor(unpack(db.general.border.normal.color))
	else
		self.NormalBorderFrame:SetBackdrop(nil)
	end

	-- Animated border --
	self.AnimatedBorderFrame:UpdateSettings(db)
	
	-- Main bars --
	local bartex = LSM:Fetch("statusbar", db.bars.main.texture)
	self.tex:SetTexture(bartex)
	self.tex:SetVertexColor(unpack(db.bars.main.color))
	self.CastGainBar.tex:SetTexture(bartex)
	self.CastGainBar.tex:SetVertexColor(unpack(db.bars.main.castcolor))
	self.PassiveGainBar.tex:SetTexture(bartex)
	self.PassiveGainBar.tex:SetVertexColor(unpack(db.bars.main.passivecolor))

	-- Voidform Threshold Mark --
	auras.vform.thresholdOverride = db.bars.main.voidformthreshold.override
	auras.vform.thresholdHideInVoidform = db.bars.main.voidformthreshold.hideinvoidfrom
	if auras.vform.thresholdOverride < 100 and db.bars.main.voidformthreshold.enable then
		self.VoidformTreshold:ClearAllPoints()
		self.VoidformTreshold:SetWidth(db.bars.main.voidformthreshold.thickness)
		self.VoidformTreshold.Texture:SetVertexColor(unpack(db.bars.main.voidformthreshold.color))
		self.VoidformTreshold:Show()
		auras.vform.thresholdShow = true
	else
		auras.vform.thresholdShow = false
		self.VoidformTreshold:Hide()
	end
	self:UpdateMaxPower()

	-- GCD bar --
	self.GcdBar:UpdateSettings(db)

	-- Mana bar --
	self.ManaBar:UpdateSettings(db)

	-- Shadowfined bar --
	self.ShadowfiendBar:UpdateSettings(db)

	-- Extra bar docking --
	self:ClearDocks()
	self:AddExtraBar(self.GcdBar, "TOP_INSIDE")
	self:AddExtraBar(self.ManaBar, "BOTTOM_INSIDE")
	self:AddExtraBar(self.ShadowfiendBar, "BOTTOM_OUTSIDE")
	
	-- Font --
	local rightTextFile, rightTextflag
	if (db.text.useMainText) then
		rightTextFile = LSM:Fetch("font", db.text.main.file)
		rightTextflag = db.text.main.flag
	else
		rightTextFile = LSM:Fetch("font", db.text.main.right.file)
		rightTextflag = db.text.main.right.flag
	end
	self.RightText:SetFont(rightTextFile, db.text.main.right.size, rightTextflag)
	self.RightText:SetTextColor(unpack(db.text.main.right.colorinsanity))
	castHexColor, asHexColor = RGBAToHex(db.text.main.right.colorcast), RGBAToHex(db.text.main.right.colorpassive)

	local leftTextFile, leftTextflag
	if (db.text.useMainText) then
		leftTextFile = LSM:Fetch("font", db.text.main.file)
		leftTextflag = db.text.main.flag
	else
		leftTextFile = LSM:Fetch("font", db.text.main.left.file)
		leftTextflag = db.text.main.left.flag
	end
	self.LeftText:SetFont(leftTextFile, db.text.main.left.size, leftTextflag)
	self.LeftText:SetTextColor(unpack(db.text.main.left.color))

	local centerTextFile, centerTextflag
	if (db.text.useMainText) then
		centerTextFile = LSM:Fetch("font", db.text.main.file)
		centerTextflag = db.text.main.flag
	else
		centerTextFile = LSM:Fetch("font", db.text.main.left.file)
		centerTextflag = db.text.main.left.flag
	end
	self.CenterText:SetFont(centerTextFile, db.text.main.center.size, centerTextflag)
	self.CenterText:SetTextColor(unpack(db.text.main.center.color))

	-- Animations --
	self.FadeoutAnim.Alpha:SetDuration(db.animations.ooc.duration)
	self.FadeoutAnim.Alpha:SetStartDelay(db.animations.ooc.startdelay)
	self.FadeoutAnim.Alpha:SetToAlpha(db.general.oocalpha)

	-- Lingering Insanity --
	auras.linsanity.display = true

	-- STM reporting --
	reports.display = db.misc.voidfromreports.enable
	reports.save = db.misc.voidfromreports.save
	reports.maxSaved = db.misc.voidfromreports.maxsaved
end

SLASH_VilinkasInsanity1, SLASH_VilinkasInsanity2 = "/vilins", "/VilinkasInsanity"

SlashCmdList["VilinkasInsanity"] = function(message)
	if select(2, UnitClass("player")) == player.class then
		if GetSpecialization() == SPEC_PRIEST_SHADOW then
			if message == "report" or message == "vf" then
				PrintSavedVfReps()
			elseif message == "opt" then
				local loaded, reason = LoadAddOn("VilinkasInsanityOptions")
				if not loaded then
					print(title .. ": Options module could not be loaded: " .. _G["ADDON_" .. reason])
					return
				end
				
				--if UnitAffectingCombat("player") then
					--print(title .. ": Options will open when you leave comat.")
					--_G["VilinkasInsanityOptions"].showWhenOutOfCombat = true
				--else
				_G["VilinkasInsanityOptions"]:Show()
				--end
			else
				print(title)
				print("Use |cFF9370DB/vilins opt|r to acces options menu.")
				print("Use |cFF9370DB/vilins vf|r display archived voidform reports.")
			end
		else
			print(title .. ":|r Current specialization is not supported.")
		end
	end
end
