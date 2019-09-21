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
        if (MS_Safewords == nil) then 
            MS_Safewords = "Leather Hide Cloth";
            print("Default Safewords loaded.");
        else print("[MonkeyStuff] Loaded Safewords: " .. MS_Safewords)
        end

        if string.find("Leather Hide", "Silk Cloth") then print("Found Heavy Hide in Leather Hide")
        else print("Nope.")
        end
    end

    if (event == "MERCHANT_SHOW") then
        MS_curMoney = GetMoney()
        MS_Merchant = true
        MonkeyStuff:SellJunk()
    end

    if (event == "PLAYER_MONEY") then
        MS_earnMoney = GetMoney()
        MS_timeMoneyChanged = time()

        if (MS_Merchant == false) then 
            if (MS_timeMerchantClosed ~= 100 and (MS_timeMerchantClosed - time()) < (MS_timeMerchantClosed + MS_timePrintEarningsDelay)) then MonkeyStuff:PrintEarnings() end
        end
    end

    if (event == "MERCHANT_CLOSED") then
        if (AvoidDoubleCall == true) then AvoidDoubleCall = false return
        else
            MS_Merchant = false

            if (MS_junk > 0 and MS_curMoney < MS_earnMoney) then
                AvoidDoubleCall = true
                MS_timeMerchantClosed = time()

                if (MS_timeMerchantClosed > MS_timeMoneyChanged) then MonkeyStuff:PrintEarnings() end
            end
        end
    end

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
            local bagName = GetBagName(bag);
            if (string.find(bagName, "Quiver") or string.find(bagName, "Pouch")) then return end; -- don't look through Quivers/Pouches for items to sell

            for slot = 1, 16, 1 do
                local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemID = GetContainerItemInfo(bag, slot)

                if (quality == 0) then
                    MS_junk = MS_junk + 1
                    ShowContainerSellCursor(bag, slot)
                    UseContainerItem(bag, slot)
                end

                if (quality == 1) then 
                    itemId = GetContainerItemID(bag, slot)

                    if (itemID ~= nil) then itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID)
                        if (itemType == "Consumable" or itemType == "Miscellaneous" or itemType == "Quest") then -- don't sell consumables 
                        elseif (string.find(itemName, "Leather") or string.find(itemName, "Hide") or string.find(itemName, "Cloth") or string.find(itemName, "Skinning Knife")) then -- nor whitelisted items
                        else
                            MS_junk = MS_junk + 1;
                            ShowContainerSellCursor(bag, slot);
                            UseContainerItem(bag, slot);
                        end
                    end

                end
            end
        end        
    end
    if (UnitClass("player") == "Hunter") then MonkeyStuff:ArrowRefill() end
end

function MonkeyStuff:ArrowRefill()
    if (MS_Merchant == true) then
        local quiver = 4;
        local freeSlots = GetContainerFreeSlots(quiver)

        if (freeSlots[1] == nil) then return -- full on arrows
        else print("[MonkeyStuff] Not full on arrows.")
            -- Buy arrows

        end
    end
end

function MonkeyStuff:PrintEarnings()
    print("[MonkeyStuff] Sold " .. MS_junk .. " item(s) [" .. GetCoinTextureString(MS_earnMoney - MS_curMoney) .. "]");
end