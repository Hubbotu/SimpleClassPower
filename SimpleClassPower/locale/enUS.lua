local ADDON = ...
local L = Wheel("LibLocale"):NewLocale(ADDON, "enUS", true)

-- Chat command menu
L["/scp - Toggle the overlay for moving/scaling."] = "|cffa365ee/scp|r - Toggle the overlay for moving/scaling."
L["/scp classcolor on - Enable class colors."] = "|cffa365ee/scp classcolor on|r - Enable class colors."
L["/scp classcolor off - Disable class colors."] = "|cffa365ee/scp classcolor off|r - Disable class colors. |cff888888(default)|r"
L["/scp show always - Always show."] = "|cffa365ee/scp show always|r - Always show. |cff888888(default)|r"
L["/scp show smart - Hide when no target or unattackable."] = "|cffa365ee/scp show smart|r - Hide when no target or unattackable."
L["/scp help - Show this."] = "|cffa365ee/scp help|r - Show this."

-- Tooltips
L["<Left-Click> to raise"] = true 
L["<Left-Click> to lower"] = true
L["<Shift Left Click> to reset position"] = true
L["<Shift Right Click> to reset scale"] = true
