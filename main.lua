MonkeyStuff = {};

colorMain = "|cff89CFF0";
colorMarked = "|cfffda82b";
colorUnmarked = "|cffffffff";

devMode = false;
MS_ItemsMarkedForSale = {""};

local MS_Merchant_EventFrame = CreateFrame("Frame");
MS_Merchant_EventFrame:RegisterEvent("ADDON_LOADED");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");

function MS_OnEvent(self, event, ...)
    MonkeyStuff:PrintDevMode("EVENT: " .. event);
    
    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then
        MonkeyStuff:ClearItemsMarkedForSale();
        MonkeyStuff:Print("Loaded.");
    end

    if (event == "MERCHANT_SHOW") then
        MonkeyStuff:AutoRepair();
        MonkeyStuff:AutoSellItems();
    end

end;
MS_Merchant_EventFrame:SetScript("OnEvent", MS_OnEvent);

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

                local shouldSell = false;
                local itemIsMarked, _ = CheckItemMarkedForSale(itemLink);

                if (ItemIsJunk(itemQuality)) then
                    shouldSell = true;
                    junkSold = junkSold + 1;
                end

                if (itemIsMarked) then
                    shouldSell = true;
                    markedSold = markedSold + 1;
                end

                if (shouldSell) then
                    C_Container.ShowContainerSellCursor(bag, slot)
                    C_Container.UseContainerItem(bag, slot)
                end
            end                
        end
    end

    if (shouldSell) then 
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