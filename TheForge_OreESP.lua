-- The Forge Ore ESP E0: client-visible metadata only. Edit these settings if needed.
local Config = {
    ScanInterval = 2, MaxDistance = 300,
    RootName = "Rocks", -- Workspace child; falls back to name matching throughout Workspace
    RockNames = {"rock", "boulder", "pebble", "basalt", "crystal", "vein"},
    RockTags = {"Rock", "OreRock"}, -- unverified; customize after inspecting your own client
    OreAttributes = {"Ore", "OreName"}, RarityAttributes = {"Rarity", "OreRarity"},
}
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then warn("Ore ESP: LocalPlayer unavailable") return end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not playerGui then warn("Ore ESP: PlayerGui unavailable") return end
local GUI_NAME = "TheForgeOreESP_E0"
local old = playerGui:FindFirstChild(GUI_NAME)
if old then
    local shutdown = old:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
    if old.Parent then old:Destroy() end
end
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.Parent = playerGui
local shutdown = Instance.new("BindableEvent")
shutdown.Name = "Shutdown"
shutdown.Parent = gui
local state = {enabled = true, showName = true, showRarity = true, showDistance = true,
    rockFilter = "", oreFilter = "", maxDistance = Config.MaxDistance}
local alive, connections, cache = true, {}, {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(260, 320)
panel.Position = UDim2.new(0, 18, 0.5, -160)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner", panel)
corner.CornerRadius = UDim.new(0, 8)
local function label(text, y, height)
    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(1, -20, 0, height or 25)
    v.Position = UDim2.fromOffset(10, y)
    v.BackgroundTransparency = 1
    v.TextColor3 = Color3.fromRGB(235, 237, 245)
    v.TextSize = 14
    v.Font = Enum.Font.Gotham
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.Text = text
    v.Parent = panel
    return v
end
local title = label("ORE ESP  |  drag here", 4, 27)
title.Font = Enum.Font.GothamBold
local function button(y, text, fn)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(10, y)
    b.Size = UDim2.new(1, -20, 0, 25)
    b.BackgroundColor3 = Color3.fromRGB(53, 57, 70)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 13
    b.Font = Enum.Font.Gotham
    b.Text = text
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    connect(b.MouseButton1Click, function() fn(b) end)
    return b
end
local function input(y, placeholder, initial, fn)
    local box = Instance.new("TextBox")
    box.Position = UDim2.fromOffset(10, y)
    box.Size = UDim2.new(1, -20, 0, 25)
    box.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.PlaceholderColor3 = Color3.fromRGB(155, 160, 175)
    box.TextSize = 13
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.PlaceholderText = placeholder
    box.Text = initial or ""
    box.Parent = panel
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    connect(box.FocusLost, function() fn(box) end)
    return box
end
button(34, "ESP: ON", function(b) state.enabled = not state.enabled b.Text = "ESP: " .. (state.enabled and "ON" or "OFF") end)
input(64, "Rock filter (empty = all)", "", function(b) state.rockFilter = b.Text:lower() end)
input(94, "Ore filter (empty = all)", "", function(b) state.oreFilter = b.Text:lower() end)
input(124, "Max distance (studs)", tostring(state.maxDistance), function(b)
    local n = tonumber(b.Text)
    if n and n == n then state.maxDistance = math.clamp(n, 1, 5000) end
    b.Text = tostring(state.maxDistance)
end)
local function toggle(y, key, name)
    button(y, name .. ": ON", function(b) state[key] = not state[key] b.Text = name .. ": " .. (state[key] and "ON" or "OFF") end)
end
toggle(154, "showName", "Rock name")
toggle(184, "showRarity", "Rarity")
toggle(214, "showDistance", "Distance")
local counter = label("Visible: 0", 244, 23)
button(275, "UNLOAD", function() shutdown:Fire() end)
local dragging, dragStart, startPos = false, nil, nil
connect(title.InputBegan, function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = inputObject.Position startPos = panel.Position
    end
end)
connect(UserInputService.InputChanged, function(inputObject)
    if dragging and (inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject.UserInputType == Enum.UserInputType.Touch) then
        local d = inputObject.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
connect(UserInputService.InputEnded, function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
local colors = {common = Color3.fromRGB(200,200,200), uncommon = Color3.fromRGB(100,220,120),
    rare = Color3.fromRGB(80,160,255), epic = Color3.fromRGB(190,100,255),
    legendary = Color3.fromRGB(255,190,65), mythic = Color3.fromRGB(255,85,110),
    divine = Color3.fromRGB(255,235,130)}
local function partOf(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
end
local function isCandidate(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    local root = workspace:FindFirstChild(Config.RootName)
    -- Direct children of Rocks only, so nested decorative parts do not become duplicates.
    if root and obj.Parent == root then return true end
    for _, tag in ipairs(Config.RockTags) do if CollectionService:HasTag(obj, tag) then return true end end
    if root then return false end
    local name = obj.Name:lower()
    for _, word in ipairs(Config.RockNames) do if name:find(word, 1, true) then return true end end
    return false
end
local function remove(obj)
    local entry = cache[obj]
    if not entry then return end
    if entry.highlight then entry.highlight:Destroy() end
    if entry.billboard then entry.billboard:Destroy() end
    cache[obj] = nil
end
local function add(obj)
    if cache[obj] or not obj:IsDescendantOf(workspace) or not isCandidate(obj) then return end
    -- Avoid duplicate nested matches in the generic fallback.
    local ancestor = obj.Parent
    while ancestor and ancestor ~= workspace do
        if cache[ancestor] then return end
        ancestor = ancestor.Parent
    end
    cache[obj] = {}
end
local function metadata(obj, names)
    -- Read only explicitly named attributes or StringValue children; never infer from colour/name.
    for _, name in ipairs(names) do
        local value = obj:GetAttribute(name)
        if type(value) == "string" and value:match("%S") then return value end
        local child = obj:FindFirstChild(name)
        if child and child:IsA("StringValue") and child.Value:match("%S") then return child.Value end
    end
    return nil
end
local function visuals(obj, entry, part)
    if entry.part == part and entry.highlight and entry.billboard then return end
    if entry.highlight then entry.highlight:Destroy() end
    if entry.billboard then entry.billboard:Destroy() end
    local h = Instance.new("Highlight")
    h.Name = "OreESPHighlight"
    h.Adornee = obj
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0.1
    h.Parent = gui
    local bill = Instance.new("BillboardGui")
    bill.Name = "OreESPLabel"
    bill.Adornee = part
    bill.Size = UDim2.fromOffset(210, 75)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bill.AlwaysOnTop = true
    bill.Parent = gui
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextStrokeTransparency = 0.2
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.Parent = bill
    entry.part, entry.highlight, entry.billboard, entry.text = part, h, bill, text
end
local function update()
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local visible = 0
    for obj, entry in pairs(cache) do
        if not obj:IsDescendantOf(workspace) or not isCandidate(obj) then
            remove(obj)
        else
            local part = partOf(obj)
            local ore = metadata(obj, Config.OreAttributes)
            local rarity = metadata(obj, Config.RarityAttributes)
            local distance = hrp and part and (hrp.Position - part.Position).Magnitude or math.huge
            local matchRock = obj.Name:lower():find(state.rockFilter, 1, true) ~= nil
            local matchOre = state.oreFilter == "" or (ore and ore:lower():find(state.oreFilter, 1, true) ~= nil)
            local show = state.enabled and part and distance <= state.maxDistance and matchRock and matchOre
            if show then
                visuals(obj, entry, part)
                local color = rarity and colors[rarity:lower()] or Color3.fromRGB(180, 180, 180)
                entry.highlight.FillColor = color entry.highlight.OutlineColor = color
                local lines = {}
                if state.showName then table.insert(lines, obj.Name) end
                table.insert(lines, "Ore: " .. (ore or "UNKNOWN"))
                if state.showRarity then table.insert(lines, "Rarity: " .. (rarity or "UNKNOWN")) end
                if state.showDistance then table.insert(lines, string.format("%.0f studs", distance)) end
                entry.text.Text = table.concat(lines, "\n")
                entry.highlight.Enabled = true entry.billboard.Enabled = true
                visible = visible + 1
            elseif entry.highlight then
                entry.highlight.Enabled = false entry.billboard.Enabled = false
            end
        end
    end
    counter.Text = "Visible: " .. visible
end
connect(workspace.DescendantAdded, function(obj) add(obj) end)
connect(workspace.DescendantRemoving, function(obj) remove(obj) end)
for _, tag in ipairs(Config.RockTags) do
    connect(CollectionService:GetInstanceAddedSignal(tag), add)
end
-- Initial discovery once; later additions arrive through events, not full per-frame scans.
for _, obj in ipairs(workspace:GetDescendants()) do add(obj) end
local function unload()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for obj in pairs(cache) do remove(obj) end
    gui:Destroy()
end
connect(shutdown.Event, unload)
task.spawn(function()
    while alive do
        local ok, err = pcall(update)
        if not ok then warn("Ore ESP update: " .. tostring(err)) end
        task.wait(math.max(0.25, tonumber(Config.ScanInterval) or 2))
    end
end)
