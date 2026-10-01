--[[
    PL-HUB v1.0 - Loader
    Executa a tela de carregamento e depois o painel principal.
]]

local BASE = "https://raw.githubusercontent.com/guizinfdk/PL-HUB-v1.0/refs/heads/main/"

-- 1. TELA DE CARREGAMENTO
local ok1, err1 = pcall(function()
    loadstring(game:HttpGet(BASE .. "carregamento.lua"))()
end)
if not ok1 then
    warn("[PL-HUB] Erro na tela de carregamento: " .. tostring(err1))
end

-- 2. Espera a tela de carregamento terminar
task.wait(2) -- ajuste o tempo se a sua tela demorar mais

-- 3. PAINEL PRINCIPAL
local ok2, err2 = pcall(function()
    loadstring(game:HttpGet(BASE .. "main.lua"))()
end)
if not ok2 then
    warn("[PL-HUB] Erro no painel principal: " .. tostring(err2))
end
