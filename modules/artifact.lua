------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("artifact", {
	label       = "Artifact",
	order       = 3,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowUnspentPoints = true,
			ShowTotalArtifactPower = false,
			UnspentInChatMessage = false,
			ShowBagArtifactPower = true,
			VisualizeBagArtifactPower = true,
			AbbreviateLargeValues = true,
		},
	},
});

module.tooltipText = "You can open artifact talent menu by shift middle clicking."

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = true;

function module:Initialize()
	self:RegisterEvent("ARTIFACT_XP_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("LOADING_SCREEN_ENABLED");
	self:RegisterEvent("LOADING_SCREEN_DISABLED");
	self.inLoadingScreen = true;
	self.scheduledPowerUpdateTimer = 2;
end

function module:LOADING_SCREEN_ENABLED()
	self.inLoadingScreen = true;
end

function module:LOADING_SCREEN_DISABLED()
	self.scheduledPowerUpdateTimer = 2;
end

function module:IsDisabled()
	-- If player doesn't have Legion on their account or hasn't completed first quest of artifact chain
	return GetExpansionLevel() < 6 or not module:HasCompletedArtifactIntro();
end

function module:Update(elapsed)
	if(self.scheduledPowerUpdateTimer) then
		self.scheduledPowerUpdateTimer = self.scheduledPowerUpdateTimer - elapsed;
		if(self.scheduledPowerUpdateTimer <= 0) then
			self.inLoadingScreen = false;
			module:RefreshText();
			self.scheduledPowerUpdateTimer = nil;
		end
	end
end

function module:OnMouseDown(button)
	if(button == "MiddleButton" and IsShiftKeyDown()) then
		if(HasArtifactEquipped()) then
			SocketInventoryItem(INVSLOT_MAINHAND);
			return true;
		end
	end
end

function module:CanLevelUp()
	if(not HasArtifactEquipped()) then return false end
	
	local _, _, _, _, totalXP, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints, xp, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP, artifactTier);
	return numPoints > 0;
end

function module:HasCompletedArtifactIntro()
	local quests = {
		40408, -- Paladin
		40579, -- Warrior
		40618, -- Hunter
		40636, -- Monk
		40646, -- Druid
		40684, -- Warlock
		40706, -- Priest
		40715, -- Death Knight
		40814, -- Demon Hunter
		40840, -- Rogue
		41085, -- Mage
		41335, -- Shaman
	};
	
	for _, questID in ipairs(quests) do
		if(IsQuestFlaggedCompleted(questID)) then return true end
	end
	
	return false;
end

function module:CalculateTotalArtifactPower()
	if(not HasArtifactEquipped()) then return 0 end
	
	local _, _, _, _, currentXP, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
	
	local totalXP = 0;
	
	for i=0, pointsSpent-1 do
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(i, 0, artifactTier);
		totalXP = totalXP + xpForNextPoint;
	end
	
	return totalXP + currentXP;
end

function module:FormatNumber(value)
	if(self.db.global.AbbreviateLargeValues) then
		return Addon:FormatNumberFancy(value);
	end
	return BreakUpLargeNumbers(value);
end

function module:GetText()
	if(not HasArtifactEquipped()) then
		return "No artifact equipped";
	end
	
	local primaryText = {};
	local secondaryText = {};
	
	local itemID, altItemID, name, icon, totalXP, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP, artifactTier);
	
	local remaining         = xpForNextPoint - artifactXP;
	
	local progress          = artifactXP / (xpForNextPoint > 0 and xpForNextPoint or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	tinsert(primaryText,
		("|cffffecB3%s|r (Rank %d):"):format(name, pointsSpent + numPoints)
	);
	
	if(self.db.global.ShowRemaining) then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, module:FormatNumber(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, module:FormatNumber(artifactXP), module:FormatNumber(xpForNextPoint), progressColor, progress * 100)
		);
	end
	
	if(self.db.global.ShowTotalArtifactPower) then
		tinsert(secondaryText,
			("%s |cffffdd00total artifact power|r"):format(module:FormatNumber(module:CalculateTotalArtifactPower()))
		);
	end
	
	if(self.db.global.ShowBagArtifactPower) then
		local totalPower = module:FindPowerItemsInInventory();
		if(totalPower and totalPower > 0) then
			tinsert(secondaryText,
				("%s |cffa8ff00artifact power in bags|r"):format(module:FormatNumber(totalPower))
			);
		end
	end
	
	if(self.db.global.ShowUnspentPoints and numPoints > 0) then
		tinsert(secondaryText,
			("|cff86ff33%d unspent point%s|r"):format(numPoints, numPoints == 1 and "" or "s")
		);
	end
	
	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return HasArtifactEquipped(), "No artifact equipped.";
end

function module:GetChatMessage()
	local outputText = {};
	
	local itemID, altItemID, name, icon, totalXP, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP, artifactTier);
	
	local remaining = xpForNextPoint - artifactXP;
	local progress  = artifactXP / (xpForNextPoint > 0 and xpForNextPoint or 1);
	
	tinsert(outputText, ("%s is currently rank %s"):format(
		name,
		pointsSpent + numPoints
	));
	
	if(pointsSpent > 0) then
		tinsert(outputText, ("at %s/%s power (%.1f%%) with %s to go"):format(
			module:FormatNumber(artifactXP),	
			module:FormatNumber(xpForNextPoint),
			progress * 100,
			module:FormatNumber(remaining)
		));
	end
	
	if(self.db.global.UnspentInChatMessage and numPoints > 0) then
		tinsert(outputText,
			(" (%d unspent point%s)"):format(numPoints, numPoints == 1 and "" or "s")
		);
	end
	
	return table.concat(outputText, " ");
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	if(HasArtifactEquipped()) then
		local itemID, altItemID, name, icon, totalXP, pointsSpent, _, _, _, _, _, _, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo();
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP, artifactTier);
		
		data.id       = itemID;
	
		data.level    = pointsSpent + numPoints or 0;
		data.max  	  = xpForNextPoint;
		data.current  = artifactXP;
		
		if(self.db.global.VisualizeBagArtifactPower) then
			local totalPower = module:FindPowerItemsInInventory();
			data.visual = totalPower;
		end
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Artifact Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining artifact power",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max artifact power",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show total artifact power",
			func = function() self.db.global.ShowTotalArtifactPower = not self.db.global.ShowTotalArtifactPower; module:RefreshText(); end,
			checked = function() return self.db.global.ShowTotalArtifactPower; end,
			isNotRadio = true,
		},
		{
			text = "Show unspent points",
			func = function() self.db.global.ShowUnspentPoints = not self.db.global.ShowUnspentPoints; module:RefreshText(); end,
			checked = function() return self.db.global.ShowUnspentPoints; end,
			isNotRadio = true,
		},
		{
			text = "Include unspent points in chat message",
			func = function() self.db.global.UnspentInChatMessage = not self.db.global.UnspentInChatMessage; module:RefreshText(); end,
			checked = function() return self.db.global.UnspentInChatMessage; end,
			isNotRadio = true,
		},
		{
			text = "Show unspent artifact power in bags",
			func = function() self.db.global.ShowBagArtifactPower = not self.db.global.ShowBagArtifactPower; module:RefreshText(); end,
			checked = function() return self.db.global.ShowBagArtifactPower; end,
			isNotRadio = true,
		},
		{
			text = "Visualize unspent artifact power in bags",
			func = function() self.db.global.VisualizeBagArtifactPower = not self.db.global.VisualizeBagArtifactPower; module:RefreshText(); end,
			checked = function() return self.db.global.VisualizeBagArtifactPower; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Abbreviate large numbers",
			func = function() self.db.global.AbbreviateLargeValues = not self.db.global.AbbreviateLargeValues; module:RefreshText(); end,
			checked = function() return self.db.global.AbbreviateLargeValues; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:ARTIFACT_XP_UPDATE()
	module:Refresh();
end

function module:UNIT_INVENTORY_CHANGED(event, unit)
	if(unit ~= "player") then return end
	if(self:IsDisabled()) then
		Addon:CheckDisabledStatus();
	else
		module:Refresh(true);
	end
end

local EMPOWERING_SPELL_ID = 227907;

local ExperiencerAPScannerTooltip = CreateFrame("GameTooltip", "ExperiencerAPScannerTooltip", nil, "GameTooltipTemplate");

local APStringValueMillion = {
	["enUS"] = "(%d*[%p%s]?%d+) million",
	["enGB"] = "(%d*[%p%s]?%d+) million",
	["ptBR"] = "(%d*[%p%s]?%d+) [[milhão][milhões]]?",
	["esMX"] = "(%d*[%p%s]?%d+) [[millón][millones]]?",
	["deDE"] = "(%d*[%p%s]?%d+) [[Million][Millionen]]?",
	["esES"] = "(%d*[%p%s]?%d+) [[millón][millones]]?",
	["frFR"] = "(%d*[%p%s]?%d+) [[million][millions]]?",
	["itIT"] = "(%d*[%p%s]?%d+) [[milione][milioni]]?",
	["ruRU"] = "(%d*[%p%s]?%d+) млн",
	["koKR"] = "(%d*[%p%s]?%d+)만",
	["zhTW"] = "(%d*[%p%s]?%d+)萬",
	["zhCN"] = "(%d*[%p%s]?%d+) 万",
};
local APValueMultiplier = {
	["koKR"] = 1e4,
	["zhTW"] = 1e4,
	["zhCN"] = 1e4,
};

local APStringValueMillionLocal = APStringValueMillion[GetLocale()];
local APValueMultiplierLocal = (APValueMultiplier[GetLocale()] or 1e6);

function module:FindPowerItemsInInventory()
	if(self.inLoadingScreen) then return 0, 0 end
	
	local powers = {};
	local totalPower = 0;
	
	local spellName = GetSpellInfo(EMPOWERING_SPELL_ID);
	
	for container = 0, NUM_BAG_SLOTS do
		local numSlots = GetContainerNumSlots(container);
		
		for slot = 1, numSlots do
			local link = GetContainerItemLink(container, slot);
			if(link and GetItemSpell(link) == spellName) then
				local power = module:GetItemArtifactPower(link);
				if(power) then
					totalPower = totalPower + power;
					tinsert(powers, {
						link = link,
						power = power,
					});
				end
			end
		end
	end
	
	return totalPower, powers;
end

function module:GetItemArtifactPower(link)
	if(not link) then return nil end
	if(self.inLoadingScreen) then return nil end
	
	ExperiencerAPScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	ExperiencerAPScannerTooltip:SetHyperlink(link);
	
	local tooltipText = ExperiencerAPScannerTooltipTextLeft4:GetText();
	if(not tooltipText) then return nil end
	
	local digit1, digit2, digit3, power;
	local value = strmatch(tooltipText, APStringValueMillionLocal);

	if (value) then
		digit1, digit2 = strmatch(value, "(%d+)[%p%s](%d+)");
		if (digit1 and digit2) then
			power = tonumber(format("%s.%s", digit1, digit2)) * APValueMultiplierLocal; 
		else
			power = tonumber(value) * APValueMultiplierLocal; 
		end 
	else
		digit1, digit2, digit3 = strmatch(tooltipText,"(%d+)[%p%s]?(%d+)[%p%s]?(%d*)");
		power = tonumber(format("%s%s%s", digit1 or "", digit2 or "", (digit2 and digit3) and digit3 or ""));
	end

	if(power) then
		return power;
	end
	
	return nil;
end
