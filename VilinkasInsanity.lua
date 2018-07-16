if select(2, UnitClass("player")) ~= "PRIEST" then return end

local name = ...
_G[name] = CreateFrame("Frame", name .. "Frame", UIParent)
local VilIns = _G[name]

local LSM = LibStub("LibSharedMedia-3.0")
local pairs, ipairs, select = pairs, ipairs, select
local format, sqrt = format, sqrt
local GetTime, GetNetStats, GetSpellCooldown = GetTime, GetNetStats, GetSpellCooldown
local UnitAura, UnitPower, UnitAffectingCombat = UnitAura, UnitPower, UnitAffectingCombat
local GetSpellPowerCost = GetSpellPowerCost

local title = "|cFF9370DB" .. select(2, GetAddOnInfo(name)) .. "|r"
VilIns.title = title

-- Shadow priest
local player = {
	class = "PRIEST",
	shadowSpec=SPEC_PRIEST_SHADOW,
	insanityPowerType=Enum.PowerType.Insanity,
	manaPowerType=Enum.PowerType.Mana,
	guid=nil, inCombat=false,
	insanity=0, maxInsnaity=100, currentCastInsanityGain=0, passiveInsanityGain=0,
	mana=0, maxMana=0, currentCastManaCost=0,
	haste=0,
}
local auras = {
	vform = {id=194249, active=false, duration=0, expirationTime=0, 
		stacks=0, currentStackTime=0, drainStacks=0, drainMod=1,
		baseThreshold=90, threshold=0},
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
		return 14 * imul
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
-- Frames
local frames = { bg, border, borderVf, borderStm, insanityBar, gcdBar, sfiendBar, stmBar, manaBar }
local fontStrings = { insnanity, vfStacks, vfTime }
local animations = { fade, vfReady, vfEnd }
-- DB
local db, defaults

local function CreateFrames()
    -- Create frames
    frames.bg = CreateFrame("Frame", name .. "Background", VilIns)
	frames.border = CreateFrame("Frame", name .. "Border", frames.bg)
	frames.vfBorder = CreateFrame("Frame", name .. "VoidformBorder", frames.border)
	frames.stmBorder = CreateFrame("Frame", name .. "StmBorder", frames.border)
	frames.insanityBar = CreateFrame("StatusBar", name .. "InsanityBar", frames.bg)
	frames.insanityBar.vfMark = CreateFrame("StatusBar", name .. "VoidformMark", frames.insanityBar)
	frames.gcdBar = CreateFrame("StatusBar", name .. "GcdBar", frames.bg)
	frames.sfiendBar = CreateFrame("StatusBar", name .. "ShadowfiendBar", frames.bg)
	frames.sfiendBar.attackMark = CreateFrame("Frame", name .. "MindbenderAttackMark",
		frames.sfiendBar)
	frames.stmBar = CreateFrame("StatusBar", name .. "StmDebuffBar", frames.insanityBar)
	frames.manaBar = CreateFrame("StatusBar", name .. "ManaBar", frames.bg)
	frames.manaBar.dispMark = CreateFrame("Frame", name .. "ManaDispMark", frames.manaBar)
	-- Create font strings
	fontStrings.insnaity = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	fontStrings.vfStacks = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	fontStrings.vfTime = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	-- Create animations
	animations.fade = VilIns:CreateAnimationGroup()
	animations.vfReady = frames.vfBorder:CreateAnimationGroup()
	animations.vfEnd = frames.vfBorder:CreateAnimationGroup()

    -- Setup frames
    frames.bg:SetAllPoints()
    frames.bg.tex = frames.bg:CreateTexture(nil, "BACKGROUND")
    frames.bg.tex:SetAllPoints()
	frames.bg.tex:SetColorTexture(1, 1, 1, 1)
    
    frames.border:SetAllPoints()
	frames.border.texs = {}
    frames.vfBorder:SetAllPoints(frames.border)
    frames.vfBorder.texs = {}
    frames.stmBorder:SetAllPoints(frames.vfBorder)
    frames.stmBorder.texs = {}
    for i=1,4,1 do
        frames.border.texs[i] = frames.border:CreateTexture(nil, "BACKGROUND")
        frames.border.texs[i]:SetColorTexture(1, 1, 1, 1)
        frames.vfBorder.texs[i] = frames.vfBorder:CreateTexture(nil, "BORDER")
        frames.vfBorder.texs[i]:SetColorTexture(1, 1, 1, 1)
        frames.stmBorder.texs[i] = frames.stmBorder:CreateTexture(nil, "ARTWORK")
        frames.stmBorder.texs[i]:SetColorTexture(1, 1, 1, 1)
	end
    
    frames.insanityBar:SetAllPoints()
    frames.insanityBar.cast = frames.insanityBar:CreateTexture()
	frames.insanityBar.passive = frames.insanityBar:CreateTexture()

    frames.gcdBar.tex = frames.gcdBar:CreateTexture(nil, "BACKGROUND")
    frames.gcdBar.tex:SetAllPoints()
	frames.gcdBar.tex:SetColorTexture(1, 1, 1, 1)
	frames.gcdBar:SetMinMaxValues(0, 1)
	
	frames.sfiendBar.tex = frames.sfiendBar:CreateTexture(nil, "BACKGROUND")
    frames.sfiendBar.tex:SetAllPoints()
	frames.sfiendBar.tex:SetColorTexture(1, 1, 1, 1)
	frames.sfiendBar:SetMinMaxValues(0, 1)

	frames.stmBar:SetAllPoints()
	frames.stmBar:SetMinMaxValues(0, 1)

	frames.manaBar.tex = frames.manaBar:CreateTexture(nil, "BACKGROUND")
	frames.manaBar.tex:SetAllPoints()
	frames.manaBar.tex:SetColorTexture(1, 1, 1, 1)
    
    frames.insanityBar.vfMark.tex = frames.insanityBar.vfMark:CreateTexture(nil, "ARTWORK")
    frames.insanityBar.vfMark.tex:SetAllPoints()
	frames.insanityBar.vfMark.tex:SetColorTexture(1, 1, 1, 1)
	
	frames.sfiendBar.attackMark.tex = frames.sfiendBar.attackMark:CreateTexture(nil, "ARTWORK")
	frames.sfiendBar.attackMark.tex:SetAllPoints()
	frames.sfiendBar.attackMark.tex:SetColorTexture(1, 1, 1, 1)

	frames.manaBar.dispMark.tex = frames.manaBar.dispMark:CreateTexture(nil, "ARTWORK")
	frames.manaBar.dispMark.tex:SetAllPoints()
	frames.manaBar.dispMark.tex:SetColorTexture(1, 1, 1, 1)
    
    fontStrings.insnaity:SetPoint("RIGHT", frames.insanityBar, "RIGHT", -2, 0)
    fontStrings.vfStacks:SetPoint("CENTER", frames.insanityBar, "CENTER")
    fontStrings.vfTime:SetPoint("LEFT", frames.insanityBar, "LEFT", 2, 0)
    
    -- Setup animations
    animations.fade:SetToFinalAlpha(true)
    animations.fade.alpha = animations.fade:CreateAnimation("Alpha")
    animations.fade.alpha:SetFromAlpha(1.0)
    animations.fade.alpha:SetSmoothing("NONE")
    
    animations.vfReady:SetToFinalAlpha(true)
    animations.vfReady:SetLooping("REPEAT")
    animations.vfReady.alphaIn = animations.vfReady:CreateAnimation("Alpha")
    animations.vfReady.alphaIn:SetSmoothing("OUT")
    animations.vfReady.alphaIn:SetOrder(1)
    animations.vfReady.alphaIn:SetFromAlpha(0.0)
    animations.vfReady.alphaIn:SetToAlpha(1.0)
    animations.vfReady.alphaOut = animations.vfReady:CreateAnimation("Alpha")
    animations.vfReady.alphaOut:SetSmoothing("IN")
    animations.vfReady.alphaOut:SetOrder(2)
    animations.vfReady.alphaOut:SetFromAlpha(1.0)
    animations.vfReady.alphaOut:SetToAlpha(0.0)
    
    animations.vfEnd:SetToFinalAlpha(true)
    animations.vfEnd.alpha = animations.vfEnd:CreateAnimation("Alpha")
    animations.vfEnd.alpha:SetSmoothing("NONE")
    animations.vfEnd.alpha:SetFromAlpha(1.0)
    animations.vfEnd.alpha:SetToAlpha(0.0)
	animations.vfEnd.alpha:SetDuration(0.1)

	local function SetValue(self, value)
		local parent = self:GetParent()
		local baseValue = player.insanity
		local maxValue = baseValue + value
		if maxValue > player.maxInsnaity then
			value = player.maxInsnaity - baseValue
		end
		
		local parentWidth = parent:GetWidth()
		local left = baseValue / player.maxInsnaity
		local right = (baseValue + value) / player.maxInsnaity
		local left_position = (baseValue / player.maxInsnaity) * parentWidth
		local width = (value / player.maxInsnaity) * parentWidth
		if width < 0.5 then
			self:Hide()
		else
			self:ClearAllPoints()
			self:SetTexCoord(left, right, 0, 1)
			self:SetWidth(width)
			self:SetPoint("TOPLEFT", left_position, 0)
			self:SetPoint("BOTTOMLEFT", left_position, 0)
			self:Show()
		end
	end

	frames.insanityBar.cast.SetValue = SetValue
	frames.insanityBar.passive.SetValue = SetValue

	local function SetOffset(self, offset)
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

	frames.insanityBar.vfMark.SetOffset = SetOffset
	frames.sfiendBar.attackMark.SetOffset = SetOffset

	local function SetBorderSize(self, size)
		for i=1,4,1 do
			self.texs[i]:ClearAllPoints()
		end
		self.texs[1]:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, size)
		self.texs[1]:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", 0, -size)
		self.texs[1]:SetSize(size, 0)
		self.texs[2]:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, size)
		self.texs[2]:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", 0, -size)
		self.texs[2]:SetSize(size, 0)
		self.texs[3]:SetPoint("TOPRIGHT", self, "BOTTOMLEFT")
		self.texs[3]:SetPoint("TOPLEFT", self, "BOTTOMRIGHT")
		self.texs[3]:SetSize(0, size)
		self.texs[4]:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT")
		self.texs[4]:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
		self.texs[4]:SetSize(0, size)
	end

	frames.border.SetBorderSize = SetBorderSize
	frames.vfBorder.SetBorderSize = SetBorderSize
	frames.stmBorder.SetBorderSize = SetBorderSize
	
	VilIns.frames = frames
	VilIns.animations = animations
	VilIns.fontStrings = fontStrings
end

local function UpdateVoidformTresholdMark()
	local vform = auras.vform
	if talents.lotvoid.active then
		vform.threshold = talents.lotvoid.threshold
	else
		vform.threshold = auras.vform.baseThreshold
	end

	if vform.threshold <= 99 then
		local offsetX = vform.threshold / player.maxInsnaity
		frames.insanityBar.vfMark:SetOffset(offsetX)
		frames.insanityBar.vfMark:Show()
	else
		frames.insanityBar.vfMark:Hide()
	end
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

local function GetPlayerAuraInfo(auraId, filter)
	for i = 1, 40 do
		local _, _, count, _, duration, expirationTime, _, _, _, id = UnitAura("player", i, filter)
		if id == auraId then
			return true, count, duration, expirationTime
		end
	end
	return false, 0, 0, 0
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

function VilinkasInsanity:ClearSavedVfReps()
	for i = 1,#db.vfreportarchive do
		table.remove(db.vfreportarchive)
	end
	print(title .. " VF report:")
	print("Saved reports cleared!")
end

local function UpdateMaxPower()
	player.maxInsnaity = UnitPowerMax("player", player.insnaityPowerType)
	player.maxMana = UnitPowerMax("player", player.manaPowerType)
	frames.insanityBar:SetMinMaxValues(0, player.maxInsnaity)
	frames.manaBar:SetMinMaxValues(0, player.maxMana)
	UpdateVoidformTresholdMark()
end

local canEnterVfPrev = false
local function UpdatePower()
	player.insanity = UnitPower("player", player.insnaityPowerType)
	if not (auras.vform.stacks > 0) then
		if (player.insanity >= auras.vform.threshold) and not canEnterVfPrev then
			animations.vfEnd:Stop()
			animations.vfReady:Play()
			canEnterVfPrev = true
		elseif player.insanity < auras.vform.threshold and canEnterVfPrev then
			animations.vfReady:Finish()
			canEnterVfPrev = false
		end
	end
	player.mana = UnitPower("player", player.manaPowerType)
end

local function UpdateInventory()
end

function VilinkasInsanity:SetupPlayerState()
	player.guid = UnitGUID("player")
	player.haste = UnitSpellHaste("player")
	player.inCombat = UnitAffectingCombat("player")
	if not player.inCombat then
		local oocAlpha = animations.fade.alpha:GetToAlpha()
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
	auras.vform.active, auras.vform.stacks = GetPlayerAuraInfo(auras.vform.id)
	auras.linsanity.active, auras.linsanity.stacks = GetPlayerAuraInfo(auras.linsanity.id)
	auras.vtorrent.active = GetPlayerAuraInfo(auras.vtorrent.id, "HELPFUL")
	auras.stmbuff.active = GetPlayerAuraInfo(auras.stmbuff.id, "HELPFUL")
	local stmdebuffActive, _, stmdebuffDuration, stmdebuffExpirationTime = GetPlayerAuraInfo(auras.stmdebuff.id, "HARMFUL")
	auras.stmdebuff.active = stmdebuffActive
	auras.stmdebuff.duration = stmdebuffDuration
	auras.stmdebuff.expirationTime = stmdebuffExpirationTime

	talents.aspirits.targets = {}
	UpdateMaxPower()
	UpdatePower()
	UpdateInventory()
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
	fontStrings.insnaity:SetText(castGainText .. passiveGainText .. player.insanity)
	local vform = auras.vform
	if (vform.stacks > 0) then
		fontStrings.vfStacks:SetText(format("%d (%d%%)", vform.stacks, player.haste))
		fontStrings.vfTime:SetText(format("%.1f (%d)", GetVoidformTime(currentTime), vform.drainStacks))
	elseif (auras.linsanity.stacks > 0) and auras.linsanity.display then
		fontStrings.vfStacks:SetText(format("%d", auras.linsanity.stacks))
		fontStrings.vfTime:SetText("")
	else
		fontStrings.vfStacks:SetText("")
		fontStrings.vfTime:SetText("")
	end
end

local function UpdateInsanityBar()
	local insanityBar = frames.insanityBar
	insanityBar:SetValue(player.insanity)
	insanityBar.cast:SetValue(player.currentCastInsanityGain)
	insanityBar.passive:SetValue(player.passiveInsanityGain)
end

local function UpdateManaBar()
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

local updateRate, lastUpdateTime = 0.02, 0
local function OnUpdate()
	local currentTime = GetTime()
	local dt = currentTime - lastUpdateTime

	
	if dt > updateRate then
		UpdateAS(currentTime)
		UpdateSF(currentTime)

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

		UpdateManaBar()
		UpdateGCD(currentTime)
		--UpdateSTM(currentTime)

		player.passiveInsanityGain = 0
		lastUpdateTime = currentTime
	end
end

function VilIns:Setup()
	local spec = GetSpecialization()
	local show = false
	if spec == player.shadowSpec then
		if not VilIns.frames then
			CreateFrames()
			self:UpdateSettings()
		end
		show = true
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("ENCOUNTER_START")
		self:RegisterEvent("ENCOUNTER_END")
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
	else
		self:UnregisterEvent("PLAYER_TALENT_UPDATE")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("ENCOUNTER_START")
		self:UnregisterEvent("ENCOUNTER_END")
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
	end

	self:SetScript("OnUpdate", OnUpdate)
	self:SetShown(show)
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

VilIns:RegisterEvent("ADDON_LOADED")
VilIns:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if name == ... then
			self:Setup()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		--print("PLAYER_ENTERING_WORLD")
		self:SetupPlayerState()
	elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
		player.inCombat = UnitAffectingCombat("player")
		if player.inCombat then
			animations.fade:Stop()
			self:SetAlpha(1)
		else
			animations.fade:Play()
		end
	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
		--print("ACTIVE_TALENT_GROUP_CHANGED")
		self:Setup()
	elseif event == "PLAYER_TALENT_UPDATE" then
		--print("PLAYER_TALENT_UPDATE")
		if GetSpecialization() == player.shadowSpec then
			talents.lotvoid.active = select(4, GetTalentInfo(talents.lotvoid.tier, talents.lotvoid.column, 1))
			talents.fotmind.active = select(4, GetTalentInfo(talents.fotmind.tier, talents.fotmind.column, 1))
			talents.mbender.active = select(4, GetTalentInfo(talents.mbender.tier, talents.mbender.column, 1))
			talents.aspirits.active = select(4, GetTalentInfo(talents.aspirits.tier, talents.aspirits.column, 1))
			if not talents.aspirits.active then
				talents.aspirits.targets = {}
				talents.aspirits.count = 0
			end
			UpdateVoidformTresholdMark()
		end
	elseif event == "UNIT_POWER_FREQUENT" then
		UpdatePower()
	elseif event == "UNIT_MAXPOWER" then
		--print("UNIT_MAXPOWER")
		UpdateMaxPower()
	elseif event == "UNIT_SPELL_HASTE" then
		--print("UNIT_SPELL_HASTE")
		player.haste = UnitSpellHaste("player")
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		local _, _, spellId = ...
		player.currentCastInsanityGain = spellInsanityGain[spellId]()
		if not player.inCombat and player.currentCastInsanityGain > 0 then
			animations.fade:Stop()
			self:SetAlpha(1)
		end
		StartGcd(spellId)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellId = ...
		StartGcd(spellId)
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if not player.inCombat and player.currentCastInsanityGain > 0 then
			animations.fade:Play()
		end
		player.currentCastInsanityGain = 0
	elseif event == "ENCOUNTER_START" then
			local _, encounterName = ...
			reports.encounterName = encounterName
	elseif event == "ENCOUNTER_END" then
			reports.encounterName = nil
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, logEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
		
		if sourceGUID == player.guid then
			--print(format("Name: %s id: %s source: %s dest: %s event: %s", spellName, spellId, sourceGUID, destGUID, logEvent))
			-- Voidform --
			if spellId == auras.vform.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					local vform = auras.vform
					vform.currentStackTime = GetTime()
					vform.drainStacks = 1
					vform.active, vform.stacks = GetPlayerAuraInfo(vform.id)
					animations.vfEnd:Stop()
					animations.vfReady:Stop()
					frames.vfBorder:SetAlpha(1.0)
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
					animations.vfEnd:Play()
					FinaliseVfRep()
				end
			-- Lingering Insianity --
			elseif spellId == auras.linsanity.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.linsanity.active, auras.linsanity.stacks = GetPlayerAuraInfo(auras.linsanity.id)
				elseif logEvent == "SPELL_AURA_REMOVED_DOSE" then
					auras.linsanity.stacks = auras.linsanity.stacks - 1
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.linsanity.stacks = 0
				end
			-- Surrender to Madness --
			elseif spellId == auras.stmbuff.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.stmbuff.active = true
					reports.current.stmduration = GetTime()
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.stmbuff.active = false
				end
			elseif spellId == auras.stmdebuff.id then
				if logEvent == "SPELL_AURA_APPLIED" then
					auras.stmdebuff.active = true
					--[[local stmdebuffActive, _, stmdebuffDuration, stmdebuffExpirationTime = GetPlayerAuraInfo(auras.stmdebuff.id, "HARMFUL")
					auras.stmdebuff.active = stmdebuffActive
					auras.stmdebuff.duration = stmdebuffDuration
					auras.stmdebuff.expirationTime = stmdebuffExpirationTime
					frames.stmBorder:Show()
					frames.stmBar:Show()]]--
				elseif logEvent == "SPELL_AURA_REMOVED" then
					auras.stmdebuff.active = false
					--[[frames.stmBorder:Hide()
					frames.stmBar:Hide()]]--
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
				if vform.stacks > 0 then
					FinaliseVfRep()
				end
				talents.aspirits.targets = {}
				vform.currentStackTime = 0
				vform.drainStacks = 0
				vform.stacks = 0
				auras.linsanity.stacks = 0
				auras.stmbuff.active = false
				auras.stmdebuff.active = false
				auras.voitorrent.active = false
				animations.vfReady:Stop()
				animations.vfEnd:Play()
			elseif destGUID == sfiend.guid then
				sfiend.active = false
				frames.sfiendBar:Hide()
			elseif talents.aspirits.targets[destGUID] then
				talents.aspirits.targets[destGUID] = nil
			end
		end
	end
end)

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
function VilIns:UpdateSettings()
    if not db then
        default = {
            profile = {
                general = {
                    posx = 0,
                    posy = 0,
                    width = 250,
                    height = 22,
                    alphaooc = 0.3,
                    orientation = "HORIZONTAL",
                    anchor = "SCREEN",
                },
                bars = {
                    texture = "Blizzard Raid Bar",
                    insbarcolor = { 0.4, 0, 0.8, 1 },
                    castbarcolor = { 1, 1, 1, 1 },
                    asbarcolor = { 1, 0.31, 0.85, 1 },
                },
                background = {
                    color = { 0.2, 0.2, 0.2, 0.5 },
                },
                border = {
                    thickness = 1,
                    color = { 0.0, 0.0, 0.0, 0.7 },
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
                    lotvthreshold = 60,
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
	self:SetPoint("CENTER", db.general.posx, db.general.posy)
	self:SetSize(db.general.width, db.general.height)
	local bugFix = self:GetWidth() -- If I dont call this function on VilIns I get wrong width later on when I need to update voidform mark. I know its weird :)
	-- Background --
	frames.bg.tex:SetVertexColor(db.background.color[1], db.background.color[2], db.background.color[3], db.background.color[4])
	-- Border --
	for i=1,4,1 do
		frames.border.texs[i]:SetVertexColor(db.border.color[1], db.border.color[2], db.border.color[3], db.border.color[4])
		frames.vfBorder.texs[i]:SetVertexColor(db.animations.bordercolor[1], db.animations.bordercolor[2], db.animations.bordercolor[3], db.animations.bordercolor[4])
		frames.stmBorder.texs[i]:SetVertexColor(db.misc.borderstmdebuffcolor[1], 
			db.misc.borderstmdebuffcolor[2], db.misc.borderstmdebuffcolor[3], db.misc.borderstmdebuffcolor[4])
	end
	local borderThickness = db.border.thickness
	frames.border:SetBorderSize(borderThickness)
	frames.vfBorder:SetBorderSize(borderThickness)
	frames.stmBorder:SetBorderSize(borderThickness)
	frames.stmBorder:Hide()
	-- Bars --
	local bartex = LSM:Fetch("statusbar", db.bars.texture)
	frames.insanityBar:SetStatusBarTexture(bartex)
	frames.insanityBar:SetStatusBarColor(db.bars.insbarcolor[1], db.bars.insbarcolor[2], db.bars.insbarcolor[3], 1)
	frames.insanityBar.cast:SetTexture(bartex)
	frames.insanityBar.cast:SetVertexColor(db.bars.castbarcolor[1], db.bars.castbarcolor[2], db.bars.castbarcolor[3], 1)
	frames.insanityBar.passive:SetTexture(bartex)
	frames.insanityBar.passive:SetVertexColor(db.bars.asbarcolor[1], db.bars.asbarcolor[2], db.bars.asbarcolor[3], 1)
	-- Enter Voidform Mark --
	talents.lotvoid.threshold = db.misc.lotvthreshold
    frames.insanityBar.vfMark:ClearAllPoints()
    frames.insanityBar.vfMark:SetWidth(db.overlay.thickness)
	frames.insanityBar.vfMark.tex:SetVertexColor(db.overlay.color[1], db.overlay.color[2], db.overlay.color[3], 1)
	UpdateVoidformTresholdMark()
	-- Font --
	local file = LSM:Fetch("font", db.text.file)
	local flag = db.text.flag
	fontStrings.insnaity:SetFont(file, db.text.insanitysize, flag)
	fontStrings.insnaity:SetTextColor(db.text.insanitycolor[1], db.text.insanitycolor[2], db.text.insanitycolor[3], 1)
	fontStrings.vfTime:SetFont(file, db.text.vftimesize, flag)
	fontStrings.vfTime:SetTextColor(db.text.vftimecolor[1], db.text.vftimecolor[2], db.text.vftimecolor[3], 1)
	fontStrings.vfStacks:SetFont(file, db.text.vfstacksize, flag)
	fontStrings.vfStacks:SetTextColor(db.text.vfstackcolor[1], db.text.vfstackcolor[2], db.text.vfstackcolor[3], 1)
	insanityHexColor, castHexColor, asHexColor = RGBAToHex(db.text.castcolor), RGBAToHex(db.text.castcolor), RGBAToHex(db.text.ascolor)
	-- Animations --
	animations.fade.alpha:SetDuration(db.animations.oocduration)
	animations.fade.alpha:SetStartDelay(db.animations.oocstartdelay)
	animations.fade.alpha:SetToAlpha(db.general.alphaooc)
	frames.vfBorder:SetAlpha(0)
	animations.vfReady.alphaIn:SetDuration(db.animations.borderduration / 2)
	animations.vfReady.alphaOut:SetDuration(db.animations.borderduration / 2)
	-- Lingering Insanity --
	auras.linsanity.display = db.misc.lingeringinsanity
	-- STM reporting --
	reports.display = db.misc.vfdisreportingenabled
	reports.save = db.misc.vfsavereportingenabled
	reports.maxSaved = db.misc.vfreportingmaxsaved
	-- Mindbender --
	sfiend.enable = db.sfiend.enable
	frames.sfiendBar.deplete = db.sfiend.deplete
	frames.sfiendBar:ClearAllPoints()
	AddBarToStack(frames.sfiendBar, db.sfiend.pos)
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
	AddBarToStack(frames.gcdBar, db.gcd.pos)
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
	frames.gcdBar:Hide()
end

SLASH_VILINKASINSANITY1, SLASH_VILINKASINSANITY2 = "/vilinkasinsanity", "/vilins"

SlashCmdList["VILINKASINSANITY"] = function(message)
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
