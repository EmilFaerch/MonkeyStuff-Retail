MonkeyStuff = {};

local colorMain = "|cff89CFF0";
local colorMarked = "|cfffda82b";
local colorUnmarked = "|cffffffff";

local monkeyStuffPrefix = colorMain .. "[MonkeyStuff]|r "

local devMode = false;
local MS_ItemsMarkedForSale = {""};

local MonkeyStuff_EventFrame = CreateFrame("Frame");
MonkeyStuff_EventFrame:RegisterEvent("ADDON_LOADED");
MonkeyStuff_EventFrame:RegisterEvent("MERCHANT_SHOW");
MonkeyStuff_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
MonkeyStuff_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");

function MS_OnEvent(self, event, ...)
    MonkeyStuff:PrintDevMode("EVENT: " .. event);
    
    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then
        MonkeyStuff:Initialize();
    end

    if (event == "MERCHANT_SHOW") then
        MonkeyStuff:AutoRepair();
        MonkeyStuff:AutoSellItems();
    end

end;
MonkeyStuff_EventFrame:SetScript("OnEvent", MS_OnEvent);

function MonkeyStuff:Initialize()
    MonkeyStuff:SetAllEquippedItemLevels();
    MonkeyStuff:Print("Loaded.");
end

function MonkeyStuff:AutoRepair()
    MonkeyStuff:PrintDevMode("AutoRepair()");
    if (CanMerchantRepair()) then 
        repairAllCost, canRepair = GetRepairAllCost()
        if (canRepair) then
            RepairAllItems(); 
            MonkeyStuff:Print("Paid " .. GetCoinTextureString(repairAllCost) .. " for repairs.");
        end
    end
end;

function MonkeyStuff:AutoSellItems()
    MonkeyStuff:PrintDevMode("AutoSellItems()");
    junkSold = 0;
    markedSold = 0;
    for bag = 0, 4, 1 do
        local bagSlots = C_Container.GetContainerNumSlots(bag);

        for slot = 1, bagSlots, 1 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            
            if (itemID ~= nil) then
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID);
                
                -- can't trust that itemTypes nor itemSubType makes sense, so just rely on itemQuality I guess... (rather than also checking itemSubType == "Junk" or itemType == "Armor" or itemType == "Weapon")

                local shouldSellItem = false;
                local itemIsMarked, _ = CheckItemMarkedForSale(itemLink);

                if (ItemIsJunk(itemQuality)) then
                    shouldSellItem = true;
                    junkSold = junkSold + 1;
                end

                if (itemIsMarked) then
                    shouldSellItem = true;
                    markedSold = markedSold + 1;
                end

                if (shouldSellItem) then
                    C_Container.ShowContainerSellCursor(bag, slot)
                    C_Container.UseContainerItem(bag, slot)
                end
            end                
        end
    end

    if (junkSold > 0 or markedSold > 0) then 
        MonkeyStuff:Print("Sold " .. junkSold .. " junk and " .. markedSold .. " marked item(s)."); 
        MonkeyStuff:ClearItemsMarkedForSale();
    end;
end;

function ItemIsJunk(itemQuality)
    if (itemQuality == 0) then return true else return false end;
end;

-- Display unit price if item is both stackable and sellable
function MonkeyStuff:Tooltip_AddUnitPrice(tooltip, maxStack, unitPrice)
    if (maxStack > 1 and unitPrice > 0) then
        tooltip:AddLine("Unit Price: " .. GetCoinTextureString(unitPrice), 1, 1, 1)
        tooltip:AddLine("|cffB2BEB5Max stack: " .. maxStack .. " (" .. GetCoinTextureString(unitPrice * maxStack) .. ")")
    end
end;

function MonkeyStuff:Tooltip_HandleMarkForSale(tooltip, itemQuality, unitPrice, itemLink)
    if (ItemIsJunk(itemQuality) or unitPrice == 0) then return end;

    -- DON'T SHOW THIS ON EQUIPPED ITEMS!!!!
    -- local x = tooltip:IsEquippedItem();
    -- MonkeyStuff:PrintDevMode(x);

    local isMarkedForSale,_ = CheckItemMarkedForSale(itemLink);

    if (isMarkedForSale) then 
        tooltip:AddLine(monkeyStuffPrefix .. colorMarked .. "Marked for auto-sell. Shift-Right click to unmark.");
    else
        tooltip:AddLine(monkeyStuffPrefix .. colorUnmarked .. "Shift-Right click to mark for auto-sell.");
    end
end

function MonkeyStuff:HandleMarkForSale(itemLink)
    local isMarked, tableIndex = CheckItemMarkedForSale(itemLink)
    if (isMarked) then 
        MonkeyStuff:UnmarkItemForSale(tableIndex)
    else
        MonkeyStuff:MarkItemForSale(itemLink)
    end
end

function MonkeyStuff:MarkItemForSale(itemLink)
    if (ItemCanBeMarkedForSale(itemLink) == false) then return end;

    local itemID = GetItemInfoFromHyperlink(itemLink)
    MS_ItemsMarkedForSale[#MS_ItemsMarkedForSale + 1] = itemID; 
end

function MonkeyStuff:UnmarkItemForSale(index)
    table.remove(MS_ItemsMarkedForSale, index); 
end

function MonkeyStuff:ClearItemsMarkedForSale()
    MS_ItemsMarkedForSale = {""};
end

--- ### CORE MARK FOR SALE FUNCTIONS START ###
-- Mark item for sale!
hooksecurefunc("HandleModifiedItemClick", function(itemLink, itemLocation)
    if (itemLocation and itemLocation:IsBagAndSlot() and IsShiftKeyDown()) then
        MonkeyStuff:HandleMarkForSale(itemLink);
    end
end);

function ItemCanBeMarkedForSale(itemLink)
    if (CheckItemMarkedForSale(itemLink) == true) then return false end;

    -- should loop through something that you can't mark, e.g. Hearthstone and such I guess

    return true;
end

function CheckItemMarkedForSale(itemLink)
    if (#MS_ItemsMarkedForSale == 0) then 
        return false, 0 
    end;

    local itemID = GetItemInfoFromHyperlink(itemLink)
    for i = 1, #MS_ItemsMarkedForSale, 1 do
        if (itemID == MS_ItemsMarkedForSale[i]) then
            return true, i;
        end
    end
    return false, 0;
end
--- ### CORE MARK FOR SALE FUNCTIONS END ###

-- ### CORE FUNCTIONS START ###
local function ModifyTooltip(tooltip, data)
    if tooltip == GameTooltip then
        local name, link = tooltip:GetItem();
        local _,_,itemQuality,_,_,_,_,maxStack,_,_,unitPrice = GetItemInfo(link);

        MonkeyStuff:Tooltip_AddUnitPrice(tooltip, maxStack, unitPrice);
        MonkeyStuff:Tooltip_HandleMarkForSale(tooltip, itemQuality, unitPrice, link);
        tooltip:Show()
    end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ModifyTooltip)

function MonkeyStuff:PrintAvailableCommands()
    MonkeyStuff:Print("Can't do much yet!");
end;

function MonkeyStuff:Print(msg)
    print(monkeyStuffPrefix .. msg)
end;

function MonkeyStuff:PrintDevMode(msg)
    if (devMode == true) then MonkeyStuff:Print(msg) end;
end

function HandleSlashCommands(msg)
    if (#msg <= 1) then MonkeyStuff:PrintAvailableCommands()
    else
        local command, item = strsplit(" ", msg, 2)

        if (command == "dev") then 
            MonkeyStuff:Print("Developer mode toggled.");
            devMode = not devMode;
        elseif (command == "marked") then
            MonkeyStuff:Print(#MS_ItemsMarkedForSale .. " items will be auto-sold.");
            for i = 1, #MS_ItemsMarkedForSale, 1 do
                MonkeyStuff:PrintDevMode(select(1, GetItemInfo(MS_ItemsMarkedForSale[i])));
            end
        end
    end
end;

SLASH_MonkeyStuff1 = "/ms";
SlashCmdList.MonkeyStuff = HandleSlashCommands;
-- ### CORE FUNCTIONS END ###

local iLvlFontSize = 12;
local iLvlTextType = "OUTLINE";

local leftColumn = -238;
local rightColumn = 43;

local weaponColumn1 = -117;
local weaponColumn2 = -75;
local weaponRow = -187;

-- difference between rows: 41 (?)
local row1 = 121;
local row2 = 80;
local row3 = 39;
local row4 = -1;
local row5 = -42;
local row6 = -83;
local row7 = -124;
local row8 = -165;


frameTextObjects = {""}
local itemLevelFrame = CreateFrame("frame", "MonkeyStuff_EquipmentItemLevel", CharacterFrame) -- Create a frame to do the work
itemLevelFrame:SetSize(50,16)
itemLevelFrame:SetPoint("CENTER", CharacterFrame)
itemLevelFrame:SetFrameLevel(9000)

-- LEFT COLUMN
itemLevelFrame.textHead = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textHead:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textHead:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textHead:SetPoint("CENTER", leftColumn, row1) 
frameTextObjects[GetInventorySlotInfo("HeadSlot")] = itemLevelFrame.textHead;

itemLevelFrame.textNeck = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textNeck:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textNeck:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textNeck:SetPoint("CENTER", leftColumn, row2) 
frameTextObjects[GetInventorySlotInfo("NeckSlot")] = itemLevelFrame.textNeck;

itemLevelFrame.textShoulders = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textShoulders:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textShoulders:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textShoulders:SetPoint("CENTER", leftColumn, row3) 
frameTextObjects[GetInventorySlotInfo("ShoulderSlot")] = itemLevelFrame.textShoulders;

itemLevelFrame.textBack= itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textBack:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textBack:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textBack:SetPoint("CENTER", leftColumn, row4) 
frameTextObjects[GetInventorySlotInfo("BackSlot")] = itemLevelFrame.textBack;

itemLevelFrame.textChest = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textChest:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textChest:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textChest:SetPoint("CENTER", leftColumn, row5) 
frameTextObjects[GetInventorySlotInfo("ChestSlot")]= itemLevelFrame.textChest;

itemLevelFrame.textShirt = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textShirt:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textShirt:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textShirt:SetPoint("CENTER", leftColumn, row6) 
frameTextObjects[GetInventorySlotInfo("ShirtSlot")] = itemLevelFrame.textShirt;

itemLevelFrame.textTabard = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textTabard:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textTabard:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textTabard:SetPoint("CENTER", leftColumn, row5) 
frameTextObjects[GetInventorySlotInfo("TabardSlot")]= itemLevelFrame.textTabard;

itemLevelFrame.textWrist = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textWrist:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textWrist:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textWrist:SetPoint("CENTER", leftColumn, row8) 
frameTextObjects[GetInventorySlotInfo("WristSlot")] = itemLevelFrame.textWrist;

-- RIGHT COLUMN
itemLevelFrame.textGloves = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textGloves:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textGloves:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textGloves:SetPoint("CENTER", rightColumn, row1) 
frameTextObjects[GetInventorySlotInfo("HandsSlot")] = itemLevelFrame.textGloves;

itemLevelFrame.textBelt= itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textBelt:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textBelt:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textBelt:SetPoint("CENTER", rightColumn, row2) 
frameTextObjects[GetInventorySlotInfo("WaistSlot")] = itemLevelFrame.textBelt;

itemLevelFrame.textLegs = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textLegs:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textLegs:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textLegs:SetPoint("CENTER", rightColumn, row3) 
frameTextObjects[GetInventorySlotInfo("LegsSlot")] = itemLevelFrame.textLegs;

itemLevelFrame.textFeet = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textFeet:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textFeet:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textFeet:SetPoint("CENTER", rightColumn, row4) 
frameTextObjects[GetInventorySlotInfo("FeetSlot")] = itemLevelFrame.textFeet;

itemLevelFrame.textRing1 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textRing1:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textRing1:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textRing1:SetPoint("CENTER", rightColumn, row5) 
frameTextObjects[GetInventorySlotInfo("Finger0Slot")] = itemLevelFrame.textRing1;

itemLevelFrame.textRing2 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textRing2:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textRing2:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textRing2:SetPoint("CENTER", rightColumn, row6) 
frameTextObjects[GetInventorySlotInfo("Finger1Slot")] = itemLevelFrame.textRing2;

itemLevelFrame.textTrinket1 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textTrinket1:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textTrinket1:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textTrinket1:SetPoint("CENTER", rightColumn, row7) 
frameTextObjects[GetInventorySlotInfo("Trinket0Slot")] = itemLevelFrame.textTrinket1;

itemLevelFrame.textTrinket2 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textTrinket2:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textTrinket2:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textTrinket2:SetPoint("CENTER", rightColumn, row8) 
frameTextObjects[GetInventorySlotInfo("Trinket1Slot")] = itemLevelFrame.textTrinket2;

-- WEAPONS
itemLevelFrame.textWeapon1 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textWeapon1:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textWeapon1:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textWeapon1:SetPoint("CENTER", weaponColumn1, weaponRow) 
frameTextObjects[GetInventorySlotInfo("MainHandSlot")] = itemLevelFrame.textWeapon1;

itemLevelFrame.textWeapon2 = itemLevelFrame:CreateFontString(nil, "OVERLAY")
itemLevelFrame.textWeapon2:SetFont("FONTS\\FRIZQT__.TTF", iLvlFontSize, iLvlTextType)
itemLevelFrame.textWeapon2:SetTextColor(1, 1, 0, 1)
itemLevelFrame.textWeapon2:SetPoint("CENTER", weaponColumn2, weaponRow) 
frameTextObjects[GetInventorySlotInfo("SecondaryHandSlot")] = itemLevelFrame.textWeapon2;

itemLevelFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
itemLevelFrame:SetScript("OnEvent", function(self, event, ...)
    local equipmentSlot, isEmpty = ...;
    UpdateItemLevelForSlot(equipmentSlot, isEmpty);
    MonkeyStuff:PrintDevMode("PLAYER_EQUIPMENT_CHANGED");
end)

function UpdateItemLevelForSlot(equipmentSlot, isEmpty)
    local text = frameTextObjects[equipmentSlot];

    if (isEmpty) then text:SetText("") return end;

    local item = Item:CreateFromEquipmentSlot(equipmentSlot)
    if (item) then
        itemLevel = item:GetCurrentItemLevel()
        text:SetText(itemLevel);
    else
        text:SetText("??");
    end
end

function MonkeyStuff:SetAllEquippedItemLevels()
    for slotIndex = 1, #frameTextObjects, 1 do
        UpdateItemLevelForSlot(slotIndex, false);
        itemLevelFrame:Show();
    end
end

-- Character Frame
CharacterFrame:HookScript("OnShow", function()
    itemLevelFrame:Show();
end)

---- Tab: Character
CharacterFrameTab1:HookScript("OnClick", function()
    itemLevelFrame:Show();
end)

---- Tab: Reputation
CharacterFrameTab2:HookScript("OnClick", function()
    itemLevelFrame:Hide();
end)

---- Tab: Currency
CharacterFrameTab3:HookScript("OnClick", function()
    itemLevelFrame:Hide();
end)