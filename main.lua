MonkeyStuff = {};
local MS_addonEnabled = false;

MS_curMoney = 0;
MS_earnMoney = 0;

MS_junk = 0;
MS_Merchant = false;
MS_AvoidDoubleCall = true;
MS_timeMerchantClosed = 100;
MS_timeMoneyChanged = 100;
MS_timePrintEarningsDelay = 2;

local MS_Merchant_EventFrame = CreateFrame("Frame");
MS_Merchant_EventFrame:RegisterEvent("ADDON_LOADED");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_SHOW");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_CLOSED");
MS_Merchant_EventFrame:RegisterEvent("PLAYER_MONEY");

function MS_OnEvent(self, event, ...)

    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then

        if (MS_Safewords == "nil") then 
            MS_Safewords = {"Leather", "Hide", "Cloth", "Skinning Knife", "Troll Sweat"};
            print("[MonkeyStuff] Default " .. #MS_Safewords .. " safewords loaded.");
        else print("[MonkeyStuff] " .. #MS_Safewords .. " safewords loaded.");
        end
    end

    if (event == "MERCHANT_SHOW") then
        reportedEarnings = false;
        MS_curMoney = GetMoney()
        MS_Merchant = true
        MonkeyStuff:SellJunk()
    end

    if (event == "PLAYER_MONEY") then
        MS_earnMoney = GetMoney()
        MS_timeMoneyChanged = time()

        if (reportedEarnings == false) then MonkeyStuff:PrintEarnings() end;
    end

    if (event == "MERCHANT_CLOSED") then MS_Merchant = false; end;

end

MS_Merchant_EventFrame:SetScript("OnEvent", MS_OnEvent);


function MonkeyStuff:SellJunk()
    if (MS_Merchant == true) then
        MS_junk = 0

        if (CanMerchantRepair()) then 
            repairAllCost, canRepair = GetRepairAllCost()
            if (canRepair) then
                RepairAllItems() 
                print("[MonkeyStuff] Paid " .. GetCoinTextureString(repairAllCost) .. " for repairs.")
            end
        end

        for bag = 0, 4, 1 do

            local bagName = GetBagName(bag); local bagSlots = GetContainerNumSlots(bag); -- get bag name and amount of slots
            if (string.find(bagName, "Quiver") or string.find(bagName, "Pouch")) then quiverSlot = bag; return end; -- don't look through Quivers/Pouches for items to sell

            for slot = 1, bagSlots, 1 do
                texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemID = GetContainerItemInfo(bag, slot)

                if (itemID ~= nil) then
                    itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID);


                    if (itemRarity < 2) then
                        if (MonkeyStuff:ShouldSellItem(itemName, itemType)) then
                            MS_junk = MS_junk + 1
                            ShowContainerSellCursor(bag, slot)
                            UseContainerItem(bag, slot)
                        end
                    end
                end
            end
        end
    end
end

function MonkeyStuff:ArrowRefill()
    -- Check for class of "player"
    local freeSlots = GetContainerFreeSlots(quiverSlot)

    if (freeSlots[1] == nil) then return -- full on arrows -- WORKS! 23-09-2019
    else print("[MonkeyStuff] Not full on arrows.")
        -- Buy arrows

    end
end

function MonkeyStuff:PrintEarnings()
    if (MS_junk > 0) then
        print("[MonkeyStuff] Sold " .. MS_junk .. " item(s) [" .. GetCoinTextureString(MS_earnMoney - MS_curMoney) .. "]");
        reportedEarnings = true;
        MS_junk = 0;
    end
end

function MonkeyStuff:ShouldSellItem(_itemName, _itemType)

    local b_ShouldSell = true;

    if (_itemType == "Quest" or _itemType == "Consumable") then b_ShouldSell = false;
    else b_ShouldSell = true;
    end
    
    for i = 1, #MS_Safewords, 1 do
        if (string.find(_itemName, MS_Safewords[i])) then
            b_ShouldSell = false; 
            break;
        end
    end

    return b_ShouldSell;

end

function MonkeyStuff:PrintAvailableCommands()
    print("[MonkeyStuff] Type /ms (add | remove) 'item name' to add/remove an item to the dont-autosell list (whitelist).\nType '/ms whitelist' to see the whitelisted items.")
end


local function HandleSlashCommands(msg)
    if (#msg <= 1) then MonkeyStuff:PrintAvailableCommands() return
    else
        local command, item = strsplit(" ", msg, 2)

        if (command == "add") then MS_Safewords[#MS_Safewords + 1] = item; print("Added '" .. item .. "' to whitelist!");
        elseif (command == "remove") then 
            for i = 1, #MS_Safewords, 1 do 
                if (string.find(MS_Safewords[i], item)) then table.remove(MS_Safewords, i); print("Removed '" .. item .. "' from whitelist."); 
                end;
            end
        elseif (command == "whitelist") then print("[MonkeyStuff]: Items on whitelist: "); print(unpack(MS_Safewords));
        end
    end;
end

SLASH_MonkeyStuff1 = "/ms";
SlashCmdList.MonkeyStuff = HandleSlashCommands;