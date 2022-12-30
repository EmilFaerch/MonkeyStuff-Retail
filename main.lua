MonkeyStuff = {};

devMode = true;
MS_ItemsMarkedForSale = {""};

local MS_Merchant_EventFrame = CreateFrame("Frame");
MS_Merchant_EventFrame:RegisterEvent("ADDON_LOADED");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");
MS_Merchant_EventFrame:RegisterEvent("TOOLTIP_DATA_UPDATE");

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
    local junkSold = 0
    for bag = 0, 4, 1 do
        local bagSlots = C_Container.GetContainerNumSlots(bag);

        for slot = 1, bagSlots, 1 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            
            if (itemID ~= nil) then
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID);
                
                MonkeyStuff:PrintDevMode("AutoSellItems() 2");  
                -- MonkeyStuff:PrintDevMode(itemName .. ": " .. itemType .. ", " .. itemSubType);
                -- can't trust that itemTypes nor itemSubType makes sense, so just rely on itemRarity I guess... (rather than also checking itemSubType == "Junk" or itemType == "Armor" or itemType == "Weapon")
                if (ItemIsJunk(itemRarity) or ItemIsMarkedForSale(itemLink)) then
                    junkSold = junkSold + 1;
                    C_Container.ShowContainerSellCursor(bag, slot)
                    C_Container.UseContainerItem(bag, slot)
                end
            end                
        end
    end

    if (junkSold > 0) then MonkeyStuff:Print("Sold " .. junkSold .. " junk item(s)."); end;
end;

function ItemIsJunk(itemRarity)
    if itemRarity == "0" then return true else return false end;
end;

-- Display unit price if item is both stackable and sellable
function MonkeyStuff:Tooltip_AddUnitPrice(tooltip)
    local name, link = tooltip:GetItem()
    local _,_,_,_,_,_,_,maxStack,_,_,unitPrice = GetItemInfo(link);
    if (maxStack > 1 and unitPrice > 0) then
        tooltip:AddLine("Unit Price: " .. GetCoinTextureString(unitPrice), 1, 1, 1)
        tooltip:AddLine("|cffB2BEB5Max stack: " .. maxStack .. " (" .. GetCoinTextureString(unitPrice * maxStack) .. ")")
    end
end;

function MonkeyStuff:Tooltip_HandleMarkForSale(tooltip)
    local itemName, itemLink = tooltip:GetItem()

    -- DON'T SHOW THIS ON EQUIPPED ITEMS!!!!
    -- local x = tooltip:IsEquippedItem();
    -- MonkeyStuff:PrintDevMode(x);

    if (ItemIsMarkedForSale(itemLink)) then 
        tooltip:AddLine("Marked for auto-sell. CTRL-Right click to unmark for auto-sell.");
    else
        tooltip:AddLine("CTRL-Right click to mark for auto-sell.");
    end
end

function MonkeyStuff:HandleMarkForSale(itemLink)
    MonkeyStuff:PrintDevMode("HandleMarkForSale");
    local isMarked, tableIndex = ItemIsMarkedForSale(itemLink);
    MonkeyStuff:PrintDevMode("isMarked: " .. isMarked);
    if (isMarked) then 
        MonkeyStuff:UnmarkItemForSale(tableIndex)
    else
        MonkeyStuff:MarkItemForSale(itemLink)
    end
end

function MonkeyStuff:MarkItemForSale(itemLink)
    MonkeyStuff:PrintDevMode("MarkItemForSale: " .. itemLink);

    if (ItemCanBeMarkedForSale(itemLink) == true) then 
        local itemID = GetItemInfoFromHyperlink(itemLink)
        MS_ItemsMarkedForSale[#MS_ItemsMarkedForSale + 1] = itemID; 
        MonkeyStuff:PrintDevMode("Item marked for sale: " .. itemID .. " at index " .. #MS_ItemsMarkedForSale + 1);
    else
        MonkeyStuff:PrintDevMode("Could not mark item for sale: " .. itemLink);
    end;
end

function MonkeyStuff:UnmarkItemForSale(index)
    table.remove(MS_ItemsMarkedForSale, index); 
end

function MonkeyStuff:ClearItemsMarkedForSale()
    MS_ItemsMarkedForSale = {};
end

--- ### CORE MARK FOR SALE FUNCTIONS START ###
-- Mark item for sale!
hooksecurefunc("HandleModifiedItemClick", function(itemLink, itemLocation)
    if (itemLocation and itemLocation:IsBagAndSlot() and IsControlKeyDown()) then
        MonkeyStuff:HandleMarkForSale(itemLink);
    end
end);

function ItemCanBeMarkedForSale(itemLink)
    if (ItemIsMarkedForSale(itemLink) == false) then 

        -- loop through something that you can't mark, e.g. Hearthstone and such I guess

        MonkeyStuff:PrintDevMode("ItemCanBeMarkedForSale: TRUE");
        return true;
    end;

    MonkeyStuff:PrintDevMode("ItemCanBeMarkedForSale: FALSE");
    return false;
end

function ItemIsMarkedForSale(itemLink)
    if (#MS_ItemsMarkedForSale == 0) then return false, 0 end;

    print("ItemIsMarkedForSale")
    local itemID = GetItemInfoFromHyperlink(itemLink)
    print("ItemIsMarkedForSale: " .. itemID)
    for i = 1, #MS_ItemsMarkedForSale, 1 do
        if (itemID == MS_ItemsMarkedForSale[i]) then
            print("ItemIsMarkedForSale: TRUE " .. itemID)
            return true, i;
        end
    end
    return false, 0;
end
--- ### CORE MARK FOR SALE FUNCTIONS END ###

-- ### CORE FUNCTIONS START ###
local function ModifyTooltip(tooltip, data)
    if tooltip == GameTooltip then
        MonkeyStuff:Tooltip_AddUnitPrice(tooltip);
        MonkeyStuff:Tooltip_HandleMarkForSale(tooltip);
        tooltip:Show()
    end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ModifyTooltip)

function MonkeyStuff:PrintAvailableCommands()
    MonkeyStuff:Print("Can't do much yet!");
end;

function MonkeyStuff:Print(msg)
    print("|cff89CFF0[MonkeyStuff]|r " .. msg)
end;

function MonkeyStuff:PrintDevMode(msg)
    if (devMode == true) then MonkeyStuff:Print(msg) end;
end

function HandleSlashCommands(msg)
    MonkeyStuff:PrintDevMode("HandleSlashCommands: " .. msg)
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