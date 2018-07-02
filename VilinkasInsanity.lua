if select(2, UnitClass("player")) ~= "PRIEST" then return end
--if tonumber(select(4, GetBuildInfo())) < 80000 then return end

local name, addon = ...
_G[name] = addon
local VilinkasInsanity = addon

local LAD = LibStub("LibArtifactData-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local pairs, ipairs, select = pairs, ipairs, select
local format, sqrt = format, sqrt
local GetTime, GetNetStats, GetSpellCooldown = GetTime, GetNetStats, GetSpellCooldown
local UnitAura, UnitPower, UnitAffectingCombat = UnitAura, UnitPower, UnitAffectingCombat

local title = "|cFF9370DB" .. select(2, GetAddOnInfo(name)) .. "|r"
addon.title = title

-- Setup event frame
addon.eventFrame = CreateFrame("Frame", name .. "EventFrame", UIParent)
function addon:RegisterEvent(event) addon.eventFrame:RegisterEvent(event) end
function addon:RegisterUnitEvent(event, unit) addon.eventFrame:RegisterUnitEvent(event, unit) end
function addon:UnregisterEvent(event) addon.eventFrame:UnregisterEvent(event) end
function addon:SetScript(frameScriptTypeName, scriptFunction) 
	addon.eventFrame:SetScript(frameScriptTypeName, scriptFunction) 
end
addon.eventFrame:SetScript("OnEvent", function(self, event, ...) addon[event](addon, ...) end)

local onUpdateRate = 0.05
-- Shadow priest
local player = {
	class="PRIEST", shadowSpec=SPEC_PRIEST_SHADOW, 
	insanityPowerType=Enum.PowerType.Insanity, insanity=0, maxInsnaity=0, 
	manaPowerType=Enum.PowerType.Mana, mana=0, maxMana=0, 
	haste=0, inCombat=false, isCasting=false, castInsnaity=0,
}
-- Spells
local spells = {
	mblast={id=8092, igain=15}, 
	swvoid={id=205351, igain=25},
	vtouch={id=34914, igain=6}, 
	mflay={id=15407, igain=3},
	msear={id=48045, igain=3},
	cttvflay={id=193473, igain=3},
}
setmetatable(spells, {
	__call=function(self, id)
		for _,v in pairs(self) do
			if v.id == id then
				return v.igain
			end
		end
		return 0
	end})
-- Auras
local auras = {
	voitorrent={id=205065, active=false},
	stmbuff={id=193223, active=false, imul=2},
	stmdebuff={id=263406, active=false, expirationTime=0, duration=0},
	linsanity={id=197937, active=false, stacks=0, display=false},
	pinfusion={id=10060, active=false, imul=1.25},
	emind={id=247226, stacks=0},
	mbender={id=200174, active=false, display=false, igain=8, lastAttackTime=0,
		baseAttackSpeed=1.5, startTime=0, duration=0, GUID=nil},
}
-- Voidform
local voidform = {
	id=194249, baseThreshold=100--[[90 (bfa)]], currentStackTime=0, stacks=0, 
	drainStacks=0, threshold=0, drainMod=1
}
-- Talents / Artefact traits / Azerite armor traits
local talents = {
	lotvoid={active=false, threshold=0, tier=7, column=1},
	aspirits={active=false, targets={}, spawnId=147193, despawnId=148859, igain=3, tier=5, column=2}, -- tier=5, column=1 -- Bfa
	fotmind={active=false, imul=1.2, tier=1, column=2}, -- tier=1, column=1 -- Bfa
	cttvoid={active=false, spawns={}, id=193470, artifactId=128827, traitId=1575},
}
-- Text colors
local hexColors = { insnaity=nil, cast=nil, passive=nil }
-- T20 set bonuses
local setBonuses = {
	t20={itemIds={ 147163, 147164, 147165, 147166, 147167, 147168 },
	is2setActive=false, is4setActive=false, drainMod=0.90, stmDrainMod=0.95}
}
-- VF reports
local reports = { current={}, display, save, maxSaved, encounterName }
-- GCD
local gcd = { start=0, duration=0, eanble=false }
-- Frames
local frames = { main, bg, border, borderVf, borderStm, insanityBar, gcdBar, mindbenderBar, stmBar, manaBar }
local fontStrings = { insnanity, vfStacks, vfTime }
local animations = { fade, vfReady, vfEnd }
-- DB
local db, defaults

local function CreateFrames()
    -- Create frames
    frames.main = CreateFrame("Frame", name .. "MainFrame", UIParent)
    frames.bg = CreateFrame("Frame", name .. "Background", frames.main)
	frames.border = CreateFrame("Frame", name .. "Border", frames.bg)
	frames.vfBorder = CreateFrame("Frame", name .. "VoidformBorder", frames.border)
	frames.stmBorder = CreateFrame("Frame", name .. "StmBorder", frames.border)
	frames.insanityBar = CreateFrame("StatusBar", name .. "InsanityBar", frames.bg)
	frames.insanityBar.vfMark = CreateFrame("Frame", name .. "VoidformMark", frames.insanityBar)
	frames.gcdBar = CreateFrame("StatusBar", name .. "GcdBar", frames.bg)
	frames.mindbenderBar = CreateFrame("StatusBar", name .. "MindbenderBar", frames.bg)
	frames.mindbenderBar.attackMark = CreateFrame("Frame", name .. "MindbenderAttackMark",
		frames.mindbenderBar)
	frames.stmBar = CreateFrame("StatusBar", name .. "StmDebuffBar", frames.insanityBar)
	frames.manaBar = CreateFrame("StatusBar", name .. "ManaBar", frames.bg)
	frames.manaBar.dispMark = CreateFrame("Frame", name .. "ManaDispMark", frames.manaBar)
	-- Create font strings
	fontStrings.insnaity = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	fontStrings.vfStacks = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	fontStrings.vfTime = frames.insanityBar:CreateFontString(nil, "OVERLAY")
	-- Create animations
	animations.fade = frames.main:CreateAnimationGroup()
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
	
	frames.mindbenderBar.tex = frames.mindbenderBar:CreateTexture(nil, "BACKGROUND")
    frames.mindbenderBar.tex:SetAllPoints()
	frames.mindbenderBar.tex:SetColorTexture(1, 1, 1, 1)
	frames.mindbenderBar:SetMinMaxValues(0, 1)

	frames.stmBar:SetAllPoints()
	frames.stmBar:SetMinMaxValues(0, 1)

	frames.manaBar.tex = frames.manaBar:CreateTexture(nil, "BACKGROUND")
	frames.manaBar.tex:SetAllPoints()
	frames.manaBar.tex:SetColorTexture(1, 1, 1, 1)
    
    frames.insanityBar.vfMark.tex = frames.insanityBar.vfMark:CreateTexture(nil, "ARTWORK")
    frames.insanityBar.vfMark.tex:SetAllPoints()
	frames.insanityBar.vfMark.tex:SetColorTexture(1, 1, 1, 1)
	
	frames.mindbenderBar.attackMark.tex = frames.mindbenderBar.attackMark:CreateTexture(nil, "ARTWORK")
	frames.mindbenderBar.attackMark.tex:SetAllPoints()
	frames.mindbenderBar.attackMark.tex:SetColorTexture(1, 1, 1, 1)

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
	
	VilinkasInsanity.frames = frames
end

local function UpdateBorderSize(border, size)
	for i=1,4,1 do
		border.texs[i]:ClearAllPoints()
	end
	border.texs[1]:SetPoint("TOPRIGHT", border, "TOPLEFT", 0, size)
	border.texs[1]:SetPoint("BOTTOMRIGHT", border, "BOTTOMLEFT", 0, -size)
	border.texs[1]:SetSize(size, 0)
	border.texs[2]:SetPoint("TOPLEFT", border, "TOPRIGHT", 0, size)
	border.texs[2]:SetPoint("BOTTOMLEFT", border, "BOTTOMRIGHT", 0, -size)
	border.texs[2]:SetSize(size, 0)
	border.texs[3]:SetPoint("TOPRIGHT", border, "BOTTOMLEFT")
	border.texs[3]:SetPoint("TOPLEFT", border, "BOTTOMRIGHT")
	border.texs[3]:SetSize(0, size)
	border.texs[4]:SetPoint("BOTTOMRIGHT", border, "TOPRIGHT")
	border.texs[4]:SetPoint("BOTTOMLEFT", border, "TOPLEFT")
	border.texs[4]:SetSize(0, size)
end

local function UpdateMark(mark, offsetX)
	local parent = mark:GetParent()
	local parent_width = parent:GetWidth()
	local mark_half_width = mark:GetWidth() / 2
	mark:ClearAllPoints()
	mark:SetPoint("TOPLEFT", parent, "TOPLEFT", parent_width * offsetX - mark_half_width, 0)
	mark:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -parent_width * (1 - offsetX) + mark_half_width, 0)
end

local function UpdateVoidformTresholdMark()
	if select(4, GetTalentInfo(talents.lotvoid.tier, talents.lotvoid.column, 1)) then
		voidform.threshold = talents.lotvoid.threshold
	else
		voidform.threshold = voidform.baseThreshold
	end

	if voidform.threshold <= 99 then
		local offsetX = voidform.threshold / player.maxInsnaity
		UpdateMark(frames.insanityBar.vfMark, offsetX)
		frames.insanityBar.vfMark:Show()
	else
		frames.insanityBar.vfMark:Hide()
	end
end

local function UpdateBarValueHelper(bar, base_value, value, parent_width)
	local max_value = base_value + value
	if max_value > player.maxInsnaity then
		value = player.maxInsnaity - base_value
	end
	local width = parent_width
	local left = base_value / player.maxInsnaity
	local right = (base_value + value) / player.maxInsnaity
	local left_position = (base_value / player.maxInsnaity) * width
	local bar_width = (value / player.maxInsnaity) * width
	if bar_width < 0.5 then
		bar:Hide()
	else
		bar:ClearAllPoints()
		bar:SetTexCoord(left, right, 0, 1)
		bar:SetWidth(bar_width)
		bar:SetPoint("TOPLEFT", left_position, 0)
		bar:SetPoint("BOTTOMLEFT", left_position, 0)
		bar:Show()
	end
end

local function UpdateBarValues(cast, as)
    frames.insanityBar:SetValue(player.insanity)
    local insanityBarWidth = frames.insanityBar:GetWidth()
    UpdateBarValueHelper(frames.insanityBar.cast, player.insanity, cast, insanityBarWidth)
    UpdateBarValueHelper(frames.insanityBar.passive, player.insanity + cast, as, insanityBarWidth)
end

local function GetInsanityDrain(stack)
	--return 6 + ((stack - 1) * (0.8) * voidform.drainMod) -- Bfa
	return 6 + ((stack - 1) * (2/3) * voidform.drainMod)
end

local function GetVoidformTime()
	if player.insanity > 0 and voidform.stacks > 0 then
		-- Drain current stack
		local vfCurrStackTimeLeft = 1.0 - (GetTime() - voidform.currentStackTime)-- + select(4, GetNetStats()) / 1000
		local vfCurrStackDrain = GetInsanityDrain(voidform.drainStacks)
		if ((vfCurrStackDrain * vfCurrStackTimeLeft) > player.insanity) then
			vfCurrStackTimeLeft = player.insanity / vfCurrStackDrain
			return vfCurrStackTimeLeft
		else
			local ins = player.insanity - (vfCurrStackDrain * vfCurrStackTimeLeft)
			-- Sum d+(x-1)*f*dm, Sum x=m to n => (-1/2)*(m-n-1)*(2*d+f*dm*(m+n-2))=ins => Solve for n, d=6, f=(2/3)
			-- Sum d+(x-1)*f*dm, Sum x=m to n => (-1/2)*(m-n-1)*(2*d+f*dm*(m+n-2))=ins => Solve for n, d=6, f=(0.8) -- Bfa
			local dm, m = voidform.drainMod, voidform.drainStacks + 1 -- We already drained current stack
			-- local vfRemStacks = (sqrt(dm*dm*(2*m-3)*(2*m-3)+dm*10*(ins+6*m-9)+225)+dm-15) / (2*dm) -- Bfa
			local vfRemStacks = (sqrt(dm*dm*(9-12*m+4*m*m)+dm*(72*m-108+12*ins)+324)+dm-18) / (2*dm)
			return vfCurrStackTimeLeft + (vfRemStacks - voidform.drainStacks)
		end
	else
		return 0
	end
end

local function UpdateBarText(castGain, asGain)
    local castGainText = castGain > 0 and "|c" .. castHexColor .. castGain .. "|r + " or ""
	local asGainText = asGain > 0 and "|c" .. asHexColor .. asGain .. "|r + " or ""
	fontStrings.insnaity:SetText(castGainText .. asGainText .. player.insanity)
	if (voidform.stacks > 0) then
		fontStrings.vfStacks:SetText(format("%d (%d%%)", voidform.stacks, player.haste))
		fontStrings.vfTime:SetText(format("%.1f (%d)", GetVoidformTime(), voidform.drainStacks))
	elseif (auras.linsanity.stacks > 0) and auras.linsanity.display then
		fontStrings.vfStacks:SetText(format("%d", auras.linsanity.stacks))
		fontStrings.vfTime:SetText("")
	else
		fontStrings.vfStacks:SetText("")
		fontStrings.vfTime:SetText("")
	end
end

local function GetAsInsanityGain(currTime)
	if not talents.aspirits.active then return 0 end
	local gain = 0
	local targets = talents.aspirits.targets
	for guid in pairs(targets) do
		if targets[guid] ~= nil then
			if (currTime - targets[guid].lastUpdateTime) > 10 then
				targets[guid] = nil
			else
				gain = gain + targets[guid].asCount*talents.aspirits.igain
			end
		end
	end
    
    return gain
end

local function GetSpellInsanityGain(castId)
	local gain = spells(castId)
	if not (gain > 0) then return 0 end
	if (castId == spells.mblast.id or castId == spells.mflay.id) then
		if castId == spells.mblast.id and setBonuses.t20.is2setActive then -- Legion
			gain = gain + auras.emind.stacks
		end
		if talents.fotmind.active then
			gain = gain * talents.fotmind.imul
		end
	end

    return gain
end

local function GetCttvInsanityGain(currTime) -- Legion
	if not talents.cttvoid.active then return 0 end
	local gain = 0
	local spawns = talents.cttvoid.spawns
	for guid in pairs(spawns) do
		if spawns[guid] ~= nil then
			if (currTime - spawns[guid].spawnTime) > 10 then
				spawns[guid] = nil
			else
				if spawns[guid].isCasting then
					gain = gain + spells.cttvflay.igain
				end
			end
		end
	end
	if talents.fotmind.active then gain = gain * talents.fotmind.imul end

	return gain
end

local function UpdateMindbender(currTime)
	local insanityGain = 0
	if auras.mbender.active and auras.mbender.enable then
		local timeLeft = auras.mbender.duration - (currTime - auras.mbender.startTime)
		local bar = frames.mindbenderBar
		if not (timeLeft > 0) then
			auras.mbender.active = false
			bar:Hide()
		else
			local attacksSpeed = auras.mbender.baseAttackSpeed / (1 + (player.haste / 100))
			local predictedTimeNextAttack = auras.mbender.lastAttackTime + attacksSpeed
			local pct = (currTime - auras.mbender.startTime) / auras.mbender.duration
			local deplete = bar.deplete
			if deplete then
				bar:SetValue(1 - pct)
			else
				bar:SetValue(pct)
			end
			if (predictedTimeNextAttack - currTime) < -0.5 then
				-- Remove attack mark
				bar.attackMark:Hide()
			else
				-- Continue as normal
				local nextAttackPtc = (predictedTimeNextAttack - auras.mbender.startTime) / auras.mbender.duration

				if deplete then
					UpdateMark(bar.attackMark, 1 - nextAttackPtc)
				else
					UpdateMark(bar.attackMark, nextAttackPtc)
				end

				frames.mindbenderBar.attackMark:Show()

				insanityGain = auras.mbender.igain
			end
		end
	end

	return insanityGain
end

local function UpdateGcdBar(currTime)
	if gcd.start > 0 then
		local netTime = 0--select(4, GetNetStats()) / 1000)
		local pct = (currTime - gcd.start - netTime) / gcd.duration
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

local function UpdateStm(currTime)
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

local lastOnUpdateTime = 0
local function OnUpdate(self)
	local currTime = GetTime()
	local timeSinceLastOnUpdate = currTime - lastOnUpdateTime
	if timeSinceLastOnUpdate >= onUpdateRate then
		local castGain, asGain = 0, 0, 0
		mindbenderGain = UpdateMindbender(currTime)
		if not auras.stmdebuff.active then
			castGain = player.castInsnaity + GetCttvInsanityGain(currTime)
			asGain = GetAsInsanityGain(currTime) + mindbenderGain
			if auras.stmbuff.active then
				castGain = castGain * auras.stmbuff.imul
				asGain = asGain * auras.stmbuff.imul
			end
			if auras.pinfusion.active then
				castGain = castGain * auras.pinfusion.imul
				asGain = asGain * auras.pinfusion.imul 
			end
		
		else
			UpdateStm(currTime)
		end

		if setBonuses.t20.is4setActive then -- Legion
			if auras.stmbuff.active then
				voidform.drainMod = setBonuses.t20.stmDrainMod
			else
				voidform.drainMod = setBonuses.t20.drainMod
			end
		else
			voidform.drainMod = 1
		end

		UpdateBarText(castGain, asGain)
		UpdateBarValues(castGain, asGain)
		UpdateGcdBar(currTime)
	end

	timeSinceLastOnUpdate = currTime
end

local function GetPlayerBuffCount(spellId)
	for i = 1, 40 do
		local _, _, _, count, _, _, _, _, _, _, auraId = UnitAura("player", i, "HELPFUL")
		--local _, _, count, _, _, _, _, _, _, auraId = UnitAura("player", i, "HELPFUL") -- Bfa
		if spellId == auraId then
			return count
		end
	end
	return 0
end

local function HasPlayerAura(spellId, filter)
	for i = 1, 40 do
		local auraId = select(11, UnitAura("player", i, filter))
		--local auraId = select(10, UnitAura("player", i, filter)) -- Bfa
		if spellId == auraId then
			return true
		end
	end
	return false
end

local function GetPlayerAuraTime(spellId, filter)
	for i = 1, 40 do
		auraId = select(11, UnitAura("player", i, filter))
		local duration, expirationTime, _, _, _, spellId = select(5, UnitAura("player", i, filter))
		--local _, _, _, _, _, _, _, _, _, auraId = UnitAura("player", i, filter) -- Bfa
		if spellId == auraId then
			return duration, expirationTime
		end
	end
	return nil
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

VilinkasInsanity:RegisterEvent("ADDON_LOADED")
function VilinkasInsanity:ADDON_LOADED(...)
	if name == ...	then
		self:ACTIVE_TALENT_GROUP_CHANGED()
		--self:UNIT_MAXPOWER()
		--self:PLAYER_TALENT_UPDATE()
		--self:UNIT_INVENTORY_CHANGED()
		self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	end
end

function VilinkasInsanity:ACTIVE_TALENT_GROUP_CHANGED()
	if GetSpecialization() == player.shadowSpec then
        if not frames.main then
            CreateFrames()
            self:UpdateSettings()
        end
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
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
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
		
		self:SetScript("OnUpdate", OnUpdate)
		
		if not UnitAffectingCombat("player") then
			local oocAlpha = animations.fade.alpha:GetToAlpha()
			frames.main:SetAlpha(oocAlpha)
		end
		
		--self:PLAYER_TALENT_UPDATE()
		--self:UNIT_INVENTORY_CHANGED()
		frames.main:Show()
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
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_INVENTORY_CHANGED")

		self:SetScript("OnUpdate", nil)
		
		if frames.main then frames.main:Hide() end
	end
end

function VilinkasInsanity:PLAYER_TALENT_UPDATE()
	if GetSpecialization() ~= player.shadowSpec then return end
	--self:UNIT_MAXPOWER()
	talents.fotmind.active = select(4, GetTalentInfo(talents.fotmind.tier, talents.fotmind.column, 1))
	talents.aspirits.active = select(4, GetTalentInfo(talents.aspirits.tier, talents.aspirits.column, 1))
	if not talents.aspirits.active then
		talents.aspirits.targets = {}
	end
	UpdateVoidformTresholdMark()
	--[[if select(4, GetTalentInfo(talents.lotvoid.tier, talents.lotvoid.column, 1)) then
		voidform.threshold = talents.lotvoid.threshold
	else
		voidform.threshold = voidform.baseThreshold
	end

    if voidform.threshold < 99 then
		local offsetX = voidform.threshold / player.maxInsnaity
		UpdateMark(frames.insanityBar.vfMark, offsetX)
		frames.insanityBar.vfMark:Show()
	else
		frames.insanityBar.vfMark:Hide()
	end]]--
end

local function IsSetBonusActive(setItemIds)
	local setItems = 0
	for i = 1, #setItemIds do
		if IsEquippedItem(setItemIds[i]) then
			setItems = setItems + 1
		end
	end
	if setItems >= 4 then
		return true, true
	elseif setItems >= 2 then
		return true, false
	else
		return false, false
	end
end

function VilinkasInsanity:UNIT_INVENTORY_CHANGED()
	setBonuses.t20.is2setActive, setBonuses.t20.is4setActive = IsSetBonusActive(setBonuses.t20.itemIds) -- Legion
end

function VilinkasInsanity:PLAYER_ENTERING_WORLD()
	if not UnitAffectingCombat("player") then
		local oocAlpha = animations.fade.alpha:GetToAlpha()
		frames.main:SetAlpha(oocAlpha)
	end
	voidform.stacks = GetPlayerBuffCount(voidform.id)
	auras.linsanity.stacks = GetPlayerBuffCount(auras.linsanity.id)
	auras.voitorrent.active = HasPlayerAura(auras.voitorrent.id, "HELPFUL")
	auras.stmbuff.active = HasPlayerAura(auras.stmbuff.id, "HELPFUL")
	auras.stmdebuff.active = HasPlayerAura(auras.stmdebuff.id, "HARMFUL")
	auras.pinfusion.active = HasPlayerAura(auras.pinfusion.id, "HELPFUL")
	auras.emind.stacks = GetPlayerBuffCount(auras.emind.id)
	local haveTotem, _, startTime, duration = GetTotemInfo(1)
	if haveTotem then
		auras.mbender.duration = duration
		auras.mbender.startTime = startTime
		auras.mbender.active = true
		frames.mindbenderBar:Show()
	end
	if auras.stmdebuff.active then
		local duration, expirationTime = GetPlayerAuraTime(auras.stmdebuff.id, "HARMFUL")
		stmDebuffDuration = duration
		stmDebuffExpirationTime = expirationTime
		frames.stmBorder:Show()
	end
	talents.aspirits.targets = {}
	self:UNIT_POWER_FREQUENT()
	self:UNIT_SPELL_HASTE()
	self:UNIT_MAXPOWER()
	self:UNIT_INVENTORY_CHANGED()
end

function VilinkasInsanity:PLAYER_REGEN_ENABLED()
    player.inCombat = false
	animations.fade:Play()
end

function VilinkasInsanity:PLAYER_REGEN_DISABLED()
    player.inCombat = true
	animations.fade:Stop()
	frames.main:SetAlpha(1)
end

local canEnterVfPrev = false
function VilinkasInsanity:UNIT_POWER_FREQUENT()
	player.insanity = UnitPower("player", player.insnaityPowerType)
	if not (voidform.stacks > 0) then
		if (player.insanity >= voidform.threshold) and not canEnterVfPrev then
			animations.vfEnd:Stop()
			animations.vfReady:Play()
			canEnterVfPrev = true
		elseif player.insanity < voidform.threshold and canEnterVfPrev then
			animations.vfReady:Finish()
			canEnterVfPrev = false
		end
	end
	player.mana = UnitPower("player", player.manaPowerType)
end

function VilinkasInsanity:UNIT_MAXPOWER()
	if GetSpecialization() ~= player.shadowSpec then return end
	player.maxInsnaity = UnitPowerMax("player", player.insnaityPowerType)
	player.maxMana = UnitPowerMax("player", player.manaPowerType)
	frames.insanityBar:SetMinMaxValues(0, player.maxInsnaity)
	frames.manaBar:SetMinMaxValues(0, player.maxMana)
	UpdateVoidformTresholdMark()
end

function VilinkasInsanity:UNIT_SPELL_HASTE()
	player.haste = UnitSpellHaste("player")
end

local function StartGcd(spellId)
	local start, duration = GetSpellCooldown(spellId)
	if start > 0 and gcd.enable then
		gcd.start = start
		gcd.duration = duration
		frames.gcdBar:Show()
	end
end

function VilinkasInsanity:UNIT_SPELLCAST_START(_, _, spellId, _, legionSpellId)
	--player.castInsnaity = GetSpellInsanityGain(spellId) -- Bfa
	player.castInsnaity = GetSpellInsanityGain(legionSpellId)
	
	if not player.inCombat and player.castInsnaity > 0 then
		animations.fade:Stop()
		frames.main:SetAlpha(1)
	end
	
	StartGcd(legionSpellId)
	--StartGcd(spellId) -- Bfa
end

function VilinkasInsanity:UNIT_SPELLCAST_SUCCEEDED(_, _, spellId, _, legionSpellId)
	StartGcd(legionSpellId)
	--StartGcd(spellId) -- Bfa
end

function VilinkasInsanity:UNIT_SPELLCAST_STOP()
	if not player.inCombat and player.castInsnaity > 0 then
		animations.fade:Play()
    end
    player.castInsnaity = 0
end

function VilinkasInsanity:UNIT_SPELLCAST_CHANNEL_START(_, _, spellId, _, legionSpellId)
	--player.castInsnaity = GetSpellInsanityGain(spellId) -- Bfa
	player.castInsnaity = GetSpellInsanityGain(legionSpellId)
end

function VilinkasInsanity:UNIT_SPELLCAST_CHANNEL_STOP()
    player.castInsnaity = 0
end

function VilinkasInsanity:ENCOUNTER_START(encounterID, encounterName)
	reports.encounterName = encounterName
end

function VilinkasInsanity:ENCOUNTER_END(encounterID, encounterName)
	reports.encounterName = nil
end

local function CombatLogEventVoidform(event)
    if event == "SPELL_AURA_APPLIED" then
        voidform.currentStackTime = GetTime()
		voidform.drainStacks = 1
		voidform.stacks = GetPlayerBuffCount(voidform.id)
        animations.vfEnd:Stop()
        animations.vfReady:Stop()
        frames.vfBorder:SetAlpha(1.0)
        CreateVfRep()
    elseif event == "SPELL_AURA_APPLIED_DOSE" then
        voidform.currentStackTime = GetTime()
        if not auras.voitorrent.active then
            voidform.drainStacks = voidform.drainStacks + 1
            reports.current.vfdrainstacks = voidform.drainStacks
        end
        voidform.stacks = voidform.stacks + 1
        reports.current.vfstacks = voidform.stacks
    elseif event == "SPELL_AURA_REMOVED" then
        voidform.drainStacks = 0
        voidform.stacks = 0
        voidform.currentStackTime = 0
        animations.vfEnd:Play()
        FinaliseVfRep()
    end
end

local function CombatLogEventAsSpawn(destGUID)
	if talents.aspirits.active then
		targets = talents.aspirits.targets
        if not targets[destGUID] then
            targets[destGUID] = {}
            targets[destGUID].asCount = 0
            targets[destGUID].asSpawnTime = {}
        end
        targets[destGUID].asCount = targets[destGUID].asCount + 1
        targets[destGUID].lastUpdateTime = GetTime()
    end
end

local function CombatLogEventAsDespawn(destGUID)
	if talents.aspirits.active then
		targets = talents.aspirits.targets
        if targets[destGUID] then
            targets[destGUID].asCount = targets[destGUID].asCount - 1
            targets[destGUID].lastUpdateTime = GetTime()
            if targets[destGUID].asCount <= 0 then
                targets[destGUID] = nil
            end
        end
    end
end

local function CombatLogEventCttvSpawn(destGUID)
	if talents.cttvoid.active then
		talents.cttvoid.spawns[destGUID] = {}
		talents.cttvoid.spawns[destGUID].spawnTime = GetTime()
	end
end

local function CombatLogEventCttvCast(sourceGUID, event)
	if event == "SPELL_AURA_APPLIED" then
		talents.cttvoid.spawns[sourceGUID].isCasting = true
	elseif event == "SPELL_AURA_REMOVED" then
		talents.cttvoid.spawns[sourceGUID].isCasting = false
	end
end

local function CombatLogEventPlayerDied()
    if voidform.stacks > 0 then
        FinaliseVfRep()
    end
    talents.aspirits.targets = {}
    voidform.currentStackTime = 0
    voidform.drainStacks = 0
    voidform.stacks = 0
    auras.linsanity.stacks = 0
    auras.stmbuff.active = false
    auras.stmdebuff.active = false
    auras.voitorrent.active = false
    animations.vfReady:Stop()
	animations.vfEnd:Play()
end

function VilinkasInsanity:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, event, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = ... -- = CombatLogGetCurrentEventInfo() -- Bfa
	--print(format("Name: %s id: %s source: %s dest: %s event: %s", spellName, spellId, sourceGUID, destGUID, event))
	if sourceGUID == UnitGUID("player") then
		--print(format("Name: %s id: %s source: %s dest: %s event: %s", spellName, spellId, sourceGUID, destGUID, event))
		-- Voidform --
		if spellId == voidform.id then
			CombatLogEventVoidform(event)
		-- Lingering Insianity --
		elseif spellId == auras.linsanity.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.linsanity.stacks = GetPlayerBuffCount(spellId)
			elseif event == "SPELL_AURA_REMOVED_DOSE" then
				--auras[spellIds.linsanity].stacks = auras[spellIds.linsanity].stacks - 1 -- Bfa
				auras.linsanity.stacks = auras.linsanity.stacks - 2
			elseif event == "SPELL_AURA_REMOVED" then
				auras.linsanity.stacks = 0
			end
		-- Surrender to Madness --
		elseif spellId == auras.stmbuff.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.stmbuff.active = true
				reports.current.stmduration = GetTime()
			elseif event == "SPELL_AURA_REMOVED" then
				auras.stmbuff.active = false
				FinaliseVfRep()
            end
		elseif spellId == auras.stmdebuff.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.stmdebuff.active = true
				local duration, expirationTime = GetPlayerAuraTime(spellId, "HARMFUL")
				auras.stmdebuff.duration = duration
				auras.stmdebuff.expirationTime = expirationTime
				frames.stmBorder:Show()
				frames.stmBar:Show()
			elseif event == "SPELL_AURA_REMOVED" then
				auras.stmdebuff.active = false
				frames.stmBorder:Hide()
				frames.stmBar:Hide()
			end
		-- Power Infusion --
		elseif spellId == auras.pinfusion.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.pinfusion.active = true
			elseif event == "SPELL_AURA_REMOVED" then
				auras.pinfusion.active = false
			end
		-- Auspicious Spirits Spawn --
		elseif spellId == talents.aspirits.spawnId then
			if event == "SPELL_CAST_SUCCESS" then
				CombatLogEventAsSpawn(destGUID)
			end
		-- Auspicious Spirits Despawn --
		elseif spellId == talents.aspirits.despawnId then
			if event == "SPELL_DAMAGE" or event == "SPELL_MISSED" then
				CombatLogEventAsDespawn(destGUID)
			end
		-- Void Torrent --
		elseif spellId == auras.voitorrent.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.voitorrent.active = true
			elseif event == "SPELL_AURA_REMOVED" then
				auras.voitorrent.active = false
			end
		-- Mindbender --
		elseif spellId == auras.mbender.id then
			if event == "SPELL_SUMMON" then
				auras.mbender.GUID = destGUID
				local _, _, startTime, duration = GetTotemInfo(1)
				auras.mbender.duration = duration
				auras.mbender.startTime = startTime
				auras.mbender.active = true
				frames.mindbenderBar:Show()
			end
		-- Call to the Void --
		elseif spellId == talents.cttvoid.id then
			if event == "SPELL_SUMMON" then
				CombatLogEventCttvSpawn(destGUID)
			end
		-- Empty Mind --
		elseif spellId == auras.emind.id then
			if event == "SPELL_AURA_APPLIED" then
				auras.emind.stacks = GetPlayerBuffCount(emAuraId)
			elseif event == "SPELL_AURA_APPLIED_DOSE" then
				auras.emind.stacks = auras.emind.stacks + 1
			elseif event == "SPELL_AURA_REMOVED" then
				auras.emind.stacks = 0
			end
		end
	elseif sourceGUID == auras.mbender.GUID and event == "SWING_DAMAGE" then
		auras.mbender.lastAttackTime = GetTime()
	-- Mindbender Power Leech spell (200010)
	elseif destGUID == UnitGUID("player") and spellId == 200010 and event == "SPELL_ENERGIZE" then
		auras.mbender.lastAttackTime = GetTime()
		auras.mbender.GUID = sourceGUID
	-- Void Tentacle spawned by Call to the Void --
	elseif talents.cttvoid.spawns[sourceGUID] then
		-- Void Tentacle's Mind Flay --
		if spellId == spells.cttvflay.id then
			CombatLogEventCttvCast(sourceGUID, event)
		end
	end
	if event == "UNIT_DIED" then
		if destGUID == UnitGUID("player") then
			CombatLogEventPlayerDied()
		elseif destGUID == auras.mbender.GUID then
			auras.mbender.active = false
			frames.mindbenderBar:Hide()
		elseif talents.aspirits.targets[destGUID] then
			talents.aspirits.targets[destGUID] = nil
		end
	end
end

function VilinkasInsanity:ARTIFACT_EQUIPPED_CHANGED(message, newArtifactID, oldArtifactID)
	talents.cttvoid.active = false
	if newArtifactID == talents.cttvoid.artifactId then
		local id, data = LAD:GetArtifactTraits(newArtifactID)
		for _,v in pairs(data) do
			if v.traitID == talents.cttvoid.traitId then
				talents.cttvoid.active = true
			end
		end
	end
end
LAD.RegisterCallback(VilinkasInsanity, "ARTIFACT_EQUIPPED_CHANGED")

function VilinkasInsanity:ARTIFACT_TRAITS_CHANGED(message, artifactID, traitsData)
	talents.cttvoid.active = false
	if artifactID == talents.cttvoid.artifactId then
		for _,v in pairs(traitsData) do
			if v.traitID == talents.cttvoid.traitId then
				talents.cttvoid.active = true
			end
		end
	end
end
LAD.RegisterCallback(VilinkasInsanity, "ARTIFACT_TRAITS_CHANGED")

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
function VilinkasInsanity:UpdateSettings()
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
					--lotvthreshold = 60, -- Bfa
                    lotvthreshold = 65,
                    lingeringinsanity = true,
                    vfdisreportingenabled = 2,
                    vfsavereportingenabled = 1,
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
				mindbender = {
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
	frames.main:ClearAllPoints()
	frames.main:SetPoint("CENTER", db.general.posx, db.general.posy)
	frames.main:SetSize(db.general.width, db.general.height)
	local bugFix = frames.main:GetWidth() -- If I dont call this function on frames.main I get wrong width later on when I need to update voidform mark. I know its weird :)
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
	UpdateBorderSize(frames.border, borderThickness)
	UpdateBorderSize(frames.vfBorder, borderThickness)
	UpdateBorderSize(frames.stmBorder, borderThickness)
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
	auras.mbender.enable = db.mindbender.enable
	frames.mindbenderBar.deplete = db.mindbender.deplete
	frames.mindbenderBar:ClearAllPoints()
	AddBarToStack(frames.mindbenderBar, db.mindbender.pos)
	frames.mindbenderBar:SetStatusBarTexture(bartex)
	frames.mindbenderBar:SetStatusBarColor(db.bars.asbarcolor[1], db.bars.asbarcolor[2], db.bars.asbarcolor[3], 1)
	frames.mindbenderBar:SetValue(0)
	frames.mindbenderBar:SetHeight(db.mindbender.height)
	frames.mindbenderBar:SetScript("OnShow", function(self)
		self:SetHeight(db.mindbender.height)
	end)
	frames.mindbenderBar:SetScript("OnHide", function(self)
		self:SetHeight(0.01)
	end)
	--frames.mindbenderBar:Hide()
	frames.mindbenderBar.tex:SetVertexColor(db.background.color[2], db.background.color[2], db.background.color[3], db.background.color[4])
	frames.mindbenderBar.attackMark:ClearAllPoints()
	frames.mindbenderBar.attackMark:SetWidth(db.mindbender.markthickness)
	frames.mindbenderBar.attackMark.tex:SetVertexColor(db.mindbender.markcolor[1], db.mindbender.markcolor[2], db.mindbender.markcolor[3], db.mindbender.markcolor[4])
	--frames.mindbenderBar.attackMark:Hide()
	auras.mbender.active = true
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
