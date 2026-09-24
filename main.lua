local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = Workspace.CurrentCamera

local VELOCIDADE_RUN    = 1e15
local DISTANCIA_CHEGADA = 4
local IGNORAR_EIXO_Y    = true
local WALK_TEMP         = 500
local JUMP_TEMP         = 120
local DURACAO_TRAVA     = 0.5
local CLONE_SO_PRA_MIM  = true

local PASTA_OVOS        = "AreaEggSlotsClient"

local Destino = { posicao = nil, usarSpawn = true }

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
        if IGNORAR_EIXO_Y then
            delta = Vector3.new(delta.X, 0, delta.Z)
        end
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

local Disfarce = { ativo = false, clone = nil, connCam = nil, thread = nil }

function Disfarce.limpar()
    Disfarce.ativo = false
    if Disfarce.connCam then
        Disfarce.connCam:Disconnect()
        Disfarce.connCam = nil
    end
    local t = Disfarce.thread
    Disfarce.thread = nil
    if t then pcall(task.cancel, t) end
    if Disfarce.clone then
        Disfarce.clone:Destroy()
        Disfarce.clone = nil
    end
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
                    p.Anchored   = true
                    p.CanCollide = false
                    p.CanTouch   = false
                    p.CanQuery   = false
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

-- ============================================================
-- DETECÇÃO — BASEADA NA LÓGICA EXATA
-- ============================================================
-- Model do ovo está FORA de AreaEggSlotsClient
-- Hitbox (Part) ganha WeldConstraint quando segurado
-- Part0 = HumanoidRootPart | Part1 = Hitbox
-- ============================================================

local function encontrarOvoSegurado()
    if not Teleporte.char then return nil end
    local root = Teleporte.char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local pasta = Workspace:FindFirstChild(PASTA_OVOS)

    for _, obj in ipairs(Workspace:GetChildren()) do
        -- Ignora o Folder dos ovos parados
        if obj ~= pasta
            and obj ~= Teleporte.char
            and obj:IsA("Model")
            -- Ignora clones locais
            and not obj.Name:match("^CloneLocal_")
        then
            local hitbox = obj:FindFirstChild("Hitbox")
            if hitbox and hitbox:IsA("Part") then
                local weld = hitbox:FindFirstChildOfClass("WeldConstraint")
                if weld and weld.Part0 == root then
                    return obj
                end
            end
        end
    end
    return nil
end

local armado, ultimoOvo = false, nil

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Teleporte.ativo then Teleporte.parar() end
    Disfarce.limpar()
    Teleporte.refs()
    ultimoOvo = nil
end)

Teleporte.refs()

RunService.Heartbeat:Connect(function()
    if not armado then return end
    if not Teleporte.refs() then return end

    local ovo = encontrarOvoSegurado()
    if ovo then
        if ovo ~= ultimoOvo then
            ultimoOvo = ovo
            Teleporte.iniciar()
            Disfarce.iniciar()
        end
    else
        ultimoOvo = nil
    end
end)

local ROXO      = Color3.fromRGB(140, 80, 255)
local ROXO_DARK = Color3.fromRGB(60, 30, 120)
local VERDE     = Color3.fromRGB(80, 240, 110)
local VERMELHO  = Color3.fromRGB(255, 70, 90)
local LARANJA   = Color3.fromRGB(255, 160, 60)
local BG        = Color3.fromRGB(14, 12, 22)
local BG_BTN    = Color3.fromRGB(28, 22, 42)

local gui = Instance.new("ScreenGui")
gui.Name = "PLHubGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.Size = UDim2.new(0, 180, 0, 160)
holder.Position = UDim2.new(0.5, -90, 0.1, 0)
holder.BackgroundTransparency = 1
holder.Active = true
holder.Draggable = true
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
titulo.Size = UDim2.new(1, -40, 0, 14)
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
subtitulo.Size = UDim2.new(1, -40, 0, 10)
subtitulo.Position = UDim2.new(0, 22, 0, 18)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = Enum.Font.Gotham
subtitulo.TextSize = 8
subtitulo.TextColor3 = Color3.fromRGB(170, 150, 210)
subtitulo.TextXAlignment = Enum.TextXAlignment.Left
subtitulo.Text = "IB: @caligsc"
subtitulo.ZIndex = 4
subtitulo.Parent = header

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

btnFechar.MouseEnter:Connect(function()
    btnFechar.TextColor3 = VERMELHO
end)
btnFechar.MouseLeave:Connect(function()
    btnFechar.TextColor3 = Color3.fromRGB(200, 160, 200)
end)
btnFechar.MouseButton1Click:Connect(function()
    holder.Visible = false
end)

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

local function criarBotaoCyber(yOffset, altura, texto)
    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1, -16, 0, altura)
    cont.Position = UDim2.new(0, 8, 0, yOffset)
    cont.BackgroundColor3 = BG_BTN
    cont.BorderSizePixel = 0
    cont.ZIndex = 3
    cont.Parent = menu

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
            TextTransparency = 0,
            Position = UDim2.new(1, -16, 0, 0),
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(cont, TweenInfo.new(0.2), {
            BackgroundColor3 = BG_BTN,
        }):Play()
        TweenService:Create(bordaBtn, TweenInfo.new(0.2), { Color = ROXO_DARK }):Play()
        TweenService:Create(seta, TweenInfo.new(0.2), {
            TextTransparency = 1,
            Position = UDim2.new(1, -20, 0, 0),
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

local btnAnti, contAnti, labelAnti, setaAnti, barraAnti, bordaAnti, bounceAnti =
    criarBotaoCyber(42, 28, "🥚 ANTI-BOSS")

local btnDst, contDst, labelDst, setaDst, barraDst, bordaDst, bounceDst =
    criarBotaoCyber(74, 24, "📍 DEFINIR DESTINO")

local btnReset, contReset, labelReset, setaReset, barraReset, bordaReset, bounceReset =
    criarBotaoCyber(102, 24, "🎯 RESET SPAWN")

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

btnAnti.MouseButton1Click:Connect(function()
    bounceAnti()
    armado = not armado
    if not armado then
        Teleporte.parar()
        Disfarce.limpar()
        ultimoOvo = nil
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

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.T then
        armado = not armado
        if not armado then
            Teleporte.parar()
            Disfarce.limpar()
            ultimoOvo = nil
        end
    end
end)

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

        if Teleporte.ativo or Disfarce.ativo then
            ledRodape.BackgroundColor3    = LARANJA
            labelStatus.TextColor3        = LARANJA
            labelStatus.Text              = "STATUS: TELEPORTANDO..."
        elseif armado then
            ledRodape.BackgroundColor3    = VERDE
            labelStatus.TextColor3        = VERDE
            labelStatus.Text              = "STATUS: ARMADO"
        else
            ledRodape.BackgroundColor3    = VERMELHO
            labelStatus.TextColor3        = Color3.fromRGB(200, 200, 220)
            labelStatus.Text              = "STATUS: INATIVO"
        end

        task.wait(0.15)
    end
end)
