MonkeyStuff = {};

devMode = false;

local MS_Merchant_EventFrame = CreateFrame("Frame");
MS_Merchant_EventFrame:RegisterEvent("ADDON_LOADED");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
MS_Merchant_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");
MS_Merchant_EventFrame:RegisterEvent("TOOLTIP_DATA_UPDATE");

function MS_OnEvent(self, event, ...)
    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then
        MonkeyStuff:Print("Loaded.");
    end

    if (event == "MERCHANT_SHOW") then
        MonkeyStuff:AutoRepair();
        MonkeyStuff:SellJunk();
    end

    if (devMode == true) then MonkeyStuff:Print("EVENT: " .. event); end;
end;
MS_Merchant_EventFrame:SetScript("OnEvent", MS_OnEvent);

function MonkeyStuff:AutoRepair()
    if (CanMerchantRepair()) then 
        repairAllCost, canRepair = GetRepairAllCost()
        if (canRepair) then
            RepairAllItems(); 
            MonkeyStuff:Print("Paid " .. GetCoinTextureString(repairAllCost) .. " for repairs.");
        end
    end
end;

function MonkeyStuff:SellJunk()
    local junkSold = 0
    for bag = 0, 5, 1 do
        local bagSlots = C_Container.GetContainerNumSlots(bag);

        for slot = 1, bagSlots, 1 do
        local itemID = C_Container.GetContainerItemID(bag, slot)

            if (itemID ~= nil) then
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID);
                if (itemSubType == "Junk" and itemRarity == 0) then
                    junkSold = junkSold + 1;
                    C_Container.ShowContainerSellCursor(bag, slot)
                    C_Container.UseContainerItem(bag, slot)
                end
            end                
        end
    end

    if (junkSold > 0) then MonkeyStuff:Print("Sold " .. junkSold .. " junk item(s)."); end;
end;


function MonkeyStuff_DisplayUnitPriceToolTip(tooltip, data)
    if tooltip == GameTooltip then
        local name, link = tooltip:GetItem()
        local maxStack = select(8, GetItemInfo(link))

        if (maxStack > 1) then 
            local unitPrice = select(11, GetItemInfo(link))

            if (unitPrice > 0) then
                tooltip:AddLine("Unit Price: " .. GetCoinTextureString(unitPrice), 1, 1, 1)
                tooltip:AddLine("|cffB2BEB5Max stack: " .. maxStack .. " (" .. GetCoinTextureString(unitPrice * maxStack) .. ")")
                tooltip:Show()
            end
        end
    end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, MonkeyStuff_DisplayUnitPriceToolTip)

function MonkeyStuff:PrintAvailableCommands()
    MonkeyStuff:Print("Can't do much yet!");
end;

local function HandleSlashCommands(msg)
    if (#msg <= 1) then MonkeyStuff:PrintAvailableCommands() return
    else
        local command, item = strsplit(" ", msg, 2)

         if (command == "dev") then 
             MonkeyStuff:Print("Developer mode toggled.");
             devMode = not devMode;
         end
    end
end;

function MonkeyStuff:Print(msg)
    print("|cff89CFF0[MonkeyStuff]|r " .. msg)
end

SLASH_MonkeyStuff1 = "/ms";
SlashCmdList.MonkeyStuff = HandleSlashCommands;