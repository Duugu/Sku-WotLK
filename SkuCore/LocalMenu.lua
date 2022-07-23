---------------------------------------------------------------------------------------------------------------------------------------
local MODULE_NAME, MODULE_PART = "SkuCore", "LocalMenu"
local L = Sku.L
local _G = _G

SkuCore = SkuCore or LibStub("AceAddon-3.0"):NewAddon("SkuCore", "AceConsole-3.0", "AceEvent-3.0")

---------------------------------------------------------------------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------------------------------------------------------------------
local escapes = {
	["|c%x%x%x%x%x%x%x%x"] = "", -- color start
	["|r"] = "", -- color end
	["|H.-|h(.-)|h"] = "%1", -- links
	["|T.-|t"] = "", -- textures
	["{.-}"] = "", -- raid target icons
}
local function unescape(str)
	if not str then return end
	for k, v in pairs(escapes) do
		str = string.gsub(str, k, v)
	end
	return str
end

local maxItemNameLength = 40
local function ItemName_helper(aText)
	aText = unescape(aText)
	local tShort, tLong = aText, ""

	local tStart, tEnd = string.find(tShort, "\r\n")
	local taTextWoLb = aText
	if tStart then
		taTextWoLb = string.sub(tShort, 1, tStart - 1)
		tLong = aText
	end

	if string.len(taTextWoLb) > maxItemNameLength then
		local tBlankPos = 1
		while (string.find(taTextWoLb, " ", tBlankPos + 1) and tBlankPos < maxItemNameLength) do
			tBlankPos = string.find(taTextWoLb, " ", tBlankPos + 1)
		end
		if tBlankPos > 1 then
			tShort = string.sub(taTextWoLb, 1, tBlankPos).."..."
		else
			tShort = string.sub(taTextWoLb, 1, maxItemNameLength).."..."
		end		
		tLong = aText
	else
		tShort = taTextWoLb
	end

	tShort = string.gsub(tShort, "\r\n", " ")
	tShort = string.gsub(tShort, "\n", " ")
	return tShort, tLong
end

---------------------------------------------------------------------------------------------------------------------------------------
local function GetButtonTooltipLines(aButtonObj, aTooltipObject)

	local tTooltipObj = aTooltipObject or GameTooltip

	if not aTooltipObject then
		GameTooltip:ClearLines()
		if aButtonObj.type then
			if aButtonObj.type ~= "" then
				if aButtonObj:GetScript("OnEnter") then
					aButtonObj:GetScript("OnEnter")(aButtonObj)
				end
			end
		end
	end

	local tQualityString = nil
	local itemName, ItemLink = tTooltipObj:GetItem()
	if not itemName then
		itemName, ItemLink = tTooltipObj:GetSpell()
	end

	if ItemLink then
		for x = 0, #ITEM_QUALITY_COLORS do
			local tItemCol = ITEM_QUALITY_COLORS[x].color:GenerateHexColor()
			if tItemCol == "ffa334ee" then 
				tItemCol = "ffa335ee"
			end
			if string.find(ItemLink, tItemCol) then
				if _G["ITEM_QUALITY"..x.."_DESC"] then
					tQualityString = _G["ITEM_QUALITY"..x.."_DESC"]
				end
			end
		end
	end


	local tTooltipText = ""
	for i = 1, select("#", tTooltipObj:GetRegions()) do
		local region = select(i, tTooltipObj:GetRegions())
		if region and region:GetObjectType() == "FontString" then
			local text = region:GetText() -- string or nil
			if text then
				if i == 1 and tQualityString and SkuOptions.db.profile["SkuCore"].itemSettings.ShowItemQality == true then
					tTooltipText = tTooltipText..text.." ("..tQualityString..")\r\n"
				else
					tTooltipText = tTooltipText..text.."\r\n"
				end

			end
		end
	end

	if not aTooltipObject then
		tTooltipObj:SetOwner(UIParent, "Center")
		tTooltipObj:Hide()
		if aButtonObj:GetScript("OnLeave") then
			aButtonObj:GetScript("OnLeave")(aButtonObj)
		end
	end
	
	if tTooltipText ~= "asd" then
		if tTooltipText ~= "" then
			tTooltipText = unescape(tTooltipText)
			if tTooltipText then
				local tText, tTextf = ItemName_helper(tTooltipText)
				return tText, tTextf
			end
		end
	end

	return "", ""
end

---------------------------------------------------------------------------------------------------------------------------------------
-- menu items
---------------------------------------------------------------------------------------------------------------------------------------

---@alias EquipLoc string See https://wowpedia.fandom.com/wiki/Enum.InventoryType
---@alias InvSlot integer See https://wowpedia.fandom.com/wiki/InventorySlotId

---Sets tooltip item and returns its cleaned up text.
---(Meant for defining other functions, not meant for direct use)
---@param tooltipSetter fun(tooltip: GameTooltip): void Define how the item tooltip should be set.
---@return string | nil Tooltip text
local function getItemTooltipTextHelper(tooltipSetter)
	local tooltip = _G["SkuScanningTooltip"]
	tooltip:ClearLines()
	tooltipSetter(tooltip)
	local getEscapedText = function() return TooltipLines_helper(tooltip:GetRegions()) end
	if getEscapedText() ~= "asd" and getEscapedText() ~= "" then
		return unescape(getEscapedText())
	end
end

local function getItemTooltipTextFromBagItem(bag, slot, itemId)
	return getItemTooltipTextHelper(function(tooltip)
		if itemId then
			tooltip:SetItemByID(itemId)
		else
			tooltip:SetBagItem(bag, slot)
		end
	end)
end

---Gets tooltip text for given equipped item
---@param invSlot InvSlot
---@return string|nil
local function getEquippedItemTooltipText(invSlot)
	return getItemTooltipTextHelper(function(tooltip)
		tooltip:SetInventoryItem("player", invSlot)
	end)
end

-- to reduce repetition
local BOTH_HANDS = {INVSLOT_MAINHAND, INVSLOT_OFFHAND}
local JUST_MAINHAND = {INVSLOT_MAINHAND}
local JUST_OFFHAND = {INVSLOT_OFFHAND}
local RANGED = {INVSLOT_RANGED}

---See https://wowpedia.fandom.com/wiki/Enum.InventoryType
---@type table<EquipLoc, InvSlot[]> Maps what inventory slots (equipped items) correspond to an equip location.
local comparableInvSlotsforInvType = {
	INVTYPE_HEAD = {INVSLOT_HEAD},
	INVTYPE_NECK = {INVSLOT_NECK},
	INVTYPE_SHOULDER = {INVSLOT_SHOULDER},
	INVTYPE_BODY = {INVSLOT_BODY},
	INVTYPE_CHEST = {INVSLOT_CHEST},
	INVTYPE_WAIST = {INVSLOT_WAIST},
	INVTYPE_LEGS = {INVSLOT_LEGS},
	INVTYPE_FEET = {INVSLOT_FEET},
	INVTYPE_WRIST = {INVSLOT_WRIST},
	INVTYPE_HAND = {INVSLOT_HAND},
	INVTYPE_FINGER = {INVSLOT_FINGER1, INVSLOT_FINGER2},
	INVTYPE_TRINKET = {INVSLOT_TRINKET1, INVSLOT_TRINKET2},
	INVTYPE_WEAPON = CanDualWield() and BOTH_HANDS or JUST_MAINHAND,
	INVTYPE_SHIELD = JUST_OFFHAND,
	INVTYPE_RANGED = RANGED,
	INVTYPE_RELIC = RANGED,
	INVTYPE_AMMO = {INVSLOT_AMMO},
	INVTYPE_2HWEAPON = BOTH_HANDS,
	INVTYPE_CLOAK = {INVSLOT_BACK},
	INVTYPE_TABARD = {INVSLOT_TABARD},
	INVTYPE_ROBE = {INVSLOT_CHEST},
	INVTYPE_THROWN = RANGED,
	INVTYPE_WEAPONMAINHAND = JUST_MAINHAND,
	INVTYPE_WEAPONOFFHAND = JUST_OFFHAND,
	INVTYPE_HOLDABLE = JUST_OFFHAND,
}

---For a given item, Returns item tooltip texts for comparable equipped items.
---@param itemId number Item ID for item for which comparisns will be returned.
---@param cache table|nil Optional lookup table for saving tooltip texts between calls to this function
---@return string[]|nil List of tooltip texts or nil if no slots to compare found
local function getItemComparisnSections(itemId, cache)
	local invType = select(4, GetItemInfoInstant(itemId))
	local invSlotsToCompare = comparableInvSlotsforInvType[invType]
	--if offhand slot and equipped a 2H weapon, compare both hands instead
	if invSlotsToCompare == JUST_OFFHAND then
		local mainHandItemId = GetInventoryItemID("player", JUST_MAINHAND[1])
		if mainHandItemId and select(4, GetItemInfoInstant(mainHandItemId)) == "INVTYPE_2HWEAPON" then
			invSlotsToCompare = BOTH_HANDS
		end
	end

	if not invSlotsToCompare then
		return
	end

	local comparisnSections = {}
	for _, slot in pairs(invSlotsToCompare) do
		local cacheEntry = cache and cache[slot]
		local text = cacheEntry or getEquippedItemTooltipText(slot)
		if text then
			table.insert(comparisnSections, text)
			if not cacheEntry then cache[slot] = text end
		end
	end
	return comparisnSections
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_BagnonGuildFrame(aParentChilds)

	if not BagnonGuildFrame1.bagGroup then
		BagnonGuildFrame.bagToggle:Click()
	end

	for x = 1, 10 do
		local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals, filtered = GetGuildBankTabInfo(x)

		if name and isViewable and isViewable == true then
			local tFriendlyName = name
			local tText, tFullText = name, ""
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = "GuildBankTab"..x,
				RoC = "Child",
				type = "Button",
				obj = _G["GuildBankTab"..x],
				textFirstLine = tFriendlyName,
				textFull = "",
				noMenuNumbers = true,
				childs = {},
				onActionFunc = function()
					SetCurrentGuildBankTab(x) 
					--print(x)
				end,
				click = true,            
			}   
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_BankFrame(aParentChilds)
	--print("Build_BankFrame")
	--ToggleAllBags() 
end

---------------------------------------------------------------------------------------------------------------------------------------
local ContainerFrame1Hook
function SkuCore:Build_BagsFrame(aParentChilds)
	if not ContainerFrame1Hook then
		hooksecurefunc(_G["ContainerFrame1"], "Hide", function()
			for x = 2, 15 do
				if _G["ContainerFrame"..x] then
					_G["ContainerFrame"..x]:Hide()
				end
			end
		end)
		ContainerFrame1Hook = true
	end

	local tEmptyCounter = 1
	local tCurrentParentContainer = nil
	local allBagResults = {}
	local tBagResultsByBag = {}
	local inventoryTooltipTextCache = {}

	local tBagSlotList = {
		[0] = L["Bag"].." 1",
		[1] = L["Bag"].." 2",
		[2] = L["Bag"].." 3",
		[3] = L["Bag"].." 4",
		[4] = L["Bag"].." 5",
		[-1] = L["Bank"],
		[5] = L["Bank"].." "..L["Bag"].." 1",
		[6] = L["Bank"].." "..L["Bag"].." 2",
		[7] = L["Bank"].." "..L["Bag"].." 3",
		[8] = L["Bank"].." "..L["Bag"].." 4",
		[9] = L["Bank"].." "..L["Bag"].." 5",
		[10] = L["Bank"].." "..L["Bag"].." 6",
		[11] = L["Bank"].." "..L["Bag"].." 7",
		[-2] = L["keyring"],
		[-3] = L["Reagent bank"],
	}

	local tBagSlotListSorted = {
		[1] = 0,
		[2] = 1,
		[3] = 2,
		[4] = 3,
		[5] = 4,
		[6] = -1,
		[7] = 5,
		[8] = 6,
		[9] = 7,
		[10] = 8,
		[11] = 9,
		[12] = 10,
		[13] = 11,
		[14] = -2,
		[15] = -3,
	}

	for i, v in pairs(tBagSlotList) do
		if i ~= -1 and GetContainerNumSlots(i) > 0 then
			if not IsBagOpen(i) then
				--print("----", i, v, OpenBag(i))
				OpenBag(i)
			end
		end
	end

	--for bagId = -3, 11 do
	for q = 1, #tBagSlotListSorted do
		local bagId = tBagSlotListSorted[q]
		--print(bagId, IsBagOpen(bagId))
		local tCurrentContainerFrameNumber = IsBagOpen(bagId)
		local tNumSlots = GetContainerNumSlots(bagId)
		for slotId = 1, tNumSlots do
			--print("bagId", bagId, "slotId", slotId)
			local containerFrameName = ""
			if tCurrentContainerFrameNumber then
				containerFrameName = "ContainerFrame"..(tCurrentContainerFrameNumber).."Item"..(tNumSlots - slotId + 1)
			end
			if bagId == -1 and _G["BankFrame"] and _G["BankFrame"]:IsVisible() == true then
				tCurrentContainerFrameNumber = -1
				containerFrameName = "BankFrameItem"..slotId
			end

			local containerFrame = _G[containerFrameName]
			if containerFrame then
				if not tBagResultsByBag[tCurrentContainerFrameNumber] then
					local bagName = tBagSlotList[bagId] --L["Bag"] .. " " .. (tCurrentContainerFrameNumber)
					table.insert(aParentChilds, bagName)
					aParentChilds[bagName] = {
						frameName = containerFrameName,
						RoC = "Child",
						type = "Button",
						obj = containerFrame,
						textFirstLine = bagName,
						textFull = "",
						noMenuNumbers = true,
						childs = {},
					}   

					tBagResultsByBag[(tCurrentContainerFrameNumber)] = { obj = aParentChilds[bagName], childs = {} }
				end

				local tFriendlyName = L["Bag"] .. (tCurrentContainerFrameNumber) .. "-" .. slotId
				local tText = L["Empty"]
				local isEmpty = true
				local bagItemButton

				--update blizzard container object
				containerFrame.GetBag = function() 
					return bagId
				end
				containerFrame.info = containerFrame.info or {}
				containerFrame.info.id = GetContainerItemID(bagId, slotId)
				local _, itemCount = GetContainerItemInfo(bagId, slotId)
				containerFrame.info.count = itemCount

				if containerFrame:IsEnabled() == true then
					aParentChilds[tFriendlyName] = {
						frameName = containerFrameName,
						RoC = "Child",
						type = "Button",
						obj = containerFrame,
						textFirstLine = tText,
						textFull = "",
						noMenuNumbers = true,
						childs = {},
						isNewItem = C_NewItems.IsNewItem(bagId, slotId),
					}   
					bagItemButton = aParentChilds[tFriendlyName]
					--get the onclick func if there is one
					if bagItemButton.obj:IsMouseClickEnabled() == true then
						if bagItemButton.obj:GetObjectType() == "Button" then
							bagItemButton.func = bagItemButton.obj:GetScript("OnClick")
						end
						bagItemButton.containerFrameName = containerFrameName
						bagItemButton.onActionFunc = function(self, aTable, aChildName)

						end
						if bagItemButton.func then
							bagItemButton.click = true
						end
					end

					local maybeText = getItemTooltipTextFromBagItem(bagItemButton.obj:GetParent():GetID(), bagItemButton.obj:GetID(), bagItemButton.obj.info.id)
					if maybeText then
						local tText = maybeText
						isEmpty = false
						if bagItemButton.obj.info then
							if bagItemButton.obj.info.id then
								bagItemButton.itemId = bagItemButton.obj.info.id
								bagItemButton.textFirstLine = ItemName_helper(tText)
								bagItemButton.textFull = SkuCore:AuctionPriceHistoryData(bagItemButton.obj.info.id, true, true)
							end
						end
						if not bagItemButton.textFull then
							bagItemButton.textFull = {}
						end
						local tFirst, tFull = ItemName_helper(tText)
						bagItemButton.textFirstLine = tFirst
						if type(bagItemButton.textFull) ~= "table" then
							bagItemButton.textFull = { (bagItemButton.textFull or bagItemButton.textFirstLine or ""), }
						end
						table.insert(bagItemButton.textFull, 1, tFull)
						local itemId = bagItemButton.itemId
						if itemId and IsEquippableItem(itemId) then
							local comparisnSections = getItemComparisnSections(itemId, inventoryTooltipTextCache)
							if comparisnSections then
								for i, section in ipairs(comparisnSections) do
									local sectionHeader = #comparisnSections > 1 and L["currently equipped"].." "..i.."\r\n" or L["currently equipped"].."\r\n"
									table.insert(bagItemButton.textFull, i + 1, sectionHeader .. section)
								end
							end
						end
					end

					if bagItemButton.textFirstLine == "" and bagItemButton.textFull == "" and bagItemButton.obj.ShowTooltip then
						GameTooltip:ClearLines()
						bagItemButton.obj:ShowTooltip()
						if TooltipLines_helper(GameTooltip:GetRegions()) ~= "asd" then
							if TooltipLines_helper(GameTooltip:GetRegions()) ~= "" then
								local tText = unescape(TooltipLines_helper(GameTooltip:GetRegions()))
								bagItemButton.textFirstLine, bagItemButton.textFull = ItemName_helper(tText)
								isEmpty = false
							end
						end
					end
					
					if _G[containerFrameName .. "Count"] and not containerFrame.info then
						if bagItemButton and _G[containerFrameName .. "Count"]:GetText() then
							if not isEmpty then
								bagItemButton.textFirstLine = bagItemButton.textFirstLine .. " " .. _G[containerFrameName .. "Count"]:GetText()
							end
						end
					end
					if bagItemButton and (string.find(containerFrameName, "ContainerFrame") or string.find(containerFrameName, "BankFrameItem") )then
						if bagItemButton.textFirstLine then
							bagItemButton.textFirstLine = (#tBagResultsByBag[(tCurrentContainerFrameNumber)].childs + 1) .. " " .. bagItemButton.textFirstLine
							tEmptyCounter = tEmptyCounter + 1
						end
					end
					if _G[containerFrameName .. "Count"] and bagItemButton then
						bagItemButton.stackSize = _G[containerFrameName .. "Count"]:GetText()
					end
					if containerFrame.info then
						bagItemButton.itemId = containerFrame.info.id
						if not containerFrame.info.count then
							bagItemButton.textFirstLine = bagItemButton.textFirstLine
						else
							if not isEmpty and containerFrame.info.count > 1 then
								bagItemButton.textFirstLine = bagItemButton.textFirstLine .. " " .. containerFrame.info.count
							end
						end								
					end							
				end
				
				tBagResultsByBag[(tCurrentContainerFrameNumber)].childs[#tBagResultsByBag[(tCurrentContainerFrameNumber)].childs + 1] = bagItemButton
				-- if the item slot isn't empty, add it to allBagResults
				if not isEmpty then
					-- create a copy that doesn't have the numbering in textFirstLine
					copy = {}
					for k, v in pairs(bagItemButton) do
						copy[k] = v
					end
					copy.textFirstLine = string.sub(copy.textFirstLine, string.find(copy.textFirstLine, " ") + 1)
					table.insert(allBagResults, copy)
					allBagResults[copy] = copy
				end
				
			end
		end  
	end

	for i, v in pairs(tBagResultsByBag) do
		for ic, vc in pairs(v.childs) do
			table.insert(v.obj.childs, vc)
			v.obj.childs[vc] = vc
		end
	end

	-- sort all items alphabetically, putting newly acquired on top
	table.sort(allBagResults, function(item1, item2)
		if item1.isNewItem and not item2.isNewItem then
			return true
		elseif item2.isNewItem and not item1.isNewItem then
			return false
		end
		return item1.textFirstLine < item2.textFirstLine
	end)

	-- prepend "new" to all new items
	for _, itemButton in pairs(allBagResults) do
		if itemButton.isNewItem then
			if not string.find(itemButton.textFirstLine, "^"..L["New"]) then
				itemButton.textFirstLine = L["New"] .. " " .. itemButton.textFirstLine
			end
		end
	end
	-- all items menu item
	do
		local allItemsMenuItemName = L["all items"]
		table.insert(aParentChilds, allItemsMenuItemName)
		aParentChilds[allItemsMenuItemName] = {
			RoC = "Child",
			type = "Button",
			textFirstLine = allItemsMenuItemName,
			noMenuNumbers = true,
			childs = allBagResults,
		}
	end

	local tFriendlyName = L["Bags"]
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = nil,
		RoC = "Child",
		type = "Button",
		obj = nil,
		textFirstLine = tFriendlyName,
		textFull = "",
		noMenuNumbers = true,
		childs = {},
		func = nil,
		click = true,
	}   

	tCurrentParentContainer = aParentChilds[tFriendlyName]

	local tBarBagSlots = {
		[1] = _G["MainMenuBarBackpackButton"],
		[2] = _G["CharacterBag0Slot"],
		[3] = _G["CharacterBag1Slot"],
		[4] = _G["CharacterBag2Slot"],
		[5] = _G["CharacterBag3Slot"],
	}

	for x = 1, #tBarBagSlots do
		local containerFrameName = "CharacterBag".. x.."Slot"
		if tBarBagSlots[x] then
			local tFriendlyName = L["Bag-slot"] .. " " .. (x)
			if tBarBagSlots[x]:IsEnabled() == true then
				aParentChilds[tFriendlyName] = {
					frameName = tBarBagSlots[x]:GetName(),--L["Bag-slot"]..(x),
					RoC = "Child",
					type = "Button",
					obj = tBarBagSlots[x],
					textFirstLine = tFriendlyName,
					textFull = "",
					noMenuNumbers = true,
					childs = {},
					func = tBarBagSlots[x]:GetScript("OnClick"),
					click = true,
					isBag = true,
				}   
				if x == 1 or x == 6 then
					aParentChilds[tFriendlyName].childs = {}
					aParentChilds[tFriendlyName].type = "Text"
					aParentChilds[tFriendlyName].func = nil
				end   

				GameTooltip:ClearLines()
				aParentChilds[tFriendlyName].obj:GetScript("OnEnter")(aParentChilds[tFriendlyName].obj)
				if TooltipLines_helper(GameTooltip:GetRegions()) ~= "asd" then
					if TooltipLines_helper(GameTooltip:GetRegions()) ~= "" then
						local tText = unescape(TooltipLines_helper(GameTooltip:GetRegions()))
						--[[
						if string.find(tText, "Equip Container") then
							tText = L["Empty"]
						end
						]]
						tText = x.." "..tText
						aParentChilds[tFriendlyName].textFirstLine, aParentChilds[tFriendlyName].textFull = ItemName_helper(tText)
					end
				end
			end

			table.insert(tCurrentParentContainer.childs, aParentChilds[tFriendlyName])
			tCurrentParentContainer.childs[aParentChilds[tFriendlyName] ] = aParentChilds[tFriendlyName]
		end
	end    
	
	if _G["BankSlotsFrame"] and _G["BankSlotsFrame"].Bag1:IsVisible() == true then
		local numPurBankSlots, fullBankSlots = GetNumBankSlots()
		local costForNextPur = GetBankSlotCost(numPurBankSlots)

		for x = 1, numPurBankSlots do
			local containerFrameName = "Bag"..x
			local tFriendlyName = ""--"Bank Bag slot".." "..(x)
			if _G["BankSlotsFrame"]["Bag"..x]:IsEnabled() == true then


				--local tText = _G["BankSlotsFrame"]["Bag"..x].tooltipText
				--print(x, tText)--Purchasable

				aParentChilds[tFriendlyName] = {
					frameName = "BankSlotsFrame.Bag"..x,
					RoC = "Child",
					type = "Button",
					obj = _G["BankSlotsFrame"]["Bag"..x],
					textFirstLine = tFriendlyName,
					textFull = "",
					noMenuNumbers = true,
					childs = {},
					func = _G["BankSlotsFrame"]["Bag"..x]:GetScript("OnClick"),
					click = true,
					isBag = true,
				}   

				GameTooltip:ClearLines()
				aParentChilds[tFriendlyName].obj:GetScript("OnEnter")(aParentChilds[tFriendlyName].obj)
				if TooltipLines_helper(GameTooltip:GetRegions()) ~= "asd" then
					if TooltipLines_helper(GameTooltip:GetRegions()) ~= "" then
						local tText = unescape(TooltipLines_helper(GameTooltip:GetRegions()))
						tText = x.." "..tText
						aParentChilds[tFriendlyName].textFirstLine, aParentChilds[tFriendlyName].textFull = ItemName_helper(tText)
						aParentChilds[tFriendlyName].textFirstLine = L["Bank"].. " "..aParentChilds[tFriendlyName].textFirstLine
					end
				end
			end

			table.insert(tCurrentParentContainer.childs, aParentChilds[tFriendlyName])
			tCurrentParentContainer.childs[aParentChilds[tFriendlyName] ] = aParentChilds[tFriendlyName]
		end  	

		if fullBankSlots ~= true then
			local cost = SkuGetCoinText(GetBankSlotCost(numPurBankSlots))
			local x = numPurBankSlots + 1
			local containerFrameName = "Bag"..x
			local tFriendlyName = L["Bank"].." "..x.." ".._G["BankSlotsFrame"]["Bag"..x].tooltipText.." "..cost
			if _G["BankSlotsFrame"]["Bag"..x]:IsEnabled() == true then
				aParentChilds[tFriendlyName] = {
					frameName = "BankSlotsFrame.Bag"..x,
					RoC = "Child",
					type = "Button",
					obj = _G["BankSlotsFrame"]["Bag"..x],
					textFirstLine = tFriendlyName,
					textFull = "",
					noMenuNumbers = true,
					childs = {},
					func = PurchaseSlot,
					click = true,
					isBag = true,
					isPurchasable = true,
				}   
			end

			table.insert(tCurrentParentContainer.childs, aParentChilds[tFriendlyName])
			tCurrentParentContainer.childs[aParentChilds[tFriendlyName] ] = aParentChilds[tFriendlyName]
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
local function round(num)
	local mult = 10^(2 or 0)
	return math.floor(num * mult + 0.5) / mult
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_CharacterFrame(aParentChilds)

	_G["GearManagerToggleButton"]:Click(_G["GearManagerToggleButton"])


	local tFrameName = "CharacterLevelText"
	local tFriendlyName = _G["CharacterLevelText"]:GetText()
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "FontString",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
	}

	--items
	local tFrameName = ""
	local tFriendlyName = "Equipment"
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "Button",
		obj = _G[tFrameName],
		textFirstLine = "Equipment",
		textFull = "",
		childs = {},
		--click = true,
	}   
	local tParentEquipment = aParentChilds[tFriendlyName].childs




--[[
		--items
		local tFrameName = ""
		local tFriendlyName = "item sub one"
		table.insert(tParentItems, tFriendlyName)
		tParentItems[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = "sub one first item",
			textFull = "",
			childs = {},
		}
]]

		--items submenu
		local tFrameName = "PaperDollItemsFrame"
		local tFriendlyName = "Items"
		table.insert(tParentEquipment, tFriendlyName)
		tParentEquipment[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = "Items",
			textFull = "",
			childs = {},
			--click = true,
		}
		tParentEquipment[tFriendlyName].childs = SkuCore:IterateChildren(tParentEquipment[tFriendlyName].obj, 2)

		--print(tParentEquipment[tFriendlyName].childs["GearManagerToggleButton"])
		for x = 1, #tParentEquipment[tFriendlyName].childs do
			--print(x)
			if tParentEquipment[tFriendlyName].childs[x] == "GearManagerToggleButton" then
				--print("GearManagerToggleButton")
				tParentEquipment[tFriendlyName].childs[x] = nil
				tParentEquipment[tFriendlyName].childs["GearManagerToggleButton"] = nil
			end
		end
		
		--item sets submenu
		local tFrameName = "GearManagerDialog"
		local tFriendlyName = "Item Sets"
		table.insert(tParentEquipment, tFriendlyName)
		tParentEquipment[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = "Item Sets",
			textFull = "",
			childs = {},
			--click = true,
		}   
		local tParentItemsItemSets = tParentEquipment[tFriendlyName].childs

		tParentEquipment[tFriendlyName].childs = SkuCore:IterateChildren(tParentEquipment[tFriendlyName].obj, 2)

		


	--pets
	local tFrameName = ""
	local tFriendlyName = L["Pets"]
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "Button",
		obj = _G[tFrameName],
		textFirstLine = L["Pets"],
		textFull = "",
		childs = {},
		--click = true,
	}   
	local tParentPets = aParentChilds[tFriendlyName].childs


	--mounts
	local tFrameName = ""
	local tFriendlyName = L["Mounts"]
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "Button",
		obj = _G[tFrameName],
		textFirstLine = L["Mounts"],
		textFull = "",
		childs = {},
		--click = true,
	}   
	local tParentMounts = aParentChilds[tFriendlyName].childs
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_ItemSocketingFrame(aParentChilds)

	local tFriendlyName, tFullText = GetButtonTooltipLines(nil, _G["ItemSocketingDescription"])
	local tFrameName = "ItemSocketingFrame"
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "FontString",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName.." ...",
		textFull = tFullText,
		childs = {},
	}
	local tSocketCount = GetNumSockets()
	for i = 1, tSocketCount do
		local tFrameName = "ItemSocketingSocket"..i

		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tCurrentGemName, tCurrentGemId = GetExistingSocketInfo(i)
			if GetNewSocketInfo(i) then
				tCurrentGemName, tCurrentGemId = GetNewSocketInfo(i)
			end
			local tCurrentGemTooltip = ""
			_G[tFrameName].type = "Button"
			if tCurrentGemName then
				tCurrentGemName, tCurrentGemTooltip = GetButtonTooltipLines(_G[tFrameName])
				tCurrentGemName = tCurrentGemName.." ..."
			else
				tCurrentGemName = L["Empty"]
			end

			local tFriendlyName = i.." "..GetSocketTypes(i).." "..L["socket"]..", "..L["current gem:"].." "..tCurrentGemName
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = tCurrentGemTooltip,
				childs = {},
				func = function(self, aButton)
					self:Click()
				end,            
				click = true,
			}   
		end
	
	end

	local tFriendlyName = _G["ItemSocketingSocketButton"]:GetText()
	local tFrameName = "ItemSocketingSocketButton"
	local tFunc = function(self, aButton)
		self:GetScript("OnClick")(self, aButton)             
		self:GetScript("OnClick")(self, aButton)             
	end
	if _G[tFrameName]:IsEnabled() ~= true then
		tFriendlyName = tFriendlyName.." ("..L["disabled"]..")"
		tFunc = nil
	end
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "Button",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
		func = tFunc,            
		click = true,
	}   


	local tFriendlyName = L["Close"]
	local tFrameName = "ItemSocketingCloseButton"
	local tFunc = function(self, aButton)
		self:GetScript("OnClick")(self, aButton)             
		self:GetScript("OnClick")(self, aButton)             
	end
	if _G[tFrameName]:IsEnabled() ~= true then
		tFriendlyName = tFriendlyName.." ("..L["disabled"]..")"
		tFunc = nil
	end
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "Button",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
		func = tFunc,            
		click = true,
	}   	
end

---------------------------------------------------------------------------------------------------------------------------------------
local tTradeSkillTypeColor = {
	--[L["optimal"]] = { r = 1, g = 0.50, b = 0.25},
	--[L["medium"]] = { r = 1, g = 1, b = 0},
	[L["New"]] = { r = 0, g = 1, b = 0},
	[L["bekannt"]] = { r = 0.50, g = 0.50, b = 0.50},
	["header"] = { r = 1, g = 0.82, b = 0},
	["subheader"] = { r = 1, g = 0.82, b = 0},
	[L["nodifficulty"]] = { r = 0.96, g = 0.96, b = 0.96},
	[L["selected"]] = { r = 1, g = 1, b = 1},
}
function SkuCore:Build_ClassTrainerFrame(aParentChilds)

	local tFrameName = "ClassTrainerFrame"
	local tFriendlyName = _G["ClassTrainerNameText"]:GetText()
	if _G["ClassTrainerGreetingText"] and _G["ClassTrainerGreetingText"].GetText and _G["ClassTrainerGreetingText"]:GetText() then
		tFriendlyName = _G["ClassTrainerGreetingText"]:GetText()
		print("c", tFriendlyName)
	end
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "FontString",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
	}

	local tFrameName = "ClassTrainerListScrollFrameScrollBarScrollUpButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Hoch blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end

	local tHasOfSkills
	for x = 1, 10 do
		local tFrameName = "ClassTrainerSkill"..x
		if _G[tFrameName] and _G[tFrameName].text and _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then
			if _G[tFrameName].text:GetText() then
				local tDifficulty = ""
				local r, g, b, a = _G[tFrameName].text:GetTextColor()
				r, g, b, a = round(r), round(g), round(b), round(a)
				if r == 1 and g == 1 and  b == 1 then
					if _G["ClassTrainerHighlightFrame"] and _G["ClassTrainerHighlightFrame"]:GetRegions() then
						r, g, b, a = _G["ClassTrainerHighlightFrame"]:GetRegions():GetVertexColor()
						if r then
							r, g, b, a = round(r), round(g), round(b), round(a)
						end
					end
				end
				for i, v in pairs(tTradeSkillTypeColor) do
					if v.r == r and v.g == g and  v.b == b then
						tDifficulty = i
					end
				end

				local tFriendlyName = unescape(_G[tFrameName].text:GetText())
				local tText, tFullText = "", ""
				if _G[tFrameName]:IsEnabled() == true then
					table.insert(aParentChilds, tFriendlyName)
					aParentChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "Button",
						obj = _G[tFrameName],
						textFirstLine = tFriendlyName,
						textFull = "",
						childs = {},
						func = _G[tFrameName]:GetScript("OnClick"),
						click = true,
					}   
				end

				if tDifficulty == "subheader" or tDifficulty == "header" then
					aParentChilds[tFriendlyName].click = false
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..L["category"]..")"
				else
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..(tDifficulty or "")..")"
				end

				tHasOfSkills = true
			end
		end
	end

	local tFrameName = "ClassTrainerListScrollFrameScrollBarScrollDownButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Runter blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end



	local tName = ""
	if _G["ClassTrainerSkillName"] then
		tName = unescape(_G["ClassTrainerSkillName"]:GetText()) or ""
	end
	local tRequirements = ""
	if _G["ClassTrainerSkillRequirements"] and _G["ClassTrainerSkillRequirements"]:IsVisible() and _G["ClassTrainerSkillRequirements"]:GetText() then
		for i, v in string.gmatch(_G["ClassTrainerSkillRequirements"]:GetText(), "([^,]+)") do 
			if string.sub(i, 1, 1) == " " then
				i = string.sub(i, 2)
			end
			local tReqStr = unescape(i) or ""
			if string.find(i, "ff2020") then
				tReqStr = tReqStr.." ("..L["missing"]..")"
			end
			tRequirements = tRequirements..tReqStr.."\r\n"
		end
	end
	local tCost = ""
	if _G["ClassTrainerDetailMoneyFrame"] and _G["ClassTrainerDetailMoneyFrame"].staticMoney then
		tCost = SkuGetCoinText(_G["ClassTrainerDetailMoneyFrame"].staticMoney, true)
	end

	if tHasOfSkills and _G["ClassTrainerSkillIcon"] then
		_G["ClassTrainerSkillIcon"].type = "sku"
		local tSkillText, tSkillFullText = GetButtonTooltipLines(_G["ClassTrainerSkillIcon"])
		local tFrameName = "ClassTrainerDetailScrollFrame"
		if tName and tName ~= "" then
			local tFriendlyName = L["Ausgewählt: "]..tName
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "FontString",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName.."...",
				textFull = tName..(("\r\n"..tCost) or "")..(("\r\n"..tRequirements) or "").."\r\n"..tSkillFullText,
				childs = {},
			}   
		end
	end

	local tFrameName = "ClassTrainerTrainButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			if _G[tFrameName]:GetText() then
				local tFriendlyName = unescape(_G[tFrameName]:GetText())
				table.insert(aParentChilds, tFriendlyName)
				aParentChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFriendlyName,
					textFull = "",
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
					--containerFrameName = "ClassTrainerTrain",
					onActionFunc = function(self, aTable, aChildName) end,
				}   
			end
		end
	end


	local tFrameName = "ClassTrainerCancelButton"
	local tFriendlyName = L["Close"]
	if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName,
			textFull = "",
			childs = {},
			func = _G[tFrameName]:GetScript("OnClick"),
			click = true,
		}   
	end   


end

---------------------------------------------------------------------------------------------------------------------------------------
local tTradeSkillTypeColor = {
	[L["optimal"]] = { r = 1.00, g = 0.50, b = 0.25},
	[L["medium"]] = { r = 1.00, g = 1.00, b = 0.00},
	[L["easy"]] = { r = 0.25, g = 0.75, b = 0.25},
	[L["trivial"]] = { r = 0.50, g = 0.50, b = 0.50},
	["header"] = { r = 1.00, g = 0.82, b = 0},
	["subheader"] = { r = 1.00, g = 0.82, b = 0},
	[L["nodifficulty"]] = { r = 0.96, g = 0.96, b = 0.96},
}
function SkuCore:Build_TradeSkillFrame(aParentChilds)

	local tFrameName = "TradeSkillFrame"
	local tFriendlyName = _G["TradeSkillFrameTitleText"]:GetText()
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "FontString",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
	}


	local tFrameName = "TradeSkillListScrollFrameScrollBarScrollUpButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Hoch blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end




	for x = 1, 8 do
		local tFrameName = "TradeSkillSkill"..x
		if _G[tFrameName] and _G[tFrameName].text and _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then
			if _G[tFrameName].text:GetText() then
				local tDifficulty = ""
				local r, g, b, a = _G[tFrameName].text:GetTextColor()
				r, g, b, a = round(r), round(g), round(b), round(a)
				if r == 1 and g == 1 and  b == 1 then
					if _G["TradeSkillHighlightFrame"] and _G["TradeSkillHighlightFrame"]:GetRegions() then
						r, g, b, a = _G["TradeSkillHighlightFrame"]:GetRegions():GetVertexColor()
						if r then
							r, g, b, a = round(r), round(g), round(b), round(a)
						end
					end
				end

				for i, v in pairs(tTradeSkillTypeColor) do
					if v.r == r and v.g == g and  v.b == b then
						tDifficulty = i
					end
				end

				local tFriendlyName = unescape(_G[tFrameName].text:GetText())
				local tText, tFullText = "", ""
				if _G[tFrameName]:IsEnabled() == true then
					table.insert(aParentChilds, tFriendlyName)
					aParentChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "Button",
						obj = _G[tFrameName],
						textFirstLine = tFriendlyName,
						textFull = "",
						childs = {},
						func = _G[tFrameName]:GetScript("OnClick"),
						click = true,
					}   
				end

				if tDifficulty == "subheader" or tDifficulty == "header" then
					aParentChilds[tFriendlyName].click = false
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..L["category"]..")"
				else
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..(tDifficulty or "")..")"
				end
			end
		end
	end

	local tFrameName = "TradeSkillListScrollFrameScrollBarScrollDownButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Runter blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end

	local tName = ""
	if _G["TradeSkillSkillName"] then
		tName = unescape(_G["TradeSkillSkillName"]:GetText()) or ""
	end
	local tRequirements = ""
	if _G["TradeSkillRequirementText"] and _G["TradeSkillRequirementText"]:IsVisible() and _G["TradeSkillRequirementText"]:GetText() then
		for i, v in string.gmatch(_G["TradeSkillRequirementText"]:GetText(), "([^,]+)") do 
			if string.sub(i, 1, 1) == " " then
				i = string.sub(i, 2)
			end
			local tReqStr = unescape(i) or ""
			if string.find(i, "ff2020") then
				tReqStr = tReqStr.." ("..L["missing"]..")"
			end
			tRequirements = tRequirements..tReqStr.."\r\n"
		end
	end
	--[[
	local tCost = ""
	if _G["CraftCost"] and _G["CraftCost"]:GetText() then
		tCost = unescape(_G["CraftCost"]:GetText()) or ""
	end
	local tDescription = ""
	if _G["CraftDescription"] and _G["CraftDescription"]:GetText() then
		tDescription = unescape(_G["CraftDescription"]:GetText()) or ""
	end
	]]

	local tReagents = ""
	if _G["TradeSkillReagentLabel"] and _G["TradeSkillReagentLabel"]:IsVisible() == true then
		tReagents = _G["TradeSkillReagentLabel"]:GetText()
	end
	for x = 1, 15 do
		if _G["TradeSkillReagent"..x] then
			if _G["TradeSkillReagent"..x]:IsVisible() == true then
				tReagents = tReagents.."\r\n"..unescape(_G["TradeSkillReagent"..x.."Name"]:GetText())
				tReagents = tReagents.." "..unescape(_G["TradeSkillReagent"..x.."Count"]:GetText())
			end
		end   
	end

	_G["TradeSkillSkillIcon"].type = "sku"
	local tSkillText, tSkillFullText = GetButtonTooltipLines(_G["TradeSkillSkillIcon"])

	local tFrameName = "TradeSkillDetailScrollChildFrame"
	if tName and tName ~= "" then
		local tFriendlyName = L["Ausgewählt: "]..tName
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName.."...",
			textFull = tName..(("\r\n"..tRequirements) or "")..(("\r\n"..tReagents) or "")..(("\r\n"..L["gegenstand"]..":\r\n"..tSkillFullText) or ""),
			childs = {},
		}   
	end
	
	local tFrameName = "TradeSkillCreateButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			if _G[tFrameName]:GetText() then
				local tFriendlyName = unescape(_G[tFrameName]:GetText())
				table.insert(aParentChilds, tFriendlyName)
				aParentChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFriendlyName,
					textFull = "",
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
					--containerFrameName = "TradeSkillCreateButton",
					onActionFunc = function(self, aTable, aChildName) end,
				}   
			end
		end
	end
	local tFrameName = "TradeSkillCreateAllButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			if _G[tFrameName]:GetText() then
				local tFriendlyName = unescape(_G[tFrameName]:GetText())
				table.insert(aParentChilds, tFriendlyName)
				aParentChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFriendlyName,
					textFull = "",
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
					--containerFrameName = "TradeSkillCreateAllButton",
					onActionFunc = function(self, aTable, aChildName) end,
				}   
			end
		end
	end


	local tFrameName = "TradeSkillFrameCloseButton"
	local tFriendlyName = L["Schließen"]
	if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName,
			textFull = "",
			childs = {},
			func = _G[tFrameName]:GetScript("OnClick"),
			click = true,
		}   
	end   

end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_CraftFrame(aParentChilds)

	local tFrameName = "CraftFrame"
	local tFriendlyName = _G["CraftFrameTitleText"]:GetText()
	table.insert(aParentChilds, tFriendlyName)
	aParentChilds[tFriendlyName] = {
		frameName = tFrameName,
		RoC = "Child",
		type = "FontString",
		obj = _G[tFrameName],
		textFirstLine = tFriendlyName,
		textFull = "",
		childs = {},
	}

	if _G["CraftFramePointsText"] and _G["CraftFramePointsText"]:IsVisible() == true then
		local tFrameName = "CraftFramePointsText"
		local tFriendlyName = L["Verfügbare punkte: "]
		tFriendlyName = tFriendlyName..(_G["CraftFramePointsText"]:GetText() or "")
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName,
			textFull = "",
			childs = {},
		}  
	end

	local tFrameName = "CraftListScrollFrameScrollBarScrollUpButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Hoch blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end

	for x = 1, 8 do
		local tFrameName = "Craft"..x
		if _G[tFrameName] then
			if _G[tFrameName.."Text"]:GetText() then
				local tKnown = ""
				local tDifficulty = ""
				local r, g, b, a = _G[tFrameName].text:GetTextColor()
				r, g, b, a = round(r), round(g), round(b), round(a)
				if r == 1 and g == 1 and  b == 1 then
					if _G["CraftHighlightFrame"] and _G["CraftHighlightFrame"]:GetRegions() then
						r, g, b, a = _G["CraftHighlightFrame"]:GetRegions():GetVertexColor()
						if r then
							r, g, b, a = round(r), round(g), round(b), round(a)
						end
					end
				end

				for i, v in pairs(tTradeSkillTypeColor) do
					if v.r == r and v.g == g and  v.b == b then
						tDifficulty = i
					end
				end

				local tFriendlyName = unescape(_G[tFrameName.."Text"]:GetText()).." ".. (unescape(_G[tFrameName.."SubText"]:GetText()) or "").." ".. (unescape(_G[tFrameName.."Cost"]:GetText()) or "").." "..tKnown
				local tText, tFullText = "", ""
				if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
					table.insert(aParentChilds, tFriendlyName)
					aParentChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "Button",
						obj = _G[tFrameName],
						textFirstLine = tFriendlyName,
						textFull = "",
						childs = {},
						func = _G[tFrameName]:GetScript("OnClick"),
						click = true,
					}   
				end

				if tDifficulty == "subheader" or tDifficulty == "header" then
					aParentChilds[tFriendlyName].click = false
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..L["category"]..")"
				else
					aParentChilds[tFriendlyName].textFirstLine = aParentChilds[tFriendlyName].textFirstLine.." ("..(tDifficulty or "")..")"
				end            
			end
		end
	end

	local tFrameName = "CraftListScrollFrameScrollBarScrollDownButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			local tFriendlyName = L["Runter blättern"]
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFriendlyName,
				textFull = "",
				childs = {},
				func = function(self, aButton)
					self:GetScript("OnClick")(self, aButton)             
					self:GetScript("OnClick")(self, aButton)             
				end,            
				click = true,
			}   
		end
	end

	local tName = ""
	if _G["CraftName"] then
		tName = unescape(_G["CraftName"]:GetText()) or ""
	end
	local tRequirements = ""
	if _G["CraftRequirements"] and _G["CraftRequirements"]:IsVisible() and _G["CraftRequirements"]:GetText() then
		tRequirements = unescape(_G["CraftRequirements"]:GetText()) or ""
		if string.find(_G["CraftRequirements"]:GetText(), "ff2020") then
			tRequirements = tRequirements.." ("..L["missing"]..")"
		end
	end
	local tCost = ""
	if _G["CraftCost"] and _G["CraftCost"]:GetText() then
		tCost = unescape(_G["CraftCost"]:GetText()) or ""
	end
	local tDescription = ""
	if _G["CraftDescription"] and _G["CraftDescription"]:GetText() then
		tDescription = unescape(_G["CraftDescription"]:GetText()) or ""
	end

	local tReagents = ""
	if _G["CraftReagentLabel"] and _G["CraftReagentLabel"]:IsVisible() == true then
		tReagents = _G["CraftReagentLabel"]:GetText()
	end
	for x = 1, 15 do
		if _G["CraftReagent"..x] then
			if _G["CraftReagent"..x]:IsVisible() == true then
				tReagents = tReagents.."\r\n"..unescape(_G["CraftReagent"..x.."Name"]:GetText())
				tReagents = tReagents.." "..unescape(_G["CraftReagent"..x.."Count"]:GetText())
			end
		end   
	end

	_G["CraftIcon"].type = "sku"
	local tSkillText, tSkillFullText = GetButtonTooltipLines(_G["CraftIcon"])


	local tFrameName = "CraftDetailScrollChildFrame"
	if tName and tName ~= "" then
		local tFriendlyName = L["Ausgewählt: "]..tName
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName.."...",
			textFull = tName..(("\r\n"..tRequirements) or "")..(("\r\n"..tCost) or "")..(("\r\n"..tDescription) or "")..(("\r\n"..tReagents) or "")..(("\r\n"..L["gegenstand"]..":\r\n"..tSkillFullText) or ""),
			childs = {},
		}   
	end

	local tFrameName = "CraftCreateButton"
	if _G[tFrameName] then
		if _G[tFrameName]:IsVisible() == true and _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
			if _G[tFrameName]:GetText() then
				local tFriendlyName = unescape(_G[tFrameName]:GetText())
				table.insert(aParentChilds, tFriendlyName)
				aParentChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFriendlyName,
					textFull = "",
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
					--containerFrameName = "CraftCreateButton",
					onActionFunc = function(self, aTable, aChildName) end,
				}   
			end
		end
	end

	local tFrameName = "CraftFrameCloseButton"
	local tFriendlyName = L["Schließen"]
	if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
		table.insert(aParentChilds, tFriendlyName)
		aParentChilds[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = tFriendlyName,
			textFull = "",
			childs = {},
			func = _G[tFrameName]:GetScript("OnClick"),
			click = true,
		}   
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:Build_PetStableFrame(aParentChilds)

	local tFrame = _G["PetStableCurrentPet"]
	local tText, tFullText = GetButtonTooltipLines(tFrame)
	table.insert(aParentChilds, L["Derzeitiger Begleiter"])
	aParentChilds[L["Derzeitiger Begleiter"]] = {
		frameName = "PetStableCurrentPet",
		RoC = "Child",
		type = "Button",
		obj = tFrame,
		textFirstLine = L["Derzeitiger Begleiter"].." "..tText,
		textFull = L["Derzeitiger Begleiter"].." "..tFullText,
		childs = {},
		func = function(...)
			local tCursorInfo = GetCursorInfo() 
			if tCursorInfo then
				tFrame:GetScript("OnReceiveDrag")(...)
			else
				tFrame:GetScript("OnDragStart")(...)
			end
		end,
		click = true,
	}   

	local tFrame = _G["PetStableStabledPet1"]
	if tFrame:IsEnabled() == true then --IsMouseClickEnabled()
		local tText, tFullText = GetButtonTooltipLines(tFrame)
		table.insert(aParentChilds, L["Stall 1"])
		aParentChilds[L["Stall 1"]] = {
			frameName = "PetStableStabledPet1",
			RoC = "Child",
			type = "Button",
			obj = tFrame,
			textFirstLine = L["Stall 1"].." "..tText,
			textFull = L["Stall 1"].." "..tFullText,
			childs = {},
			func = function(...)
				local tCursorInfo = GetCursorInfo() 
				if tCursorInfo then
					tFrame:GetScript("OnReceiveDrag")(...)
				else
					tFrame:GetScript("OnDragStart")(...)
				end
			end,
			click = true,
		}
	end

	local tFrame = _G["PetStableStabledPet2"]
	if tFrame:IsEnabled() == true then --IsMouseClickEnabled()
		local tText, tFullText = GetButtonTooltipLines(tFrame)
		table.insert(aParentChilds, L["Stall 2"])
		aParentChilds[L["Stall 2"]] = {
			frameName = "PetStableStabledPet2",
			RoC = "Child",
			type = "Button",
			obj = tFrame,
			textFirstLine = L["Stall 2"].." "..tText,
			textFull = L["Stall 2"].." "..tFullText,
			childs = {},
			func = function(...)
				local tCursorInfo = GetCursorInfo() 
				if tCursorInfo then
					tFrame:GetScript("OnReceiveDrag")(...)
				else
					tFrame:GetScript("OnDragStart")(...)
				end
			end,
			click = true,
		}
	end

	local tFrame = _G["PetStablePurchaseButton"]
	if tFrame:IsEnabled() == true then --IsMouseClickEnabled()
		if tFrame:IsShown() == true then --IsMouseClickEnabled()
			table.insert(aParentChilds, L["Weiteren Platz kaufen"])
			aParentChilds[L["Weiteren Platz kaufen"]] = {
				frameName = "PetStablePurchaseButton",
				RoC = "Child",
				type = "Button",
				obj = tFrame,
				textFirstLine = L["Weiteren Platz kaufen"],
				textFull = "",
				childs = {},
				func = tFrame:GetScript("OnClick"),
				click = true,
			}   
		end
	end

	local tFrame = _G["PetStableFrameCloseButton"]
	if tFrame:IsEnabled() == true then --IsMouseClickEnabled()
		table.insert(aParentChilds, L["Schließen"])
		aParentChilds[L["Schließen"]] = {
			frameName = "PetStableFrameCloseButton",
			RoC = "Child",
			type = "Button",
			obj = tFrame,
			textFirstLine = L["Schließen"],
			textFull = "",
			childs = {},
			func = tFrame:GetScript("OnClick"),
			click = true,
		}   
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:ItemTextFrame(aParent)
	local tFrameName = "ItemTextTitleText"
	if _G[tFrameName]:IsShown() == true  then
		local tText = _G[tFrameName]:GetText()
		local tFrst, tFll = ItemName_helper(tText)
		local tFriendlyName = tFrst
		table.insert(aParent, tFriendlyName)
		aParent[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = tFrst,
			textFull = tFll,
			childs = {},
		}
	end

	local tFrameName = "ItemTextPageText"
	if _G[tFrameName]:IsShown() == true  then
		local tHtmlTable = _G[tFrameName]:GetTextData()

		local tText = ""
		for i, v in pairs(tHtmlTable) do
			if v.text then
				tText = unescape(v.text).."\r\n"
			end
		end

		local tFrst, tFll = ItemName_helper(tText)
		local tFriendlyName = tFrst
		table.insert(aParent, tFriendlyName)
		aParent[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "FontString",
			obj = _G[tFrameName],
			textFirstLine = tFrst,
			textFull = tFll,
			childs = {},
		}
	end

	local tFrameName = "ItemTextPrevPageButton"
	if _G[tFrameName]:IsShown() == true  then
		local tFriendlyName = L["Previous"]
		local tFrst, tFll = tFriendlyName, ""
		table.insert(aParent, tFriendlyName)
		aParent[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = tFrst,
			textFull = tFll,
			childs = {},
			func = _G[tFrameName]:GetScript("OnClick"),
			click = true,
		}
	end

	local tFrameName = "ItemTextNextPageButton"
	if _G[tFrameName]:IsShown() == true  then
		local tFriendlyName = L["Next"]
		local tFrst, tFll = tFriendlyName, ""
		table.insert(aParent, tFriendlyName)
		aParent[tFriendlyName] = {
			frameName = tFrameName,
			RoC = "Child",
			type = "Button",
			obj = _G[tFrameName],
			textFirstLine = tFrst,
			textFull = tFll,
			childs = {},
			func = _G[tFrameName]:GetScript("OnClick"),
			click = true,
		}
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:GossipFrame(aParentChilds)

	local dtc = { _G["GossipGreetingScrollChildFrame"]:GetRegions() }
	for x = 1, #dtc do
		if dtc[x].GetText then
			local tText = dtc[x]:GetText()
			if tText then
				local tFrameName = "GossipText"
				local tFriendlyName = tText
				local tFrst, tFll = ItemName_helper(tText)
				table.insert(aParentChilds, tFriendlyName)
				aParentChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "FontString",
					obj = _G[tFrameName],
					textFirstLine = tFrst,
					textFull = tFll,
					childs = {},
				}  
			end
		end
	end


	local tIconStrings = {
		[132048] = L["Accepted Quest"],
		[132049] = L["Available Quest"],
	}

	for x = 1, GossipFrame.buttonIndex - 1 do
		local tFrameName = "GossipTitleButton"..x
		if _G[tFrameName] then
			if _G[tFrameName]:IsShown() == true  then
				if _G[tFrameName]:GetText() then
					local tFriendlyName = unescape(_G[tFrameName]:GetText())
					if _G["GossipTitleButton"..x.."GossipIcon"]:IsShown() == true then
						tFriendlyName = (tIconStrings[_G["GossipTitleButton"..x.."GossipIcon"]:GetTextureFileID()] or "").." "..unescape(_G[tFrameName]:GetText())
					end
					local tText, tFullText = "", ""
					if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
						table.insert(aParentChilds, tFriendlyName)
						aParentChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "Button",
							obj = _G[tFrameName],
							textFirstLine = tFriendlyName,
							textFull = "",
							childs = {},
							func = _G[tFrameName]:GetScript("OnClick"),
							click = true,
						} 
					end
				end
			end
		end
	end
end


-----------------------------------------------------------------------------------------------------------------------------------------------------
function SkuCore:QuestFrame(aParentChilds)


	local function QuestInfoRewardsFrameHelper(aParent, aInfoOnly)
		if QuestInfoRewardsFrame.ItemChooseText:IsVisible() == true or QuestInfoRewardsFrame.ItemReceiveText:IsVisible() == true or (QuestInfoMoneyFrame:IsVisible() == true and QuestInfoMoneyFrame:IsVisible() == true and QuestInfoMoneyFrame.staticMoney) then
			local tFrameName = "QuestInfoRewardsFrame"
			local tFriendlyName = L["Rewards"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(aParent, tFriendlyName)
			aParent[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
			}

			local tTaken = {}
			local tQuestInfoRewardsFrameChilds = aParent[tFriendlyName].childs

			if QuestInfoRewardsFrame.ItemChooseText then
				if QuestInfoRewardsFrame.ItemChooseText:IsVisible() == true then
					local tText = QuestInfoRewardsFrame.ItemChooseText:GetText()
					local tFrst, tFll = ItemName_helper(tText)
					local tFriendlyName = tFrst
					table.insert(tQuestInfoRewardsFrameChilds, tFriendlyName)
					tQuestInfoRewardsFrameChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					} 

					for x = 1, 10 do
						local tFrameName = "QuestInfoRewardsFrameQuestInfoItem"..x
						if _G[tFrameName] then
							if _G[tFrameName]:IsVisible() == true then
								local tText, tFullText = GetButtonTooltipLines(_G[tFrameName])
								if tText then
									tTaken[x] = true
									tText = tText.." "..(_G[tFrameName].count or "")
									local tFriendlyName = unescape(tText)
									if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
										table.insert(tQuestInfoRewardsFrameChilds, tFriendlyName)
										tQuestInfoRewardsFrameChilds[tFriendlyName] = {
											frameName = tFrameName,
											RoC = "Child",
											type = "Button",
											obj = _G[tFrameName],
											textFirstLine = tText,
											textFull = tFullText,
											childs = {},
											func = _G[tFrameName]:GetScript("OnClick"),
											click = true,
										} 
										if aInfoOnly then
											tQuestInfoRewardsFrameChilds[tFriendlyName].func = nil
											tQuestInfoRewardsFrameChilds[tFriendlyName].click = nil
										end
									end
								end
							end
						end
					end
				end
			end

			local tQuestInfoRewardsFrameChilds = aParent[tFriendlyName].childs
			if QuestInfoRewardsFrame.ItemReceiveText then
				if QuestInfoRewardsFrame.ItemReceiveText:IsVisible() == true then
					local tText = QuestInfoRewardsFrame.ItemReceiveText:GetText()
					local tFrst, tFll = ItemName_helper(tText)
					local tFriendlyName = tFrst
					table.insert(tQuestInfoRewardsFrameChilds, tFriendlyName)
					tQuestInfoRewardsFrameChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					} 

					for x = 1, 10 do
						if not tTaken[x] then
							local tFrameName = "QuestInfoRewardsFrameQuestInfoItem"..x
							if _G[tFrameName] then
								if _G[tFrameName]:IsVisible() == true then
									local tText, tFullText = GetButtonTooltipLines(_G[tFrameName])
									if tText then
										tTaken[x] = true
										tText = tText.." "..(_G[tFrameName].count or "")
										local tFriendlyName = unescape(tText)
										if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
											table.insert(tQuestInfoRewardsFrameChilds, tFriendlyName)
											tQuestInfoRewardsFrameChilds[tFriendlyName] = {
												frameName = tFrameName,
												RoC = "Child",
												type = "Button",
												obj = _G[tFrameName],
												textFirstLine = tText,
												textFull = tFullText,
												childs = {},
												func = _G[tFrameName]:GetScript("OnClick"),
												click = true,
											} 
											if aInfoOnly then
												tQuestInfoRewardsFrameChilds[tFriendlyName].func = nil
												tQuestInfoRewardsFrameChilds[tFriendlyName].click = nil
											end
										end
									end
								end
							end
						end
					end
				end
			end

			if QuestInfoMoneyFrame then
				if QuestInfoMoneyFrame:IsVisible() == true then
					if QuestInfoMoneyFrame.staticMoney then
						local tFrst, tFll = SkuGetCoinText(QuestInfoMoneyFrame.staticMoney, true), ""
						local tFriendlyName = tFrst
						table.insert(tQuestInfoRewardsFrameChilds, tFriendlyName)
						tQuestInfoRewardsFrameChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "FontString",
							obj = _G[tFrameName],
							textFirstLine = tFrst,
							textFull = tFll,
							childs = {},
						}
					end
				end
			end   
		end

	end


	--QuestFrameGreetingPanel
	if _G["QuestFrameGreetingPanel"] then 
		if _G["QuestFrameGreetingPanel"]:IsVisible() == true then

			local tFrameName = "QuestFrameGreetingPanel"
			local tFriendlyName = L["Greeting"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
			}  

			local tGreetingChilds = aParentChilds[tFriendlyName].childs
			local dtc = { _G["QuestGreetingScrollChildFrame"]:GetRegions() }
			for x = 1, 1 do --#dtc do
				if dtc[x].GetText then
					local tText = dtc[x]:GetText()
					if tText then
						local tFrameName = "GreetingText"
						local tFriendlyName = tText
						local tFrst, tFll = ItemName_helper(tText)
						table.insert(tGreetingChilds, tFriendlyName)
						tGreetingChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "FontString",
							obj = _G[tFrameName],
							textFirstLine = tFrst,
							textFull = tFll,
							childs = {},
						}  
					end
				end
			end

			local tIconStrings = {
				[132048] = L["Accepted Quest"],
				[132049] = L["Available Quest"],
			}

			for x = 1, 10 do
				local tFrameName = "QuestTitleButton"..x
				if _G[tFrameName] then
					if _G[tFrameName]:IsVisible() == true then
						if _G[tFrameName]:GetText() then
							local tFriendlyName = unescape(_G[tFrameName]:GetText())
							if _G["QuestTitleButton"..x.."QuestIcon"]:IsVisible() == true  then
								tFriendlyName = (tIconStrings[_G["QuestTitleButton"..x.."QuestIcon"]:GetTextureFileID()] or "").." "..unescape(_G[tFrameName]:GetText())
							end
							local tText, tFullText = "", ""
							if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
								table.insert(tGreetingChilds, tFriendlyName)
								tGreetingChilds[tFriendlyName] = {
									frameName = tFrameName,
									RoC = "Child",
									type = "Button",
									obj = _G[tFrameName],
									textFirstLine = tFriendlyName,
									textFull = "",
									childs = {},
									func = _G[tFrameName]:GetScript("OnClick"),
									click = true,
								} 
							end
						end
					end
				end
			end
		end
	end

	--QuestFrameProgressPanel
	if _G["QuestFrameProgressPanel"] then 
		if _G["QuestFrameProgressPanel"]:IsVisible() == true then
			local tFrameName = "QuestFrameProgressPanel"
			local tFriendlyName = L["Progress"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
			}  

			local tProgressChilds = aParentChilds[tFriendlyName].childs
			local dtc = { _G["QuestProgressScrollChildFrame"]:GetRegions() }
			for x = 1, 2 do
				if dtc[x].GetText then
					local tText = dtc[x]:GetText()
					if tText then
						local tFrameName = "QuestInfo"
						local tFriendlyName = tText
						local tFrst, tFll = ItemName_helper(tText)
						table.insert(tProgressChilds, tFriendlyName)
						tProgressChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "FontString",
							obj = _G[tFrameName],
							textFirstLine = tFrst,
							textFull = tFll,
							childs = {},
						}  
					end
				end
			end
			if dtc[3]:IsVisible() == true then
				if dtc[3].GetText then
					local tText = dtc[3]:GetText()
					if tText then
						local tFrameName = "QuestInfo"
						local tFriendlyName = tText
						local tFrst, tFll = ItemName_helper(tText)
						table.insert(tProgressChilds, tFriendlyName)
						tProgressChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "FontString",
							obj = _G[tFrameName],
							textFirstLine = tFrst,
							textFull = tFll,
							childs = {},
						}  
					end
				end

				for x = 1, 10 do
					local tFrameName = "QuestProgressItem"..x
					if _G[tFrameName] then
						if _G[tFrameName]:IsVisible() == true then
							local tText, tFullText = GetButtonTooltipLines(_G[tFrameName])
							if tText then
								tText = tText.." "..(_G[tFrameName].count or "")
								local tFriendlyName = unescape(tText)
								--if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
									table.insert(tProgressChilds, tFriendlyName)
									tProgressChilds[tFriendlyName] = {
										frameName = tFrameName,
										RoC = "Child",
										type = "Button",
										obj = _G[tFrameName],
										textFirstLine = tText,
										textFull = tFullText,
										childs = {},
										--func = _G[tFrameName]:GetScript("OnClick"),
										--click = true,
									} 
								--end
							end
						end
					end
				end
			end

			if dtc[4]:IsVisible() == true then
				if dtc[4].GetText then
					local tText = dtc[4]:GetText()
					if tText then
						local tFrameName = "QuestInfo"
						local tFriendlyName = tText
						local tFrst, tFll = ItemName_helper(tText)
						table.insert(tProgressChilds, tFriendlyName)
						tProgressChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "FontString",
							obj = _G[tFrameName],
							textFirstLine = tFrst,
							textFull = tFll,
							childs = {},
						}  
					end
				end
			end

			local tFrameName = "QuestFrameCompleteButton"
			if _G[tFrameName] then
				if _G[tFrameName]:IsVisible() == true then
					if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
						local tFriendlyName = _G[tFrameName]:GetText()
						table.insert(tProgressChilds, tFriendlyName)
						tProgressChilds[tFriendlyName] = {
							frameName = tFrameName,
							RoC = "Child",
							type = "Button",
							obj = _G[tFrameName],
							textFirstLine = tFriendlyName,
							textFull = "",
							childs = {},
							func = _G[tFrameName]:GetScript("OnClick"),
							click = true,
						} 
					end
				end
			end
		end
	end

	--QuestFrameDetailPanel
	if _G["QuestFrameDetailPanel"] then 
		if _G["QuestFrameDetailPanel"]:IsVisible() == true then
			local tFrameName = "QuestFrameDetailPanel"
			local tFriendlyName = L["Detail"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
			}  


			local tDetailChilds = aParentChilds[tFriendlyName].childs
			local dtc = { _G["QuestDetailScrollChildFrame"]:GetRegions() }

			local tFrameName = "QuestInfoTitleHeader"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end
			local tFrameName = "QuestInfoDescriptionText"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end

			local tFrameName = "QuestInfoObjectivesHeader"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end
			local tFrameName = "QuestInfoObjectivesText"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end

			--rewards
			if _G["QuestInfoRewardsFrame"] then 
				QuestInfoRewardsFrameHelper(tDetailChilds, true)
			end

			local tFrameName = "QuestFrameAcceptButton"
			local tFriendlyName = L["Accept"]
			local tFrst, tFll = tFriendlyName, ""
			if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
				table.insert(tDetailChilds, tFriendlyName)
				tDetailChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFrst,
					textFull = tFll,
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
				}  
			end
			local tFrameName = "QuestFrameDeclineButton"
			local tFriendlyName = L["Ablehnen"]
			local tFrst, tFll = tFriendlyName, ""
			if _G[tFrameName]:IsEnabled() == true then --IsMouseClickEnabled()
				table.insert(tDetailChilds, tFriendlyName)
				tDetailChilds[tFriendlyName] = {
					frameName = tFrameName,
					RoC = "Child",
					type = "Button",
					obj = _G[tFrameName],
					textFirstLine = tFrst,
					textFull = tFll,
					childs = {},
					func = _G[tFrameName]:GetScript("OnClick"),
					click = true,
				}  			
			end
		end
	end


	--QuestFrameRewardPanel
	if _G["QuestFrameRewardPanel"] then 
		if _G["QuestFrameRewardPanel"]:IsVisible() == true then
			local tFrameName = "QuestFrameRewardPanel"
			local tFriendlyName = L["Abgabe"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(aParentChilds, tFriendlyName)
			aParentChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
			}  

			local tDetailChilds = aParentChilds[tFriendlyName].childs

			local tFrameName = "QuestInfoTitleHeader"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end
			local tFrameName = "QuestInfoRewardText"
			if _G[tFrameName] then
				local tText = _G[tFrameName]:GetText()
				if tText then
					local tFriendlyName = tText
					local tFrst, tFll = ItemName_helper(tText)
					table.insert(tDetailChilds, tFriendlyName)
					tDetailChilds[tFriendlyName] = {
						frameName = tFrameName,
						RoC = "Child",
						type = "FontString",
						obj = _G[tFrameName],
						textFirstLine = tFrst,
						textFull = tFll,
						childs = {},
					}  
				end
			end

			if QuestInfoRewardsFrame.ItemChooseText:IsVisible() == true or QuestInfoRewardsFrame.ItemReceiveText:IsVisible() == true or (QuestInfoMoneyFrame:IsVisible() == true and QuestInfoMoneyFrame:IsVisible() == true and QuestInfoMoneyFrame.staticMoney) then
				QuestInfoRewardsFrameHelper(tDetailChilds)
			end
			
			local tFrameName = "QuestFrameCompleteQuestButton"
			local tFriendlyName = L["Complete"]
			local tFrst, tFll = tFriendlyName, ""
			table.insert(tDetailChilds, tFriendlyName)
			tDetailChilds[tFriendlyName] = {
				frameName = tFrameName,
				RoC = "Child",
				type = "Button",
				obj = _G[tFrameName],
				textFirstLine = tFrst,
				textFull = tFll,
				childs = {},
				func = _G[tFrameName]:GetScript("OnClick"),
				click = true,
			}  
						
		end
	end



end

