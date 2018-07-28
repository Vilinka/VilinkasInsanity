local LSM = LibStub("LibSharedMedia-3.0")
local pairs, ipairs, select = pairs, ipairs, select
local format, sqrt = format, sqrt
local GetTime, GetNetStats, GetSpellCooldown = GetTime, GetNetStats, GetSpellCooldown
local UnitAura, UnitPower, UnitAffectingCombat = UnitAura, UnitPower, UnitAffectingCombat
local GetSpellPowerCost = GetSpellPowerCost

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
		baseThreshold=90, thresholdOverride=0, threshold=0},
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
end

local function GetPlayerBuffInfo(id)
	return GetPlayerAuraInfo(id, "HELPFUL")
end

local function PlayerHasDebuff(id)
	for i = 1, 40 do
		local spellId = select(10, UnitAura("player", i, "HARMFUL"))
		if (not spellId) then
			break;
		elseif (id == spellId) then
			return true
		end
	end
end

VilinkasInsnaity = {}

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
		value = GetBaseValueRecursion(pBar)
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
	self:SetPoint("BOTTOMRIGHT", 0, self.offset["BOTTOM"])
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
	local animationSettings = newSettings.animations

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
			alphaMode = "DISABLE",
			insets = {0, 0, 0, 0}
		})
		self.voidformColor = borderSettings.animated.colorvf
		self:SetBackdropBorderColor(unpack(self.voidformColor))
		self.stmdebuffColor = borderSettings.animated.colorstm

		self.Pulse.AlphaOut:SetToAlpha(self.voidformColor[4])
		self.Pulse.AlphaIn:SetFromAlpha(self.voidformColor[4])
		self.Pulse.AlphaOut:SetDuration(animationSettings.borderduration / 2)
		self.Pulse.AlphaIn:SetDuration(animationSettings.borderduration / 2)
		self.Fadeout.Alpha:SetFromAlpha(self.voidformColor[4])
	else
		self:SetBackdrop(nil)
	end
end

VilinkasInsanityExtraFrame = {}

function VilinkasInsanityExtraFrame:OnLoad()
	local parent = self:GetParent()
	parent.ExtraBars[self:GetName()] = self
end

function VilinkasInsanityExtraFrame:OnSizeChanged(w, h)
	print("OnSizeChanged" .. self:GetName())
	local parent = self:GetParent()
	parent:ExtraBarOnSizeChanged(self)
end

function VilinkasInsanityExtraFrame:UpdateSettings(height)
	self.height = height
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
	VilinkasInsanityExtraFrame.UpdateSettings(self, height)

	self.active = gcdSettings.enable
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
			if (not self:IsVisible()) then
				self:Show()
			end
			self:SetValue(ptc)
		end
	end
end

function VilinkasInsanityMana:UpdateSettings(newSettings)
	local manaSettings = newSettings.bars.mana
	local height = manaSettings.height
	VilinkasInsanityExtraFrame.UpdateSettings(self, height)

	self.active = manaSettings.enable

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
end

local function UpdateMarkPosition(mark, x)
	if x > 1 then
		x = 1
	elseif x < 0 then
		x = 0
	end
	local parent = mark:GetParent()
	local parentWidth = parent:GetWidth()
	local markHalfWidth = mark:GetWidth() / 2
	mark:ClearAllPoints()
	mark:SetPoint("TOPLEFT", parent, "TOPLEFT", parentWidth * x - markHalfWidth, 0)
	mark:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -parentWidth * (1 - x) + markHalfWidth, 0)
end

local function GetInsanityDrain(stack)
	return 6 + ((stack - 1) * (0.8) * auras.vform.drainMod)
end

local function GetVoidformTime(currentTime)
	local vform = auras.vform
	if player.insanity > 0 and vform.stacks > 0 then
		-- Drain current stack
		local vfCurrStackTimeLeft = 1.0 - (currentTime - vform.currentStackTime)-- + select(4, GetNetStats()) / 1000
		local vfCurrStackDrain = GetInsanityDrain(vform.drainStacks)
		if ((vfCurrStackDrain * vfCurrStackTimeLeft) > player.insanity) then
			vfCurrStackTimeLeft = player.insanity / vfCurrStackDrain
			return vfCurrStackTimeLeft
		else
			local ins = player.insanity - (vfCurrStackDrain * vfCurrStackTimeLeft)
			-- Sum d+(x-1)*f*dm, Sum x=m to n => (-1/2)*(m-n-1)*(2*d+f*dm*(m+n-2))=ins => Solve for n, d=6, f=(0.8)
			local dm, m = vform.drainMod, vform.drainStacks + 1 -- We already drained current stack
			local vfRemStacks = (sqrt(dm*dm*(2*m-3)*(2*m-3)+dm*10*(ins+6*m-9)+225)+dm-15) / (2*dm)
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
		UpdateMarkPosition(self.VoidformTresholdTexture, offsetX)
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

	-- Check for shadow fiend
	local haveTotem, _, startTime, duration = GetTotemInfo(1)
	if haveTotem then
		sfiend.duration = duration
		sfiend.startTime = startTime
		sfiend.active = true
		frames.sfiendBar:Show()
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

local updateASRate, lastUpdateASTime = 1, 0
local function UpdateAS(currentTime)
	local aspirits = talents.aspirits
	if aspirits.active then
		local dt = currentTime - lastUpdateASTime
		if dt > updateASRate and aspirits.active then
			local targets = aspirits.targets
			for guid in pairs(targets) do
				if targets[guid] ~= nil then
					if (currentTime - targets[guid].lastUpdateTime) > 10 then
						aspirits.count = aspirits.count - targets[guid].asCount
						targets[guid] = nil
					end
				end
			end
			if aspirits.count < 0 then
				aspirits.count = 0
			end
		end
		local igain = aspirits.count * aspirits.igain
		player.passiveInsanityGain = player.passiveInsanityGain + igain
	end
end

local function UpdateSF(currentTime)
	if sfiend.active and sfiend.enable then
		--local timeLeft = sfiend.duration - (currentTime - sfiend.startTime)
		local timeLeft = sfiend.expirationTime - currentTime
		local bar = frames.sfiendBar
		if not (timeLeft > 0) then
			sfiend.active = false
			bar:Hide()
		else
			local attacksSpeed = sfiend.baseAttackSpeed / (1 + (player.haste / 100))
			local predictedTimeNextAttack = sfiend.lastAttackTime + attacksSpeed
			local pct = (sfiend.expirationTime - currentTime) / sfiend.duration
			local deplete = bar.deplete
			if deplete then
				bar:SetValue(pct)
			else
				bar:SetValue(1 - pct)
			end
			if (predictedTimeNextAttack - currentTime) < -0.5 then
				-- Remove attack mark
				bar.attackMark:Hide()
			else
				-- Continue as normal
				local nextAttackPtc = (sfiend.expirationTime - predictedTimeNextAttack) / sfiend.duration

				if deplete then
					bar.attackMark:SetOffset(nextAttackPtc)
					--UpdateMark(bar.attackMark, nextAttackPtc)
				else
					--UpdateMark(bar.attackMark, 1 - nextAttackPtc)
					bar.attackMark:SetOffset(1 - nextAttackPtc)
				end

				frames.sfiendBar.attackMark:Show()

				if talents.mbender.active then
					player.passiveInsanityGain = player.passiveInsanityGain + talents.mbender.igain
				else
					player.passiveInsanityGain = player.passiveInsanityGain +  sfiend.igain
				end
			end
		end
	end
end

local function UpdateText(currentTime)
	local castGain = player.currentCastInsanityGain
	local castGainText = castGain > 0 and "|c" .. castHexColor .. castGain .. "|r + " or ""
	local passiveGain = player.passiveInsanityGain
	local passiveGainText = passiveGain > 0 and "|c" .. asHexColor .. passiveGain .. "|r + " or ""
	VilinkasInsnaity.RightText:SetText(castGainText .. passiveGainText .. player.insanity)
	local vform = auras.vform
	if (vform.stacks > 0) then
		VilinkasInsnaity.CenterText:SetText(format("%d (%d%%)", vform.stacks, player.haste))
		VilinkasInsnaity.LeftText:SetText(format("%.1f (%d)", GetVoidformTime(currentTime), vform.drainStacks))
	elseif (auras.linsanity.stacks > 0) and auras.linsanity.display then
		VilinkasInsnaity.CenterText:SetText(format("%d", auras.linsanity.stacks))
		VilinkasInsnaity.LeftText:SetText("")
	else
		VilinkasInsnaity.CenterText:SetText("")
		VilinkasInsnaity.LeftText:SetText("")
	end
end

local function StartGcd(spellId)
	local start, duration = GetSpellCooldown(spellId)
	if start > 0 and gcd.enable then
		gcd.start = start
		gcd.duration = duration
		frames.gcdBar:Show()
	end
end

local function UpdateGCD(currentTime)
	if gcd.start > 0 then
		local netTime = 0--select(4, GetNetStats()) / 1000)
		local pct = (currentTime - gcd.start - netTime) / gcd.duration
		local gcdBar = frames.gcdBar
		if pct > 1 then
			gcdBar:SetValue(0)
			gcdBar:Hide()
			gcd.start = 0
        else
			if gcdBar.deplete then
				gcdBar:SetValue(1-pct)
			else
				gcdBar:SetValue(pct)
			end
		end
	end
end

local function UpdateSTM(currentTime)
	local stmDebuffTimeLeft = stmDebuffExpirationTime - currentTime
	if stmDebuffTimeLeft < 0 then
		frames.stmBorder:Hide()
		frames.stmBar:Hide()
		auras.stmdebuff.active = false
	else
		local pct = stmDebuffTimeLeft / stmDebuffDuration
		local deplete = frames.stmBar.deplete
		if deplete then
			frames.stmBar:SetValue(1 - pct)
		else
			frames.stmBar:SetValue(pct)
		end
	end
end

local function OnUpdate()
	local currentTime = GetTime()
	local elapsed = currentTime - self.lastUpdateTime
	
	if dt > updateRate then
		UpdateAS(currentTime)
		--UpdateSF(currentTime)

		local stmbuff = auras.stmbuff
		if stmbuff.active then
			local imul = stmbuff.imul
			player.passiveInsanityGain = player.passiveInsanityGain * imul
		elseif auras.stmdebuff.active then
			player.currentCastInsanityGain = 0
			player.passiveInsanityGain = 0
		end

		UpdateText(currentTime)
		UpdateInsanityBar()

		--UpdateManaBar()
		--UpdateSTM(currentTime)

		player.passiveInsanityGain = 0
		lastUpdateTime = currentTime
	end
	UpdateGCD(currentTime)
end

VilinkasInsnaity.ExtraBars = {}

function VilinkasInsnaity:OnLoad()
	self.class = "PRIEST";
	self.spec = SPEC_PRIEST_SHADOW;
	self.powerType = Enum.PowerType.Insanity
	self.powerToke = "INSANITY"
	self.lastUpdateTime = 0

	self.NormalBorderFrame = self.BorderFrame.NormalBorderFrame
	self.AnimatedBorderFrame = self.BorderFrame.AnimatedBorderFrame

	self.nBar = self.CastGainBar
	self.CastGainBar.pBar = self

	self.ExtraBarsDock = {
		["TOP_OUTSIDE"] = {},
		["TOP_INSIDE"] = {},
		["BOTTOM_OUTSIDE"] = {},
		["BOTTOM_INSIDE"] = {}
	}

	VilinkasInsnaityBuilder.OnLoad(self)

	self:RegisterEvent("ADDON_LOADED")
	self:Setup()
end

local function VilinkasInsnaity_OnUpdate(self)
	local currTime = GetTime()
	local elapsed = currTime - self.lastUpdateTime
	self.lastUpdateTime = currTime

	--self:UpdateDockSize("TOP_INSIDE")
	--[[for k,v in pairs(self.ExtraBars) do
		print(k)
	end]]--
end

function VilinkasInsnaity:Setup()
	local show = false
	local _, class = UnitClass("player");
	if class == self.class then
		local spec = GetSpecialization()
		if spec == self.spec then
			show = true
			self.powerType = Enum.PowerType.Insanity
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
	self:SetShown(show)
end

function VilinkasInsnaity:UpdateAuras()
	auras.linsanity.active, auras.linsanity.stacks = GetPlayerBuffInfo(auras.vtorrent.id)
end

--VilinkasInsnaity:SetScript("OnEvent", function(self, event, ...)
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
	elseif (event == "PLAYER_TALENT_UPDATE") then
		if GetSpecialization() == player.shadowSpec then
			talents.lotvoid.active = select(4, GetTalentInfo(talents.lotvoid.tier, talents.lotvoid.column, 1))
			talents.fotmind.active = select(4, GetTalentInfo(talents.fotmind.tier, talents.fotmind.column, 1))
			talents.mbender.active = select(4, GetTalentInfo(talents.mbender.tier, talents.mbender.column, 1))
			talents.aspirits.active = select(4, GetTalentInfo(talents.aspirits.tier, talents.aspirits.column, 1))
			if not talents.aspirits.active then
				talents.aspirits.targets = {}
				talents.aspirits.count = 0
			end
			self:UpdateMaxPower()
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
		if not player.inCombat and castGain > 0 then
			self.FadeoutAnim:Stop()
			self:SetAlpha(1)
		end
		--self:UpdatePower()
		self.CastGainBar:SetValue(castGain)
		--self.BuilderFrame:SetCastValue(castGain)
		--StartGcd(spellId)
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
		player.predictedCastPowerGain = 0
		self.CastGainBar:SetValue(0)
		--self.BuilderFrame:SetCastValue(0)
		--self:UpdatePower()
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
			-- Auspicious Spirits Spawn --
			elseif spellId == talents.aspirits.idSpawn then
				if logEvent == "SPELL_CAST_SUCCESS" then
					local aspirits = talents.aspirits
					if aspirits.active then
						targets = aspirits.targets
						if not targets[destGUID] then
							targets[destGUID] = {}
							targets[destGUID].asCount = 0
							targets[destGUID].asSpawnTime = {}
						end
						targets[destGUID].asCount = targets[destGUID].asCount + 1
						targets[destGUID].lastUpdateTime = GetTime()
						aspirits.count = aspirits.count + 1
					end
				end
			-- Auspicious Spirits Despawn --
			elseif spellId == talents.aspirits.idDespawn then
				if logEvent == "SPELL_DAMAGE" or event == "SPELL_MISSED" then
					local aspirits = talents.aspirits
					if talents.aspirits.active then
						targets = aspirits.targets
						if targets[destGUID] then
							targets[destGUID].asCount = targets[destGUID].asCount - 1
							targets[destGUID].lastUpdateTime = GetTime()
							aspirits.count = aspirits.count - 1
							if targets[destGUID].asCount <= 0 then
								targets[destGUID] = nil
							end
							if aspirits.count < 0 then
								aspirits.count = 0
							end
						end
					end
				end
			-- Void Torrent --
			elseif spellId == auras.vtorrent.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.vtorrent.active = true
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.vtorrent.active = false
				end
			-- Shadow fiend / Mindbender --
			elseif spellId == sfiend.id or spellId == talents.mbender.id then
				if logEvent == "SPELL_SUMMON" then
					sfiend.guid = destGUID
					local _, _, startTime, duration = GetTotemInfo(1)
					sfiend.duration = duration
					sfiend.expirationTime = startTime + duration
					sfiend.active = true
					frames.sfiendBar:Show()
				end
			end
		elseif sourceGUID == sfiend.guid and logEvent == "SWING_DAMAGE" then
			sfiend.lastAttackTime = GetTime()
		-- Power Leech (Mindbender Power Leech spell (200010))
		elseif destGUID == UnitGUID("player") and 
			spellId == sfiend.idLeech or spellId == talents.mbender.idLeech and
			logEvent == "SPELL_ENERGIZE" then
			sfiend.lastAttackTime = GetTime()
			sfiend.guid = sourceGUID
		end
		if logEvent == "UNIT_DIED" then
			if destGUID == UnitGUID("player") then
				if auras.vform.stacks > 0 then
					FinaliseVfRep()
				end
				talents.aspirits.targets = {}
				auras.vform.currentStackTime = 0
				auras.vform.drainStacks = 0
				auras.vform.stacks = 0
				auras.stmbuff.active = false
				auras.vtorrent.active = false
				sfiend.active = false
			elseif destGUID == sfiend.guid then
				sfiend.active = false
				frames.sfiendBar:Hide()
			elseif talents.aspirits.targets[destGUID] then
				local count = targets[destGUID].asCount
				local aspirits = talents.aspirits
				if count > 0 then
					aspirits.count = aspirits.count - count
				end
				aspirits.targets[destGUID] = nil
			end
		end
	end
end

function VilinkasInsnaity:ExtraBarOnSizeChanged(extraBar)
	local dock = extraBar.dock
	print(dock)
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
		if extraBar:IsVisible() then
			borderFrame:SetOffset(borderFrame:GetOffset("BOTTOM") + extraBar.height, "BOTTOM")
		else
			borderFrame:SetOffset(borderFrame:GetOffset("BOTTOM") - extraBar.height, "BOTTOM")
		end
	elseif dock == "BOTTOM_INSIDE" then
		print("ExtraBarOnSizeChanged")
		print(extraBar:IsVisible())
		if extraBar:IsVisible() then
			local newOffset = self:GetOffset("BOTTOM") + extraBar.height
			print(newOffset)
			self:SetOffset(newOffset, "BOTTOM")
			self.BackgroundFrame:SetOffset(newOffset, "BOTTOM")
		else
			local newOffset = self:GetOffset("BOTTOM") - extraBar.height
			print(newOffset)
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

local topOffsetStack, bottomOffsetStack
local function AddBarToStack(bar, pos)
	local t = db.border.thickness
	bar:ClearAllPoints()
	if pos == "TOP" then
		if topOffsetStack then
			bar:SetPoint("BOTTOMLEFT", topOffsetStack, "TOPLEFT", 0, 0)
			bar:SetPoint("BOTTOMRIGHT", topOffsetStack, "TOPRIGHT", 0, 0)
		else
			bar:SetPoint("BOTTOMLEFT", frames.bg, "TOPLEFT", 0, t)
			bar:SetPoint("BOTTOMRIGHT", frames.bg, "TOPRIGHT", 0, t)
		end
		topOffsetStack = bar
	else
		if bottomOffsetStack then
			bar:SetPoint("TOPLEFT", bottomOffsetStack, "BOTTOMLEFT", 0, 0)
			bar:SetPoint("TOPRIGHT", bottomOffsetStack, "BOTTOMRIGHT", 0, 0)
		else
			bar:SetPoint("TOPLEFT", frames.bg, "BOTTOMLEFT", 0, -t)
			bar:SetPoint("TOPRIGHT", frames.bg, "BOTTOMRIGHT", 0, -t)
		end
		bottomOffsetStack = bar
	end
end

local default
function VilinkasInsnaity:UpdateSettings()
    if not db then
        default = {
            profile = {
                general = {
                    x = 0,
                    y = 0,
                    width = 260,
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
								thickness = 8,
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
							color = { 1, 1, 1, 1 },
							thickness = 2,
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
							color = { 0.2, 0.2, 0.2, 0.5 },
							texture = "Solid"
						},
					},
					mana = {
						enable = true,
						color = { 0, 0, 1, 1 },
						texture = "Blizzard Raid Bar",
						height = 5.0,
						background = {
							enable = true,
							color = { 0.2, 0.2, 0.2, 0.5 },
							texture = "Solid"
						}
					},
					shadowfiend = {
						enable = true,
						color = { 1, 1, 1, 1 },
						texture = "Blizzard Raid Bar",
						height = 5.0,
						background = {
							enable = true,
							color = { 0.2, 0.2, 0.2, 0.5 },
							texture = "Solid",
						},
						nextattack = {
							enable = true,
							color = { 1, 1, 1, 1 },
							thickness = 1,
						}
					},
                    texture = "Blizzard Raid Bar",
                    insbarcolor = { 0.4, 0, 0.8, 1 },
                    castbarcolor = { 1, 1, 1, 1 },
                    asbarcolor = { 1, 0.31, 0.85, 1 },
                },
                overlay = {
                    thickness = 1,
                    color = { 1, 1, 1, 1 },
                },
                text = {
                    file = "Friz Quadrata TT",
                    flag = "OUTLINE",
                    insanitycolor = { 1, 1, 1, 1 },
                    insanitysize = 12,
                    castcolor = { 1, 1, 1, 1 },
                    ascolor = { 1, 0.31, 0.85, 1 },
                    vfstackcolor = { 1, 1, 1, 1 },
                    vfstacksize = 12,
                    vftimecolor = { 1, 1, 1, 1 },
                    vftimesize = 12,
                },
                misc = {
                    voidformthreshold = 60,
                    lingeringinsanity = true,
                    vfdisreportingenabled = 2,
                    vfsavereportingenabled = 2,
					vfreportingmaxsaved = 3,
					borderstmdebuffcolor = { 1.0, 0.0, 0.0, 1.0 }
                },
                animations = {
                    oocduration = 0.5,
                    oocstartdelay = 1,
                    bordercolor = { 0.7, 0.0, 1.0, 1.0 },
                    borderduration = 1,
                },
                gcd = {
                    enable = true,
                    pos = "TOP",
                    height = 5.0,
                    barcolor = { 1, 1, 1, 1 },
                    deplete = false,
				},
				sfiend = {
					enable = true,
					pos = "BOTTOM",
					height = 10,
					barcolor = { 1, 0.31, 0.85, 1 },
					deplete = true,
					markthickness = 1,
                    markcolor = { 1, 1, 1, 1 },
				},
				manabar = {
					enable = false,
					pos = "BOTTOM",
					height = 5.0,
					barcolor = { 0, 0, 1, 1 },
					deplete = true,
					markthickness = 1,
					markcolor = { 1, 1, 1, 1 },
				},
				stmdebuff = {
					enable = true,
					bordercolor = { 1, 0, 0, 1 },
					height = 5,
					barcolor = { 1, 0, 0, 0.5 },
					deplete = true,
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
	auras.vform.thresholdOverride = db.misc.voidformthreshold
	if auras.vform.thresholdOverride < 100 and db.bars.main.voidformthreshold.enable then
		self.VoidformTresholdTexture:ClearAllPoints()
		self.VoidformTresholdTexture:SetWidth(db.bars.main.voidformthreshold.thickness)
		self.VoidformTresholdTexture:SetVertexColor(unpack(db.bars.main.voidformthreshold.color))
		self.VoidformTresholdTexture:Show()
		
	else
		self.VoidformTresholdTexture:Hide()
	end
	self:UpdateMaxPower()

	-- GCD bar --
	self.GcdBar:UpdateSettings(db)

	-- Mana bar --
	self.ManaBar:UpdateSettings(db)

	-- Extra bar docking --
	self:ClearDocks()
	self:AddExtraBar(self.GcdBar, "TOP_INSIDE")
	self:AddExtraBar(self.ManaBar, "BOTTOM_INSIDE")
	
	-- Font --
	local file = LSM:Fetch("font", db.text.file)
	local flag = db.text.flag
	self.RightText:SetFont(file, db.text.insanitysize, flag)
	self.RightText:SetTextColor(unpack(db.text.insanitycolor))
	self.LeftText:SetFont(file, db.text.vftimesize, flag)
	self.LeftText:SetTextColor(unpack(db.text.vftimecolor))
	self.CenterText:SetFont(file, db.text.vfstacksize, flag)
	self.CenterText:SetTextColor(unpack(db.text.vfstackcolor))
	castHexColor, asHexColor = RGBAToHex(db.text.castcolor), RGBAToHex(db.text.ascolor)
	-- Animations --
	self.FadeoutAnim.Alpha:SetDuration(db.animations.oocduration)
	self.FadeoutAnim.Alpha:SetStartDelay(db.animations.oocstartdelay)
	self.FadeoutAnim.Alpha:SetToAlpha(db.general.oocalpha)
	--[[animations.fade.alpha:SetDuration(db.animations.oocduration)
	animations.fade.alpha:SetStartDelay(db.animations.oocstartdelay)
	animations.fade.alpha:SetToAlpha(db.general.alphaooc)]]--
	--self.AnimatedBorderFrame:SetAlpha(0)
	--[[self.AnimatedBorderFrame.PulseAnim.AlphaOut:SetToAlpha(db.general.border.animated.colorvf[4])
	self.AnimatedBorderFrame.PulseAnim.AlphaOut:SetDuration(db.animations.borderduration / 2)
	self.AnimatedBorderFrame.PulseAnim.AlphaIn:SetFromAlpha(db.general.border.animated.colorvf[4])
	self.AnimatedBorderFrame.PulseAnim.AlphaIn:SetDuration(db.animations.borderduration / 2)
	self.AnimatedBorderFrame.FadeoutAnim.Alpha:SetFromAlpha(db.general.border.animated.colorvf[4])]]--
	--[[animations.vfReady.alphaIn:SetDuration(db.animations.borderduration / 2)
	animations.vfReady.alphaOut:SetDuration(db.animations.borderduration / 2)]]--
	-- Lingering Insanity --
	auras.linsanity.display = db.misc.lingeringinsanity
	-- STM reporting --
	reports.display = db.misc.vfdisreportingenabled
	reports.save = db.misc.vfsavereportingenabled
	reports.maxSaved = db.misc.vfreportingmaxsaved
	-- Mindbender --
	--[[sfiend.enable = db.sfiend.enable
	frames.sfiendBar.deplete = db.sfiend.deplete
	frames.sfiendBar:ClearAllPoints()
	--AddBarToStack(frames.sfiendBar, db.sfiend.pos)
	frames.sfiendBar:SetStatusBarTexture(bartex)
	frames.sfiendBar:SetStatusBarColor(db.sfiend.barcolor[1], db.sfiend.barcolor[2], db.sfiend.barcolor[3], 1)
	frames.sfiendBar:SetValue(0)
	frames.sfiendBar:SetHeight(db.sfiend.height)
	frames.sfiendBar:SetScript("OnShow", function(self)
		self:SetHeight(db.sfiend.height)
	end)
	frames.sfiendBar:SetScript("OnHide", function(self)
		self:SetHeight(0.01)
	end)
	frames.sfiendBar:Hide()
	frames.sfiendBar.tex:SetVertexColor(db.background.color[2], db.background.color[2], db.background.color[3], db.background.color[4])
	frames.sfiendBar.attackMark:ClearAllPoints()
	frames.sfiendBar.attackMark:SetWidth(db.sfiend.markthickness)
	frames.sfiendBar.attackMark.tex:SetVertexColor(db.sfiend.markcolor[1], db.sfiend.markcolor[2], db.sfiend.markcolor[3], db.sfiend.markcolor[4])
	--frames.sfiendBar.attackMark:Hide()
	--sfiend.active = true
	-- GCD --
	gcd.enable = db.gcd.enable
	frames.gcdBar.deplete = db.gcd.deplete
	frames.gcdBar:ClearAllPoints()
	--AddBarToStack(frames.gcdBar, db.gcd.pos)
	frames.gcdBar:SetScript("OnShow", function(self)
		self:SetHeight(db.gcd.height)
	end)
	frames.gcdBar:SetScript("OnHide", function(self)
		self:SetHeight(0.01)
	end)
	frames.gcdBar:SetStatusBarTexture(bartex)
	frames.gcdBar:SetStatusBarColor(db.gcd.barcolor[1], db.gcd.barcolor[2], db.gcd.barcolor[3], 1)
	frames.gcdBar:SetValue(0)
	frames.gcdBar.tex:SetVertexColor(db.background.color[2], db.background.color[2], db.background.color[3], db.background.color[4])
	frames.gcdBar:Hide()]]--
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
