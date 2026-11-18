-- TheForge_AutoSell.lua -- S0 smoke test and read-only diagnostics
-- No sales are implemented. Inventory schema and official transaction flow are unverified.
local stage = "starting"
local gui
local ok, err = xpcall(function()
    stage = "getting Roblox services"
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    stage = "waiting for LocalPlayer"
    local player = Players.LocalPlayer
    assert(player, "LocalPlayer unavailable")
    stage = "waiting for PlayerGui"
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    assert(pg, "PlayerGui unavailable after 10 seconds")
    stage = "removing old instance"
    local old = pg:FindFirstChild("ForgeSellS0")
    if old then
        local close = old:FindFirstChild("Shutdown")
        if close and close:IsA("BindableEvent") then close:Fire() end
        if old.Parent then old:Destroy() end
    end
    stage = "creating ScreenGui"
    gui = Instance.new("ScreenGui")
    gui.Name = "ForgeSellS0"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 30
    gui.Parent = pg
    local shutdown = Instance.new("BindableEvent")
    shutdown.Name = "Shutdown"
    shutdown.Parent = gui
    local connections = {}
    local alive = true
    local function on(signal, callback)
        local conn = signal:Connect(callback)
        connections[#connections + 1] = conn
        return conn
    end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(370, 465)
    frame.Position = UDim2.new(0, 18, 0.5, -232)
    frame.BackgroundColor3 = Color3.fromRGB(27, 29, 36)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local function text(parent, name, x, y, w, h, value)
        local t = Instance.new("TextLabel")
        t.Name = name t.Position = UDim2.fromOffset(x, y) t.Size = UDim2.fromOffset(w, h)
        t.BackgroundTransparency = 1 t.TextColor3 = Color3.fromRGB(235, 238, 245)
        t.Font = Enum.Font.Gotham t.TextSize = 13 t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = value t.Parent = parent
        return t
    end
    local title = text(frame, "Title", 12, 5, 345, 25, "AUTO SELL S0  |  drag here")
    title.Font = Enum.Font.GothamBold
    local function button(x, y, w, h, label, action)
        local b = Instance.new("TextButton")
        b.Position = UDim2.fromOffset(x, y) b.Size = UDim2.fromOffset(w, h)
        b.BackgroundColor3 = Color3.fromRGB(52, 57, 70) b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.Gotham b.TextSize = 12
        b.Text = label b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        on(b.MouseButton1Click, function() action(b) end)
        return b
    end
    local output = Instance.new("TextBox")
    output.Name = "DebugConsole" output.Position = UDim2.fromOffset(10, 274) output.Size = UDim2.fromOffset(350, 145)
    output.BackgroundColor3 = Color3.fromRGB(15, 17, 22) output.TextColor3 = Color3.fromRGB(190, 225, 200)
    output.ClearTextOnFocus = false output.MultiLine = true output.TextEditable = false
    output.Font = Enum.Font.Code output.TextSize = 12 output.TextXAlignment = Enum.TextXAlignment.Left
    output.TextYAlignment = Enum.TextYAlignment.Top output.TextWrapped = true output.Text = "" output.Parent = frame
    local lines = {}
    local function log(s)
        print("[Forge S0] " .. s)
        table.insert(lines, s)
        while #lines > 8 do table.remove(lines, 1) end
        output.Text = table.concat(lines, "\n")
    end
    local state = {auto = false, selected = {}, blacklist = ""}
    local status = text(frame, "Status", 10, 238, 350, 30, "Status: BLOCKED - no verified inventory or sale flow")
    status.TextWrapped = true
    button(10, 35, 170, 26, "Auto Sell: OFF", function(b)
        state.auto = not state.auto
        b.Text = "Auto Sell: " .. (state.auto and "ON (DRY)" or "OFF")
        log(state.auto and "DRY RUN armed; no transaction can be sent." or "Auto Sell off.")
    end)
    button(190, 35, 170, 26, "Mode: DRY RUN (locked)", function() log("Sale disabled until official UI and inventory are verified.") end)
    text(frame, "RarityHeading", 10, 64, 340, 20, "Rarity filters (none selected by default)")
    local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine"}
    for i, rarity in ipairs(rarities) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        button(10 + col * 89, 86 + row * 26, 84, 23, "[ ] " .. rarity, function(b)
            state.selected[rarity] = not state.selected[rarity]
            b.Text = (state.selected[rarity] and "[x] " or "[ ] ") .. rarity
        end)
    end
    local blacklist = Instance.new("TextBox")
    blacklist.Position = UDim2.fromOffset(10, 142) blacklist.Size = UDim2.fromOffset(350, 25)
    blacklist.BackgroundColor3 = Color3.fromRGB(45, 48, 58) blacklist.TextColor3 = Color3.new(1, 1, 1)
    blacklist.PlaceholderText = "Blacklist: comma-separated names" blacklist.Text = ""
    blacklist.ClearTextOnFocus = false blacklist.Font = Enum.Font.Gotham blacklist.TextSize = 12
    blacklist.Parent = frame
    on(blacklist.FocusLost, function() state.blacklist = blacklist.Text log("Blacklist stored; adapter unavailable.") end)
    text(frame, "Counts", 10, 171, 350, 24, "Inventory items: UNKNOWN  |  Selected: UNKNOWN")
    local function diagnose()
        log("Scanning object names only (no item counts inferred)...")
        local found, capped = 0, false
        for _, root in ipairs({player, pg}) do
            for _, obj in ipairs(root:GetDescendants()) do
                local n = obj.Name:lower()
                if n:find("inventory", 1, true) or n:find("stash", 1, true) or n:find("backpack", 1, true) then
                    found = found + 1
                    if found <= 5 then log(obj.ClassName .. ": " .. obj:GetFullName()) else capped = true end
                end
            end
        end
        if found == 0 then log("No matching object names found.") end
        if capped then log("More matches omitted; total: " .. tostring(found)) end
        log("Names are hints only; inventory and rarity unverified.")
    end
    button(10, 200, 170, 27, "Run diagnostics", function()
        local pass, why = pcall(diagnose)
        if not pass then log("Diagnostic error: " .. tostring(why)) end
    end)
    button(190, 200, 170, 27, "Preview selected", function()
        log("Preview unavailable: no verified item adapter.")
        log("No item selected or sold.")
    end)
    button(10, 427, 350, 27, "UNLOAD", function() shutdown:Fire() end)
    local dragging, start, position = false, nil, nil
    on(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true start = input.Position position = frame.Position
        end
    end)
    on(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - start
            frame.Position = UDim2.new(position.X.Scale, position.X.Offset + delta.X, position.Y.Scale, position.Y.Offset + delta.Y)
        end
    end)
    on(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    on(shutdown.Event, function()
        if not alive then return end
        alive = false
        for _, c in ipairs(connections) do c:Disconnect() end
        gui:Destroy()
    end)
    stage = "GUI created"
    log("GUI constructed; check visually that it is displayed.")
    log("DRY RUN locked. Selling is not implemented.")
    print("[Forge S0] Initialization complete: " .. stage)
end, function(message) return tostring(message) end)
if not ok then
    warn("[Forge S0] Initialization failed at '" .. stage .. "': " .. tostring(err))
    if gui then pcall(function() gui:Destroy() end) end
end
