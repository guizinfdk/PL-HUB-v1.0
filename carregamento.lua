-- ============================================
-- PL HUB - Painel Cyberpunk com Loading Screen
-- Criado por: SR
-- TK: @PL SCRIPTS
-- ============================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- Remove GUI antiga se existir
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("PLHubGui")
if oldGui then oldGui:Destroy() end

-- Cria a ScreenGui principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PLHubGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ==================== FUNDO ESCURO ====================
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
background.BackgroundTransparency = 1
background.BorderSizePixel = 0
background.ZIndex = 1
background.Parent = screenGui

-- Gradiente de fundo cyberpunk
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 0, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 5, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 0, 40)),
})
bgGradient.Rotation = 45
bgGradient.Parent = background

-- ==================== PAINEL CENTRAL ====================
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 0, 0, 0)
panel.BackgroundColor3 = Color3.fromRGB(8, 5, 25)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.ZIndex = 5
panel.Parent = background

-- Cantos arredondados
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

-- Borda neon rosa/ciano
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(0, 255, 255)
panelStroke.Thickness = 2
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

-- Gradiente interno
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 5, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 5, 60)),
})
panelGradient.Rotation = 135
panelGradient.Parent = panel

-- ==================== TÍTULO "PL HUB" ====================
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.35, 0)
title.Position = UDim2.new(0, 0, 0.08, 0)
title.BackgroundTransparency = 1
title.Text = "PL HUB"
title.Font = Enum.Font.GothamBlack
title.TextSize = 52
title.TextColor3 = Color3.fromRGB(0, 255, 255)
title.TextScaled = false
title.ZIndex = 6
title.Parent = panel

-- Sombra/glow no título
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(255, 0, 200)
titleStroke.Thickness = 2
titleStroke.Transparency = 0.3
titleStroke.Parent = title

-- ==================== SUBTÍTULO ====================
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, 0, 0.15, 0)
subtitle.Position = UDim2.new(0, 0, 0.42, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Criado por: SR"
subtitle.Font = Enum.Font.GothamBold
subtitle.TextSize = 20
subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
subtitle.ZIndex = 6
subtitle.Parent = panel

-- ==================== TK ====================
local tkLabel = Instance.new("TextLabel")
tkLabel.Name = "TKLabel"
tkLabel.Size = UDim2.new(1, 0, 0.12, 0)
tkLabel.Position = UDim2.new(0, 0, 0.55, 0)
tkLabel.BackgroundTransparency = 1
tkLabel.Text = "TK: @PL SCRIPTS"
tkLabel.Font = Enum.Font.GothamMedium
tkLabel.TextSize = 16
tkLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
tkLabel.ZIndex = 6
tkLabel.Parent = panel

-- ==================== BARRA DE CARREGAMENTO ====================
local barBg = Instance.new("Frame")
barBg.Name = "BarBG"
barBg.AnchorPoint = Vector2.new(0.5, 0)
barBg.Position = UDim2.new(0.5, 0, 0.75, 0)
barBg.Size = UDim2.new(0.75, 0, 0, 10)
barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
barBg.BorderSizePixel = 0
barBg.ZIndex = 6
barBg.Parent = panel

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(1, 0)
barBgCorner.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
barFill.BorderSizePixel = 0
barFill.ZIndex = 7
barFill.Parent = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent = barFill

local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 200)),
})
barGradient.Parent = barFill

-- ==================== PORCENTAGEM ====================
local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "Percent"
percentLabel.AnchorPoint = Vector2.new(0.5, 0)
percentLabel.Position = UDim2.new(0.5, 0, 0.87, 0)
percentLabel.Size = UDim2.new(0.8, 0, 0.08, 0)
percentLabel.BackgroundTransparency = 1
percentLabel.Text = "0%"
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 14
percentLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
percentLabel.ZIndex = 6
percentLabel.Parent = panel

-- ==================== ANIMAÇÕES ====================

-- Fade in do fundo
TweenService:Create(background, TweenInfo.new(0.6), {
    BackgroundTransparency = 0
}):Play()

-- Expande o painel
TweenService:Create(panel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 480, 0, 320)
}):Play()

wait(0.7)

-- Efeito de pulso no título
spawn(function()
    while screenGui.Parent do
        local tween1 = TweenService:Create(titleStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Transparency = 0
        })
        tween1:Play()
        tween1.Completed:Wait()
        local tween2 = TweenService:Create(titleStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Transparency = 0.6
        })
        tween2:Play()
        tween2.Completed:Wait()
    end
end)

-- Animação da barra de carregamento
local loadingTime = 3 -- duração em segundos
local steps = 100
local interval = loadingTime / steps

for i = 1, steps do
    local percent = i / steps
    TweenService:Create(barFill, TweenInfo.new(interval, Enum.EasingStyle.Linear), {
        Size = UDim2.new(percent, 0, 1, 0)
    }):Play()

    percentLabel.Text = tostring(math.floor(percent * 100)) .. "%"

    -- Efeito de cor piscando
    if i % 10 == 0 then
        barFill.BackgroundColor3 = Color3.fromRGB(255, 0, 200)
        wait(0.05)
        barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    end

    wait(interval)
end

percentLabel.Text = "100% - PRONTO!"
wait(0.5)

-- ==================== SAÍDA ====================

-- Fade out do painel
TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    Size = UDim2.new(0, 0, 0, 0)
}):Play()

TweenService:Create(background, TweenInfo.new(0.6), {
    BackgroundTransparency = 1
}):Play()

wait(0.7)

-- Remove a GUI completamente
screenGui:Destroy()

print("[PL HUB] Loading screen concluída. Bem-vindo!")
