local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = Workspace.CurrentCamera

local VELOCIDADE_RUN    = 1e95
local DISTANCIA_CHEGADA = 4
local IGNORAR_EIXO_Y    = true
local WALK_TEMP         = 700
local JUMP_TEMP         = 260
local DURACAO_TRAVA     = 0.6
local CLONE_SO_PRA_MIM  = true
local NOME_SMART        = "SmartPromptPart"

local AntiKB    = true
local DEBUG_KB  = false
local THRESHOLD_KB = 15

local Destino = { posicao = nil, usarSpawn = true }

-- MÓDULOS
local EggState, AreasData, RarityData, AssetsData, PetsData
pcall(function() EggState   = require(ReplicatedStorage.Client.EggState) end)
pcall(function() AreasData  = require(ReplicatedStorage.Data.Areas) end)
pcall(function() RarityData = require(ReplicatedStorage.Data.Rarity) end)
pcall(function() AssetsData = require(ReplicatedStorage.Data.Assets) end)
pcall(function() PetsData   = require(ReplicatedStorage.Data.Pets) end)

local RARITY_SCORE_MAP = {
    ["Light & Dark"]    = 1300, ["Titan"]           = 1100,
    ["Divine"]          = 1000, ["Transcendent"]    = 1000,
    ["Superior"]        = 1000, ["Eternal"]         = 900,
    ["Limited"]         = 900,  ["Secret"]          = 800,
    ["Exotic"]          = 800,  ["Cosmic"]          = 700,
    ["Exclusive"]       = 700,  ["Admin"]           = 700,
    ["Mythic"]          = 600,  ["Mythical"]        = 600,
    ["Prismatic"]       = 600,  ["Rainbow"]         = 600,
    ["Squishy God"]     = 600,  ["BrainrotGod"]     = 600,
    ["Legendary"]       = 500,  ["Epic"]            = 400,
    ["Rare"]            = 300,  ["SuperRare"]       = 200,
    ["Celestial"]       = 200,  ["Uncommon"]        = 200,
    ["Basic"]           = 100,  ["Common"]          = 100,
}

-- TELEPORTE
local Teleporte = {
    conn = nil, ativo = false, char = nil, hum = nil, root = nil,
    walkOrig = nil, jumpOrig = nil,
}

function Teleporte.refs()
    Teleporte.char = LocalPlayer.Character
    if not Teleporte.char then return false end
    Teleporte.hum  = Teleporte.char:FindFirstChildOfClass("Humanoid")
    Teleporte.root = Teleporte.char:FindFirstChild("HumanoidRootPart")
    return Teleporte.hum ~= nil and Teleporte.root ~= nil
end

function Teleporte.pegarSpawn()
    local lista = {}
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("SpawnLocation") then table.insert(lista, o) end
    end
    if #lista == 0 then return nil end
    if not Teleporte.root then return lista[1] end
    local melhor, dMin = nil, math.huge
    for _, sp in ipairs(lista) do
        local d = (sp.Position - Teleporte.root.Position).Magnitude
        if d < dMin then melhor, dMin = sp, d end
    end
    return melhor
end

function Teleporte.pegarAlvo()
    if Destino.usarSpawn then
        local spawn = Teleporte.pegarSpawn()
        if not spawn then return nil end
        return spawn.Position + Vector3.new(0, 3, 0)
    end
    if not Destino.posicao then return nil end
    return Destino.posicao + Vector3.new(0, 3, 0)
end

function Teleporte.parar()
    if Teleporte.conn then
        Teleporte.conn:Disconnect()
        Teleporte.conn = nil
    end
    if Teleporte.hum then
        if Teleporte.walkOrig then Teleporte.hum.WalkSpeed = Teleporte.walkOrig end
        if Teleporte.jumpOrig then Teleporte.hum.JumpPower = Teleporte.jumpOrig end
    end
    Teleporte.walkOrig = nil
    Teleporte.jumpOrig = nil
    Teleporte.ativo    = false
end

function Teleporte.iniciar()
    if Teleporte.ativo then Teleporte.parar() return end
    if not Teleporte.refs() then return end
    local alvo = Teleporte.pegarAlvo()
    if not alvo then return end
    Teleporte.walkOrig = Teleporte.hum.WalkSpeed
    Teleporte.jumpOrig = Teleporte.hum.JumpPower
    Teleporte.hum.WalkSpeed = WALK_TEMP
    Teleporte.hum.JumpPower = JUMP_TEMP
    Teleporte.ativo = true

    Teleporte.conn = RunService.Heartbeat:Connect(function(dt)
        if not Teleporte.ativo then return end
        if not Teleporte.refs() then Teleporte.parar() return end
        local origem = Teleporte.root.Position
        local delta  = alvo - origem
        if IGNORAR_EIXO_Y then delta = Vector3.new(delta.X, 0, delta.Z) end
        local dist = delta.Magnitude
        if dist <= DISTANCIA_CHEGADA then
            Teleporte.root.CFrame = CFrame.new(alvo)
                * (Teleporte.root.CFrame - Teleporte.root.CFrame.Position)
            Teleporte.root.AssemblyLinearVelocity  = Vector3.zero
            Teleporte.root.AssemblyAngularVelocity = Vector3.zero
            Teleporte.parar()
            return
        end
        local direcao = (dist > 0) and delta.Unit or Teleporte.root.CFrame.LookVector
        local passo   = math.min(VELOCIDADE_RUN * dt, dist)
        local novaPos = origem + direcao * passo
        Teleporte.root.CFrame = CFrame.lookAt(novaPos, novaPos + direcao)
        Teleporte.root.AssemblyLinearVelocity  = Vector3.zero
        Teleporte.root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- DISFARCE
local Disfarce = { ativo = false, clone = nil, connCam = nil, thread = nil }

function Disfarce.limpar()
    Disfarce.ativo = false
    if Disfarce.connCam then Disfarce.connCam:Disconnect() Disfarce.connCam = nil end
    local t = Disfarce.thread
    Disfarce.thread = nil
    if t then pcall(task.cancel, t) end
    if Disfarce.clone then Disfarce.clone:Destroy() Disfarce.clone = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

function Disfarce.iniciar()
    if Disfarce.ativo then Disfarce.limpar() return end
    local char = LocalPlayer.Character
    if not char then return end
    if not char:FindFirstChild("HumanoidRootPart") then return end
    Disfarce.ativo = true
    local cframeSalvo = Camera.CFrame
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = cframeSalvo

    Disfarce.connCam = RunService.RenderStepped:Connect(function()
        if Disfarce.ativo then Camera.CFrame = cframeSalvo end
    end)

    if CLONE_SO_PRA_MIM and char.Parent then
        local eraArch = char.Archivable
        char.Archivable = true
        local ok, resultado = pcall(function() return char:Clone() end)
        if ok and resultado then
            resultado.Name = "CloneLocal_" .. LocalPlayer.Name
            for _, d in ipairs(resultado:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
            end
            local h = resultado:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 0
                h.JumpPower = 0
                h.PlatformStand = true
                h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            end
            for _, p in ipairs(resultado:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Anchored = true
                    p.CanCollide = false
                    p.CanTouch = false
                    p.CanQuery = false
                end
            end
            resultado.Parent = Workspace
            Disfarce.clone = resultado
        end
        char.Archivable = eraArch
    end

    Disfarce.thread = task.delay(DURACAO_TRAVA, function()
        Disfarce.thread = nil
        Disfarce.limpar()
    end)
end

-- ANTI-TRAP
local AntiTrap = { ativo = false, thread = nil }

local function neutralizarHitboxes()
    local transient = Workspace:FindFirstChild("Transient")
    if not transient then return end
    for _, obj in ipairs(transient:GetDescendants()) do
        if obj.Name == "Hitbox" and obj:IsA("BasePart") then
            if obj.CanTouch or obj.CanCollide then
                pcall(function()
                    obj.CanTouch = false
                    obj.CanCollide = false
                end)
            end
        end
    end
end

function AntiTrap.iniciar()
    if AntiTrap.ativo then return end
    AntiTrap.ativo = true
    neutralizarHitboxes()
    AntiTrap.thread = task.spawn(function()
        while AntiTrap.ativo do
            neutralizarHitboxes()
            task.wait(0.1)
        end
    end)
end

function AntiTrap.parar()
    AntiTrap.ativo = false
    if AntiTrap.thread then
        pcall(task.cancel, AntiTrap.thread)
        AntiTrap.thread = nil
    end
end

function AntiTrap.toggle()
    if AntiTrap.ativo then AntiTrap.parar() else AntiTrap.iniciar() end
end

-- ANTI-KNOCKBACK
local ultimaPosKB = nil

local function estaEmKB(hum)
    local temRagdoll = false
    pcall(function()
        local rd = tonumber(LocalPlayer:GetAttribute("RagdollEndTime"))
        if rd and rd > Workspace:GetServerTimeNow() then temRagdoll = true end
    end)
    if temRagdoll then return true end
    local s
    pcall(function() s = hum:GetState() end)
    if s == Enum.HumanoidStateType.Physics
    or s == Enum.HumanoidStateType.Ragdoll
    or s == Enum.HumanoidStateType.FallingDown then
        return true
    end
    if hum.PlatformStand then return true end
    return false
end

local function DebugKB(estado, diff, restaurou)
    if not DEBUG_KB then return end
    print(string.format("[Anti-KB] estado=%s | diff=%.1f | restaurou=%s",
        tostring(estado), diff or 0, tostring(restaurou)))
end

RunService.Heartbeat:Connect(function()
    if not AntiKB then return end
    local char, hum, hrp
    pcall(function()
        char = LocalPlayer.Character
        if char then
            hum = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        end
    end)
    if not char or not hum or not hrp then return end
    if hum.Health <= 0 then ultimaPosKB = nil return end
    if estaEmKB(hum) then return end
    pcall(function() ultimaPosKB = hrp.Position end)
end)

task.spawn(function()
    while true do
        if not AntiKB then
            task.wait(0.1)
        else
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then return end
                if hum.Health <= 0 then return end
                if not estaEmKB(hum) then return end

                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

                local diff, restaurou = 0, false
                if ultimaPosKB then
                    diff = (hrp.Position - ultimaPosKB).Magnitude
                    if diff > THRESHOLD_KB then
                        hrp.CFrame = CFrame.new(ultimaPosKB,
                            ultimaPosKB + hrp.CFrame.LookVector)
                        restaurou = true
                    end
                end
                local estado
                pcall(function() estado = hum:GetState() end)
                DebugKB(estado, diff, restaurou)
            end)
            task.wait(0.01)
        end
    end
end)

-- TP-AREA
local function FindGuardAreas(parent)
    parent = parent or Workspace
    for _, child in pairs(parent:GetChildren()) do
        if child.Name == "GuardAreas" then
            return child
        end
        local found = FindGuardAreas(child)
        if found then return found end
    end
    return nil
end

local function GetNestsModel(areaName)
    local guardAreas = FindGuardAreas()
    if not guardAreas then
        warn("[TP-AREA] Pasta GuardAreas não encontrada!")
        return nil
    end
    local areaFolder = guardAreas:FindFirstChild(areaName)
    if not areaFolder then
        warn("[TP-AREA] Área não encontrada: " .. areaName)
        return nil
    end
    local nests = areaFolder:FindFirstChild("Nests")
    if not nests then
        for _, v in pairs(areaFolder:GetDescendants()) do
            if v.Name == "Nests" then nests = v break end
        end
    end
    return nests
end

local function TeleportAndFireClosestPrompt(nestsModel)
    if not nestsModel then return false end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local hrp = char.HumanoidRootPart
    local targetPart = nestsModel.PrimaryPart or nestsModel:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
    else
        local cf, size = nestsModel:GetBoundingBox()
        hrp.CFrame = cf + Vector3.new(0, size.Y/2 + 3, 0)
    end
    task.wait(0.5)
    local closestPrompt = nil
    local shortestDist = math.huge
    local MAX_DISTANCE = 200
    for _, desc in pairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Parent:IsA("BasePart") then
            local dist = (hrp.Position - desc.Parent.Position).Magnitude
            if dist < shortestDist and dist <= MAX_DISTANCE then
                shortestDist = dist
                closestPrompt = desc
            end
        end
    end
    if closestPrompt then
        hrp.CFrame = closestPrompt.Parent.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.3)
        if fireproximityprompt then
            fireproximityprompt(closestPrompt)
        else
            closestPrompt:InputHoldBegin()
            if closestPrompt.HoldDuration > 0 then
                task.wait(closestPrompt.HoldDuration)
            else
                task.wait(0.1)
            end
            closestPrompt:InputHoldEnd()
        end
        return true
    else
        warn("[TP-AREA] Nenhum ProximityPrompt encontrado num raio de " .. MAX_DISTANCE .. " studs.")
        return false
    end
end

local function executarTpAreaIntegrado(areaNome, setStatus, setBtn)
    if not areaNome then
        if setStatus then setStatus("Selecione uma área primeiro!", Color3.fromRGB(255, 200, 0)) end
        return
    end
    if setBtn then setBtn("Teleportando...", Color3.fromRGB(200, 150, 0)) end
    if setStatus then setStatus("Indo para Forest...", Color3.fromRGB(255, 200, 0)) end
    local forestNests = GetNestsModel("Forest")
    if forestNests then
        TeleportAndFireClosestPrompt(forestNests)
    else
        warn("[TP-AREA] Área 'Forest' não encontrada no GuardAreas.")
    end
    if setStatus then setStatus("Aguardando 3 segundos...", Color3.fromRGB(255, 200, 0)) end
    task.wait(3)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if setStatus then setStatus("Personagem morreu ou resetou.", Color3.fromRGB(255, 100, 100)) end
        if setBtn then setBtn("🌪️TP-AREA", Color3.fromRGB(0, 150, 255)) end
        return
    end
    if setStatus then setStatus("Indo para " .. areaNome .. "...", Color3.fromRGB(100, 255, 100)) end
    local targetNests = GetNestsModel(areaNome)
    if targetNests then
        TeleportAndFireClosestPrompt(targetNests)
    else
        warn("[TP-AREA] Model 'Nests' não encontrado para a área: " .. areaNome)
        if setStatus then setStatus("Erro: Nests não encontrado em " .. areaNome, Color3.fromRGB(255, 100, 100)) end
    end
    if setBtn then setBtn("🌪️TP-AREA", Color3.fromRGB(0, 150, 255)) end
    task.wait(2)
    if setStatus then setStatus("Selecione uma área...", Color3.fromRGB(200, 200, 220)) end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Teleporte.ativo then Teleporte.parar() end
    Disfarce.limpar()
    ultimaPosKB = nil
    Teleporte.refs()
end)

Teleporte.refs()

-- GUI
local ROXO      = Color3.fromRGB(140, 80, 255)
local ROXO_DARK = Color3.fromRGB(60, 30, 120)
local VERDE     = Color3.fromRGB(80, 240, 110)
local VERMELHO  = Color3.fromRGB(255, 70, 90)
local LARANJA   = Color3.fromRGB(255, 160, 60)
local AMARELO   = Color3.fromRGB(255, 200, 60)
local AZUL      = Color3.fromRGB(80, 180, 255)
local BG        = Color3.fromRGB(14, 12, 22)
local BG_BTN    = Color3.fromRGB(28, 22, 42)

local gui = Instance.new("ScreenGui")
gui.Name = "PLHubGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

-- Toast
local toastContainer = Instance.new("Frame")
toastContainer.Name = "Toasts"
toastContainer.Size = UDim2.new(0, 300, 1, 0)
toastContainer.Position = UDim2.new(0.5, -150, 0, 0)
toastContainer.BackgroundTransparency = 1
toastContainer.ZIndex = 100
toastContainer.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastContainer

local toastPad = Instance.new("UIPadding")
toastPad.PaddingTop = UDim.new(0, 20)
toastPad.Parent = toastContainer

function Toast(msg, cor)
    cor = cor or Color3.fromRGB(200, 200, 220)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 0, 30)
    t.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
    t.BackgroundTransparency = 0.15
    t.BorderSizePixel = 0
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.TextColor3 = cor
    t.Text = msg
    t.ZIndex = 101
    t.Parent = toastContainer
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke")
    stroke.Color = cor
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = t
    t.BackgroundTransparency = 1
    t.TextTransparency = 1
    TweenService:Create(t, TweenInfo.new(0.25), {
        BackgroundTransparency = 0.15, TextTransparency = 0,
    }):Play()
    task.delay(2, function()
        TweenService:Create(t, TweenInfo.new(0.3), {
            BackgroundTransparency = 1, TextTransparency = 1,
        }):Play()
        task.wait(0.35)
        t:Destroy()
    end)
end

-- Holder
local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.Size = UDim2.new(0, 200, 0, 220)
holder.Position = UDim2.new(0.5, -100, 0.1, 0)
holder.BackgroundTransparency = 1
holder.Active = true
holder.Draggable = true
holder.ClipsDescendants = true
holder.Parent = gui

local bordaGradiente = Instance.new("Frame")
bordaGradiente.Size = UDim2.new(1, 4, 1, 4)
bordaGradiente.Position = UDim2.new(0, -2, 0, -2)
bordaGradiente.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
bordaGradiente.BorderSizePixel = 0
bordaGradiente.ZIndex = 1
bordaGradiente.Parent = holder
Instance.new("UICorner", bordaGradiente).CornerRadius = UDim.new(0, 14)

local gradBorda = Instance.new("UIGradient")
gradBorda.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, ROXO),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 90, 220)),
    ColorSequenceKeypoint.new(0.60, Color3.fromRGB(90, 180, 255)),
    ColorSequenceKeypoint.new(1.00, ROXO),
})
gradBorda.Parent = bordaGradiente

local menu = Instance.new("Frame")
menu.Size = UDim2.new(1, -4, 1, -4)
menu.Position = UDim2.new(0, 2, 0, 2)
menu.BackgroundColor3 = BG
menu.BorderSizePixel = 0
menu.ZIndex = 2
menu.Parent = holder
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 12)

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundTransparency = 1
header.ZIndex = 3
header.Parent = menu

local ledHeader = Instance.new("Frame")
ledHeader.Size = UDim2.new(0, 6, 0, 6)
ledHeader.Position = UDim2.new(0, 10, 0, 13)
ledHeader.BackgroundColor3 = VERMELHO
ledHeader.BorderSizePixel = 0
ledHeader.ZIndex = 4
ledHeader.Parent = header
Instance.new("UICorner", ledHeader).CornerRadius = UDim.new(1, 0)

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -60, 0, 14)
titulo.Position = UDim2.new(0, 22, 0, 4)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBold
titulo.TextSize = 12
titulo.TextColor3 = Color3.fromRGB(240, 230, 255)
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Text = "PL HUB"
titulo.ZIndex = 4
titulo.Parent = header

local subtitulo = Instance.new("TextLabel")
subtitulo.Size = UDim2.new(1, -60, 0, 10)
subtitulo.Position = UDim2.new(0, 22, 0, 18)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = Enum.Font.Gotham
subtitulo.TextSize = 8
subtitulo.TextColor3 = Color3.fromRGB(170, 150, 210)
subtitulo.TextXAlignment = Enum.TextXAlignment.Left
subtitulo.Text = "IB: @caligsc"
subtitulo.ZIndex = 4
subtitulo.Parent = header

local btnMin = Instance.new("TextButton")
btnMin.Size = UDim2.new(0, 18, 0, 18)
btnMin.Position = UDim2.new(1, -44, 0, 7)
btnMin.BackgroundTransparency = 1
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 14
btnMin.TextColor3 = Color3.fromRGB(200, 180, 220)
btnMin.Text = "—"
btnMin.ZIndex = 5
btnMin.Parent = header
btnMin.MouseEnter:Connect(function() btnMin.TextColor3 = ROXO end)
btnMin.MouseLeave:Connect(function() btnMin.TextColor3 = Color3.fromRGB(200, 180, 220) end)

local btnFechar = Instance.new("TextButton")
btnFechar.Size = UDim2.new(0, 18, 0, 18)
btnFechar.Position = UDim2.new(1, -22, 0, 7)
btnFechar.BackgroundTransparency = 1
btnFechar.Font = Enum.Font.GothamBold
btnFechar.TextSize = 12
btnFechar.TextColor3 = Color3.fromRGB(200, 160, 200)
btnFechar.Text = "✕"
btnFechar.ZIndex = 5
btnFechar.Parent = header
btnFechar.MouseEnter:Connect(function() btnFechar.TextColor3 = VERMELHO end)
btnFechar.MouseLeave:Connect(function() btnFechar.TextColor3 = Color3.fromRGB(200, 160, 200) end)
btnFechar.MouseButton1Click:Connect(function() holder.Visible = false end)

local faixaTopo = Instance.new("Frame")
faixaTopo.Size = UDim2.new(1, -16, 0, 2)
faixaTopo.Position = UDim2.new(0, 8, 0, 34)
faixaTopo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
faixaTopo.BorderSizePixel = 0
faixaTopo.ZIndex = 3
faixaTopo.Parent = menu
local gradTopo = Instance.new("UIGradient")
gradTopo.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.00, 1),
    NumberSequenceKeypoint.new(0.20, 0),
    NumberSequenceKeypoint.new(0.80, 0),
    NumberSequenceKeypoint.new(1.00, 1),
})
gradTopo.Color = ColorSequence.new(ROXO, Color3.fromRGB(200, 130, 255))
gradTopo.Parent = faixaTopo

-- TabBar
local tabBarHolder = Instance.new("Frame")
tabBarHolder.Size = UDim2.new(1, -16, 0, 22)
tabBarHolder.Position = UDim2.new(0, 8, 0, 38)
tabBarHolder.BackgroundColor3 = BG_BTN
tabBarHolder.BorderSizePixel = 0
tabBarHolder.ZIndex = 3
tabBarHolder.ClipsDescendants = true
tabBarHolder.Parent = menu
Instance.new("UICorner", tabBarHolder).CornerRadius = UDim.new(0, 6)

local tabScroll = Instance.new("ScrollingFrame")
tabScroll.Size = UDim2.new(1, 0, 1, 0)
tabScroll.BackgroundTransparency = 1
tabScroll.BorderSizePixel = 0
tabScroll.ScrollBarThickness = 0
tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
tabScroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
tabScroll.ZIndex = 3
tabScroll.Parent = tabBarHolder

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabScroll

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 2)
tabPad.PaddingRight = UDim.new(0, 2)
tabPad.Parent = tabScroll

local function criarTabBtn(texto, ordem)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 40, 1, -4)
    b.BackgroundColor3 = BG
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(200, 180, 220)
    b.Text = texto
    b.LayoutOrder = ordem
    b.ZIndex = 4
    b.Parent = tabScroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local btnTabFunc  = criarTabBtn("🎯", 1)
local btnTabTps   = criarTabBtn("🌀", 2)
local btnTabSpeed = criarTabBtn("⚡", 3)
local btnTabHop   = criarTabBtn("🌐", 4)

-- Containers
local containerFunc = Instance.new("Frame")
containerFunc.Size = UDim2.new(1, 0, 1, -98)
containerFunc.Position = UDim2.new(0, 0, 0, 64)
containerFunc.BackgroundTransparency = 1
containerFunc.ZIndex = 3
containerFunc.Parent = menu

local containerTps = Instance.new("Frame")
containerTps.Size = UDim2.new(1, 0, 1, -98)
containerTps.Position = UDim2.new(0, 0, 0, 64)
containerTps.BackgroundTransparency = 1
containerTps.ZIndex = 3
containerTps.Visible = false
containerTps.Parent = menu

local containerSpeed = Instance.new("Frame")
containerSpeed.Size = UDim2.new(1, 0, 1, -98)
containerSpeed.Position = UDim2.new(0, 0, 0, 64)
containerSpeed.BackgroundTransparency = 1
containerSpeed.ZIndex = 3
containerSpeed.Visible = false
containerSpeed.Parent = menu

local containerHop = Instance.new("Frame")
containerHop.Size = UDim2.new(1, 0, 1, -98)
containerHop.Position = UDim2.new(0, 0, 0, 64)
containerHop.BackgroundTransparency = 1
containerHop.ZIndex = 3
containerHop.Visible = false
containerHop.Parent = menu

-- Scroll Funções
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ScrollBotoes"
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.Position = UDim2.new(0, 0, 0, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = ROXO
scroll.ScrollBarImageTransparency = 0.3
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scroll.ZIndex = 3
scroll.Parent = containerFunc

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = scroll

local padScroll = Instance.new("UIPadding")
padScroll.PaddingTop = UDim.new(0, 2)
padScroll.PaddingBottom = UDim.new(0, 4)
padScroll.Parent = scroll

-- Scroll Áreas
local statusAreaLbl = Instance.new("TextLabel")
statusAreaLbl.Size = UDim2.new(1, -16, 0, 14)
statusAreaLbl.Position = UDim2.new(0, 8, 0, 0)
statusAreaLbl.BackgroundTransparency = 1
statusAreaLbl.Font = Enum.Font.Gotham
statusAreaLbl.TextSize = 9
statusAreaLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
statusAreaLbl.TextXAlignment = Enum.TextXAlignment.Left
statusAreaLbl.Text = "Selecione uma área..."
statusAreaLbl.ZIndex = 4
statusAreaLbl.Parent = containerTps

local scrollAreas = Instance.new("ScrollingFrame")
scrollAreas.Name = "ScrollAreas"
scrollAreas.Size = UDim2.new(1, 0, 1, -52)
scrollAreas.Position = UDim2.new(0, 0, 0, 18)
scrollAreas.BackgroundTransparency = 1
scrollAreas.BorderSizePixel = 0
scrollAreas.ScrollBarThickness = 4
scrollAreas.ScrollBarImageColor3 = AZUL
scrollAreas.ScrollBarImageTransparency = 0.3
scrollAreas.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollAreas.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollAreas.ScrollingDirection = Enum.ScrollingDirection.Y
scrollAreas.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scrollAreas.ZIndex = 3
scrollAreas.Parent = containerTps

local layoutAreas = Instance.new("UIListLayout")
layoutAreas.Padding = UDim.new(0, 3)
layoutAreas.SortOrder = Enum.SortOrder.LayoutOrder
layoutAreas.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutAreas.Parent = scrollAreas

local padAreas = Instance.new("UIPadding")
padAreas.PaddingTop = UDim.new(0, 2)
padAreas.PaddingBottom = UDim.new(0, 4)
padAreas.Parent = scrollAreas

local btnTpArea2 = Instance.new("TextButton")
btnTpArea2.Size = UDim2.new(1, -16, 0, 28)
btnTpArea2.Position = UDim2.new(0, 8, 1, -32)
btnTpArea2.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
btnTpArea2.BorderSizePixel = 0
btnTpArea2.Font = Enum.Font.GothamBold
btnTpArea2.TextSize = 12
btnTpArea2.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTpArea2.Text = "🌪️TP-AREA"
btnTpArea2.ZIndex = 4
btnTpArea2.Parent = containerTps
Instance.new("UICorner", btnTpArea2).CornerRadius = UDim.new(0, 7)

local AreaSelecionada = nil
local areaButtons = {}

local function updateSelectionAreaUI()
    for areaName, btn in pairs(areaButtons) do
        if areaName == AreaSelecionada then
            btn.BackgroundColor3 = Color3.fromRGB(0, 130, 60)
        else
            btn.BackgroundColor3 = BG_BTN
        end
    end
end

local function popularAreas()
    for _, c in ipairs(scrollAreas:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
    areaButtons = {}
    AreaSelecionada = nil

    local ga = FindGuardAreas()
    if not ga then
        statusAreaLbl.Text = "GuardAreas não encontrado"
        statusAreaLbl.TextColor3 = VERMELHO
        return
    end
    statusAreaLbl.Text = "Selecione uma área..."
    statusAreaLbl.TextColor3 = Color3.fromRGB(200, 200, 220)

    local i = 0
    for _, child in ipairs(ga:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            i = i + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 22)
            btn.BackgroundColor3 = BG_BTN
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.TextColor3 = Color3.fromRGB(230, 220, 255)
            btn.Text = child.Name
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.ZIndex = 3
            btn.Parent = scrollAreas
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.Parent = btn

            areaButtons[child.Name] = btn

            btn.MouseButton1Click:Connect(function()
                AreaSelecionada = child.Name
                updateSelectionAreaUI()
                statusAreaLbl.Text = "Selecionado: " .. child.Name
                statusAreaLbl.TextColor3 = Color3.fromRGB(180, 230, 255)
            end)
        end
    end
end

-- ============================================
-- ABA SPEED (⚡)
-- ============================================
local Speed = {
    Active      = false,
    Value       = 100,
    Thread      = nil,
    WalkOrig    = nil,
    Capturado   = false,
}

local speedStatus = Instance.new("TextLabel")
speedStatus.Size = UDim2.new(1, -16, 0, 16)
speedStatus.Position = UDim2.new(0, 8, 0, 0)
speedStatus.BackgroundTransparency = 1
speedStatus.Font = Enum.Font.GothamBold
speedStatus.TextSize = 10
speedStatus.TextColor3 = Color3.fromRGB(180, 220, 255)
speedStatus.TextXAlignment = Enum.TextXAlignment.Left
speedStatus.Text = "Speed: Inativo"
speedStatus.ZIndex = 4
speedStatus.Parent = containerSpeed

local btnSpeedToggle = Instance.new("TextButton")
btnSpeedToggle.Size = UDim2.new(1, -16, 0, 30)
btnSpeedToggle.Position = UDim2.new(0, 8, 0, 22)
btnSpeedToggle.BackgroundColor3 = BG_BTN
btnSpeedToggle.BorderSizePixel = 0
btnSpeedToggle.Font = Enum.Font.GothamBold
btnSpeedToggle.TextSize = 12
btnSpeedToggle.TextColor3 = Color3.fromRGB(230, 220, 255)
btnSpeedToggle.Text = "⚡ Speed: OFF"
btnSpeedToggle.ZIndex = 4
btnSpeedToggle.Parent = containerSpeed
Instance.new("UICorner", btnSpeedToggle).CornerRadius = UDim.new(0, 7)

local strokeSpeed = Instance.new("UIStroke")
strokeSpeed.Color = ROXO_DARK
strokeSpeed.Thickness = 1
strokeSpeed.Parent = btnSpeedToggle

local valorLbl = Instance.new("TextLabel")
valorLbl.Size = UDim2.new(1, -16, 0, 14)
valorLbl.Position = UDim2.new(0, 8, 0, 58)
valorLbl.BackgroundTransparency = 1
valorLbl.Font = Enum.Font.Gotham
valorLbl.TextSize = 10
valorLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
valorLbl.TextXAlignment = Enum.TextXAlignment.Left
valorLbl.Text = "Valor: 100 studs/s"
valorLbl.ZIndex = 4
valorLbl.Parent = containerSpeed

local boxValor = Instance.new("TextBox")
boxValor.Size = UDim2.new(1, -16, 0, 26)
boxValor.Position = UDim2.new(0, 8, 0, 74)
boxValor.BackgroundColor3 = BG_BTN
boxValor.BorderSizePixel = 0
boxValor.Font = Enum.Font.GothamBold
boxValor.TextSize = 11
boxValor.TextColor3 = Color3.fromRGB(230, 220, 255)
boxValor.PlaceholderText = "Digite o valor (1-1000)"
boxValor.Text = ""
boxValor.ZIndex = 4
boxValor.Parent = containerSpeed
Instance.new("UICorner", boxValor).CornerRadius = UDim.new(0, 7)

boxValor.FocusLost:Connect(function()
    local n = tonumber(boxValor.Text)
    if n then
        n = math.clamp(n, 1, 1000)
        Speed.Value = n
        valorLbl.Text = "Valor: " .. n .. " studs/s"
        boxValor.Text = ""
    else
        boxValor.Text = ""
    end
end)

local function aplicarSpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.WalkSpeed = Speed.Value end)
    end
end

local function pararSpeed()
    Speed.Active = false
    if Speed.Thread then
        pcall(task.cancel, Speed.Thread)
        Speed.Thread = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and Speed.WalkOrig then
        pcall(function() hum.WalkSpeed = Speed.WalkOrig end)
    end
    Speed.WalkOrig  = nil
    Speed.Capturado = false

    btnSpeedToggle.Text = "⚡ Speed: OFF"
    btnSpeedToggle.BackgroundColor3 = BG_BTN
    strokeSpeed.Color = ROXO_DARK
end

local function iniciarSpeed()
    if not Speed.Capturado then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            Speed.WalkOrig = hum.WalkSpeed
            Speed.Capturado = true
        end
    end

    Speed.Active = true
    btnSpeedToggle.Text = "⚡ Speed: ON"
    btnSpeedToggle.BackgroundColor3 = Color3.fromRGB(20, 55, 28)
    strokeSpeed.Color = VERDE
    aplicarSpeed()

    if Speed.Thread then pcall(task.cancel, Speed.Thread) end
    Speed.Thread = task.spawn(function()
        while Speed.Active do
            aplicarSpeed()
            task.wait(0.2)
        end
    end)
end

btnSpeedToggle.MouseButton1Click:Connect(function()
    if Speed.Active then
        pararSpeed()
        Toast("Speed OFF", AMARELO)
    else
        iniciarSpeed()
        Toast("Speed ON", VERDE)
    end
end)

-- ============================================
-- ABA 🌐 — SERVER HOP
-- ============================================
local HopState = {
    Servers    = {},
    Items      = {},
    FiltroIdx  = 1,
    Carregando = false,
}

local HopFiltros = {
    { label = "TODOS",         max = 999 },
    { label = "0-1 PLAYER",    max = 1 },
    { label = "0-3 PLAYERS",   max = 3 },
    { label = "0-5 PLAYERS",   max = 5 },
    { label = "0-10 PLAYERS",  max = 10 },
}

local btnHopFiltro = Instance.new("TextButton")
btnHopFiltro.Size = UDim2.new(1, -16, 0, 22)
btnHopFiltro.Position = UDim2.new(0, 8, 0, 2)
btnHopFiltro.BackgroundColor3 = BG_BTN
btnHopFiltro.BorderSizePixel = 0
btnHopFiltro.Font = Enum.Font.GothamBold
btnHopFiltro.TextSize = 10
btnHopFiltro.TextColor3 = Color3.fromRGB(230, 220, 255)
btnHopFiltro.Text = "Filtro: TODOS"
btnHopFiltro.ZIndex = 4
btnHopFiltro.Parent = containerHop
Instance.new("UICorner", btnHopFiltro).CornerRadius = UDim.new(0, 5)

local hopStatus = Instance.new("TextLabel")
hopStatus.Size = UDim2.new(1, -16, 0, 12)
hopStatus.Position = UDim2.new(0, 8, 0, 26)
hopStatus.BackgroundTransparency = 1
hopStatus.Font = Enum.Font.Gotham
hopStatus.TextSize = 9
hopStatus.TextColor3 = Color3.fromRGB(180, 180, 200)
hopStatus.TextXAlignment = Enum.TextXAlignment.Left
hopStatus.Text = "Pronto."
hopStatus.ZIndex = 4
hopStatus.Parent = containerHop

local btnHopEnter = Instance.new("TextButton")
btnHopEnter.Size = UDim2.new(1, -16, 0, 26)
btnHopEnter.Position = UDim2.new(0, 8, 0, 42)
btnHopEnter.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
btnHopEnter.BorderSizePixel = 0
btnHopEnter.Font = Enum.Font.GothamBold
btnHopEnter.TextSize = 11
btnHopEnter.TextColor3 = Color3.fromRGB(255, 255, 255)
btnHopEnter.Text = "Entrar no Melhor"
btnHopEnter.ZIndex = 4
btnHopEnter.Parent = containerHop
Instance.new("UICorner", btnHopEnter).CornerRadius = UDim.new(0, 6)

local btnHopLista = Instance.new("TextButton")
btnHopLista.Size = UDim2.new(1, -16, 0, 22)
btnHopLista.Position = UDim2.new(0, 8, 0, 72)
btnHopLista.BackgroundColor3 = BG_BTN
btnHopLista.BorderSizePixel = 0
btnHopLista.Font = Enum.Font.GothamBold
btnHopLista.TextSize = 10
btnHopLista.TextColor3 = Color3.fromRGB(230, 220, 255)
btnHopLista.Text = "Ver Lista de Servidores"
btnHopLista.ZIndex = 4
btnHopLista.Parent = containerHop
Instance.new("UICorner", btnHopLista).CornerRadius = UDim.new(0, 6)

local hopScroll = Instance.new("ScrollingFrame")
hopScroll.Size = UDim2.new(1, -16, 1, -102)
hopScroll.Position = UDim2.new(0, 8, 0, 98)
hopScroll.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
hopScroll.BorderSizePixel = 0
hopScroll.ScrollBarThickness = 4
hopScroll.ScrollBarImageColor3 = ROXO
hopScroll.ScrollBarImageTransparency = 0.3
hopScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
hopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
hopScroll.ScrollingDirection = Enum.ScrollingDirection.Y
hopScroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
hopScroll.ZIndex = 3
hopScroll.Parent = containerHop
Instance.new("UICorner", hopScroll).CornerRadius = UDim.new(0, 6)

local hopLayout = Instance.new("UIListLayout")
hopLayout.Padding = UDim.new(0, 3)
hopLayout.SortOrder = Enum.SortOrder.LayoutOrder
hopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hopLayout.Parent = hopScroll

local hopPad = Instance.new("UIPadding")
hopPad.PaddingTop = UDim.new(0, 3)
hopPad.PaddingBottom = UDim.new(0, 3)
hopPad.Parent = hopScroll

local function hopSetStatus(txt, cor)
    hopStatus.Text = txt
    hopStatus.TextColor3 = cor or Color3.fromRGB(180, 180, 200)
end

local function hopLimparLista()
    for _, item in ipairs(HopState.Items) do item:Destroy() end
    HopState.Items = {}
    hopScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end

local function hopAddMsg(msg, cor)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = msg
    lbl.TextColor3 = cor or Color3.fromRGB(180, 180, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = hopScroll
    table.insert(HopState.Items, lbl)
end

local function hopHttpGet(url)
    if game and game.HttpGet then
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if ok and result and #result > 0 then return true, result end
    end
    local ok2, result2 = pcall(function() return HttpService:GetAsync(url, true) end)
    if ok2 and result2 and #result2 > 0 then return true, result2 end
    return false, "HTTP falhou."
end

local function hopFetchServers()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, raw = hopHttpGet(url)
    if not ok or not raw or raw == "" then return nil end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or not data or not data.data then return nil end
    local currentId = tostring(game.JobId)
    local lista = {}
    for _, s in ipairs(data.data) do
        if s.id and tostring(s.id) ~= currentId and s.playing < s.maxPlayers then
            table.insert(lista, {
                id = tostring(s.id),
                playing = s.playing or 0,
                maxPlayers = s.maxPlayers or 0,
                ping = s.ping or 0,
            })
        end
    end
    table.sort(lista, function(a, b) return a.playing < b.playing end)
    return lista
end

local function hopVerificarVaga(serverId)
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, raw = hopHttpGet(url)
    if not ok or not raw then return false, nil end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or not data or not data.data then return false, nil end
    for _, s in ipairs(data.data) do
        if tostring(s.id) == tostring(serverId) then
            return (s.playing or 0) < (s.maxPlayers or 0), {
                id = tostring(s.id), playing = s.playing or 0,
                maxPlayers = s.maxPlayers or 0,
            }
        end
    end
    return false, nil
end

local function hopAplicarFiltro(lista)
    local opt = HopFiltros[HopState.FiltroIdx]
    local out = {}
    for _, s in ipairs(lista) do
        if s.playing <= opt.max then table.insert(out, s) end
    end
    return out
end

local function hopTentarTeleport(lista, maxTentativas)
    maxTentativas = maxTentativas or 5
    local t = 0
    for _, s in ipairs(lista) do
        if t >= maxTentativas then break end
        t = t + 1
        local temVaga, dados = hopVerificarVaga(s.id)
        if temVaga and dados then
            hopSetStatus("Tentando " .. t .. ": " .. dados.playing .. "/" .. dados.maxPlayers,
                Color3.fromRGB(120, 180, 255))
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, dados.id, LocalPlayer)
            end)
            if ok then return true, dados end
            task.wait(0.6)
        end
    end
    return false, nil
end

local function hopRenderServers(lista)
    hopLimparLista()
    if not lista or #lista == 0 then
        hopAddMsg("Nenhum servidor com vaga.", Color3.fromRGB(230, 150, 150))
        return
    end
    for i, s in ipairs(lista) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 24)
        row.BackgroundColor3 = BG_BTN
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = hopScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -54, 1, 0)
        info.Position = UDim2.new(0, 8, 0, 0)
        info.BackgroundTransparency = 1
        info.Text = string.format("%d/%d jogadores", s.playing, s.maxPlayers)
        info.TextColor3 = Color3.fromRGB(230, 220, 255)
        info.Font = Enum.Font.Gotham
        info.TextSize = 10
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = row

        local joinBtn = Instance.new("TextButton")
        joinBtn.Size = UDim2.new(0, 44, 0, 18)
        joinBtn.Position = UDim2.new(1, -48, 0.5, -9)
        joinBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
        joinBtn.BorderSizePixel = 0
        joinBtn.Font = Enum.Font.GothamBold
        joinBtn.TextSize = 9
        joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        joinBtn.Text = "JOIN"
        joinBtn.Parent = row
        Instance.new("UICorner", joinBtn).CornerRadius = UDim.new(0, 4)

        joinBtn.MouseButton1Click:Connect(function()
            joinBtn.Text = "..."
            local temVaga, dados = hopVerificarVaga(s.id)
            if not temVaga then
                joinBtn.Text = "CHEIO"
                hopSetStatus("Server cheio.", Color3.fromRGB(255, 100, 100))
                task.wait(1.5)
                joinBtn.Text = "JOIN"
                return
            end
            hopSetStatus("Entrando...", Color3.fromRGB(120, 180, 255))
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, dados.id, LocalPlayer)
            end)
            if not ok then
                joinBtn.Text = "ERRO"
                task.wait(1.5)
                joinBtn.Text = "JOIN"
            end
        end)

        table.insert(HopState.Items, row)
    end
end

btnHopFiltro.MouseButton1Click:Connect(function()
    HopState.FiltroIdx = HopState.FiltroIdx + 1
    if HopState.FiltroIdx > #HopFiltros then HopState.FiltroIdx = 1 end
    btnHopFiltro.Text = "Filtro: " .. HopFiltros[HopState.FiltroIdx].label
    if #HopState.Servers > 0 then
        hopRenderServers(hopAplicarFiltro(HopState.Servers))
    end
end)

btnHopEnter.MouseButton1Click:Connect(function()
    if HopState.Carregando then return end
    HopState.Carregando = true
    btnHopEnter.Text = "Procurando..."
    hopSetStatus("Buscando o mais vazio...", Color3.fromRGB(255, 200, 50))
    task.wait(0.1)
    local lista = hopFetchServers()
    if not lista or #lista == 0 then
        hopSetStatus("Nenhum server com vaga.", Color3.fromRGB(255, 100, 100))
        btnHopEnter.Text = "Entrar no Melhor"
        HopState.Carregando = false
        return
    end
    local filtrada = hopAplicarFiltro(lista)
    if #filtrada == 0 then filtrada = lista end
    hopSetStatus("Teleportando (top 5)...", Color3.fromRGB(120, 180, 255))
    local sucesso, dados = hopTentarTeleport(filtrada, 5)
    if sucesso then
        hopSetStatus("Entrando em " .. dados.playing .. "/" .. dados.maxPlayers,
            Color3.fromRGB(100, 255, 150))
    else
        hopSetStatus("Falha em todos os 5.", Color3.fromRGB(255, 100, 100))
    end
    btnHopEnter.Text = "Entrar no Melhor"
    HopState.Carregando = false
end)

btnHopLista.MouseButton1Click:Connect(function()
    if HopState.Carregando then return end
    HopState.Carregando = true
    btnHopLista.Text = "Buscando..."
    hopSetStatus("Buscando servidores...", Color3.fromRGB(255, 200, 50))
    task.wait(0.1)
    local lista = hopFetchServers()
    if not lista or #lista == 0 then
        hopSetStatus("Nenhum server com vaga.", Color3.fromRGB(255, 100, 100))
        btnHopLista.Text = "Ver Lista de Servidores"
        HopState.Carregando = false
        return
    end
    HopState.Servers = lista
    local filtrada = hopAplicarFiltro(lista)
    hopSetStatus(#filtrada .. " servers. Clica JOIN.", Color3.fromRGB(100, 255, 150))
    btnHopLista.Text = "Ver Lista de Servidores"
    hopRenderServers(filtrada)
    HopState.Carregando = false
end)

-- ============================================
-- SISTEMA DE ABAS
-- ============================================
local abaAtiva = 1
local function atualizarAbas()
    containerFunc.Visible  = (abaAtiva == 1)
    containerTps.Visible   = (abaAtiva == 2)
    containerSpeed.Visible = (abaAtiva == 3)
    containerHop.Visible   = (abaAtiva == 4)

    local function setCor(btn, ativo)
        if ativo then
            btn.BackgroundColor3 = Color3.fromRGB(50, 30, 80)
            btn.TextColor3 = ROXO
        else
            btn.BackgroundColor3 = BG
            btn.TextColor3 = Color3.fromRGB(200, 180, 220)
        end
    end
    setCor(btnTabFunc,  abaAtiva == 1)
    setCor(btnTabTps,   abaAtiva == 2)
    setCor(btnTabSpeed, abaAtiva == 3)
    setCor(btnTabHop,   abaAtiva == 4)
end

btnTabFunc.MouseButton1Click:Connect(function()
    abaAtiva = 1
    atualizarAbas()
end)

btnTabTps.MouseButton1Click:Connect(function()
    abaAtiva = 2
    atualizarAbas()
    popularAreas()
end)

btnTabSpeed.MouseButton1Click:Connect(function()
    abaAtiva = 3
    atualizarAbas()
end)

btnTabHop.MouseButton1Click:Connect(function()
    abaAtiva = 4
    atualizarAbas()
end)

-- Fábrica de botões
local function criarBotaoCyber(altura, texto, ordem)
    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1, -16, 0, altura)
    cont.BackgroundColor3 = BG_BTN
    cont.BorderSizePixel = 0
    cont.LayoutOrder = ordem
    cont.ZIndex = 3
    cont.Parent = scroll
    Instance.new("UICorner", cont).CornerRadius = UDim.new(0, 7)

    local barraLat = Instance.new("Frame")
    barraLat.Size = UDim2.new(0, 3, 1, -6)
    barraLat.Position = UDim2.new(0, 3, 0, 3)
    barraLat.BackgroundColor3 = ROXO
    barraLat.BorderSizePixel = 0
    barraLat.ZIndex = 4
    barraLat.Parent = cont
    Instance.new("UICorner", barraLat).CornerRadius = UDim.new(0, 2)

    local bordaBtn = Instance.new("UIStroke")
    bordaBtn.Thickness = 1
    bordaBtn.Color = ROXO_DARK
    bordaBtn.Parent = cont

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(230, 220, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = texto
    label.ZIndex = 4
    label.Parent = cont

    local seta = Instance.new("TextLabel")
    seta.Size = UDim2.new(0, 18, 1, 0)
    seta.Position = UDim2.new(1, -20, 0, 0)
    seta.BackgroundTransparency = 1
    seta.Font = Enum.Font.GothamBold
    seta.TextSize = 14
    seta.TextColor3 = ROXO
    seta.TextTransparency = 1
    seta.Text = "›"
    seta.ZIndex = 4
    seta.Parent = cont

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 6
    btn.Parent = cont

    btn.MouseEnter:Connect(function()
        TweenService:Create(cont, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(40, 30, 60),
        }):Play()
        TweenService:Create(bordaBtn, TweenInfo.new(0.15), { Color = ROXO }):Play()
        TweenService:Create(seta, TweenInfo.new(0.15), {
            TextTransparency = 0, Position = UDim2.new(1, -16, 0, 0),
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(cont, TweenInfo.new(0.2), {
            BackgroundColor3 = BG_BTN,
        }):Play()
        TweenService:Create(bordaBtn, TweenInfo.new(0.2), { Color = ROXO_DARK }):Play()
        TweenService:Create(seta, TweenInfo.new(0.2), {
            TextTransparency = 1, Position = UDim2.new(1, -20, 0, 0),
        }):Play()
    end)

    local function bounce()
        local tam = cont.Size
        TweenService:Create(cont, TweenInfo.new(0.06), {
            Size = UDim2.new(tam.X.Scale, tam.X.Offset - 5,
                             tam.Y.Scale, tam.Y.Offset - 2),
        }):Play()
        task.wait(0.07)
        TweenService:Create(cont,
            TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = tam,
        }):Play()
    end

    return btn, cont, label, seta, barraLat, bordaBtn, bounce
end

-- ===== BOTÕES DA ABA FUNÇÕES (INVISIBLE EGG em cima) =====
local btnInvisible, contInvisible, labelInvisible, setaInvisible,
      barraInvisible, bordaInvisible, bounceInvisible =
    criarBotaoCyber(30, "👻 INVISIBLE EGG", 1)

local btnAnti,  contAnti,  labelAnti,  setaAnti,  barraAnti,  bordaAnti,  bounceAnti  =
    criarBotaoCyber(30, "🥚 ANTI-BOSS", 2)

local btnTrap,  contTrap,  labelTrap,  setaTrap,  barraTrap,  bordaTrap,  bounceTrap  =
    criarBotaoCyber(30, "🚫 ANTI-TRAP", 3)

local btnKB,    contKB,    labelKB,    setaKB,    barraKB,    bordaKB,    bounceKB    =
    criarBotaoCyber(30, "💫 ANTI-KNOCKBACK", 4)

local btnBypass, contBypass, labelBypass, setaBypass, barraBypass, bordaBypass, bounceBypass =
    criarBotaoCyber(30, "🔥 BYPASS", 5)

local btnDst,   contDst,   labelDst,   setaDst,   barraDst,   bordaDst,   bounceDst   =
    criarBotaoCyber(30, "📍 DEFINIR DESTINO", 6)

local btnReset, contReset, labelReset, setaReset, barraReset, bordaReset, bounceReset =
    criarBotaoCyber(30, "🎯 RESET SPAWN", 7)

local btnFlutuante, contFlutuante, labelFlutuante, setaFlutuante,
      barraFlutuante, bordaFlutuante, bounceFlutuante =
    criarBotaoCyber(30, "🌌 TP-EGG", 8)

local btnAutoSteal, contAutoSteal, labelAutoSteal, setaAutoSteal,
      barraAutoSteal, bordaAutoSteal, bounceAutoSteal =
    criarBotaoCyber(30, "🤖 AUTO-STEAL", 9)

-- ============================================
-- 👻 PAINEL INVISIBLE EGG (novo)
-- ============================================
local InvisibleEgg = { gui = nil, aberto = false, ativado = false }

local function criarInvisibleEggGui()
    if InvisibleEgg.gui then return InvisibleEgg.gui end

    local States = { OvoInvisivel = false }

    local function isOvo(tool)
        if not tool or not tool:IsA("Tool") then return false end
        local uid = tool:GetAttribute("UID")
        local it = tool:GetAttribute("ItemType")
        return uid or it == "Egg" or tool.Name:lower():find("egg")
    end

    local function aplicarInvisibilidadeTool(tool)
        if not tool or not tool.Parent then return end
        for _, d in ipairs(tool:GetDescendants()) do
            pcall(function()
                if d:IsA("BasePart") then
                    d.LocalTransparencyModifier = 1
                    d.Transparency = 1
                    d.CanCollide = false
                    d.CanTouch = false
                    d.CanQuery = false
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
                    d.Enabled = false
                elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                    d.Enabled = false
                elseif d:IsA("Highlight") then
                    d.Enabled = false
                elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                    d.Enabled = false
                elseif d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                    d.Enabled = false
                end
            end)
        end
    end

    local function restaurarInvisibilidadeTool(tool)
        if not tool or not tool.Parent then return end
        for _, d in ipairs(tool:GetDescendants()) do
            pcall(function()
                if d:IsA("BasePart") then
                    d.LocalTransparencyModifier = 0
                    d.Transparency = 0
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 0
                elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
                    d.Enabled = true
                elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                    d.Enabled = true
                elseif d:IsA("Highlight") then
                    d.Enabled = true
                elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                    d.Enabled = true
                elseif d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                    d.Enabled = true
                end
            end)
        end
    end

    local function aplicarInvisibilidadeOvo()
        if not States.OvoInvisivel then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, t in ipairs(char:GetChildren()) do
            if isOvo(t) then
                aplicarInvisibilidadeTool(t)
            end
        end
    end

    local function hookOvo(child)
        if not States.OvoInvisivel then return end
        if isOvo(child) then
            task.wait(0.05)
            aplicarInvisibilidadeTool(child)
        end
    end

    -- GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "InvisibleEggPanel"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Enabled = false
    ScreenGui.Parent = PlayerGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 220, 0, 60)
    Container.Position = UDim2.new(0.5, -110, 1, -120)
    Container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Container.BackgroundTransparency = 0.15
    Container.BorderSizePixel = 0
    Container.Active = true
    Container.Draggable = true
    Container.Parent = ScreenGui

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 12)
    ContainerCorner.Parent = Container

    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Color = Color3.fromRGB(60, 60, 70)
    ContainerStroke.Thickness = 1.5
    ContainerStroke.Transparency = 0.3
    ContainerStroke.Parent = Container

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Ovo Invisível"
    Title.TextColor3 = Color3.fromRGB(240, 240, 240)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Container

    local SwitchTrack = Instance.new("TextButton")
    SwitchTrack.Name = "SwitchTrack"
    SwitchTrack.Size = UDim2.new(0, 50, 0, 26)
    SwitchTrack.Position = UDim2.new(1, -65, 0.5, 0)
    SwitchTrack.AnchorPoint = Vector2.new(0, 0.5)
    SwitchTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    SwitchTrack.BorderSizePixel = 0
    SwitchTrack.Text = ""
    SwitchTrack.AutoButtonColor = false
    SwitchTrack.Parent = Container

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = SwitchTrack

    local SwitchBall = Instance.new("Frame")
    SwitchBall.Name = "SwitchBall"
    SwitchBall.Size = UDim2.new(0, 20, 0, 20)
    SwitchBall.Position = UDim2.new(0, 3, 0.5, 0)
    SwitchBall.AnchorPoint = Vector2.new(0, 0.5)
    SwitchBall.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
    SwitchBall.BorderSizePixel = 0
    SwitchBall.Parent = SwitchTrack

    local BallCorner = Instance.new("UICorner")
    BallCorner.CornerRadius = UDim.new(1, 0)
    BallCorner.Parent = SwitchBall

    local ativo = false

    local function animarSwitch(ligado)
        ativo = ligado
        States.OvoInvisivel = ligado
        InvisibleEgg.ativado = ligado

        local posAlvo = ligado
            and UDim2.new(1, -23, 0.5, 0)
            or  UDim2.new(0, 3, 0.5, 0)
        local corTrilho = ligado
            and Color3.fromRGB(80, 200, 120)
            or  Color3.fromRGB(60, 60, 70)
        local corBola = ligado
            and Color3.fromRGB(255, 255, 255)
            or  Color3.fromRGB(230, 230, 230)

        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(SwitchBall, tweenInfo, {
            Position = posAlvo,
            BackgroundColor3 = corBola
        }):Play()
        TweenService:Create(SwitchTrack, tweenInfo, {
            BackgroundColor3 = corTrilho
        }):Play()

        local char = LocalPlayer.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if isOvo(t) then
                    if ligado then
                        aplicarInvisibilidadeTool(t)
                    else
                        restaurarInvisibilidadeTool(t)
                    end
                end
            end
        end
    end

    SwitchTrack.MouseButton1Click:Connect(function()
        animarSwitch(not ativo)
    end)

    local function onCharacterAdded(char)
        task.wait(0.5)
        char.ChildAdded:Connect(hookOvo)
        if States.OvoInvisivel then
            aplicarInvisibilidadeOvo()
        end
    end

    if LocalPlayer.Character then
        onCharacterAdded(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

    task.spawn(function()
        while InvisibleEgg.gui and InvisibleEgg.gui.Parent do
            task.wait(0.03)
            if States.OvoInvisivel then
                pcall(aplicarInvisibilidadeOvo)
            end
        end
    end)

    InvisibleEgg.gui = ScreenGui
    return ScreenGui
end

local function toggleInvisibleEgg()
    if not InvisibleEgg.gui then
        criarInvisibleEggGui()
    end
    InvisibleEgg.aberto = not InvisibleEgg.aberto
    InvisibleEgg.gui.Enabled = InvisibleEgg.aberto
    if InvisibleEgg.aberto then
        Toast("Invisible Egg ON", VERDE)
    else
        Toast("Invisible Egg OFF", AMARELO)
    end
end

-- ============================================
-- 🥚 PAINEL ANTI-BOSS
-- ============================================
local AntiBoss = { gui = nil, aberto = false, ativado = false }

local function criarAntiBossGui()
    if AntiBoss.gui then return AntiBoss.gui end

    local VelocidadeRun    = 1e15
    local DistanciaChegada = 4
    local IgnorarEixoY     = true
    local WalkSpeedFake    = 500
    local JumpPowerFake    = 120
    local NomeParte        = "SmartPromptPart"
    local NomePrompt       = "CarryAreaEgg"
    local TempoNoSpawn     = 0.3

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AntiBossGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Enabled = false
    ScreenGui.Parent = PlayerGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 180, 0, 45)
    MainFrame.Position = UDim2.new(0.5, -90, 1, -180)
    MainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = MainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 70)
    stroke.Thickness = 1
    stroke.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.6, 0, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "ANTI-BOSS"
    Title.TextColor3 = Color3.fromRGB(230, 230, 230)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    local ToggleBg = Instance.new("Frame")
    ToggleBg.Size = UDim2.new(0, 50, 0, 26)
    ToggleBg.Position = UDim2.new(1, -60, 0.5, -13)
    ToggleBg.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    ToggleBg.BorderSizePixel = 0
    ToggleBg.Parent = MainFrame

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(1, 0)
    tbCorner.Parent = ToggleBg

    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Size = UDim2.new(0, 22, 0, 22)
    ToggleCircle.Position = UDim2.new(0, 2, 0.5, -11)
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    ToggleCircle.BorderSizePixel = 0
    ToggleCircle.Parent = ToggleBg

    local tcCorner = Instance.new("UICorner")
    tcCorner.CornerRadius = UDim.new(1, 0)
    tcCorner.Parent = ToggleCircle

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.BackgroundTransparency = 1
    Button.Text = ""
    Button.Parent = ToggleBg

    local Character, Humanoid, RootPart
    local connRun = nil
    local walkOriginal, jumpOriginal
    local alvoAtual = nil
    local promptsConectados = setmetatable({}, {__mode = "k"})
    local executando = false

    local function AtualizarPersonagem()
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid  = Character:WaitForChild("Humanoid")
        RootPart  = Character:WaitForChild("HumanoidRootPart")
    end
    task.spawn(AtualizarPersonagem)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if connRun then connRun:Disconnect(); connRun = nil end
        alvoAtual, walkOriginal, jumpOriginal = nil, nil, nil
        task.spawn(AtualizarPersonagem)
    end)

    local function PararTeleporte()
        if connRun then connRun:Disconnect(); connRun = nil end
        if Humanoid and Humanoid.Parent then
            if walkOriginal then Humanoid.WalkSpeed = walkOriginal end
            if jumpOriginal then Humanoid.JumpPower = jumpOriginal end
        end
        alvoAtual = nil
    end

    local function TeleportarPara(posicaoAlvo, aoChegar)
        if not RootPart or not Humanoid or not RootPart.Parent then return end
        if connRun then connRun:Disconnect() end

        if not walkOriginal then walkOriginal = Humanoid.WalkSpeed end
        if not jumpOriginal then jumpOriginal = Humanoid.JumpPower end
        Humanoid.WalkSpeed = WalkSpeedFake
        Humanoid.JumpPower = JumpPowerFake
        alvoAtual = posicaoAlvo

        connRun = RunService.Heartbeat:Connect(function(dt)
            if not RootPart or not RootPart.Parent or not Humanoid.Parent then
                PararTeleporte(); return
            end
            local origem = RootPart.Position
            local delta  = alvoAtual - origem
            if IgnorarEixoY then delta = Vector3.new(delta.X, 0, delta.Z) end
            local dist = delta.Magnitude

            if dist <= DistanciaChegada then
                RootPart.CFrame = CFrame.new(alvoAtual) * (RootPart.CFrame - RootPart.Position)
                PararTeleporte()
                if aoChegar then aoChegar() end
                return
            end

            local passo   = math.min(VelocidadeRun * dt, dist)
            local direcao = delta.Unit
            local novaPos = origem + direcao * passo
            if IgnorarEixoY then
                novaPos = Vector3.new(novaPos.X, origem.Y, novaPos.Z)
            end

            local lookDir = direcao
            if lookDir.Magnitude < 0.001 then lookDir = Vector3.new(0, 0, 1) end
            RootPart.CFrame = CFrame.lookAt(novaPos, novaPos + lookDir)
        end)
    end

    local function GetSpawnLocation()
        return Workspace:FindFirstChildOfClass("SpawnLocation")
    end

    local function ConectarPrompt(prompt)
        if promptsConectados[prompt] then return end
        promptsConectados[prompt] = true

        prompt.Triggered:Connect(function()
            if not AntiBoss.ativado then return end
            if executando then return end
            if not RootPart or not RootPart.Parent then return end

            local spawn = GetSpawnLocation()
            if not spawn then return end

            -- Clone + trava câmera
            pcall(function() Disfarce.iniciar() end)

            executando = true
            local posicaoSalva = RootPart.Position

            TeleportarPara(spawn.Position, function()
                task.wait(TempoNoSpawn)
                if not AntiBoss.ativado then
                    executando = false
                    pcall(function() Disfarce.limpar() end)
                    return
                end
                TeleportarPara(posicaoSalva, function()
                    executando = false
                end)
            end)
        end)
    end

    local function VerificarPart(part)
        if part.Name ~= NomeParte then return end
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("ProximityPrompt") and child.Name == NomePrompt then
                ConectarPrompt(child)
            end
        end
    end

    local function EscanearTudo()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == NomeParte then VerificarPart(obj) end
        end
    end

    Workspace.DescendantAdded:Connect(function(obj)
        if not AntiBoss.ativado then return end
        if obj.Name == NomeParte then
            task.wait(0.05); VerificarPart(obj)
        elseif obj:IsA("ProximityPrompt") and obj.Name == NomePrompt then
            task.wait(0.05)
            local p = obj.Parent
            while p and p ~= Workspace do
                if p.Name == NomeParte then ConectarPrompt(obj); break end
                p = p.Parent
            end
        end
    end)

    local TweenInfoToggle = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function SetAtivado(valor)
        AntiBoss.ativado = valor
        if valor then
            TweenService:Create(ToggleBg, TweenInfoToggle, {BackgroundColor3 = Color3.fromRGB(80, 200, 120)}):Play()
            TweenService:Create(ToggleCircle, TweenInfoToggle, {Position = UDim2.new(1, -24, 0.5, -11)}):Play()
            EscanearTudo()
            Toast("Anti-Boss ON", VERDE)
        else
            TweenService:Create(ToggleBg, TweenInfoToggle, {BackgroundColor3 = Color3.fromRGB(60, 60, 65)}):Play()
            TweenService:Create(ToggleCircle, TweenInfoToggle, {Position = UDim2.new(0, 2, 0.5, -11)}):Play()
            PararTeleporte()
            pcall(function() Disfarce.limpar() end)
            executando = false
            Toast("Anti-Boss OFF", AMARELO)
        end
    end

    Button.MouseButton1Click:Connect(function()
        SetAtivado(not AntiBoss.ativado)
    end)

    AntiBoss.gui = ScreenGui
    return ScreenGui
end

local function toggleAntiBoss()
    if not AntiBoss.gui then
        criarAntiBossGui()
    end
    AntiBoss.aberto = not AntiBoss.aberto
    AntiBoss.gui.Enabled = AntiBoss.aberto
    if AntiBoss.aberto then
        Toast("Painel Anti-Boss ON", VERDE)
    else
        Toast("Painel Anti-Boss OFF", AMARELO)
    end
end

-- ============================================
-- PAINEL FLUTUANTE (TP-EGG)
-- ============================================
local PainelFlutuante = { gui = nil, aberto = false }

local function criarPainelFlutuante()
    if PainelFlutuante.gui then return PainelFlutuante.gui end

    local RESPAWN_WAIT = 2

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TweenTPPanel"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 50
    screenGui.Enabled = false
    screenGui.Parent = PlayerGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 280, 0, 118)
    panel.Position = UDim2.new(0, 20, 0, 100)
    panel.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = Color3.fromRGB(70, 75, 90)
    stroke.Thickness = 1

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 12, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "TP  •  Nests (loop)"
    title.TextColor3 = Color3.fromRGB(230, 230, 240)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 50, 0, 26)
    toggleBg.Position = UDim2.new(0, 15, 0, 30)
    toggleBg.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
    toggleBg.BorderSizePixel = 0
    toggleBg.Active = true
    toggleBg.Parent = panel
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 100, 0, 20)
    statusLabel.Position = UDim2.new(0, 80, 0, 33)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "OFF"
    statusLabel.TextColor3 = Color3.fromRGB(220, 90, 90)
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 14
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = panel

    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 90, 0, 26)
    testBtn.Position = UDim2.new(1, -100, 0, 30)
    testBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    testBtn.BorderSizePixel = 0
    testBtn.Text = "TP TESTE"
    testBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 12
    testBtn.Parent = panel
    Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0, 6)

    local footerHolder = Instance.new("Frame")
    footerHolder.Size = UDim2.new(1, -20, 0, 52)
    footerHolder.Position = UDim2.new(0, 10, 0, 62)
    footerHolder.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    footerHolder.BorderSizePixel = 0
    footerHolder.Parent = panel
    Instance.new("UICorner", footerHolder).CornerRadius = UDim.new(0, 6)

    local footerScroll = Instance.new("ScrollingFrame")
    footerScroll.Size = UDim2.new(1, -8, 1, -8)
    footerScroll.Position = UDim2.new(0, 4, 0, 4)
    footerScroll.BackgroundTransparency = 1
    footerScroll.BorderSizePixel = 0
    footerScroll.ScrollBarThickness = 3
    footerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    footerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    footerScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 95, 110)
    footerScroll.Parent = footerHolder

    local footerList = Instance.new("UIListLayout")
    footerList.Padding = UDim.new(0, 1)
    footerList.SortOrder = Enum.SortOrder.LayoutOrder
    footerList.Parent = footerScroll

    local MAX_LINES = 30
    local lineCount = 0

    local function log(msg, color)
        lineCount += 1
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 12)
        lbl.BackgroundTransparency = 1
        lbl.Text = "• " .. tostring(msg)
        lbl.TextColor3 = color or Color3.fromRGB(180, 200, 220)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = lineCount
        lbl.Parent = footerScroll
        footerScroll.CanvasPosition = Vector2.new(0, math.huge)
        local labels = {}
        for _, c in ipairs(footerScroll:GetChildren()) do
            if c:IsA("TextLabel") then table.insert(labels, c) end
        end
        if #labels > MAX_LINES then
            table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
            labels[1]:Destroy()
        end
    end

    log("Script carregado.", Color3.fromRGB(120, 220, 160))

    local enabled = false

    local function findNests()
        local guardAreas
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == "GuardAreas" then guardAreas = d break end
        end
        if not guardAreas then
            log("GuardAreas NAO encontrado.", Color3.fromRGB(240, 120, 120))
            return nil
        end
        local forest
        for _, d in ipairs(guardAreas:GetDescendants()) do
            if d.Name == "Forest" then forest = d break end
        end
        if not forest then
            log("Forest NAO encontrado.", Color3.fromRGB(240, 120, 120))
            return nil
        end
        local nests = forest:FindFirstChild("Nests")
        if not nests then
            for _, d in ipairs(forest:GetDescendants()) do
                if d.Name == "Nests" then nests = d break end
            end
        end
        if not nests then
            log("Nests NAO encontrado.", Color3.fromRGB(240, 120, 120))
            return nil
        end
        return nests
    end

    local function getNestsPosition(doLog)
        local nests = findNests()
        if not nests then return nil end
        local pos
        if nests:IsA("Model") then
            local ok, cf, size = pcall(function() return nests:GetBoundingBox() end)
            if ok and cf and size then
                local topY = cf.Position.Y + (size.Y / 2) + 4
                pos = Vector3.new(cf.Position.X, topY, cf.Position.Z)
            else
                local pp = nests.PrimaryPart or nests:FindFirstChildWhichIsA("BasePart", true)
                if pp then pos = pp.Position + Vector3.new(0, pp.Size.Y/2 + 4, 0) end
            end
        elseif nests:IsA("BasePart") then
            pos = nests.Position + Vector3.new(0, nests.Size.Y/2 + 4, 0)
        end
        if not pos then
            if doLog then log("Nests sem posicao.", Color3.fromRGB(240, 120, 120)) end
            return nil
        end
        if doLog then
            log(string.format("Destino: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z),
                Color3.fromRGB(255, 220, 120))
        end
        return pos
    end

    local function isSmartPrompt(prompt)
        if not prompt or not prompt.Parent then return false end
        if prompt.Name == "CarryAreaEgg" then return true end
        if prompt.Parent.Name == "SmartPromptPart" then return true end
        local p, depth = prompt.Parent, 0
        while p and p ~= Workspace and depth < 15 do
            if p.Name == "SmartPromptPart" then return true end
            p = p.Parent
            depth += 1
        end
        return false
    end

    local loopConn  = nil
    local cachedPos = nil

    local function stopLoop()
        if loopConn then
            loopConn:Disconnect()
            loopConn = nil
            log("Loop parado.", Color3.fromRGB(220, 180, 90))
        end
    end

    local function startLoop()
        stopLoop()
        cachedPos = getNestsPosition(true)
        if not cachedPos then return end

        log("Loop iniciado.", Color3.fromRGB(120, 220, 160))

        loopConn = RunService.Heartbeat:Connect(function()
            if not enabled then
                stopLoop()
                return
            end
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and cachedPos then
                hrp.CFrame = CFrame.new(cachedPos) * (hrp.CFrame - hrp.CFrame.Position)
            end
        end)
    end

    local function setToggle(state)
        enabled = state
        if state then
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 175, 100)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -24, 0, 2)}):Play()
            statusLabel.Text = "ON"
            statusLabel.TextColor3 = Color3.fromRGB(90, 220, 130)
            log("Ativado.", Color3.fromRGB(120, 220, 160))
        else
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 62, 72)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0, 2)}):Play()
            statusLabel.Text = "OFF"
            statusLabel.TextColor3 = Color3.fromRGB(220, 90, 90)
            stopLoop()
            log("Desativado.", Color3.fromRGB(220, 150, 90))
        end
    end

    toggleBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            setToggle(not enabled)
        end
    end)

    local function doTeleport(withLoop)
        cachedPos = getNestsPosition(true)
        if not cachedPos then return end

        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            log("Sem HRP.", Color3.fromRGB(240, 120, 120))
            return
        end

        hrp.CFrame = CFrame.new(cachedPos) * (hrp.CFrame - hrp.CFrame.Position)
        log("TP feito.", Color3.fromRGB(120, 220, 160))

        if withLoop then
            startLoop()
        end
    end

    local function tryTeleport(prompt, triggeringPlayer)
        log("Prompt disparou: " .. (prompt and prompt.Name or "?"),
            Color3.fromRGB(200, 200, 200))
        if not enabled then return end
        if triggeringPlayer and triggeringPlayer ~= LocalPlayer then return end
        if not isSmartPrompt(prompt) then
            log("Nao e SmartPrompt. Ignorando.", Color3.fromRGB(220, 180, 90))
            return
        end
        doTeleport(true)
    end

    local watched = setmetatable({}, {__mode = "k"})

    local function watchPrompt(prompt)
        if watched[prompt] then return end
        watched[prompt] = true
        prompt.Triggered:Connect(function(triggeringPlayer)
            tryTeleport(prompt, triggeringPlayer)
        end)
    end

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then watchPrompt(d) end
    end

    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then watchPrompt(d) end
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
        tryTeleport(prompt, triggeringPlayer)
    end)
    ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, triggeringPlayer)
        tryTeleport(prompt, triggeringPlayer)
    end)

    testBtn.MouseButton1Click:Connect(function()
        log("TP TESTE clicado.", Color3.fromRGB(180, 200, 255))
        doTeleport(true)
    end)

    local lastDeathCFrame = nil

    local function hookCharacter(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        humanoid.Died:Connect(function()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                lastDeathCFrame = hrp.CFrame
                log(string.format("Morreu em %.1f, %.1f, %.1f",
                    lastDeathCFrame.Position.X,
                    lastDeathCFrame.Position.Y,
                    lastDeathCFrame.Position.Z),
                    Color3.fromRGB(240, 150, 150))
            end
            stopLoop()
        end)
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        hookCharacter(char)
        if not enabled or not lastDeathCFrame then return end
        local savedCF = lastDeathCFrame

        task.spawn(function()
            task.wait(RESPAWN_WAIT)
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if not hrp then return end
            if hrp.Parent then
                hrp.CFrame = savedCF
                log("Respawn reposicionado (sem loop).", Color3.fromRGB(120, 220, 160))
            end
        end)
    end)

    if LocalPlayer.Character then
        hookCharacter(LocalPlayer.Character)
    end

    log("Pronto. Prompts monitorados.", Color3.fromRGB(120, 220, 160))

    PainelFlutuante.gui = screenGui
    return screenGui
end

local function togglePainelFlutuante()
    if not PainelFlutuante.gui then
        criarPainelFlutuante()
    end
    PainelFlutuante.aberto = not PainelFlutuante.aberto
    PainelFlutuante.gui.Enabled = PainelFlutuante.aberto
    if PainelFlutuante.aberto then
        Toast("TP-EGG ON", VERDE)
    else
        Toast("TP-EGG OFF", AMARELO)
    end
end

-- ============================================
-- 🤖 PAINEL AUTO-STEAL
-- ============================================
local AutoSteal = { gui = nil, aberto = false }

local function criarAutoStealGui()
    if AutoSteal.gui then return AutoSteal.gui end

    local LOOP_POSITION       = Vector3.new(615.8, 70.3, -394.2)
    local VELOCIDADE_RUN      = 1e15
    local DISTANCIA_CHEGADA   = 4
    local RESPAWN_WAIT        = 0.8
    local RESPAWN_TWEEN_TIME  = 1.5
    local MOSTRAR_SUFIXO_S    = false
    local ORDENAR_POR_VALOR   = true

    local AUTO_DROP_TIMEOUT      = 8
    local TIMEOUT_RETORNO        = 120
    local HOLD_DURATION_RETORNO  = 1.2
    local WAIT_LOOP_ANTES_DROP   = 1
    local WAIT_APOS_DROP         = 1

    local TEMA = {
        fundo      = Color3.fromRGB(15, 15, 20),
        painel     = Color3.fromRGB(25, 25, 35),
        destaque   = Color3.fromRGB(46, 204, 113),
        texto      = Color3.fromRGB(240, 240, 245),
        textoFraco = Color3.fromRGB(150, 150, 160),
        borda      = Color3.fromRGB(45, 45, 60),
        perigo     = Color3.fromRGB(231, 76, 60),
        dinheiro   = Color3.fromRGB(255, 215, 0),
    }

    local maxEspDistance = 1000
    local targetRarityName = "Todos"
    local iconCache = {}
    local rarityCache = {}
    local valueCache = {}

    local RARITY_SCORE = {
        Secret = 800, Cosmic = 700, Mythic = 600, Rainbow = 600,
        Legendary = 500, Epic = 400, Rare = 300, Uncommon = 200, Common = 100,
    }

    local function getAssetInfo(category)
        if not category or not AssetsData then return nil end
        return (AssetsData.Directory or AssetsData)[category]
    end

    local function mutationMultiplier(record)
        local multiplier = 1
        local mutations = record.Mutations or record.Mutation
        if type(mutations) == "table" then
            for _, mutation in pairs(mutations) do
                if type(mutation) == "table" then
                    multiplier = multiplier * (tonumber(mutation.Multiplier or mutation.Value or mutation.Scale) or 1.5)
                else
                    local text = tostring(mutation):lower()
                    if text:find("rainbow") then multiplier = multiplier * 3
                    elseif text:find("gold") then multiplier = multiplier * 2
                    elseif text:find("silver") then multiplier = multiplier * 1.5
                    elseif text:find("parasite") or text:find("monstrous") then multiplier = multiplier * 5
                    else multiplier = multiplier * 1.25 end
                end
            end
        elseif mutations then
            multiplier = multiplier * 1.5
        end
        if record.HasParasite then multiplier = multiplier * 5 end
        return multiplier
    end

    local function GetEggRarityInfo(egg)
        if not egg then return "Common", 100 end
        if egg.Rarity then
            local r = egg.Rarity
            local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
            return name, RARITY_SCORE_MAP[name] or 100
        end
        local cat = egg.AssetCategory or egg.Category or egg.Name
        if cat and AssetsData then
            local aInfo = (AssetsData.Directory or AssetsData)[cat]
            if aInfo and aInfo.Rarity then
                local r = aInfo.Rarity
                local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
                return name, RARITY_SCORE_MAP[name] or 100
            end
        end
        local areaData = AreasData and (AreasData.Directory or AreasData) and (AreasData.Directory or AreasData)[egg.AreaId]
        local rarity = areaData and areaData.Rarity
        local rarityId = (type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name)) or (type(rarity) == "string" and rarity) or "Common"
        local rInfo = (RarityData and (RarityData.Rarities or RarityData) or {})[rarityId] or {}
        local rarityDisplayName = (type(rInfo) == "table" and (rInfo.DisplayName or rInfo._id)) or (type(rarity) == "table" and rarity.DisplayName) or rarityId or "Common"
        return rarityDisplayName, RARITY_SCORE_MAP[rarityDisplayName] or 100
    end

    local function getRarityName(record) return (GetEggRarityInfo(record)) end

    local function getEggValue(record)
        if not record then return 0 end
        local category = tostring(record.AssetCategory or record.Category or record.Name or "Egg")
        local info = getAssetInfo(category)
        local raw = tonumber(record.Money or record.Cash or record.Income or record.EarningRate or record.Value or record.Price)
        if (not raw or raw <= 0) and type(info) == "table" then
            raw = tonumber(info.Money or info.Cash or info.Income or info.EarningRate or info.ProfileIncome or info.SalePrice or info.Price)
            if (not raw or raw <= 0) and type(info.Egg) == "table" then
                raw = tonumber(info.Egg.Money or info.Egg.Income or info.Egg.EarningRate or info.Egg.SalePrice)
            end
        end
        raw = tonumber(raw) or 0
        local scale = tonumber(record.AssetScale or record.Scale or record.NestScale) or 1
        local value = raw * scale * mutationMultiplier(record)
        if value <= 0 then
            local rarity = getRarityName(record)
            local score = RARITY_SCORE[rarity] or 100
            local area = tonumber(tostring(record.AreaId or ""):match("%d+")) or 50
            value = score * math.max(area, 50) * math.max(scale, 1)
        end
        return value
    end

    local function formatarValor(n)
        if not n or n <= 0 then return nil end
        n = tonumber(n) or 0
        local sufixo = MOSTRAR_SUFIXO_S and "/s" or ""
        if n >= 1e12 then return string.format("$%.1fT%s", n/1e12, sufixo) end
        if n >= 1e9  then return string.format("$%.1fB%s", n/1e9,  sufixo) end
        if n >= 1e6  then return string.format("$%.1fM%s", n/1e6,  sufixo) end
        if n >= 1e3  then return string.format("$%.1fK%s", n/1e3,  sufixo) end
        return string.format("$%d%s", math.floor(n + 0.5), sufixo)
    end

    local function GetPetIcon(record)
        if not record then return nil end
        local targetName = record.Pet or record.PetId or record.PetName or record.AssetCategory or record.Category
        if targetName then
            local c = iconCache[targetName]
            if c ~= nil then return c end
        end
        local rawIcon = record.Icon or record.PetIcon or record.ImageAsset or record.TextureId
        local result
        if rawIcon then
            result = (type(rawIcon) == "number" or not string.match(tostring(rawIcon), "://"))
                and ("rbxassetid://" .. tostring(rawIcon)) or tostring(rawIcon)
        elseif targetName then
            if PetsData then
                local pInfo = (PetsData.Directory or PetsData)[targetName]
                if pInfo and (pInfo.Icon or pInfo.Image or pInfo.AssetId) then
                    local img = pInfo.Icon or pInfo.Image or pInfo.AssetId
                    result = (type(img) == "number" or not string.match(tostring(img), "://"))
                        and ("rbxassetid://" .. tostring(img)) or tostring(img)
                end
            end
            if not result and AssetsData then
                local aInfo = (AssetsData.Directory or AssetsData)[targetName]
                if aInfo and (aInfo.Icon or aInfo.Image or aInfo.AssetId) then
                    local img = aInfo.Icon or aInfo.Image or aInfo.AssetId
                    result = (type(img) == "number" or not string.match(tostring(img), "://"))
                        and ("rbxassetid://" .. tostring(img)) or tostring(img)
                end
            end
        end
        if targetName then iconCache[targetName] = result end
        return result
    end

    local SG = Instance.new("ScreenGui")
    SG.Name = "AutoStealPanel"
    SG.ResetOnSpawn = false
    SG.IgnoreGuiInset = true
    SG.DisplayOrder = 999999998
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.Enabled = false
    SG.Parent = (gethui and gethui()) or PlayerGui

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 200, 0, 220)
    Main.Position = UDim2.new(0.5, -100, 0.5, -110)
    Main.BackgroundColor3 = TEMA.fundo
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.ZIndex = 10
    Main.Parent = SG

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = Main

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = TEMA.borda
    MainStroke.Thickness = 1
    MainStroke.Parent = Main

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundColor3 = TEMA.painel
    Header.BorderSizePixel = 0
    Header.Parent = Main

    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 8)
    HeaderCorner.Parent = Header

    local LinhaDecor = Instance.new("Frame")
    LinhaDecor.Size = UDim2.new(0, 3, 0, 18)
    LinhaDecor.Position = UDim2.new(0, 8, 0.5, -9)
    LinhaDecor.BackgroundColor3 = TEMA.destaque
    LinhaDecor.BorderSizePixel = 0
    LinhaDecor.Parent = Header

    local Logo = Instance.new("TextLabel")
    Logo.Size = UDim2.new(1, -20, 1, 0)
    Logo.Position = UDim2.new(0, 16, 0, 0)
    Logo.BackgroundTransparency = 1
    Logo.Text = "AUTO-STEAL"
    Logo.TextColor3 = TEMA.texto
    Logo.Font = Enum.Font.GothamBlack
    Logo.TextSize = 11
    Logo.TextXAlignment = Enum.TextXAlignment.Left
    Logo.Parent = Header

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -10, 1, -36)
    Content.Position = UDim2.new(0, 5, 0, 32)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local niveisFiltro = { "Todos", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
    local idxFiltro = 1

    local BtnFiltro = Instance.new("TextButton")
    BtnFiltro.Size = UDim2.new(1, 0, 0, 24)
    BtnFiltro.Position = UDim2.new(0, 0, 0, 0)
    BtnFiltro.BackgroundColor3 = TEMA.painel
    BtnFiltro.Text = "Filtro: Todos"
    BtnFiltro.TextColor3 = TEMA.texto
    BtnFiltro.Font = Enum.Font.GothamBold
    BtnFiltro.TextSize = 10
    BtnFiltro.Parent = Content
    Instance.new("UICorner", BtnFiltro).CornerRadius = UDim.new(0, 5)

    local DistInput = Instance.new("TextBox")
    DistInput.Size = UDim2.new(1, 0, 0, 24)
    DistInput.Position = UDim2.new(0, 0, 0, 28)
    DistInput.BackgroundColor3 = TEMA.painel
    DistInput.TextColor3 = TEMA.texto
    DistInput.Font = Enum.Font.GothamBold
    DistInput.TextSize = 11
    DistInput.Text = tostring(maxEspDistance)
    DistInput.PlaceholderText = "Distância máxima"
    DistInput.Parent = Content
    Instance.new("UICorner", DistInput).CornerRadius = UDim.new(0, 5)

    local Lista = Instance.new("ScrollingFrame")
    Lista.Size = UDim2.new(1, 0, 1, -120)
    Lista.Position = UDim2.new(0, 0, 0, 56)
    Lista.BackgroundTransparency = 1
    Lista.BorderSizePixel = 0
    Lista.ScrollBarThickness = 4
    Lista.ScrollBarImageColor3 = TEMA.destaque
    Lista.CanvasSize = UDim2.new(0, 0, 0, 0)
    Lista.Parent = Content

    local ListaLayout = Instance.new("UIListLayout")
    ListaLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListaLayout.Padding = UDim.new(0, 4)
    ListaLayout.Parent = Lista

    local BtnCancelarLoop = Instance.new("TextButton")
    BtnCancelarLoop.Size = UDim2.new(1, 0, 0, 28)
    BtnCancelarLoop.Position = UDim2.new(0, 0, 1, -60)
    BtnCancelarLoop.BackgroundColor3 = TEMA.perigo
    BtnCancelarLoop.Text = "CANCELAR LOOP"
    BtnCancelarLoop.TextColor3 = Color3.fromRGB(255, 255, 255)
    BtnCancelarLoop.Font = Enum.Font.GothamBlack
    BtnCancelarLoop.TextSize = 12
    BtnCancelarLoop.Visible = false
    BtnCancelarLoop.Parent = Content
    Instance.new("UICorner", BtnCancelarLoop).CornerRadius = UDim.new(0, 5)

    local BtnSteal = Instance.new("TextButton")
    BtnSteal.Size = UDim2.new(1, 0, 0, 28)
    BtnSteal.Position = UDim2.new(0, 0, 1, -28)
    BtnSteal.BackgroundColor3 = TEMA.destaque
    BtnSteal.Text = "STEAL TOP"
    BtnSteal.TextColor3 = Color3.fromRGB(255, 255, 255)
    BtnSteal.Font = Enum.Font.GothamBlack
    BtnSteal.TextSize = 12
    BtnSteal.Parent = Content
    Instance.new("UICorner", BtnSteal).CornerRadius = UDim.new(0, 5)

    local _topTarget = nil
    local stealActive = false
    local stealBodyVel = nil

    local loopActive = false
    local loopConn = nil
    local loopPos = nil
    local tweenConn = nil
    local lastDeathPos = nil

    local SPAWN_POSITION = nil

    local function acharSpawnNoWorkspace()
        local candidatos = {
            "Spawn", "Spawns", "SpawnLocation", "SpawnPart",
            "SpawnArea", "BaseSpawn", "HomeSpawn", "PlayerSpawn",
        }
        for _, nome in ipairs(candidatos) do
            local obj = workspace:FindFirstChild(nome)
            if obj then
                if obj:IsA("BasePart") then
                    return obj.Position
                elseif obj:IsA("Model") then
                    local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if root then return root.Position end
                elseif obj:IsA("Folder") then
                    local part = obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then return part.Position end
                end
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("SpawnLocation") then
                return obj.Position
            end
        end
        return nil
    end

    task.spawn(function()
        local t0 = tick()
        while not SPAWN_POSITION and (tick() - t0) < 5 do
            SPAWN_POSITION = acharSpawnNoWorkspace()
            if not SPAWN_POSITION then task.wait(0.3) end
        end
    end)

    local function pararLoop()
        loopActive = false
        if loopConn then
            loopConn:Disconnect()
            loopConn = nil
        end
        BtnCancelarLoop.Visible = false
    end

    local function iniciarLoop(posicao)
        loopActive = true
        loopPos = posicao
        BtnCancelarLoop.Visible = true
        if loopConn then loopConn:Disconnect() end
        loopConn = RunService.Heartbeat:Connect(function()
            if not loopActive or not loopPos then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            h.Velocity = Vector3.zero
            h.CFrame = CFrame.new(loopPos) * (h.CFrame - h.Position)
        end)
    end

    local function teleportarDisfarcado(destino, callback)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then
            if callback then callback(false) end
            return
        end

        local walkOrig = humanoid.WalkSpeed
        local jumpOrig = humanoid.JumpPower
        humanoid.WalkSpeed = 500
        humanoid.JumpPower = 120

        local done = false
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if done then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then done = true; return end

            local origem = h.Position
            local delta = destino - origem
            local dist = delta.Magnitude

            if dist <= DISTANCIA_CHEGADA then
                h.CFrame = CFrame.new(destino) * (h.CFrame - h.Position)
                h.Velocity = Vector3.zero
                done = true
                return
            end

            local direcao = delta.Unit
            local passo = math.min(VELOCIDADE_RUN * dt, dist)
            local novaPos = origem + direcao * passo

            local dirH = Vector3.new(direcao.X, 0, direcao.Z)
            local lookDir = dirH.Magnitude > 0.001 and dirH.Unit or Vector3.new(0, 0, 1)
            h.CFrame = CFrame.lookAt(novaPos, novaPos + lookDir)
            h.Velocity = Vector3.zero
        end)

        local t0 = tick()
        while not done and (tick() - t0) < 5 do
            RunService.Heartbeat:Wait()
        end
        if conn then conn:Disconnect() end

        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            h.WalkSpeed = walkOrig
            h.JumpPower = jumpOrig
        end

        if callback then callback(done) end
    end

    local function tweenPara(destino, duracao, callback)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            if callback then callback() end
            return
        end
        if tweenConn then tweenConn:Disconnect(); tweenConn = nil end

        local origem = hrp.Position
        local delta = destino - origem
        if delta.Magnitude < 0.5 then
            if callback then callback() end
            return
        end

        local t0 = tick()
        tweenConn = RunService.Heartbeat:Connect(function()
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then
                if tweenConn then tweenConn:Disconnect(); tweenConn = nil end
                if callback then callback() end
                return
            end
            local elapsed = tick() - t0
            local alpha = math.min(elapsed / duracao, 1)
            local eased = alpha * alpha * (3 - 2 * alpha)
            local novaPos = origem:Lerp(destino, eased)
            local dirVec = destino - origem
            local dirH = Vector3.new(dirVec.X, 0, dirVec.Z)
            if dirH.Magnitude > 0.01 then
                h.CFrame = CFrame.lookAt(novaPos, novaPos + dirH.Unit)
            else
                h.CFrame = CFrame.new(novaPos) * (h.CFrame - h.Position)
            end
            h.Velocity = Vector3.zero
            if alpha >= 1 then
                if tweenConn then tweenConn:Disconnect(); tweenConn = nil end
                if callback then callback() end
            end
        end)
    end

    local function walkNormalTo(destino, callback)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then
            if callback then callback(false) end
            return
        end

        humanoid:MoveTo(destino)

        local done = false
        local t0 = tick()
        local conn

        conn = humanoid.MoveToFinished:Connect(function(reached)
            if done then return end
            done = true
            if conn then conn:Disconnect() end
            if callback then callback(reached) end
        end)

        task.spawn(function()
            while not done and (tick() - t0) < TIMEOUT_RETORNO do
                task.wait(0.2)
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if not h then break end
                local horiz = Vector3.new(destino.X - h.Position.X, 0, destino.Z - h.Position.Z)
                if horiz.Magnitude < 5 then
                    if not done then
                        done = true
                        if conn then conn:Disconnect() end
                        if callback then callback(true) end
                    end
                    return
                end
                humanoid:MoveTo(destino)
            end
            if not done then
                done = true
                if conn then conn:Disconnect() end
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if h then humanoid:MoveTo(h.Position) end
                if callback then callback(false) end
            end
        end)
    end

    local framePool = {}
    local activeItems = {}
    local frameTemplate = nil

    local function criarTemplate()
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -4, 0, 36)
        frame.BackgroundColor3 = TEMA.painel
        frame.BorderSizePixel = 0
        frame.Visible = false

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = frame

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 28, 0, 28)
        icon.Position = UDim2.new(0, 4, 0.5, -14)
        icon.BackgroundTransparency = 1
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Image = ""
        icon.Parent = frame

        local labelNome = Instance.new("TextLabel")
        labelNome.Name = "Nome"
        labelNome.Size = UDim2.new(1, -106, 0, 14)
        labelNome.Position = UDim2.new(0, 36, 0, 3)
        labelNome.BackgroundTransparency = 1
        labelNome.TextColor3 = TEMA.texto
        labelNome.Font = Enum.Font.GothamBold
        labelNome.TextSize = 10
        labelNome.TextXAlignment = Enum.TextXAlignment.Left
        labelNome.TextTruncate = Enum.TextTruncate.AtEnd
        labelNome.Parent = frame

        local labelMoney = Instance.new("TextLabel")
        labelMoney.Name = "Money"
        labelMoney.Size = UDim2.new(0, 68, 0, 14)
        labelMoney.Position = UDim2.new(1, -72, 0, 3)
        labelMoney.BackgroundTransparency = 1
        labelMoney.TextColor3 = TEMA.dinheiro
        labelMoney.Font = Enum.Font.GothamBold
        labelMoney.TextSize = 9
        labelMoney.TextXAlignment = Enum.TextXAlignment.Right
        labelMoney.Text = ""
        labelMoney.Parent = frame

        local labelRarity = Instance.new("TextLabel")
        labelRarity.Name = "Rarity"
        labelRarity.Size = UDim2.new(1, -90, 0, 12)
        labelRarity.Position = UDim2.new(0, 36, 0, 18)
        labelRarity.BackgroundTransparency = 1
        labelRarity.TextColor3 = TEMA.destaque
        labelRarity.Font = Enum.Font.Gotham
        labelRarity.TextSize = 9
        labelRarity.TextXAlignment = Enum.TextXAlignment.Left
        labelRarity.TextTruncate = Enum.TextTruncate.AtEnd
        labelRarity.Parent = frame

        local labelDist = Instance.new("TextLabel")
        labelDist.Name = "Dist"
        labelDist.Size = UDim2.new(0, 44, 0, 12)
        labelDist.Position = UDim2.new(1, -48, 0, 18)
        labelDist.BackgroundTransparency = 1
        labelDist.TextColor3 = TEMA.textoFraco
        labelDist.Font = Enum.Font.Gotham
        labelDist.TextSize = 9
        labelDist.TextXAlignment = Enum.TextXAlignment.Right
        labelDist.Parent = frame

        frameTemplate = {
            frame = frame, icon = icon,
            labelNome = labelNome, labelRarity = labelRarity,
            labelDist = labelDist, labelMoney = labelMoney,
        }
    end
    criarTemplate()

    local function obterFrame()
        local item = table.remove(framePool)
        if not item then
            local frameClone = frameTemplate.frame:Clone()
            item = {
                frame = frameClone,
                icon = frameClone:FindFirstChild("Icon"),
                labelNome = frameClone:FindFirstChild("Nome"),
                labelRarity = frameClone:FindFirstChild("Rarity"),
                labelDist = frameClone:FindFirstChild("Dist"),
                labelMoney = frameClone:FindFirstChild("Money"),
            }
        end
        item._lastDist = -1
        item._lastRarity = ""
        item._lastIcon = ""
        item._lastName = ""
        item._lastMoney = "\0"
        item._lastOrder = -1
        item.frame.Visible = true
        item.frame.Parent = Lista
        return item
    end

    local function devolverFrame(item)
        item.frame.Visible = false
        item.frame.Parent = nil
        table.insert(framePool, item)
    end

    local ovosBuffer = {}
    local bufferCount = 0
    local currentUids = {}

    local function atualizarLista()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local myPos = hrp.Position

        if not EggState or not EggState.ReadFieldEggs then return end
        local ok, snapshot = pcall(EggState.ReadFieldEggs)
        if not ok or not snapshot or not snapshot.Records then return end

        for i = 1, bufferCount do ovosBuffer[i] = nil end
        bufferCount = 0
        for k in pairs(currentUids) do currentUids[k] = nil end

        for _, record in ipairs(snapshot.Records) do
            if record.State == "Slot" and record.BoundsCFrame then
                local eggPos = record.BoundsCFrame.Position
                local dx, dy, dz = eggPos.X - myPos.X, eggPos.Y - myPos.Y, eggPos.Z - myPos.Z
                local distSq = dx*dx + dy*dy + dz*dz
                if distSq <= maxEspDistance * maxEspDistance then
                    local uid = record.Uid or tostring(record.BoundsCFrame)
                    local rarityName, score
                    local cached = rarityCache[uid]
                    if cached then
                        rarityName, score = cached.name, cached.score
                    else
                        rarityName, score = GetEggRarityInfo(record)
                        rarityCache[uid] = { name = rarityName, score = score }
                    end
                    if targetRarityName == "Todos" or (rarityName:lower() == targetRarityName:lower()) then
                        currentUids[uid] = true
                        bufferCount = bufferCount + 1
                        local entry = ovosBuffer[bufferCount]
                        if not entry then
                            entry = {}
                            ovosBuffer[bufferCount] = entry
                        end
                        entry.uid = uid
                        entry.record = record
                        entry.rarityName = rarityName
                        entry.dist = math.floor(math.sqrt(distSq) + 0.5)
                        entry.score = score

                        local vCached = valueCache[uid]
                        if vCached == nil then
                            local okv, v = pcall(getEggValue, record)
                            vCached = (okv and v) or 0
                            valueCache[uid] = vCached
                        end
                        entry.valor = vCached
                    end
                end
            end
        end

        table.sort(ovosBuffer, function(a, b)
            if not a then return false end
            if not b then return true end
            if ORDENAR_POR_VALOR then
                local va, vb = a.valor or 0, b.valor or 0
                if va ~= vb then return va > vb end
                return a.score > b.score
            else
                return a.score > b.score
            end
        end)
        for i = #ovosBuffer, 1, -1 do
            if ovosBuffer[i] == nil then table.remove(ovosBuffer, i) else break end
        end

        local top = ovosBuffer[1]
        if top then
            _topTarget = { uid = top.uid, record = top.record }
        else
            _topTarget = nil
        end

        for uid, item in pairs(activeItems) do
            if not currentUids[uid] then
                devolverFrame(item)
                activeItems[uid] = nil
            end
        end

        for i = 1, bufferCount do
            local ovo = ovosBuffer[i]
            if not ovo then break end
            local uid = ovo.uid
            local item = activeItems[uid]
            if not item then
                item = obterFrame()
                activeItems[uid] = item
            end

            if item._lastOrder ~= i then
                item.frame.LayoutOrder = i
                item._lastOrder = i
            end

            local nome = ovo.record.AssetCategory or ovo.record.Category or ovo.record.Name or "Ovo"
            nome = tostring(nome)
            if item._lastName ~= nome then
                item.labelNome.Text = nome
                item._lastName = nome
            end
            if item._lastRarity ~= ovo.rarityName then
                item.labelRarity.Text = ovo.rarityName
                item._lastRarity = ovo.rarityName
            end
            if item._lastDist ~= ovo.dist then
                item.labelDist.Text = ovo.dist .. "m"
                item._lastDist = ovo.dist
            end

            local valor = ovo.valor or 0
            local moneyText = formatarValor(valor) or "—"
            if item._lastMoney ~= moneyText then
                item.labelMoney.Text = moneyText
                item._lastMoney = moneyText
            end

            local iconAsset = GetPetIcon(ovo.record)
            if iconAsset then
                if item._lastIcon ~= iconAsset then
                    item.icon.Image = iconAsset
                    item._lastIcon = iconAsset
                end
                if not item.icon.Visible then item.icon.Visible = true end
            else
                if item.icon.Visible then item.icon.Visible = false end
            end
        end

        for uid in pairs(valueCache) do
            if not currentUids[uid] then valueCache[uid] = nil end
        end

        local canvasY = bufferCount * 40
        if Lista.CanvasSize.Y.Offset ~= canvasY then
            Lista.CanvasSize = UDim2.new(0, 0, 0, canvasY)
        end
    end

    local function atualizarSeguro()
        local ok, err = pcall(atualizarLista)
        if not ok then warn("[Auto-Steal] " .. tostring(err)) end
    end

    BtnFiltro.MouseButton1Click:Connect(function()
        idxFiltro = idxFiltro + 1
        if idxFiltro > #niveisFiltro then idxFiltro = 1 end
        targetRarityName = niveisFiltro[idxFiltro]
        BtnFiltro.Text = "Filtro: " .. targetRarityName
        for uid, item in pairs(activeItems) do devolverFrame(item) end
        activeItems = {}
        atualizarSeguro()
    end)

    DistInput.FocusLost:Connect(function()
        local valor = tonumber(DistInput.Text)
        if valor and valor > 0 then maxEspDistance = valor
        else DistInput.Text = tostring(maxEspDistance) end
        for uid, item in pairs(activeItems) do devolverFrame(item) end
        activeItems = {}
        atualizarSeguro()
    end)

    local function pararSteal()
        stealActive = false
        if stealBodyVel then
            stealBodyVel:Destroy()
            stealBodyVel = nil
        end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then h.Velocity = Vector3.zero end
    end

    local function acharPromptMaisProximo(refPos)
        if not refPos then return nil end
        local best, bestD = nil, math.huge
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt")
                and obj.Name == "CarryAreaEgg"
                and obj.Parent
                and obj.Parent.Name == "SmartPromptPart"
            then
                local d = (obj.Parent.Position - refPos).Magnitude
                if d < bestD then best, bestD = obj, d end
            end
        end
        return best
    end

    BtnCancelarLoop.MouseButton1Click:Connect(function()
        pararLoop()
    end)

    local function tentarDrop()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end
        local dropGui = pg:FindFirstChild("DropHeldEgg")
        if not dropGui or not dropGui.Enabled then return false end
        local btn = dropGui:FindFirstChild("Button")
        if not btn then return false end

        btn.Active = true
        btn.Selectable = true

        if firesignal then
            pcall(function() firesignal(btn.Activated) end)
            return true
        end
        if mousemoveabs and mouse1click then
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            mousemoveabs(pos.X, pos.Y)
            task.wait(0.03)
            mouse1click()
            return true
        end
        local ok = pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local ctrl = require(RS.Controllers.GUI.AreaEggDropGuiController)
            if type(ctrl.DropFieldEgg) == "function" then
                ctrl:DropFieldEgg()
            end
        end)
        return ok
    end

    local function esperarEDropar(timeout)
        timeout = timeout or AUTO_DROP_TIMEOUT
        local t0 = tick()
        local tentativas = 0
        while (tick() - t0) < timeout do
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local dropGui = pg and pg:FindFirstChild("DropHeldEgg")
            if dropGui and dropGui.Enabled then
                if tentarDrop() then
                    tentativas = tentativas + 1
                    task.wait(0.15)
                    local still = pg:FindFirstChild("DropHeldEgg")
                    if not still or not still.Enabled then
                        return true
                    end
                    if tentativas >= 3 then
                        return true
                    end
                else
                    task.wait(0.1)
                end
            else
                task.wait(0.1)
            end
        end
        return false
    end

    BtnSteal.MouseButton1Click:Connect(function()
        if stealActive then
            pararSteal()
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            return
        end

        if loopActive then pararLoop() end

        local alvo = _topTarget
        if not alvo then
            BtnSteal.Text = "SEM ALVO"
            task.wait(1)
            BtnSteal.Text = "STEAL TOP"
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        stealActive = true
        BtnSteal.Text = "PARAR (0m)"
        BtnSteal.BackgroundColor3 = TEMA.perigo

        stealBodyVel = Instance.new("BodyVelocity")
        stealBodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        stealBodyVel.P = 1250
        stealBodyVel.Velocity = Vector3.zero
        stealBodyVel.Parent = hrp

        local targetUid = alvo.uid
        local targetPos = alvo.record.BoundsCFrame and alvo.record.BoundsCFrame.Position or nil
        if not targetPos then
            pararSteal()
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            return
        end

        while stealActive do
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h or not stealBodyVel or not stealBodyVel.Parent then break end

            local found = false
            local ok, snap = pcall(EggState.ReadFieldEggs)
            if ok and snap and snap.Records then
                for _, rec in ipairs(snap.Records) do
                    if rec.Uid == targetUid and rec.BoundsCFrame then
                        targetPos = rec.BoundsCFrame.Position
                        found = true
                        break
                    end
                end
            end
            if not found then break end

            local myPos = h.Position
            local diff = targetPos - myPos
            local horiz = Vector3.new(diff.X, 0, diff.Z)
            local dist = horiz.Magnitude

            BtnSteal.Text = string.format("PARAR (%dm)", math.floor(dist))
            if dist < 1 then break end

            local dir = horiz.Unit
            local speed = dist < 6 and math.max(30, dist * 30) or 250
            stealBodyVel.Velocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
            RunService.Heartbeat:Wait()
        end

        if stealBodyVel then
            stealBodyVel:Destroy()
            stealBodyVel = nil
        end
        local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if h2 then h2.Velocity = Vector3.zero end

        if not stealActive then
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            return
        end

        BtnSteal.Text = "SEGURANDO..."
        local prompt = acharPromptMaisProximo(targetPos)
        if prompt then
            local done = false
            local conn
            conn = prompt.Triggered:Connect(function(plr)
                if plr == LocalPlayer then done = true end
            end)
            pcall(function() prompt:InputHoldBegin() end)
            local holdTime = prompt.HoldDuration or 1.2
            local t0 = tick()
            while not done and (tick() - t0) < (holdTime + 1.5) do
                RunService.Heartbeat:Wait()
            end
            pcall(function() prompt:InputHoldEnd() end)
            if conn then conn:Disconnect() end
        end

        BtnSteal.Text = "TELEPORTANDO..."
        local tpOk = false
        teleportarDisfarcado(LOOP_POSITION, function(sucesso)
            tpOk = sucesso
            if sucesso then
                iniciarLoop(LOOP_POSITION)
            end
        end)

        if not tpOk then
            stealActive = false
            BtnSteal.Text = "FALHA NO TP"
            task.wait(1.5)
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            return
        end

        BtnSteal.Text = "LOOPANDO..."
        task.wait(WAIT_LOOP_ANTES_DROP)

        BtnSteal.Text = "DROPANDO..."
        local dropOk = esperarEDropar(AUTO_DROP_TIMEOUT)
        if not dropOk then
            pararLoop()
            stealActive = false
            BtnSteal.Text = "FALHA DROP"
            task.wait(2)
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            return
        end

        pararLoop()
        BtnSteal.Text = "✅ SUCESSO!"
        BtnSteal.BackgroundColor3 = TEMA.destaque

        task.wait(WAIT_APOS_DROP)

        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h then
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
            stealActive = false
            return
        end

        local promptRetorno = acharPromptMaisProximo(h.Position)
        if promptRetorno then
            BtnSteal.Text = "SEGURANDO VOLTA..."
            pcall(function() promptRetorno:InputHoldBegin() end)
            task.wait(promptRetorno.HoldDuration or HOLD_DURATION_RETORNO)
            pcall(function() promptRetorno:InputHoldEnd() end)
        end

        BtnSteal.Text = "VOLTANDO..."
        if not SPAWN_POSITION then
            SPAWN_POSITION = acharSpawnNoWorkspace()
        end
        local destino = SPAWN_POSITION

        if destino then
            walkNormalTo(destino, function(chegou)
                BtnSteal.Text = chegou and "CHEGOU!" or "TIMEOUT VOLTA"
                task.wait(1)
                BtnSteal.Text = "STEAL TOP"
                BtnSteal.BackgroundColor3 = TEMA.destaque
            end)
        else
            BtnSteal.Text = "SEM SPAWN"
            task.wait(1.5)
            BtnSteal.Text = "STEAL TOP"
            BtnSteal.BackgroundColor3 = TEMA.destaque
        end

        stealActive = false
    end)

    local function hookChar(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then lastDeathPos = hrp.Position end
            end)
        end
    end

    if LocalPlayer.Character then hookChar(LocalPlayer.Character) end

    LocalPlayer.CharacterAdded:Connect(function(char)
        hookChar(char)

        if not SPAWN_POSITION then
            task.spawn(function()
                local t0 = tick()
                while not SPAWN_POSITION and (tick() - t0) < 5 do
                    SPAWN_POSITION = acharSpawnNoWorkspace()
                    if not SPAWN_POSITION then task.wait(0.3) end
                end
            end)
        end

        if loopActive then
            if loopConn then
                loopConn:Disconnect()
                loopConn = nil
            end
            local alvoRetorno = lastDeathPos or loopPos
            task.wait(RESPAWN_WAIT)
            if not loopActive then return end
            local hrp = char:WaitForChild("HumanoidRootPart", 10)
            if not hrp then return end
            tweenPara(alvoRetorno, RESPAWN_TWEEN_TIME, function()
                if loopActive and loopPos then
                    iniciarLoop(loopPos)
                end
            end)
        end
    end)

    RunService:BindToRenderStep("AutoSteal_Update", Enum.RenderPriority.Last.Value, atualizarSeguro)

    task.spawn(function()
        while AutoSteal.gui and AutoSteal.gui.Parent do
            task.wait(0.1)
            if AutoSteal.aberto then
                atualizarSeguro()
            end
        end
    end)

    AutoSteal.gui = SG
    return SG
end

local function toggleAutoSteal()
    if not AutoSteal.gui then
        criarAutoStealGui()
    end
    AutoSteal.aberto = not AutoSteal.aberto
    AutoSteal.gui.Enabled = AutoSteal.aberto
    if AutoSteal.aberto then
        Toast("AUTO-STEAL ON", VERDE)
    else
        Toast("AUTO-STEAL OFF", AMARELO)
    end
end

-- Faixa base + rodapé
local faixaBase = Instance.new("Frame")
faixaBase.Size = UDim2.new(1, -16, 0, 2)
faixaBase.Position = UDim2.new(0, 8, 1, -26)
faixaBase.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
faixaBase.BorderSizePixel = 0
faixaBase.ZIndex = 3
faixaBase.Parent = menu
local gradBase = Instance.new("UIGradient")
gradBase.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.00, 1),
    NumberSequenceKeypoint.new(0.20, 0),
    NumberSequenceKeypoint.new(0.80, 0),
    NumberSequenceKeypoint.new(1.00, 1),
})
gradBase.Color = ColorSequence.new(ROXO, Color3.fromRGB(200, 130, 255))
gradBase.Parent = faixaBase

local rodape = Instance.new("Frame")
rodape.Size = UDim2.new(1, 0, 0, 20)
rodape.Position = UDim2.new(0, 0, 1, -23)
rodape.BackgroundTransparency = 1
rodape.ZIndex = 3
rodape.Parent = menu

local ledRodape = Instance.new("Frame")
ledRodape.Size = UDim2.new(0, 6, 0, 6)
ledRodape.Position = UDim2.new(0, 10, 0, 7)
ledRodape.BackgroundColor3 = VERMELHO
ledRodape.BorderSizePixel = 0
ledRodape.ZIndex = 4
ledRodape.Parent = rodape
Instance.new("UICorner", ledRodape).CornerRadius = UDim.new(1, 0)

local labelStatus = Instance.new("TextLabel")
labelStatus.Size = UDim2.new(1, -26, 1, 0)
labelStatus.Position = UDim2.new(0, 22, 0, 0)
labelStatus.BackgroundTransparency = 1
labelStatus.Font = Enum.Font.GothamBold
labelStatus.TextSize = 9
labelStatus.TextColor3 = Color3.fromRGB(200, 200, 220)
labelStatus.TextXAlignment = Enum.TextXAlignment.Left
labelStatus.Text = "STATUS: INATIVO"
labelStatus.ZIndex = 4
labelStatus.Parent = rodape

-- Minimizar
local corpoPainel = { faixaTopo, tabBarHolder, containerFunc, containerTps, containerSpeed, containerHop, faixaBase, rodape }
local minimizado = false
local tamanhoNormal = UDim2.new(0, 200, 0, 220)
local tamanhoMin    = UDim2.new(0, 200, 0, 36)

btnMin.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    if minimizado then
        for _, obj in ipairs(corpoPainel) do obj.Visible = false end
        btnMin.Text = "□"
    else
        for _, obj in ipairs(corpoPainel) do obj.Visible = true end
        btnMin.Text = "—"
        atualizarAbas()
    end
    TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = minimizado and tamanhoMin or tamanhoNormal
    }):Play()
end)

-- Callbacks
btnInvisible.MouseButton1Click:Connect(function()
    bounceInvisible()
    toggleInvisibleEgg()
end)

btnAnti.MouseButton1Click:Connect(function()
    bounceAnti()
    toggleAntiBoss()
end)

btnTrap.MouseButton1Click:Connect(function()
    bounceTrap()
    AntiTrap.toggle()
end)

btnKB.MouseButton1Click:Connect(function()
    bounceKB()
    AntiKB = not AntiKB
    if AntiKB then
        Toast("Anti-KB ON", VERDE)
    else
        ultimaPosKB = nil
        Toast("Anti-KB OFF", AMARELO)
    end
end)

btnDst.MouseButton1Click:Connect(function()
    bounceDst()
    if not Teleporte.refs() then return end
    Destino.posicao   = Teleporte.root.Position
    Destino.usarSpawn = false
end)

btnReset.MouseButton1Click:Connect(function()
    bounceReset()
    Destino.posicao   = nil
    Destino.usarSpawn = true
end)

btnFlutuante.MouseButton1Click:Connect(function()
    bounceFlutuante()
    togglePainelFlutuante()
end)

btnAutoSteal.MouseButton1Click:Connect(function()
    bounceAutoSteal()
    toggleAutoSteal()
end)

btnTpArea2.MouseButton1Click:Connect(function()
    executarTpAreaIntegrado(
        AreaSelecionada,
        function(txt, cor)
            statusAreaLbl.Text = txt
            statusAreaLbl.TextColor3 = cor
        end,
        function(txt, cor)
            btnTpArea2.Text = txt
            btnTpArea2.BackgroundColor3 = cor
        end
    )
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.T then
        toggleAntiBoss()
    elseif i.KeyCode == Enum.KeyCode.H then
        AntiKB = not AntiKB
        if AntiKB then Toast("Anti-KB ON", VERDE)
        else ultimaPosKB = nil Toast("Anti-KB OFF", AMARELO) end
    elseif i.KeyCode == Enum.KeyCode.P then
        togglePainelFlutuante()
    end
end)

-- Loops visuais
task.spawn(function()
    while gui.Parent do
        for rot = 0, 360, 6 do
            if not gui.Parent then break end
            gradBorda.Rotation = rot
            task.wait(0.03)
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        TweenService:Create(ledHeader, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
            BackgroundTransparency = 0.4,
            Size = UDim2.new(0, 5, 0, 5),
            Position = UDim2.new(0, 10, 0, 13),
        }):Play()
        task.wait(0.6)
        if not gui.Parent then break end
        TweenService:Create(ledHeader, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 6, 0, 6),
            Position = UDim2.new(0, 10, 0, 13),
        }):Play()
        task.wait(0.6)
    end
end)

task.spawn(function()
    while gui.Parent do
        if InvisibleEgg.aberto then
            contInvisible.BackgroundColor3     = Color3.fromRGB(20, 55, 28)
            barraInvisible.BackgroundColor3    = VERDE
            bordaInvisible.Color               = VERDE
            labelInvisible.TextColor3          = Color3.fromRGB(180, 255, 200)
            setaInvisible.TextColor3           = VERDE
            labelInvisible.Text                = "👻 INVISIBLE EGG  [ON]"
        else
            contInvisible.BackgroundColor3     = BG_BTN
            barraInvisible.BackgroundColor3    = ROXO
            bordaInvisible.Color               = ROXO_DARK
            labelInvisible.TextColor3          = Color3.fromRGB(230, 220, 255)
            setaInvisible.TextColor3           = ROXO
            labelInvisible.Text                = "👻 INVISIBLE EGG"
        end

        if AntiBoss.aberto then
            contAnti.BackgroundColor3     = Color3.fromRGB(20, 55, 28)
            barraAnti.BackgroundColor3    = VERDE
            bordaAnti.Color               = VERDE
            labelAnti.TextColor3          = Color3.fromRGB(180, 255, 200)
            setaAnti.TextColor3           = VERDE
            labelAnti.Text                = "🥚 ANTI-BOSS  [ON]"
        else
            contAnti.BackgroundColor3     = BG_BTN
            barraAnti.BackgroundColor3    = ROXO
            bordaAnti.Color               = ROXO_DARK
            labelAnti.TextColor3          = Color3.fromRGB(230, 220, 255)
            setaAnti.TextColor3           = ROXO
            labelAnti.Text                = "🥚 ANTI-BOSS"
        end

        if AntiTrap.ativo then
            contTrap.BackgroundColor3     = Color3.fromRGB(55, 20, 25)
            barraTrap.BackgroundColor3    = VERMELHO
            bordaTrap.Color               = VERMELHO
            labelTrap.TextColor3          = Color3.fromRGB(255, 190, 200)
            setaTrap.TextColor3           = VERMELHO
            labelTrap.Text                = "🚫 ANTI-TRAP  [ON]"
        else
            contTrap.BackgroundColor3     = BG_BTN
            barraTrap.BackgroundColor3    = ROXO
            bordaTrap.Color               = ROXO_DARK
            labelTrap.TextColor3          = Color3.fromRGB(230, 220, 255)
            setaTrap.TextColor3           = ROXO
            labelTrap.Text                = "🚫 ANTI-TRAP"
        end

        if AntiKB then
            contKB.BackgroundColor3       = Color3.fromRGB(20, 55, 28)
            barraKB.BackgroundColor3      = VERDE
            bordaKB.Color                 = VERDE
            labelKB.TextColor3            = Color3.fromRGB(180, 255, 200)
            setaKB.TextColor3             = VERDE
            labelKB.Text                  = "💫 ANTI-KNOCKBACK  [ON]"
        else
            contKB.BackgroundColor3       = BG_BTN
            barraKB.BackgroundColor3      = ROXO
            bordaKB.Color                 = ROXO_DARK
            labelKB.TextColor3            = Color3.fromRGB(230, 220, 255)
            setaKB.TextColor3             = ROXO
            labelKB.Text                  = "💫 ANTI-KNOCKBACK"
        end

        if Destino.usarSpawn then
            contDst.BackgroundColor3      = BG_BTN
            barraDst.BackgroundColor3     = ROXO
            bordaDst.Color                = ROXO_DARK
            labelDst.TextColor3           = Color3.fromRGB(230, 220, 255)
            labelDst.Text                 = "📍 DEFINIR DESTINO"
        else
            contDst.BackgroundColor3      = Color3.fromRGB(20, 45, 55)
            barraDst.BackgroundColor3     = Color3.fromRGB(80, 200, 240)
            bordaDst.Color                = Color3.fromRGB(80, 200, 240)
            labelDst.TextColor3           = Color3.fromRGB(180, 230, 255)
            labelDst.Text                 = "✅ DESTINO SALVO"
        end

        if PainelFlutuante.aberto then
            contFlutuante.BackgroundColor3   = Color3.fromRGB(20, 55, 28)
            barraFlutuante.BackgroundColor3  = VERDE
            bordaFlutuante.Color             = VERDE
            labelFlutuante.TextColor3        = Color3.fromRGB(180, 255, 200)
            setaFlutuante.TextColor3         = VERDE
            labelFlutuante.Text              = "🌌 TP-EGG  [ON]"
        else
            contFlutuante.BackgroundColor3   = BG_BTN
            barraFlutuante.BackgroundColor3  = ROXO
            bordaFlutuante.Color             = ROXO_DARK
            labelFlutuante.TextColor3        = Color3.fromRGB(230, 220, 255)
            setaFlutuante.TextColor3         = ROXO
            labelFlutuante.Text              = "🌌 TP-EGG"
        end

        if AutoSteal.aberto then
            contAutoSteal.BackgroundColor3   = Color3.fromRGB(20, 55, 28)
            barraAutoSteal.BackgroundColor3  = VERDE
            bordaAutoSteal.Color             = VERDE
            labelAutoSteal.TextColor3        = Color3.fromRGB(180, 255, 200)
            setaAutoSteal.TextColor3         = VERDE
            labelAutoSteal.Text              = "🤖 AUTO-STEAL  [ON]"
        else
            contAutoSteal.BackgroundColor3   = BG_BTN
            barraAutoSteal.BackgroundColor3  = ROXO
            bordaAutoSteal.Color             = ROXO_DARK
            labelAutoSteal.TextColor3        = Color3.fromRGB(230, 220, 255)
            setaAutoSteal.TextColor3         = ROXO
            labelAutoSteal.Text              = "🤖 AUTO-STEAL"
        end

        if InvisibleEgg.ativado and not (Teleporte.ativo or Disfarce.ativo) then
            ledRodape.BackgroundColor3    = Color3.fromRGB(180, 200, 255)
            labelStatus.TextColor3        = Color3.fromRGB(180, 200, 255)
            labelStatus.Text              = "STATUS: INVISIBLE EGG ON"
        elseif AntiBoss.ativado and not (Teleporte.ativo or Disfarce.ativo) then
            ledRodape.BackgroundColor3    = VERDE
            labelStatus.TextColor3        = VERDE
            labelStatus.Text              = "STATUS: ANTI-BOSS ATIVO"
        elseif Teleporte.ativo or Disfarce.ativo then
            ledRodape.BackgroundColor3    = LARANJA
            labelStatus.TextColor3        = LARANJA
            labelStatus.Text              = "STATUS: TELEPORTANDO..."
        elseif AntiTrap.ativo then
            ledRodape.BackgroundColor3    = VERMELHO
            labelStatus.TextColor3        = VERMELHO
            labelStatus.Text              = "STATUS: ANTI-TRAP ON"
        elseif AntiKB then
            ledRodape.BackgroundColor3    = AZUL
            labelStatus.TextColor3        = AZUL
            labelStatus.Text              = "STATUS: ANTI-KB ON"
        else
            ledRodape.BackgroundColor3    = VERMELHO
            labelStatus.TextColor3        = Color3.fromRGB(200, 200, 220)
            labelStatus.Text              = "STATUS: INATIVO"
        end

        task.wait(0.15)
    end
end)

atualizarAbas()

-- BYPASS (Humanoid swap)
do
    local BypassProps = {
        "WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower",
        "MaxHealth", "Health",
        "AutoRotate", "AutoJumpEnabled", "BreakJointsOnDeath",
        "CameraOffset", "DisplayDistanceType",
        "HealthDisplayDistance", "HealthDisplayType",
        "NameDisplayDistance", "NameOcclusion",
        "RequiresNeck", "WalkJumpPower", "HipHeight",
        "RigType", "WalkSpeedCheck", "EvaluateStateMachine",
        "MaxSlopeAngle", "AutomaticScalingEnabled",
    }

    local StateEnums = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.GettingUp,
        Enum.HumanoidStateType.Landed,
        Enum.HumanoidStateType.Flying,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.PlatformStanding,
        Enum.HumanoidStateType.Dead,
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.RunningNoPhysics,
        Enum.HumanoidStateType.StrafingNoPhysics,
        Enum.HumanoidStateType.Jumping,
    }

    local BypassState = {
        Enabled    = false,
        InProgress = false,
        Clone      = nil,
    }

    local function copiarProps(orig, clone)
        for _, prop in ipairs(BypassProps) do
            pcall(function()
                local ok, value = pcall(function() return orig[prop] end)
                if ok and value ~= nil then
                    pcall(function() clone[prop] = value end)
                end
            end)
        end
        pcall(function()
            for k, v in pairs(orig:GetAttributes()) do
                pcall(function() clone:SetAttribute(k, v) end)
            end
        end)
        pcall(function()
            local desc = orig:FindFirstChildOfClass("HumanoidDescription")
            if desc then
                local dc = desc:Clone()
                dc.Parent = clone
            end
        end)
    end

    local function capturarEstados(hum)
        local states = {}
        for _, s in ipairs(StateEnums) do
            local ok, en = pcall(function() return hum:GetStateEnabled(s) end)
            if ok then states[s] = en end
        end
        local cur
        pcall(function() cur = hum:GetState() end)
        return states, cur
    end

    local function reaplicarEstados(hum, states, cur)
        for s, en in pairs(states or {}) do
            pcall(function() hum:SetStateEnabled(s, en) end)
        end
        if cur then
            pcall(function() hum:ChangeState(cur) end)
        end
    end

    local function aplicarBypass(character)
        if BypassState.InProgress then return false end
        BypassState.InProgress = true

        character = character or LocalPlayer.Character
        if not character then
            BypassState.InProgress = false
            return false
        end

        local origHum = character:FindFirstChildOfClass("Humanoid")
        if not origHum then
            pcall(function() origHum = character:WaitForChild("Humanoid", 10) end)
        end
        if not origHum then
            BypassState.InProgress = false
            return false
        end

        local cloneHum
        local okClone = pcall(function() cloneHum = origHum:Clone() end)
        if not okClone or not cloneHum then
            BypassState.InProgress = false
            return false
        end

        local animatorMoved = false
        local animator = origHum:FindFirstChildOfClass("Animator")
        if animator then
            local ok = pcall(function() animator.Parent = cloneHum end)
            animatorMoved = ok
        end

        copiarProps(origHum, cloneHum)
        local states, cur = capturarEstados(origHum)

        pcall(function() cloneHum.Name = "Humanoid" end)
        local okParent = pcall(function() cloneHum.Parent = character end)
        if not okParent then
            if animatorMoved and animator and animator.Parent ~= origHum then
                pcall(function() animator.Parent = origHum end)
            end
            BypassState.InProgress = false
            return false
        end

        task.wait(0.05)
        local okDestroy = pcall(function() origHum:Destroy() end)
        if not okDestroy then
            pcall(function() cloneHum:Destroy() end)
            if animatorMoved and animator and animator.Parent ~= origHum then
                pcall(function() animator.Parent = origHum end)
            end
            BypassState.InProgress = false
            return false
        end

        task.wait(0.05)
        pcall(function()
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CameraSubject = cloneHum
            end
        end)
        reaplicarEstados(cloneHum, states, cur)
        pcall(function()
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Parent = character end
        end)

        BypassState.Clone      = cloneHum
        BypassState.InProgress = false
        return true
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        if BypassState.Enabled then
            aplicarBypass(char)
        end
    end)

    btnBypass.MouseButton1Click:Connect(function()
        bounceBypass()
        if BypassState.Enabled then return end
        BypassState.Enabled = true
        contBypass.BackgroundColor3  = Color3.fromRGB(55, 20, 25)
        barraBypass.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
        bordaBypass.Color            = Color3.fromRGB(255, 70, 90)
        labelBypass.TextColor3       = Color3.fromRGB(255, 190, 200)
        setaBypass.TextColor3        = Color3.fromRGB(255, 70, 90)
        labelBypass.Text             = "🔥 BYPASS  [ON]"
        Toast("Bypass aplicado", Color3.fromRGB(255, 70, 90))
        aplicarBypass(LocalPlayer.Character)
    end)
end
