MonkeyStuff = {};
local MS_addonEnabled = false;

MS_curMoney = 0;
MS_earnMoney = 0;

MS_junk = 0;
MS_Merchant = false;
MS_farming = true;
MS_curXP = 0;

local MS_Merchant_EventFrame = CreateFrame("Frame");
MS_Merchant_EventFrame:RegisterEvent("ADDON_LOADED");
MS_Merchant_EventFrame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_SHOW");
MS_Merchant_EventFrame:RegisterEvent("MERCHANT_CLOSED");
MS_Merchant_EventFrame:RegisterEvent("PLAYER_MONEY");

function MS_OnEvent(self, event, ...)
    
    if (event == "ADDON_LOADED" and ... == "MonkeyStuff") then
         if (MS_Safewords == "nil") then 
            MS_Safewords = {"Hearthstone", "Leather", "Hide", "Cloth", "Skinning Knife", "Fishing Pole", "Blacksmith Hammer", "Arrow", "Bullet"};
            print("[MonkeyStuff] " .. #MS_Safewords .. " default safewords loaded.");
         else print("[MonkeyStuff] " .. #MS_Safewords .. " safewords loaded.");
         end

         MS_curXP = UnitXP("player");
    end

    if (event == "MERCHANT_SHOW") then
        MonkeyStuff:AutoRepair();
        reportedEarnings = false;
        MS_curMoney = GetMoney();
        MS_Merchant = true;
        MonkeyStuff:SellJunk();
    end

    if (event == "PLAYER_MONEY") then
        if (MS_junk > 0 and reportedEarnings == false) then MonkeyStuff:PrintEarnings() end;
    end

    if (event == "MERCHANT_CLOSED") then MS_Merchant = false; end;

    if (event == "CHAT_MSG_COMBAT_XP_GAIN") then
        if (MS_farming == true) then    
            MS_XP = UnitXP("player")
            MS_GainedXP = MS_XP - MS_curXP;
            if (MS_GainedXP == 0) then return; end;

            XPMax = UnitXPMax("player")

            RemainingXP = XPMax - MS_curXP;
            print(RemainingXP .. "XP to lvl (Gained " .. MS_GainedXP ..")");
            print((RemainingXP / MS_GainedXP));
            killsToLVL = ceil(RemainingXP / MS_GainedXP);

            print("[MonkeyStuff]: " .. killsToLVL .. " kills remaining to lvl " .. (UnitLevel("player") + 1)); MS_curXP = MS_XP;
        end;
    end;
end

MS_Merchant_EventFrame:SetScript("OnEvent", MS_OnEvent);

function MonkeyStuff:AutoRepair()
    if (CanMerchantRepair()) then 
        repairAllCost, canRepair = GetRepairAllCost()
        if (canRepair) then
            RepairAllItems() 
            print("[MonkeyStuff] Paid " .. GetCoinTextureString(repairAllCost) .. " for repairs.")
        end
    end
end


function MonkeyStuff:SellJunk()
    if (MS_Merchant == true) then
        MS_junk = 0
        MS_sold = 0

        for bag = 0, 4, 1 do

            local bagName = GetBagName(bag); bagSlots = GetContainerNumSlots(bag, bagSlots); -- get bag name and amount of slots
            if (string.find(bagName, "Quiver") or string.find(bagName, "Pouch")) then MonkeyStuff:RefillAmmo(bag); return end; -- don't look through Quivers/Pouches for items to sell

            for slot = 1, bagSlots, 1 do
                local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemID = GetContainerItemInfo(bag, slot)

                if (itemID ~= nil) then
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID);


                    if (itemRarity < 2) then
                        if (MonkeyStuff:ShouldSellItem(itemName, itemType)) then
                            ShowContainerSellCursor(bag, slot)
                            UseContainerItem(bag, slot)
                            MS_junk = MS_junk + 1
                            MS_sold = MS_sold + (itemSellPrice * count)
                        end
                    end
                end
            end
        end
    end
end

function MonkeyStuff:ShouldSellItem(_itemName, _itemType)

    local MS_b_ShouldSell = true;

    if (_itemType == "Quest" or _itemType == "Consumable") then MS_b_ShouldSell = false;
    else MS_b_ShouldSell = true;
    end
    
    for i = 1, #MS_Safewords, 1 do
        if (string.find(_itemName, MS_Safewords[i])) then
            MS_b_ShouldSell = false; 
            break;
        end
    end

    return MS_b_ShouldSell;
end

function MonkeyStuff:PrintEarnings()
        print("[MonkeyStuff] Vendored items for " .. GetCoinTextureString(MS_sold) .. ".");
        reportedEarnings = true;
end

function MonkeyStuff:RefillAmmo(ammoBag)
    maxStackSize = 200
    -- Check for class of "player" -- obsolete? Who else carries Ammo Bags?
    local freeSlots = GetContainerFreeSlots(ammoBag) -- the amount of arrow stacks to buy

    if (#freeSlots == 0) then -- full on (stacks of) arrows
    else -- refill arrow stacks
        local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, ammoItemID = GetContainerItemInfo(ammoBag, bagSlots); -- what ammo are we using? (ID)
        local ammoName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(ammoItemID); -- get name of ammo

        local vendorItems = GetMerchantNumItems(); -- get vendor items
        if (vendorItems > 0) then -- if vendor has any thing to sell
            for i = 1, vendorItems, 1 do -- look through each item
                local itemName, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)

                if (ammoName == itemName) then -- vendor has the ammo we are using?
                    print("[MonkeyStuff] Refilling " .. ammoName .. "s.");
                    
                    local texture, ammoCount, locked, quality, readable, lootable, link, isFiltered, hasNoValue, ammoItemID = GetContainerItemInfo(ammoBag, #freeSlots + 1);

                    -- fill up single stack of arrows (e.g 47 -> 200)
                    stackSize = maxStackSize - ammoCount; -- returns 0 if full, otherwise returns amount of arrows missing for a full stack
                    if (stackSize ~= 0) then BuyMerchantItem(i, stackSize); end

                    for j = 1, #freeSlots, 1 do -- buy arrows equal to the amount of free slots
                        BuyMerchantItem(i);
                    end
                    return; -- don't need to go through the other vendor items if already bought ammo
                end
            end
        end
    end
end

function MonkeyStuff:PrintAvailableCommands()
    print("[MonkeyStuff] Available commands:\n# Type /ms (add | remove) 'item name' to add/remove an item to the dont-autosell list (whitelist).\n# Type '/ms whitelist' to see the whitelisted items.")
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
        elseif (command == "whitelist") then print("[MonkeyStuff]: " .. #MS_Safewords .. " items on whitelist (apart from Consumables):"); 
            str_whitelist = "";
            for i = 1, #MS_Safewords, 1 do
               str_whitelist = str_whitelist .. ' "' .. MS_Safewords[i] .. '", '
            end
            print(str_whitelist);
        elseif (command == "farm") then 
            if (MS_farming == false) then print("[MonkeyStuff]: Farming mode activated"); MS_farming = true; 
            else print("[MonkeyStuff]: Farming mode deactivated."); MS_farming = false;
            end;

            print(MS_farming);
        end;
    end;
end

SLASH_MonkeyStuff1 = "/ms";
SlashCmdList.MonkeyStuff = HandleSlashCommands;