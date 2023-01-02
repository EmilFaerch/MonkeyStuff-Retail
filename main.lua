MonkeyStuff = {};

colorMain = "|cff89CFF0";
colorMarked = "|cfffda82b";
colorUnmarked = "|cffffffff";

devMode = false;
MS_ItemsMarkedForSale = {""};

local MonkeyStuff_EventFrame = CreateFrame("Frame");
MonkeyStuff_EventFrame:RegisterEvent("ADDON_LOADED");
MonkeyStuff_EventFrame:RegisterEvent("MERCHANT_SHOW");
MonkeyStuff_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
MonkeyStuff_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");

function MS_OnEvent(self, event, ...)
    MonkeyStuff:PrintDevMode("EVENT: " .. event);
    
    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then
        MonkeyStuff:Print("Loaded.");
    end

    if (event == "MERCHANT_SHOW") then
        MonkeyStuff:AutoRepair();
        MonkeyStuff:AutoSellItems();
    end

end;
MonkeyStuff_EventFrame:SetScript("OnEvent", MS_OnEvent);

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
        tooltip:AddLine(colorMarked .. "Marked for auto-sell.\nShift-Right click to unmark.");
    else
        tooltip:AddLine(colorUnmarked .. "Shift-Right click to mark for auto-sell.");
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
    print(colorMain .. "[MonkeyStuff]|r " .. msg)
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
itemLevelFrame.textHead = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textHead:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textHead:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textHead:SetPoint("CENTER", leftColumn, row1) -- Anchor the text display and make it the same size as the frame
frameTextObjects[1] = itemLevelFrame.textHead;

itemLevelFrame.textNeck = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textNeck:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textNeck:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textNeck:SetPoint("CENTER", leftColumn, row2) -- Anchor the text display and make it the same size as the frame
frameTextObjects[2] = itemLevelFrame.textNeck;

itemLevelFrame.textShoulders = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textShoulders:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textShoulders:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textShoulders:SetPoint("CENTER", leftColumn, row3) -- Anchor the text display and make it the same size as the frame
frameTextObjects[3] = itemLevelFrame.textShoulders;

itemLevelFrame.textBack= itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textBack:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textBack:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textBack:SetPoint("CENTER", leftColumn, row4) -- Anchor the text display and make it the same size as the frame
frameTextObjects[4] = itemLevelFrame.textBack;

itemLevelFrame.textChest = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textChest:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textChest:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textChest:SetPoint("CENTER", leftColumn, row5) -- Anchor the text display and make it the same size as the frame
frameTextObjects[5] = itemLevelFrame.textChest;

itemLevelFrame.textWrist = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textWrist:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textWrist:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textWrist:SetPoint("CENTER", leftColumn, row8) -- Anchor the text display and make it the same size as the frame
frameTextObjects[6] = itemLevelFrame.textWrist;

-- RIGHT COLUMN
itemLevelFrame.textGloves = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textGloves:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textGloves:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textGloves:SetPoint("CENTER", rightColumn, row1) -- Anchor the text display and make it the same size as the frame
frameTextObjects[7] = itemLevelFrame.textGloves;

itemLevelFrame.textBelt= itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textBelt:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textBelt:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textBelt:SetPoint("CENTER", rightColumn, row2) -- Anchor the text display and make it the same size as the frame
frameTextObjects[8] = itemLevelFrame.textBelt;

itemLevelFrame.textLegs = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textLegs:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textLegs:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textLegs:SetPoint("CENTER", rightColumn, row3) -- Anchor the text display and make it the same size as the frame
frameTextObjects[9] = itemLevelFrame.textLegs;

itemLevelFrame.textFeet = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textFeet:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textFeet:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textFeet:SetPoint("CENTER", rightColumn, row4) -- Anchor the text display and make it the same size as the frame
frameTextObjects[10] = itemLevelFrame.textFeet;

itemLevelFrame.textRing1 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textRing1:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textRing1:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textRing1:SetPoint("CENTER", rightColumn, row5) -- Anchor the text display and make it the same size as the frame
frameTextObjects[11] = itemLevelFrame.textRing1;

itemLevelFrame.textRing2 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textRing2:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textRing2:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textRing2:SetPoint("CENTER", rightColumn, row6) -- Anchor the text display and make it the same size as the frame
frameTextObjects[12] = itemLevelFrame.textRing2;

itemLevelFrame.textTrinket1 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textTrinket1:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textTrinket1:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textTrinket1:SetPoint("CENTER", rightColumn, row7) -- Anchor the text display and make it the same size as the frame
frameTextObjects[13] = itemLevelFrame.textTrinket1;

itemLevelFrame.textTrinket2 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textTrinket2:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textTrinket2:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textTrinket2:SetPoint("CENTER", rightColumn, row8) -- Anchor the text display and make it the same size as the frame
frameTextObjects[14] = itemLevelFrame.textTrinket2;

-- WEAPONS
itemLevelFrame.textWeapon1 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textWeapon1:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textWeapon1:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textWeapon1:SetPoint("CENTER", weaponColumn1, weaponRow) -- Anchor the text display and make it the same size as the frame
frameTextObjects[15] = itemLevelFrame.textWeapon1;

itemLevelFrame.textWeapon2 = itemLevelFrame:CreateFontString(nil, "OVERLAY") -- Add a text display widget (FontString)
itemLevelFrame.textWeapon2:SetFont("FONTS\\FRIZQT__.TTF", 12, "OUTLINE") -- General text settings
itemLevelFrame.textWeapon2:SetTextColor(1, 1, 0, 1) -- Yellow
itemLevelFrame.textWeapon2:SetPoint("CENTER", weaponColumn2, weaponRow) -- Anchor the text display and make it the same size as the frame
frameTextObjects[16] = itemLevelFrame.textWeapon2;

itemLevelFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- Get notified when you bags inventory changes
itemLevelFrame:SetScript("OnEvent", function(self, event, ...) -- self=the frame the event is registered for, event=the event (for multiple events), ...=a variable number of parameters based on the event
    local equipmentSlot, isEmpty = ...;
    UpdateItemLevelForSlot(equipmentSlot, isEmpty);
end)

function UpdateItemLevelForSlot(equipmentSlot, isEmpty)
    local text = frameTextObjects[equipmentSlot];

    if (isEmpty) then text:SetText(""); return end;

    local item = Item:CreateFromEquipmentSlot(equipmentSlot)
    if ( item ) then
        itemLevel = item:GetCurrentItemLevel()
    end

    text:SetText(itemLevel);
end