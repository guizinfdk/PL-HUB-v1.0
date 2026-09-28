local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- MÓDULOS ESP
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

local RARITY_COLOR = {
    ["Light & Dark"]    = Color3.fromRGB(255, 100, 255),
    ["Titan"]           = Color3.fromRGB(255, 80, 80),
    ["Divine"]          = Color3.fromRGB(255, 215, 0),
    ["Transcendent"]    = Color3.fromRGB(255, 180, 255),
    ["Superior"]        = Color3.fromRGB(200, 255, 100),
    ["Eternal"]         = Color3.fromRGB(180, 220, 255),
    ["Limited"]         = Color3.fromRGB(255, 200, 100),
    ["Secret"]          = Color3.fromRGB(255, 100, 200),
    ["Exotic"]          = Color3.fromRGB(255, 140, 60),
    ["Cosmic"]          = Color3.fromRGB(160, 100, 255),
    ["Exclusive"]       = Color3.fromRGB(255, 150, 50),
    ["Admin"]           = Color3.fromRGB(255, 50, 50),
    ["Mythic"]          = Color3.fromRGB(255, 60, 200),
    ["Mythical"]        = Color3.fromRGB(255, 60, 200),
    ["Prismatic"]       = Color3.fromRGB(150, 255, 200),
    ["Rainbow"]         = Color3.fromRGB(255, 120, 120),
    ["Squishy God"]     = Color3.fromRGB(120, 200, 255),
    ["BrainrotGod"]     = Color3.fromRGB(255, 200, 0),
    ["Legendary"]       = Color3.fromRGB(255, 200, 0),
    ["Epic"]            = Color3.fromRGB(180, 80, 255),
    ["Rare"]            = Color3.fromRGB(80, 150, 255),
    ["SuperRare"]       = Color3.fromRGB(80, 200, 255),
    ["Celestial"]       = Color3.fromRGB(200, 220, 255),
    ["Uncommon"]        = Color3.fromRGB(100, 255, 100),
    ["Basic"]           = Color3.fromRGB(200, 200, 200),
    ["Common"]          = Color3.fromRGB(180, 180, 180),
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

-- TP-AREA (lógica)
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
            if v.Name == "Nests" then
                nests = v
                break
            end
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

-- PROMPT
local armado = false
local function ehSmartPrompt(prompt)
    if not prompt then return false end
    local pai = prompt.Parent
    if not pai then return false end
    return pai.Name == NOME_SMART
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if not armado then return end
    if player ~= LocalPlayer then return end
    if not ehSmartPrompt(prompt) then return end
    Teleporte.iniciar()
    Disfarce.iniciar()
end)

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

-- Holder (aumentado pra caber o EggBox)
local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.Size = UDim2.new(0, 280, 0, 400)
holder.Position = UDim2.new(0.5, -140, 0.05, 0)
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
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 22)
tabBar.Position = UDim2.new(0, 8, 0, 38)
tabBar.BackgroundColor3 = BG_BTN
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 3
tabBar.Parent = menu
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local function criarTabBtn(texto, ordem)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/4, -3, 1, -4)
    b.BackgroundColor3 = BG
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(200, 180, 220)
    b.Text = texto
    b.LayoutOrder = ordem
    b.ZIndex = 4
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local btnTabFunc  = criarTabBtn("🎯", 1)
local btnTabTps   = criarTabBtn("🌀", 2)
local btnTabSpeed = criarTabBtn("⚡", 3)
local btnTabEye   = criarTabBtn("👁️", 4)

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

local containerEye = Instance.new("Frame")
containerEye.Size = UDim2.new(1, 0, 1, -98)
containerEye.Position = UDim2.new(0, 0, 0, 64)
containerEye.BackgroundTransparency = 1
containerEye.ZIndex = 3
containerEye.Visible = false
containerEye.Parent = menu

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

-- Scroll Áreas (aba TPs)
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

-- Botão TP-AREA
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

-- Lista de áreas
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
-- ESP STATE (só lista + best egg)
-- ============================================
local espOvosAtivo     = false
local maxEspDistance   = 500
local targetRarityName = "Todos"

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
    local rarityId = (type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name))
        or (type(rarity) == "string" and rarity) or "Common"
    local rInfo = (RarityData and (RarityData.Rarities or RarityData) or {})[rarityId] or {}
    local rarityDisplayName = (type(rInfo) == "table" and (rInfo.DisplayName or rInfo._id))
        or (type(rarity) == "table" and rarity.DisplayName) or rarityId or "Common"

    return rarityDisplayName, RARITY_SCORE_MAP[rarityDisplayName] or 100
end

local function GetPetIcon(record)
    if not record then return nil end

    local rawIcon = record.Icon or record.PetIcon or record.ImageAsset or record.TextureId
    if rawIcon then
        return (type(rawIcon) == "number" or not string.match(tostring(rawIcon), "://"))
            and ("rbxassetid://" .. tostring(rawIcon)) or tostring(rawIcon)
    end

    local targetName = record.Pet or record.PetId or record.PetName
        or record.AssetCategory or record.Category
    if targetName then
        if PetsData then
            local pInfo = (PetsData.Directory or PetsData)[targetName]
            if pInfo and (pInfo.Icon or pInfo.Image or pInfo.AssetId) then
                local img = pInfo.Icon or pInfo.Image or pInfo.AssetId
                return (type(img) == "number" or not string.match(tostring(img), "://"))
                    and ("rbxassetid://" .. tostring(img)) or tostring(img)
            end
        end
        if AssetsData then
            local aInfo = (AssetsData.Directory or AssetsData)[targetName]
            if aInfo and (aInfo.Icon or aInfo.Image or aInfo.AssetId) then
                local img = aInfo.Icon or aInfo.Image or aInfo.AssetId
                return (type(img) == "number" or not string.match(tostring(img), "://"))
                    and ("rbxassetid://" .. tostring(img)) or tostring(img)
            end
        end
    end
    return nil
end

-- ============================================
-- ABA 👁️ — VISUALIZADOR DETALHADO + EGG BOX
-- ============================================
local eyeHeaderLbl = Instance.new("TextLabel")
eyeHeaderLbl.Size = UDim2.new(1, -16, 0, 14)
eyeHeaderLbl.Position = UDim2.new(0, 8, 0, 0)
eyeHeaderLbl.BackgroundTransparency = 1
eyeHeaderLbl.Font = Enum.Font.GothamBold
eyeHeaderLbl.TextSize = 10
eyeHeaderLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
eyeHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
eyeHeaderLbl.Text = "ESP: OFF | Filtro: Todos | 0 ovos"
eyeHeaderLbl.ZIndex = 4
eyeHeaderLbl.Parent = containerEye

-- ============================================
-- EGG BOX — melhor ovo/pet disponível
-- ============================================
local eggBox = Instance.new("Frame")
eggBox.Name = "EggBox"
eggBox.Size = UDim2.new(1, -16, 0, 70)
eggBox.Position = UDim2.new(0, 8, 0, 18)
eggBox.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
eggBox.BorderSizePixel = 0
eggBox.ZIndex = 4
eggBox.Parent = containerEye
Instance.new("UICorner", eggBox).CornerRadius = UDim.new(0, 8)

local eggBoxStroke = Instance.new("UIStroke")
eggBoxStroke.Color = Color3.fromRGB(46, 204, 113)
eggBoxStroke.Thickness = 1.5
eggBoxStroke.Transparency = 0.4
eggBoxStroke.Parent = eggBox

-- Ícone do pet
local petIconFrame = Instance.new("Frame")
petIconFrame.Name = "PetIconFrame"
petIconFrame.Size = UDim2.new(0, 54, 0, 54)
petIconFrame.Position = UDim2.new(0, 8, 0.5, -27)
petIconFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
petIconFrame.BorderSizePixel = 0
petIconFrame.ZIndex = 5
petIconFrame.Parent = eggBox
Instance.new("UICorner", petIconFrame).CornerRadius = UDim.new(0, 6)

local petIconStroke = Instance.new("UIStroke")
petIconStroke.Color = Color3.fromRGB(46, 204, 113)
petIconStroke.Thickness = 1
petIconStroke.Transparency = 0.5
petIconStroke.Parent = petIconFrame

local petIcon = Instance.new("ImageLabel")
petIcon.Name = "PetIcon"
petIcon.Size = UDim2.new(1, -6, 1, -6)
petIcon.Position = UDim2.new(0, 3, 0, 3)
petIcon.BackgroundTransparency = 1
petIcon.ScaleType = Enum.ScaleType.Fit
petIcon.Image = ""
petIcon.ZIndex = 6
petIcon.Parent = petIconFrame

-- Nome do ovo
local eggName = Instance.new("TextLabel")
eggName.Name = "EggName"
eggName.Size = UDim2.new(1, -80, 0, 18)
eggName.Position = UDim2.new(0, 70, 0, 8)
eggName.BackgroundTransparency = 1
eggName.Font = Enum.Font.GothamBold
eggName.TextSize = 13
eggName.TextColor3 = Color3.fromRGB(240, 240, 245)
eggName.TextXAlignment = Enum.TextXAlignment.Left
eggName.TextTruncate = Enum.TextTruncate.AtEnd
eggName.Text = "Nenhum ovo detectado"
eggName.ZIndex = 5
eggName.Parent = eggBox

-- Raridade
local eggRarity = Instance.new("TextLabel")
eggRarity.Name = "EggRarity"
eggRarity.Size = UDim2.new(1, -80, 0, 14)
eggRarity.Position = UDim2.new(0, 70, 0, 28)
eggRarity.BackgroundTransparency = 1
eggRarity.Font = Enum.Font.GothamBold
eggRarity.TextSize = 11
eggRarity.TextColor3 = Color3.fromRGB(46, 204, 113)
eggRarity.TextXAlignment = Enum.TextXAlignment.Left
eggRarity.Text = "★ —"
eggRarity.ZIndex = 5
eggRarity.Parent = eggBox

-- Distância + Score
local eggInfo = Instance.new("TextLabel")
eggInfo.Name = "EggInfo"
eggInfo.Size = UDim2.new(1, -80, 0, 12)
eggInfo.Position = UDim2.new(0, 70, 0, 46)
eggInfo.BackgroundTransparency = 1
eggInfo.Font = Enum.Font.Gotham
eggInfo.TextSize = 10
eggInfo.TextColor3 = Color3.fromRGB(170, 180, 200)
eggInfo.TextXAlignment = Enum.TextXAlignment.Left
eggInfo.Text = "📏 —m  ⚖ —"
eggInfo.ZIndex = 5
eggInfo.Parent = eggBox

-- Botão toggle ESP (dentro da aba 👁️)
local btnEyeToggle = Instance.new("TextButton")
btnEyeToggle.Size = UDim2.new(1, -16, 0, 26)
btnEyeToggle.Position = UDim2.new(0, 8, 0, 94)
btnEyeToggle.BackgroundColor3 = BG_BTN
btnEyeToggle.BorderSizePixel = 0
btnEyeToggle.Font = Enum.Font.GothamBold
btnEyeToggle.TextSize = 11
btnEyeToggle.TextColor3 = Color3.fromRGB(255, 190, 200)
btnEyeToggle.Text = "🥚 ESP Ovos: OFF"
btnEyeToggle.ZIndex = 4
btnEyeToggle.Parent = containerEye
Instance.new("UICorner", btnEyeToggle).CornerRadius = UDim.new(0, 6)

-- Botão filtro
local btnEyeFiltro = Instance.new("TextButton")
btnEyeFiltro.Size = UDim2.new(1, -16, 0, 26)
btnEyeFiltro.Position = UDim2.new(0, 8, 0, 124)
btnEyeFiltro.BackgroundColor3 = BG_BTN
btnEyeFiltro.BorderSizePixel = 0
btnEyeFiltro.Font = Enum.Font.GothamBold
btnEyeFiltro.TextSize = 11
btnEyeFiltro.TextColor3 = Color3.fromRGB(230, 220, 255)
btnEyeFiltro.Text = "Filtro: Todos"
btnEyeFiltro.ZIndex = 4
btnEyeFiltro.Parent = containerEye
Instance.new("UICorner", btnEyeFiltro).CornerRadius = UDim.new(0, 6)

local niveisFiltroEye = {
    "Todos","Common","Uncommon","Rare","Epic","Legendary",
    "Mythic","Cosmic","Secret","Eternal","Divine"
}
local idxFiltroEye = 1

btnEyeFiltro.MouseButton1Click:Connect(function()
    idxFiltroEye = idxFiltroEye + 1
    if idxFiltroEye > #niveisFiltroEye then idxFiltroEye = 1 end
    targetRarityName = niveisFiltroEye[idxFiltroEye]
    btnEyeFiltro.Text = "Filtro: " .. targetRarityName
end)

btnEyeToggle.MouseButton1Click:Connect(function()
    espOvosAtivo = not espOvosAtivo
    if espOvosAtivo then
        btnEyeToggle.Text = "🥚 ESP Ovos: ON"
        btnEyeToggle.TextColor3 = VERDE
        Toast("ESP ON", VERDE)
    else
        btnEyeToggle.Text = "🥚 ESP Ovos: OFF"
        btnEyeToggle.TextColor3 = Color3.fromRGB(255, 190, 200)
        Toast("ESP OFF", AMARELO)
    end
end)

-- Scroll de cards (abaixo dos controles)
local scrollEye = Instance.new("ScrollingFrame")
scrollEye.Name = "ScrollEye"
scrollEye.Size = UDim2.new(1, 0, 1, -156)
scrollEye.Position = UDim2.new(0, 0, 0, 154)
scrollEye.BackgroundTransparency = 1
scrollEye.BorderSizePixel = 0
scrollEye.ScrollBarThickness = 4
scrollEye.ScrollBarImageColor3 = ROXO
scrollEye.ScrollBarImageTransparency = 0.3
scrollEye.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollEye.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollEye.ScrollingDirection = Enum.ScrollingDirection.Y
scrollEye.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scrollEye.ZIndex = 3
scrollEye.Parent = containerEye

local eyeLayout = Instance.new("UIListLayout")
eyeLayout.Padding = UDim.new(0, 5)
eyeLayout.SortOrder = Enum.SortOrder.LayoutOrder
eyeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
eyeLayout.Parent = scrollEye

local eyePad = Instance.new("UIPadding")
eyePad.PaddingTop = UDim.new(0, 2)
eyePad.PaddingBottom = UDim.new(0, 4)
eyePad.Parent = scrollEye

local function limparListaEye()
    for _, c in ipairs(scrollEye:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function atualizarListaEye(records)
    table.sort(records, function(a, b) return a.dist < b.dist end)

    eyeHeaderLbl.Text = string.format("ESP: %s | Filtro: %s | %d ovos",
        espOvosAtivo and "ON" or "OFF", targetRarityName, #records)

    limparListaEye()
    if #records == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size              = UDim2.new(1, -8, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text              = "Nenhum ovo detectado."
        empty.TextColor3        = Color3.fromRGB(150, 150, 160)
        empty.Font              = Enum.Font.Gotham
        empty.TextSize          = 10
        empty.TextWrapped       = true
        empty.LayoutOrder       = 1
        empty.Parent            = scrollEye
        return
    end

    for i, rec in ipairs(records) do
        if i > 40 then break end

        local rarCor = RARITY_COLOR[rec.rarity] or ROXO

        local card = Instance.new("Frame")
        card.Size             = UDim2.new(1, -8, 0, 64)
        card.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
        card.BorderSizePixel  = 0
        card.LayoutOrder      = i
        card.Parent           = scrollEye

        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke")
        stroke.Color        = rarCor
        stroke.Thickness    = 1
        stroke.Transparency = 0.4
        stroke.Parent       = card

        local barra = Instance.new("Frame")
        barra.Size             = UDim2.new(0, 3, 1, -10)
        barra.Position         = UDim2.new(0, 4, 0, 5)
        barra.BackgroundColor3 = rarCor
        barra.BorderSizePixel  = 0
        barra.Parent           = card

        Instance.new("UICorner", barra).CornerRadius = UDim.new(0, 2)

        local imgFrame = Instance.new("Frame")
        imgFrame.Size             = UDim2.new(0, 48, 0, 48)
        imgFrame.Position         = UDim2.new(0, 12, 0, 8)
        imgFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
        imgFrame.BorderSizePixel  = 0
        imgFrame.Parent           = card

        Instance.new("UICorner", imgFrame).CornerRadius = UDim.new(0, 5)

        local imgStroke = Instance.new("UIStroke")
        imgStroke.Color        = rarCor
        imgStroke.Thickness    = 1
        imgStroke.Transparency = 0.5
        imgStroke.Parent       = imgFrame

        local img = Instance.new("ImageLabel")
        img.Size              = UDim2.new(1, -4, 1, -4)
        img.Position          = UDim2.new(0, 2, 0, 2)
        img.BackgroundTransparency = 1
        img.ScaleType         = Enum.ScaleType.Fit
        img.Image             = rec.icon or ""
        img.Parent            = imgFrame

        local nameL = Instance.new("TextLabel")
        nameL.Size              = UDim2.new(1, -80, 0, 14)
        nameL.Position          = UDim2.new(0, 66, 0, 6)
        nameL.BackgroundTransparency = 1
        nameL.Text              = rec.name or "?"
        nameL.TextColor3        = Color3.fromRGB(240, 240, 245)
        nameL.Font              = Enum.Font.GothamBold
        nameL.TextSize          = 11
        nameL.TextXAlignment    = Enum.TextXAlignment.Left
        nameL.TextTruncate      = Enum.TextTruncate.AtEnd
        nameL.Parent            = card

        local rarL = Instance.new("TextLabel")
        rarL.Size              = UDim2.new(1, -80, 0, 12)
        rarL.Position          = UDim2.new(0, 66, 0, 20)
        rarL.BackgroundTransparency = 1
        rarL.Text              = "★ " .. (rec.rarity or "?")
        rarL.TextColor3        = rarCor
        rarL.Font              = Enum.Font.GothamBold
        rarL.TextSize          = 9
        rarL.TextXAlignment    = Enum.TextXAlignment.Left
        rarL.Parent            = card

        local distL = Instance.new("TextLabel")
        distL.Size              = UDim2.new(1, -80, 0, 12)
        distL.Position          = UDim2.new(0, 66, 0, 32)
        distL.BackgroundTransparency = 1
        distL.Text              = "📏 " .. rec.dist .. "m  ⚖ " .. (RARITY_SCORE_MAP[rec.rarity] or 100)
        distL.TextColor3        = Color3.fromRGB(150, 150, 160)
        distL.Font              = Enum.Font.Gotham
        distL.TextSize          = 9
        distL.TextXAlignment    = Enum.TextXAlignment.Left
        distL.Parent            = card

        if i == 1 then
            local badge = Instance.new("TextLabel")
            badge.Size              = UDim2.new(0, 56, 0, 12)
            badge.Position          = UDim2.new(1, -62, 1, -16)
            badge.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            badge.BorderSizePixel  = 0
            badge.Text              = "PRÓXIMO"
            badge.TextColor3        = Color3.fromRGB(12, 14, 18)
            badge.Font              = Enum.Font.GothamBlack
            badge.TextSize          = 8
            badge.Parent            = card

            Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 3)
        end
    end
end

-- Atualiza a EggBox com o melhor ovo
local function atualizarEggBox(bestRecord)
    if not bestRecord then
        eggName.Text   = "Nenhum ovo detectado"
        eggName.TextColor3 = Color3.fromRGB(150, 150, 160)
        eggRarity.Text = "★ —"
        eggRarity.TextColor3 = Color3.fromRGB(100, 100, 110)
        eggInfo.Text   = "📏 —m  ⚖ —"
        petIcon.Image  = ""
        petIcon.Visible = false
        eggBoxStroke.Color = Color3.fromRGB(46, 204, 113)
        petIconStroke.Color = Color3.fromRGB(46, 204, 113)
        return
    end

    local rarityName = bestRecord.rarity or "Common"
    local score      = RARITY_SCORE_MAP[rarityName] or 100
    local rarCor     = RARITY_COLOR[rarityName] or Color3.fromRGB(46, 204, 113)

    eggName.Text   = bestRecord.name or "Ovo"
    eggName.TextColor3 = Color3.fromRGB(240, 240, 245)

    eggRarity.Text = "★ " .. rarityName
    eggRarity.TextColor3 = rarCor

    eggInfo.Text = string.format("📏 %dm  ⚖ %d", bestRecord.dist or 0, score)

    local iconId = GetPetIcon(bestRecord)
    if iconId then
        petIcon.Image = iconId
        petIcon.Visible = true
    else
        petIcon.Image = ""
        petIcon.Visible = false
    end

    eggBoxStroke.Color = rarCor
    petIconStroke.Color = rarCor
end

-- ============================================
-- SISTEMA DE ABAS
-- ============================================
local abaAtiva = 1
local function atualizarAbas()
    containerFunc.Visible  = (abaAtiva == 1)
    containerTps.Visible   = (abaAtiva == 2)
    containerSpeed.Visible = (abaAtiva == 3)
    containerEye.Visible   = (abaAtiva == 4)

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
    setCor(btnTabEye,   abaAtiva == 4)
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

btnTabEye.MouseButton1Click:Connect(function()
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

local btnAnti,  contAnti,  labelAnti,  setaAnti,  barraAnti,  bordaAnti,  bounceAnti  =
    criarBotaoCyber(30, "🥚 ANTI-BOSS", 1)

local btnTrap,  contTrap,  labelTrap,  setaTrap,  barraTrap,  bordaTrap,  bounceTrap  =
    criarBotaoCyber(30, "🚫 ANTI-TRAP", 2)

local btnKB,    contKB,    labelKB,    setaKB,    barraKB,    bordaKB,    bounceKB    =
    criarBotaoCyber(30, "💫 ANTI-KNOCKBACK", 3)

local btnBypass, contBypass, labelBypass, setaBypass, barraBypass, bordaBypass, bounceBypass =
    criarBotaoCyber(30, "🔥 BYPASS", 4)

local btnESP,   contESP,   labelESP,   setaESP,   barraESP,   bordaESP,   bounceESP   =
    criarBotaoCyber(30, "🥚 ESP OVOS", 5)

local btnDst,   contDst,   labelDst,   setaDst,   barraDst,   bordaDst,   bounceDst   =
    criarBotaoCyber(30, "📍 DEFINIR DESTINO", 6)

local btnReset, contReset, labelReset, setaReset, barraReset, bordaReset, bounceReset =
    criarBotaoCyber(30, "🎯 RESET SPAWN", 7)

local btnFlutuante, contFlutuante, labelFlutuante, setaFlutuante,
      barraFlutuante, bordaFlutuante, bounceFlutuante =
    criarBotaoCyber(30, "🌌 TP-EGG", 8)

-- ============================================
-- PAINEL FLUTUANTE INTEGRADO
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
            if d.Name == "GuardAreas" then guardAreas = d; break end
        end
        if not guardAreas then
            log("GuardAreas NAO encontrado.", Color3.fromRGB(240, 120, 120))
            return nil
        end
        local forest
        for _, d in ipairs(guardAreas:GetDescendants()) do
            if d.Name == "Forest" then forest = d; break end
        end
        if not forest then
            log("Forest NAO encontrado.", Color3.fromRGB(240, 120, 120))
            return nil
        end
        local nests = forest:FindFirstChild("Nests")
        if not nests then
            for _, d in ipairs(forest:GetDescendants()) do
                if d.Name == "Nests" then nests = d; break end
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
local corpoPainel = { faixaTopo, tabBar, containerFunc, containerTps, containerSpeed, containerEye, faixaBase, rodape }
local minimizado = false
local tamanhoNormal = UDim2.new(0, 280, 0, 400)
local tamanhoMin    = UDim2.new(0, 280, 0, 36)

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
btnAnti.MouseButton1Click:Connect(function()
    bounceAnti()
    armado = not armado
    if not armado then Teleporte.parar() Disfarce.limpar() end
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

btnESP.MouseButton1Click:Connect(function()
    bounceESP()
    espOvosAtivo = not espOvosAtivo
    if espOvosAtivo then
        Toast("ESP ON", VERDE)
        btnEyeToggle.Text = "🥚 ESP Ovos: ON"
        btnEyeToggle.TextColor3 = VERDE
    else
        Toast("ESP OFF", AMARELO)
        btnEyeToggle.Text = "🥚 ESP Ovos: OFF"
        btnEyeToggle.TextColor3 = Color3.fromRGB(255, 190, 200)
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
        armado = not armado
        if not armado then Teleporte.parar() Disfarce.limpar() end
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
        if espOvosAtivo then
            contESP.BackgroundColor3       = Color3.fromRGB(20, 55, 28)
            barraESP.BackgroundColor3      = VERDE
            bordaESP.Color                 = VERDE
            labelESP.TextColor3            = Color3.fromRGB(180, 255, 200)
            setaESP.TextColor3             = VERDE
            labelESP.Text                  = "🥚 ESP OVOS  [ON]"
        else
            contESP.BackgroundColor3       = BG_BTN
            barraESP.BackgroundColor3      = ROXO
            bordaESP.Color                 = ROXO_DARK
            labelESP.TextColor3            = Color3.fromRGB(230, 220, 255)
            setaESP.TextColor3             = ROXO
            labelESP.Text                  = "🥚 ESP OVOS"
        end

        if armado then
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

        if espOvosAtivo then
            ledRodape.BackgroundColor3    = VERDE
            labelStatus.TextColor3        = VERDE
            labelStatus.Text              = "STATUS: ESP ATIVO"
        elseif AntiTrap.ativo and not (Teleporte.ativo or Disfarce.ativo) then
            ledRodape.BackgroundColor3    = VERMELHO
            labelStatus.TextColor3        = VERMELHO
            labelStatus.Text              = "STATUS: ANTI-TRAP ON"
        elseif Teleporte.ativo or Disfarce.ativo then
            ledRodape.BackgroundColor3    = LARANJA
            labelStatus.TextColor3        = LARANJA
            labelStatus.Text              = "STATUS: TELEPORTANDO..."
        elseif armado then
            ledRodape.BackgroundColor3    = VERDE
            labelStatus.TextColor3        = VERDE
            labelStatus.Text              = "STATUS: ARMADO"
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

-- ESP LOOP PRINCIPAL (lista + melhor ovo)
task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        pcall(function()
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = hrp and hrp.Position or Vector3.zero

            if espOvosAtivo and EggState and EggState.ReadFieldEggs then
                local ok, snapshot = pcall(EggState.ReadFieldEggs)
                if ok and snapshot and snapshot.Records then
                    local visiveis = {}
                    local melhorOvo = nil
                    local melhorScore = -1

                    for _, record in ipairs(snapshot.Records) do
                        if record.State == "Slot" and record.BoundsCFrame then
                            local eggPos = record.BoundsCFrame.Position
                            local dist   = math.floor((eggPos - myPos).Magnitude)

                            if dist <= maxEspDistance then
                                local rarityName = GetEggRarityInfo(record)
                                local score = RARITY_SCORE_MAP[rarityName] or 100

                                if targetRarityName == "Todos"
                                or rarityName:lower() == targetRarityName:lower() then

                                    local dados = {
                                        name   = record.AssetCategory or record.Pet or "Ovo",
                                        rarity = rarityName,
                                        dist   = dist,
                                        icon   = GetPetIcon(record),
                                        _record = record,
                                    }
                                    table.insert(visiveis, dados)

                                    if score > melhorScore then
                                        melhorScore = score
                                        melhorOvo = dados
                                    end
                                end
                            end
                        end
                    end

                    atualizarListaEye(visiveis)
                    atualizarEggBox(melhorOvo)
                else
                    atualizarListaEye({})
                    atualizarEggBox(nil)
                end
            else
                atualizarListaEye({})
                atualizarEggBox(nil)
            end
        end)
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
