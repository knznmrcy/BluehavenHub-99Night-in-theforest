-- ==========================================
-- BlueHavenHub by Kntzy | v5.32 (Obsidian)
-- ==========================================

local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheWildLama/Obsidian/main/source.lua"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local ItemsFolder = Workspace:FindFirstChild("Items") or Workspace:WaitForChild("Items")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") or ReplicatedStorage:WaitForChild("RemoteEvents")
local RemoteConsume = ReplicatedStorage:FindFirstChild("RequestConsumeItem")
local TreesFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Foliage")

local ScriptRunning = true
local CAMPFIRE_POS = Vector3.new(0, 19, 0)
local MACHINE_POS = Vector3.new(21, 16, -5)

-- ==========================================
-- DISCORD LINK
-- ==========================================
local DISCORD_LINK = "https://discord.gg/Vzbs245EC"

-- ==========================================
-- OBSIDIAN UI SETUP
-- ==========================================
local Window = Obsidian:New({
    Name = "BlueHavenHub v5.32",
    Folder = "BlueHaven_Config",
    Icon = "rbxassetid://4483345998",
    Theme = "Dark",
    IntroEnabled = true,
    IntroText = "BlueHavenHub",
    IntroIcon = "rbxassetid://4483345998",
})

-- ==========================================
-- FUNGSI UNTUK LOST CHILD (1-4)
-- ==========================================
local function getLostChildPart(index)
    local path = string.format("Map.Landmarks.Jail Cellar%d.Dino", index)
    local success, result = pcall(function()
        local parts = {}
        for part in string.gmatch(path, "[^%.]+") do
            table.insert(parts, part)
        end
        local current = workspace
        for _, name in ipairs(parts) do
            current = current:FindFirstChild(name)
            if not current then return nil end
        end
        return current
    end)
    if success and result then
        return findValidPart(result)
    end
    return nil
end

-- ==========================================
-- CORE FUNCTIONS
-- ==========================================
local function getRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findValidPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("BasePart") or child:IsA("MeshPart") then return child end
    end
    return nil
end

local function getItemPosition(item)
    if not item or not item:IsDescendantOf(workspace) then return nil end
    if item:IsA("Model") then
        return item:GetPivot().Position
    elseif item:IsA("BasePart") or item:IsA("MeshPart") then
        return item.Position
    else
        local part = findValidPart(item)
        return part and part.Position or nil
    end
end

local function resetVelocity(item)
    pcall(function()
        if item:IsA("BasePart") or item:IsA("MeshPart") then
            item.AssemblyLinearVelocity = Vector3.zero
            item.AssemblyAngularVelocity = Vector3.zero
        elseif item:IsA("Model") then
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("MeshPart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end)
end

local function setItemCFrame(item, pos)
    pcall(function()
        if item:IsA("BasePart") or item:IsA("MeshPart") then
            item.CFrame = CFrame.new(pos)
        elseif item:IsA("Model") then
            item:PivotTo(CFrame.new(pos))
        end
    end)
end

local function reliableDragItemToPos(item, pos)
    if not item or not item:IsDescendantOf(workspace) then return false end
    local success = false
    pcall(function()
        local dragStart = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
        local dragStop = RemoteEvents:FindFirstChild("StopDraggingItem")
        
        if dragStart then dragStart:FireServer(item) end
        task.wait(0.1) 
        
        if not item:IsDescendantOf(workspace) then return end
        resetVelocity(item)
        setItemCFrame(item, pos)
        
        task.wait(0.1) 
        
        if not item:IsDescendantOf(workspace) then return end
        resetVelocity(item)
        if dragStop then dragStop:FireServer(item) end
        
        success = true
    end)
    return success
end

local function teleportPlayerTo(pos)
    local hrp = getRootPart()
    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        end)
    end
end

-- ==========================================
-- TREE AURA UTILITY
-- ==========================================
local TreeUtility = {
    ToolDamageObject = RemoteEvents.ToolDamageObject,
    EnemyHandler = require(game.Players.LocalPlayer.PlayerScripts.Client.EnemyHandler)
}

TreeUtility.HoldingAxe = function()
    local success, result = pcall(function()
        for _, model in ipairs(game.Players.LocalPlayer.Character:GetChildren()) do
            if model:IsA("Model") then
                if model:GetAttribute("ToolName") and model:GetAttribute("ToolName"):find("Axe") then
                    return model:FindFirstChild("OriginalItem").Value
                end
            end
        end
    end)

    if success then
        return result
    end

    return nil
end

TreeUtility.CanChop = function(self, tree)
    local success, result = pcall(function()
        if tostring(tree):find("Big") then
            for _, tool in pairs(game:GetService("Players").LocalPlayer.Inventory:GetChildren()) do
                if tool:GetAttribute("ToolName") and tool:GetAttribute("ToolName"):find("Chainsaw") then
                    return true
                end
            end
        else
            return true
        end
    end)

    if success then
        return result
    end

    return false
end

TreeUtility.GetTreesInRadius = function(self, radius)
    local success, result = pcall(function()
        local treesInRadius = {}
        local hrp = getRootPart()
        if not hrp then return treesInRadius end

        local folder = TreesFolder or Workspace:FindFirstChild("Foliage") or Workspace:FindFirstChild("Trees")
        if not folder then return treesInRadius end

        for _, tree in ipairs(folder:GetChildren()) do
            if tree:IsA("Model") and tree:FindFirstChild("Trunk") and self:CanChop(tree) then
                local Trunk = tree:FindFirstChild("Trunk")
                local distance = (Trunk.Position - hrp.Position).Magnitude
                local health = tree:GetAttribute("Health") or 10
                if distance < radius and health > 0 then
                    table.insert(treesInRadius, {Tree=tree, Trunk=Trunk, Distance=distance})
                end
            end
        end

        table.sort(treesInRadius, function(a, b) return a.Distance < b.Distance end)
        return treesInRadius
    end)

    if success then return result end
    return {}
end

TreeUtility.ChopTree = function(self, tree, trunk)
    local _, result = pcall(function()
        if not tree or not trunk then return "invalid tree" end

        local myroot = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myroot then return "failed to get rootpart" end

        local axe = self.HoldingAxe()
        if not axe then return "failed to get axe" end

        return {tree.Name, self.ToolDamageObject:InvokeServer(
            tree,
            axe,
            self.EnemyHandler.GetHitRegId(),
            myroot.CFrame,
            true
        )}
    end)

    return result
end

-- ==========================================
-- TREE ESP
-- ==========================================
local treeESPEnabled = false
local treeESPList = {}
local espFolderTree = Instance.new("Folder")
espFolderTree.Name = "TreeESP"
espFolderTree.Parent = CoreGui

local function getTreePart(tree)
    local trunk = tree:FindFirstChild("Trunk")
    if trunk and trunk:IsA("BasePart") then return trunk end
    if tree.PrimaryPart then return tree.PrimaryPart end
    for _, child in ipairs(tree:GetDescendants()) do
        if child:IsA("BasePart") or child:IsA("MeshPart") then
            return child
        end
    end
    return nil
end

local function createTreeESP(tree)
    if treeESPList[tree] then return end
    local part = getTreePart(tree)
    if not part then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "TreeESP"
    bb.Size = UDim2.fromScale(4, 1)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolderTree
    bb.Adornee = part

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.TextStrokeTransparency = 0
    text.TextColor3 = Color3.fromRGB(0, 255, 0)
    text.Parent = bb

    treeESPList[tree] = { gui = bb, label = text, part = part }
end

local function updateTreeESP(tree)
    local esp = treeESPList[tree]
    if not esp then return end
    local hp = tree:GetAttribute("Health")
    if not hp or hp <= 0 then
        esp.gui:Destroy()
        treeESPList[tree] = nil
        return
    end
    esp.label.Text = ("HP: %d"):format(hp)
    if hp > 5 then
        esp.label.TextColor3 = Color3.fromRGB(0, 255, 0)
    elseif hp > 2 then
        esp.label.TextColor3 = Color3.fromRGB(255, 170, 0)
    else
        esp.label.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end

local function refreshTreeESP()
    for _, esp in pairs(treeESPList) do
        pcall(function() esp.gui:Destroy() end)
    end
    treeESPList = {}
    if treeESPEnabled and TreesFolder then
        for _, tree in ipairs(TreesFolder:GetChildren()) do
            if tree.Name == "Small Tree" then
                createTreeESP(tree)
                updateTreeESP(tree)
            end
        end
    end
end

-- ==========================================
-- MAIN TAB
-- ==========================================
local MainTab = Window:Tab("Main", "rbxassetid://4483345998")

MainTab:Paragraph("Auto Farm", "Otomatisasi Makanan & Grind")

local autoEatEnabled = false
local autoCookEnabled = false
local autoEatFoods = {"Cooked Steak", "Cooked Morsel", "Berry", "Carrot", "Apple"}
local rawFoodsToCook = {"Morsel", "Steak"}
local maxGrindRadius = 1000 

MainTab:Toggle("Auto Eat", "Makan otomatis saat HP < 70%", function(state) autoEatEnabled = state end)
MainTab:Toggle("Auto Cook", "Masak makanan mentah di Campfire", function(state) autoCookEnabled = state end)

MainTab:Divider()

MainTab:Paragraph("Grind & Fuel", "")

MainTab:Slider("Max Grab Radius", "Batas jarak ambil item", 0, 2000, 1000, function(value) maxGrindRadius = value end)

local autoGrindItems = {}
MainTab:Dropdown("Auto Grind", "Pilih item untuk mesin", 
    {"UFO Junk", "UFO Component", "Old Car Engine", "Broken Fan", "Old Microwave", "Bolt", "Log", "Cultist Gem", "Sheet Metal", "Old Radio", "Tyre", "Washing Machine", "Gem of the Forest Fragment", "Broken Microwave"},
    function(selected)
        autoGrindItems = {}
        if selected then autoGrindItems[selected] = true end
    end
)

local autoFuelItems = {}
MainTab:Dropdown("Auto Fuel", "Pilih bahan bakar Campfire",
    {"Log", "Coal", "Fuel Canister", "Oil Barrel", "Biofuel"},
    function(selected)
        autoFuelItems = {}
        if selected then autoFuelItems[selected] = true end
    end
)

-- ==========================================
-- TELEPORTS TAB
-- ==========================================
local TeleportsTab = Window:Tab("Teleports", "rbxassetid://4483345998")

TeleportsTab:Paragraph("Locations", "Teleportasi Karakter")

TeleportsTab:Button("TP to Campfire", "Kembali ke area perapian", function() teleportPlayerTo(CAMPFIRE_POS) end)

for i = 1, 4 do
    TeleportsTab:Button("TP to Lost Child " .. i, "Teleport ke Jail Cellar " .. i, function()
        local part = getLostChildPart(i)
        if part then
            teleportPlayerTo(part.Position)
            Window:Notify({
                Title = "Teleport",
                Description = "Lost Child "..i.." Berhasil!",
                Time = 2
            })
        else
            Window:Notify({
                Title = "Error",
                Description = "Lost Child "..i.." tidak ditemukan!",
                Time = 2
            })
        end
    end)
end

-- ==========================================
-- AURA TAB (KILL AURA)
-- ==========================================
local CombatTab = Window:Tab("Aura", "rbxassetid://4483345998")

CombatTab:Paragraph("Combat", "Kill Aura (Damage Spoofing)")

local killAuraEnabled = false
local auraRadius = 350 
local toolPriority = {"Chainsaw", "Strong Axe", "Good Axe", "Spear", "Old Axe"}
local toolIds = { ["Chainsaw"]="647", ["Strong Axe"]="116", ["Good Axe"]="112", ["Spear"]="196", ["Old Axe"]="1" }

local function getBestSpoofTool()
    local locations = {LocalPlayer.Inventory, LocalPlayer.Backpack, LocalPlayer.Character}
    for _, toolName in ipairs(toolPriority) do
        for _, loc in ipairs(locations) do
            if loc then
                local tool = loc:FindFirstChild(toolName)
                if tool then return tool, toolIds[toolName] .. "_" .. tostring(LocalPlayer.UserId) end
            end
        end
    end
    return nil, nil
end

CombatTab:Toggle("Kill Aura", "Serang mobs di sekitar", function(state) killAuraEnabled = state end)
CombatTab:Slider("Radius", "Jangkauan serangan", 0, 500, 350, function(value) auraRadius = value end)

-- ==========================================
-- TREE AURA TAB
-- ==========================================
local TreeTab = Window:Tab("Tree Aura", "rbxassetid://4483345998")

TreeTab:Paragraph("Tree Aura", "Nebang pohon di sekitar")

local treeAuraEnabled = false
local treeAuraRadius = 80

TreeTab:Toggle("Tree Aura", "Aktifkan / Nonaktifkan", function(state)
    treeAuraEnabled = state
    if state then
        Window:Notify({
            Title = "Tree Aura",
            Description = "ON! Radius: " .. treeAuraRadius,
            Time = 2
        })
    else
        Window:Notify({
            Title = "Tree Aura",
            Description = "OFF!",
            Time = 2
        })
    end
end)

TreeTab:Slider("Radius", "Jarak tebang pohon", 0, 200, 80, function(value) treeAuraRadius = value end)

TreeTab:Button("Test Chop All", "Tebang SEMUA pohon dalam radius (1x)", function()
    local trees = TreeUtility:GetTreesInRadius(treeAuraRadius)
    if #trees == 0 then
        Window:Notify({
            Title = "Info",
            Description = "Tidak ada pohon dalam radius!",
            Time = 2
        })
        return
    end

    local chopped = 0
    for _, info in ipairs(trees) do
        local result = TreeUtility:ChopTree(info.Tree, info.Trunk)
        if typeof(result) == "table" and #result == 2 then
            chopped = chopped + 1
        end
        task.wait(0.05)
    end

    Window:Notify({
        Title = "Chop All",
        Description = "Menebang " .. chopped .. " pohon!",
        Time = 2
    })
end)

-- ==========================================
-- ITEM TP TAB
-- ==========================================
local ItemTPTab = Window:Tab("Item TP", "rbxassetid://4483345998")

ItemTPTab:Paragraph("Item TP", "Tarik item ke karakter dengan stabil")

local itemCategories = {
    Food_Consumables = {"Berry", "Carrot", "Cake", "Apple", "Steak", "Morsel", "Cooked Steak", "Cooked Morsel", "Pumpkin", "Ribs"},
    Equipment_Weapons = {"Pistol", "Revolver", "Rifle", "Chainsaw", "Old Flashlight", "Rifle Ammo", "Revolver Ammo", "Spear"},
    Medic_Items = {"MedKit", "Bandage"},
    Armor_Clothing = {"Iron Body", "Leather Body"},
    Fuel_Items = {"Log", "Coal", "Fuel Canister", "Oil Barrel", "Biofuel", "Chair", "Metal Chair"},
    Junk_Materials = {"UFO Junk", "UFO Component", "Old Car Engine", "Broken Fan", "Old Microwave", "Bolt", "Sheet Metal", "Old Radio", "Tyre", "Washing Machine", "Broken Microwave", "Mossy Coin"}
}

local selectedItems = {}

for catName, listItems in pairs(itemCategories) do
    selectedItems[catName] = listItems[1]
    ItemTPTab:Dropdown(catName:gsub("_", " "), "Pilih item", listItems, function(value) selectedItems[catName] = value end)
    ItemTPTab:Button("Bring " .. catName:gsub("_", " "), "Tarik semua item", function()
        local hrp = getRootPart()
        if not hrp then return end
        local selected = selectedItems[catName]
        local toProcess = {}
        for _, item in ipairs(ItemsFolder:GetDescendants()) do
            if item.Name == selected and (item:IsA("Model") or item:IsA("Tool") or item:IsA("BasePart")) then
                local pos = getItemPosition(item)
                if pos then
                    table.insert(toProcess, {item = item, dist = (pos - hrp.Position).Magnitude})
                end
            end
        end
        table.sort(toProcess, function(a, b) return a.dist < b.dist end)
        local basePos = hrp.Position + Vector3.new(0, 2, 0)
        for i, data in ipairs(toProcess) do
            local tpPos = basePos + Vector3.new((i-1) % 3 * 1.5, math.floor((i-1) / 3) * 1.5, 0)
            task.spawn(function() reliableDragItemToPos(data.item, tpPos) end)
        end
        Window:Notify({
            Title = "Item TP",
            Description = "Tarik "..#toProcess.."x "..selected,
            Time = 2
        })
    end)
end

-- ==========================================
-- MISC TAB
-- ==========================================
local MiscTab = Window:Tab("Misc", "rbxassetid://4483345998")

MiscTab:Paragraph("Miscellaneous", "Fitur Tambahan & Optimasi")

local fullbrightConn = nil
MiscTab:Toggle("Fullbright", "Membuat seluruh map menjadi terang benderang", function(state)
    if state then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        fullbrightConn = RunService.RenderStepped:Connect(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
        end)
    else
        if fullbrightConn then
            fullbrightConn:Disconnect()
            fullbrightConn = nil
        end
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = true
    end
end)

MiscTab:Button("Reduce Map (Potato Mode)", "Hapus tekstur, part kecil & efek berat untuk boost FPS", function()
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                if obj.Size.Magnitude < 1.5 and not obj.Anchored and not obj:IsDescendantOf(LocalPlayer.Character) then
                    obj:Destroy()
                end
            elseif obj:IsA("Texture") or obj:IsA("Decal") then
                obj:Destroy()
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj:Destroy()
            elseif obj:IsA("PostEffect") then
                obj.Enabled = false
            end
        end
        
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") or effect:IsA("Sky") then
                effect:Destroy()
            end
        end
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        
        Window:Notify({
            Title = "Success",
            Description = "Potato Mode Activated! FPS meningkat drastis.",
            Time = 3
        })
    end)
end)

MiscTab:Divider()
MiscTab:Paragraph("Social", "Join komunitas kami!")
MiscTab:Button("Join Discord", "Klik untuk bergabung ke Discord server", function()
    pcall(function()
        setclipboard(DISCORD_LINK)
        Window:Notify({
            Title = "Discord",
            Description = "Link Discord disalin! " .. DISCORD_LINK,
            Time = 3
        })
    end)
end)

-- ==========================================
-- AUTO NIGHT & DAY NOTIFICATION
-- ==========================================
local wasNight = nil
local function checkTime()
    local currentTime = Lighting.ClockTime
    local isNight = (currentTime >= 18 or currentTime < 6)
    if wasNight == nil then
        wasNight = isNight
        return
    end
    if isNight and not wasNight then
        Window:Notify({
            Title = "🌙 Night Time",
            Description = "Hati-hati dengan mob! Jam: " .. string.format("%.1f", currentTime),
            Time = 4
        })
    elseif not isNight and wasNight then
        Window:Notify({
            Title = "☀️ Day Time",
            Description = "Jam: " .. string.format("%.1f", currentTime),
            Time = 4
        })
    end
    wasNight = isNight
end

checkTime()
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(checkTime)

-- ==========================================
-- FPS & PING COUNTER
-- ==========================================
local fpsPingGui = Instance.new("ScreenGui")
fpsPingGui.Name = "BlueHaven_FPS_Ping"
fpsPingGui.ResetOnSpawn = false
fpsPingGui.Parent = CoreGui
fpsPingGui.Enabled = false

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 150, 0, 30)
fpsLabel.Position = UDim2.new(0, 10, 0, 120)
fpsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
fpsLabel.BackgroundTransparency = 0.4
fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 128)
fpsLabel.TextSize = 14
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.Text = "FPS: 0 | Ping: 0ms"
fpsLabel.Parent = fpsPingGui
Instance.new("UICorner", fpsLabel).CornerRadius = UDim.new(0, 6)

local lastFpsTime = workspace.DistributedGameTime
local frameCount = 0
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = workspace.DistributedGameTime
    if now - lastFpsTime >= 1 then
        local fps = math.round(frameCount / (now - lastFpsTime))
        local ping = 0
        pcall(function() ping = math.round(LocalPlayer:GetNetworkPing() * 1000) end)
        fpsLabel.Text = string.format("FPS: %d | Ping: %dms", fps, ping)
        frameCount = 0
        lastFpsTime = now
    end
end)

MiscTab:Toggle("FPS & Ping Counter", "Tampilkan indikator FPS & Ping di layar", function(state)
    fpsPingGui.Enabled = state
end)

-- ==========================================
-- VISUALS TAB (ESP Mobs & Items + Tree ESP)
-- ==========================================
local VisualsTab = Window:Tab("Visuals", "rbxassetid://4483345998")

VisualsTab:Paragraph("ESP", "Deteksi lokasi visual")

local espMobsEnabled, espItemsEnabled = false, false
local espFolder = Instance.new("Folder")
espFolder.Name = "BlueHaven_ESP"
espFolder.Parent = CoreGui

local function createESP(instance, name, color)
    local part = findValidPart(instance)
    if not part then return end
    local hl = Instance.new("Highlight", espFolder)
    hl.Adornee, hl.FillColor, hl.OutlineColor = instance, color, Color3.new(1,1,1)
    hl.FillTransparency, hl.OutlineTransparency = 0.6, 0
    local bg = Instance.new("BillboardGui", espFolder)
    bg.Adornee, bg.Size, bg.AlwaysOnTop, bg.StudsOffset = part, UDim2.new(0, 120, 0, 25), true, Vector3.new(0, 3, 0)
    local txt = Instance.new("TextLabel", bg)
    txt.Size, txt.BackgroundTransparency, txt.TextColor3, txt.TextStrokeTransparency, txt.Font, txt.TextScaled = UDim2.new(1,0,1,0), 1, color, 0.2, Enum.Font.GothamBold, true
    task.spawn(function()
        while bg.Parent and instance.Parent do
            local hrp = getRootPart()
            if hrp then txt.Text = string.format("%s [%dm]", name, math.floor((part.Position - hrp.Position).Magnitude)) end
            task.wait(0.5)
        end
        hl:Destroy() bg:Destroy()
    end)
end

local function refreshESP()
    espFolder:ClearAllChildren()
    if espMobsEnabled then
        local chars = Workspace:FindFirstChild("Characters")
        if chars then for _, mob in ipairs(chars:GetChildren()) do createESP(mob, mob.Name, Color3.fromRGB(255,50,50)) end end
    end
    if espItemsEnabled then
        for _, item in ipairs(ItemsFolder:GetChildren()) do createESP(item, item.Name, Color3.fromRGB(50,255,50)) end
    end
end

VisualsTab:Toggle("ESP Mobs", "Tampilkan lokasi mobs", function(state) espMobsEnabled = state; refreshESP() end)
VisualsTab:Toggle("ESP Items", "Tampilkan lokasi items", function(state) espItemsEnabled = state; refreshESP() end)
VisualsTab:Toggle("ESP Trees", "Tampilkan HP pohon", function(state)
    treeESPEnabled = state
    if state then
        refreshTreeESP()
    else
        for _, esp in pairs(treeESPList) do
            pcall(function() esp.gui:Destroy() end)
        end
        treeESPList = {}
    end
end)

-- ==========================================
-- PLAYER TAB
-- ==========================================
local PlayerTab = Window:Tab("Player", "rbxassetid://4483345998")

PlayerTab:Paragraph("Stats", "Modifikasi Karakter")

PlayerTab:Slider("WalkSpeed", "Kecepatan berjalan", 0, 200, 16, function(value)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = value end
end)

local infiniteJumpEnabled = false
PlayerTab:Toggle("Infinite Jump", "Lompat tanpa batas di udara", function(state) infiniteJumpEnabled = state end)

UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

-- ==========================================
-- KILL AURA BACKGROUND LOOP
-- ==========================================
task.spawn(function()
    while ScriptRunning do
        if killAuraEnabled then
            local hrp = getRootPart()
            local tool, damageID = getBestSpoofTool()
            if hrp and tool and damageID then
                pcall(function() RemoteEvents.EquipItemHandle:FireServer("FireAllClients", tool) end)
                
                local searchFolders = {Workspace:FindFirstChild("Characters"), Workspace}
                for _, folder in ipairs(searchFolders) do
                    if folder then
                        for _, mob in ipairs(folder:GetChildren()) do
                            local hum = mob:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 and mob ~= LocalPlayer.Character then
                                local mobHrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or findValidPart(mob)
                                if mobHrp then
                                    if (mobHrp.Position - hrp.Position).Magnitude <= auraRadius then
                                        task.spawn(function() 
                                            pcall(function() 
                                                RemoteEvents.ToolDamageObject:InvokeServer(mob, tool, damageID, mobHrp.CFrame) 
                                            end) 
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ==========================================
-- TREE AURA BACKGROUND LOOP
-- ==========================================
task.spawn(function()
    while true do
        if treeAuraEnabled then
            local trees = TreeUtility:GetTreesInRadius(treeAuraRadius)
            for _, info in ipairs(trees) do
                if info.Tree and info.Tree:IsDescendantOf(workspace) then
                    local health = info.Tree:GetAttribute("Health")
                    if health == nil or health > 0 then
                        TreeUtility:ChopTree(info.Tree, info.Trunk)
                        task.wait(0.1)
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- ==========================================
-- AUTO GRIND / COOK / FUEL LOOP
-- ==========================================
local processingItems = {}
task.spawn(function()
    while ScriptRunning do
        local hrp = getRootPart()
        if hrp then
            for _, item in ipairs(ItemsFolder:GetDescendants()) do
                if item and item:IsDescendantOf(workspace) and
                   (item:IsA("Model") or item:IsA("Tool") or item:IsA("BasePart")) then
                    local itemId = tostring(item)
                    if not processingItems[itemId] then
                        local shouldGrind = autoGrindItems[item.Name] == true
                        local shouldFuel = autoFuelItems[item.Name] == true
                        local shouldCook = autoCookEnabled and table.find(rawFoodsToCook, item.Name)
                        if shouldGrind or shouldFuel or shouldCook then
                            local targetPos = shouldGrind and MACHINE_POS or CAMPFIRE_POS
                            local itemPos = getItemPosition(item)
                            if itemPos then
                                local distToPlayer = (itemPos - hrp.Position).Magnitude
                                local distToTarget = (itemPos - targetPos).Magnitude
                                if distToPlayer <= maxGrindRadius and distToTarget >= 12 then
                                    processingItems[itemId] = true
                                    task.spawn(function()
                                        reliableDragItemToPos(item, targetPos)
                                        task.wait(1)
                                        processingItems[itemId] = nil
                                    end)
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- AUTO EAT LOOP
-- ==========================================
local autoEatHPThreshold = 70
MainTab:Slider("Eat HP Threshold", "Makan saat HP di bawah %", 10, 95, 70, function(value)
    autoEatHPThreshold = value
end)

task.spawn(function()
    while ScriptRunning do
        if autoEatEnabled then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.Health < (hum.MaxHealth * (autoEatHPThreshold / 100)) then
                local hrp = getRootPart()
                local bestFood = nil
                local bestDist = math.huge
                for _, item in ipairs(ItemsFolder:GetChildren()) do
                    if table.find(autoEatFoods, item.Name) and item:IsDescendantOf(workspace) then
                        if hrp then
                            local pos = getItemPosition(item)
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude
                                if dist < bestDist then
                                    bestDist = dist
                                    bestFood = item
                                end
                            end
                        else
                            bestFood = item
                            break
                        end
                    end
                end
                if bestFood then
                    if hrp then
                        reliableDragItemToPos(bestFood, hrp.Position + Vector3.new(0, 2, 0))
                        task.wait(0.2)
                    end
                    if RemoteConsume then
                        pcall(function() RemoteConsume:InvokeServer(bestFood) end)
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- ==========================================
-- TREE ESP REFRESH LOOP
-- ==========================================
task.spawn(function()
    while true do
        if treeESPEnabled and TreesFolder then
            for _, tree in ipairs(TreesFolder:GetChildren()) do
                if tree.Name == "Small Tree" then
                    createTreeESP(tree)
                    updateTreeESP(tree)
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- KEYBIND F5 TOGGLE TREE AURA
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        treeAuraEnabled = not treeAuraEnabled
        Window:Notify({
            Title = "Tree Aura",
            Description = treeAuraEnabled and "ON" or "OFF",
            Time = 2
        })
    end
end)

-- ==========================================
-- NOTIFICATION LOADED
-- ==========================================
Window:Notify({
    Title = "BlueHavenHub",
    Description = "v5.32: Kill Aura + Tree Aura + Lost Child 1-4 siap!",
    Time = 5
})

print("✅ BlueHavenHub v5.32 loaded – Kill Aura + Tree Aura + Lost Child 1-4 siap!")
