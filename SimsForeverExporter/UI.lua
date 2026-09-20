local _, addon = ...
local window, editBox

local function message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("SimsForever: " .. text) end
end

local function createWindow()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    window = CreateFrame("Frame", "SimsForeverExporterWindow", UIParent, template)
    window:SetSize(740, 500)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetBackdrop then
        window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    end
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText("SimsForever character export")
    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 20, -48)
    hint:SetWidth(690)
    hint:SetJustifyH("LEFT")
    hint:SetText("Press Ctrl+C to copy, then paste at simsforever.com. Escape closes this window.\nExport again after changing gear, spells, talents, or buffs.")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -95)
    scroll:SetPoint("BOTTOMRIGHT", -42, 22)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(670)
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnEscapePressed", function() window:Hide() end)
    editBox:SetScript("OnTextChanged", function(self)
        local _, fontSize = self:GetFont()
        self:SetHeight(math.max(360, self:GetNumLines() * (fontSize + 4) + 30))
    end)
    scroll:SetScrollChild(editBox)
    window:SetScript("OnHide", function() editBox:ClearFocus() end)
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", function() window:Hide() end)
    UISpecialFrames = UISpecialFrames or {}
    UISpecialFrames[#UISpecialFrames + 1] = "SimsForeverExporterWindow"
end

local function command(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")
    if input == "clear" then
        SimsForeverExporterDB = nil
        message("Saved export cleared.")
        return
    end
    if input ~= "" and input ~= "save" then
        message("/sfexport opens JSON. /sfexport save also saves the latest JSON locally. /sfexport clear removes that saved copy.")
        return
    end
    local ok, json, errorMessage = pcall(addon.Export)
    if not ok then
        message("Export failed on this game build. No export was saved. Please report the build and addon version.")
        return
    end
    if not json then message(errorMessage or "Export unavailable."); return end
    if input == "save" then
        SimsForeverExporterDB = { lastExport = json }
        message("Saved this export locally. WoW writes SavedVariables on logout or /reload.")
    end
    if not window then createWindow() end
    window:Show()
    editBox:SetText(json)
    editBox:SetFocus()
    editBox:HighlightText()
end

SLASH_SIMFOREVEREXPORTER1 = "/simsforever"
SLASH_SIMFOREVEREXPORTER2 = "/sfexport"
SlashCmdList.SIMFOREVEREXPORTER = command
