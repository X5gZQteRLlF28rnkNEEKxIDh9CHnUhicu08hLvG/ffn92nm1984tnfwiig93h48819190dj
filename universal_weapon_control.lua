-- 武器専用 Fire Rate & Spread & Recoil Control Script (完全修正版)
-- 初期設定: 全機能OFF
local FAST_FIRE_ENABLED = false  -- 初期OFF
local NO_RECOIL_ENABLED = false  -- 初期OFF
local SPREAD_ENABLED = false  -- スプレッド制御 初期OFF
local INFINITE_AMMO_ENABLED = false -- 弾薬無限 初期OFF

-- 設定値（スライダーで調整可能）
local FIRE_RATE_MULTIPLIER = 10  -- 発射速度倍率（1=通常、10=10倍速）
local SPREAD_VALUE = 1.0  -- スプレッド倍率（0.0=無し、1.0=通常、2.0=2倍）

-- オリジナル値を保存するテーブル（メモリアドレスベースで管理）
local ORIGINAL_VALUES = {
    RPM = {},
    FireDelay = {},
    FireRate = {},
    Spread = {},
    Recoil = {},
    Ammo = {},
    AmmoInClip = {}
}

-- 値が初回保存されたかを追跡
local INITIAL_SCAN_COMPLETED = false

-- リコイル制御用の設定
local CUSTOM_RECOIL_MULTIPLIER = 0
local CUSTOM_X_SCALE = 0
local CUSTOM_Y_SCALE = 0

-- 最適化用の変数
local RECOIL_TABLES_CACHE = {}
local SPREAD_TABLES_CACHE = {}
local LAST_GC_CHECK = 0
local GC_CHECK_INTERVAL = 8

-- GUI関連の変数
local FireRateGUI = nil
local GUI_VISIBLE = true
local StatusLabel = nil
local RecoilStatusLabel = nil
local SpreadStatusLabel = nil
local AmmoStatusLabel = nil
local ToggleButton = nil
local RecoilToggleButton = nil
local SpreadToggleButton = nil
local AmmoToggleButton = nil
local GunRPMSlider = nil
local SpreadSlider = nil
local GunRPMLabel = nil
local SpreadLabel = nil

-- 必要なサービス
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- プレイヤー情報
local player = Players.LocalPlayer

-- 初回スキャンでオリジナル値を保存
local function performInitialScan()
    if INITIAL_SCAN_COMPLETED then return end
    
    for _, v in pairs(getgc(true)) do
        if typeof(v) == "table" then
            -- RPM値を保存
            if rawget(v, "RPM") and type(rawget(v, "RPM")) == "number" then
                ORIGINAL_VALUES.RPM[v] = rawget(v, "RPM")
            end
            
            -- FireDelay値を保存
            if rawget(v, "FireDelay") and type(rawget(v, "FireDelay")) == "number" then
                ORIGINAL_VALUES.FireDelay[v] = rawget(v, "FireDelay")
            end
            
            -- FireRate値を保存
            if rawget(v, "FireRate") and type(rawget(v, "FireRate")) == "number" then
                ORIGINAL_VALUES.FireRate[v] = rawget(v, "FireRate")
            end
            
            -- Spread関連値を保存
            if rawget(v, "Spread") and type(rawget(v, "Spread")) == "number" then
                ORIGINAL_VALUES.Spread[v] = {
                    Spread = rawget(v, "Spread")
                }
            end
            
            if rawget(v, "SpreadIncrease") and type(rawget(v, "SpreadIncrease")) == "number" then
                if not ORIGINAL_VALUES.Spread[v] then
                    ORIGINAL_VALUES.Spread[v] = {}
                end
                ORIGINAL_VALUES.Spread[v].SpreadIncrease = rawget(v, "SpreadIncrease")
            end
            
            if rawget(v, "MaxSpread") and type(rawget(v, "MaxSpread")) == "number" then
                if not ORIGINAL_VALUES.Spread[v] then
                    ORIGINAL_VALUES.Spread[v] = {}
                end
                ORIGINAL_VALUES.Spread[v].MaxSpread = rawget(v, "MaxSpread")
            end
            
            if rawget(v, "MinSpread") and type(rawget(v, "MinSpread")) == "number" then
                if not ORIGINAL_VALUES.Spread[v] then
                    ORIGINAL_VALUES.Spread[v] = {}
                end
                ORIGINAL_VALUES.Spread[v].MinSpread = rawget(v, "MinSpread")
            end
            
            if rawget(v, "Accuracy") and type(rawget(v, "Accuracy")) == "number" then
                if not ORIGINAL_VALUES.Spread[v] then
                    ORIGINAL_VALUES.Spread[v] = {}
                end
                ORIGINAL_VALUES.Spread[v].Accuracy = rawget(v, "Accuracy")
            end
            
            -- 弾薬値を保存
            if rawget(v, "Ammo") and type(rawget(v, "Ammo")) == "number" then
                ORIGINAL_VALUES.Ammo[v] = rawget(v, "Ammo")
            end
            if rawget(v, "AmmoInClip") and type(rawget(v, "AmmoInClip")) == "number" then
                ORIGINAL_VALUES.AmmoInClip[v] = rawget(v, "AmmoInClip")
            end
        end
    end
    
    INITIAL_SCAN_COMPLETED = true
end

-- 以下、GUI作成やイベント設定、機能適用関数などの既存コード...

-- 弾薬制御関数
function applyInfiniteAmmo(enable)
    if enable == nil then enable = INFINITE_AMMO_ENABLED end
    
    if enable then
        if not INITIAL_SCAN_COMPLETED then
            performInitialScan()
        end
        for table, originalValue in pairs(ORIGINAL_VALUES.Ammo) do
            if typeof(table) == "table" and rawget(table, "Ammo") then
                rawset(table, "Ammo", 9999)
            end
        end
        for table, originalValue in pairs(ORIGINAL_VALUES.AmmoInClip) do
            if typeof(table) == "table" and rawget(table, "AmmoInClip") then
                rawset(table, "AmmoInClip", 9999)
            end
        end
    else
        for table, originalValue in pairs(ORIGINAL_VALUES.Ammo) do
            if typeof(table) == "table" and rawget(table, "Ammo") then
                rawset(table, "Ammo", originalValue)
            end
        end
        for table, originalValue in pairs(ORIGINAL_VALUES.AmmoInClip) do
            if typeof(table) == "table" and rawget(table, "AmmoInClip") then
                rawset(table, "AmmoInClip", originalValue)
            end
        end
    end
end

-- 監視システムの既存関数に弾薬制御を追加
local function startOptimizedMonitoring()
    spawn(function()
        while true do
            pcall(function()
                wait(2)
                if FAST_FIRE_ENABLED then
                    modifyAllWeaponsRPM(true)
                end
                if NO_RECOIL_ENABLED then
                    findAndCacheRecoilTables()
                end
                if SPREAD_ENABLED then
                    applySpreadControl(true)
                end
                if INFINITE_AMMO_ENABLED then
                    applyInfiniteAmmo(true)
                end
            end)
        end
    end)
end

-- 装備監視にも弾薬制御を追加
local function monitorToolEquipping()
    if player and player.Character then
        pcall(function()
            player.Character.ChildAdded:Connect(function(child)
                pcall(function()
                    if child and child:IsA("Tool") then
                        wait(0.1)
                        if FAST_FIRE_ENABLED then
                            modifyAllWeaponsRPM(true)
                        end
                        if NO_RECOIL_ENABLED then
                            applyRecoilControl(true)
                        end
                        if SPREAD_ENABLED then
                            applySpreadControl(true)
                        end
                        if INFINITE_AMMO_ENABLED then
                            applyInfiniteAmmo(true)
                        end
                    end
                end)
            end)
        end)
        
        pcall(function()
            player.CharacterAdded:Connect(function()
                pcall(function()
                    wait(1)
                    INITIAL_SCAN_COMPLETED = false
                    ORIGINAL_VALUES = {
                        RPM = {},
                        FireDelay = {},
                        FireRate = {},
                        Spread = {},
                        Recoil = {},
                        Ammo = {},
                        AmmoInClip = {}
                    }
                    performInitialScan()
                    if NO_RECOIL_ENABLED then
                        applyRecoilControl(true)
                    end
                    if FAST_FIRE_ENABLED then
                        modifyAllWeaponsRPM(true)
                    end
                    if SPREAD_ENABLED then
                        applySpreadControl(true)
                    end
                    if INFINITE_AMMO_ENABLED then
                        applyInfiniteAmmo(true)
                    end
                end)
            end)
        end)
    end
end

-- GUI更新関数に弾薬表示を追加
local function updateGUI()
    if StatusLabel then
        StatusLabel.Text = "Gun RapidFire: " .. (FAST_FIRE_ENABLED and "ENABLED" or "DISABLED")
        StatusLabel.TextColor3 = FAST_FIRE_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    end
    if RecoilStatusLabel then
        RecoilStatusLabel.Text = "No Recoil: " .. (NO_RECOIL_ENABLED and "ENABLED" or "DISABLED")
        RecoilStatusLabel.TextColor3 = NO_RECOIL_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    end
    if SpreadStatusLabel then
        SpreadStatusLabel.Text = "Spread Control: " .. (SPREAD_ENABLED and "ENABLED" or "DISABLED")
        SpreadStatusLabel.TextColor3 = SPREAD_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    end
    if AmmoStatusLabel then
        AmmoStatusLabel.Text = "Infinite Ammo: " .. (INFINITE_AMMO_ENABLED and "ENABLED" or "DISABLED")
        AmmoStatusLabel.TextColor3 = INFINITE_AMMO_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    end
    if ToggleButton then
        ToggleButton.Text = FAST_FIRE_ENABLED and "RapidFire: ON" or "RapidFire: OFF"
        ToggleButton.BackgroundColor3 = FAST_FIRE_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    end
    if RecoilToggleButton then
        RecoilToggleButton.Text = NO_RECOIL_ENABLED and "NO RECOIL: ON" or "NO RECOIL: OFF"
        RecoilToggleButton.BackgroundColor3 = NO_RECOIL_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    end
    if SpreadToggleButton then
        SpreadToggleButton.Text = SPREAD_ENABLED and "Spread: ON" or "Spread: OFF"
        SpreadToggleButton.BackgroundColor3 = SPREAD_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    end
    if AmmoToggleButton then
        AmmoToggleButton.Text = INFINITE_AMMO_ENABLED and "InfAmmo: ON" or "InfAmmo: OFF"
        AmmoToggleButton.BackgroundColor3 = INFINITE_AMMO_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    end
end

-- GUI作成関数の一部（弾薬トグルとステータスを追加）
local function createFireRateGUI()
    if not player then
        player = Players.LocalPlayer
    end
    local playerGui = player:WaitForChild("PlayerGui")
    local existingGUI = playerGui:FindFirstChild("UniversalFireRateControlGUI")
    if existingGUI then existingGUI:Destroy() end
    FireRateGUI = Instance.new("ScreenGui")
    FireRateGUI.Name = "UniversalFireRateControlGUI"
    FireRateGUI.Parent = playerGui
    FireRateGUI.ResetOnSpawn = false
    FireRateGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = FireRateGUI
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0, 20, 0, 20)
    MainFrame.Size = UDim2.new(0, 380, 0, 460)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ZIndex = 10
    MainFrame.Visible = GUI_VISIBLE
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Parent = MainFrame
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 0, 0, 0)
    TitleLabel.Size = UDim2.new(1, 0, 0, 40)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "Universal Weapon Control System"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 14
    TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
    TitleLabel.ZIndex = 11
    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 10, 0, 45)
    StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Gun RapidFire: " .. (FAST_FIRE_ENABLED and "ENABLED" or "DISABLED")
    StatusLabel.TextColor3 = FAST_FIRE_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    StatusLabel.TextSize = 11
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.ZIndex = 11
    RecoilStatusLabel = Instance.new("TextLabel")
    RecoilStatusLabel.Name = "RecoilStatusLabel"
    RecoilStatusLabel.Parent = MainFrame
    RecoilStatusLabel.BackgroundTransparency = 1
    RecoilStatusLabel.Position = UDim2.new(0, 10, 0, 65)
    RecoilStatusLabel.Size = UDim2.new(1, -20, 0, 20)
    RecoilStatusLabel.Font = Enum.Font.Gotham
    RecoilStatusLabel.Text = "No Recoil: " .. (NO_RECOIL_ENABLED and "ENABLED" or "DISABLED")
    RecoilStatusLabel.TextColor3 = NO_RECOIL_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    RecoilStatusLabel.TextSize = 11
    RecoilStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    RecoilStatusLabel.ZIndex = 11
    SpreadStatusLabel = Instance.new("TextLabel")
    SpreadStatusLabel.Name = "SpreadStatusLabel"
    SpreadStatusLabel.Parent = MainFrame
    SpreadStatusLabel.BackgroundTransparency = 1
    SpreadStatusLabel.Position = UDim2.new(0, 10, 0, 85)
    SpreadStatusLabel.Size = UDim2.new(1, -20, 0, 20)
    SpreadStatusLabel.Font = Enum.Font.Gotham
    SpreadStatusLabel.Text = "Spread Control: " .. (SPREAD_ENABLED and "ENABLED" or "DISABLED")
    SpreadStatusLabel.TextColor3 = SPREAD_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    SpreadStatusLabel.TextSize = 11
    SpreadStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpreadStatusLabel.ZIndex = 11
    AmmoStatusLabel = Instance.new("TextLabel")
    AmmoStatusLabel.Name = "AmmoStatusLabel"
    AmmoStatusLabel.Parent = MainFrame
    AmmoStatusLabel.BackgroundTransparency = 1
    AmmoStatusLabel.Position = UDim2.new(0, 10, 0, 105)
    AmmoStatusLabel.Size = UDim2.new(1, -20, 0, 20)
    AmmoStatusLabel.Font = Enum.Font.Gotham
    AmmoStatusLabel.Text = "Infinite Ammo: " .. (INFINITE_AMMO_ENABLED and "ENABLED" or "DISABLED")
    AmmoStatusLabel.TextColor3 = INFINITE_AMMO_ENABLED and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
    AmmoStatusLabel.TextSize = 11
    AmmoStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    AmmoStatusLabel.ZIndex = 11
    ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Parent = MainFrame
    ToggleButton.BackgroundColor3 = FAST_FIRE_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Position = UDim2.new(0, 10, 0, 130)
    ToggleButton.Size = UDim2.new(0, 115, 0, 35)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.Text = FAST_FIRE_ENABLED and "RapidFire: ON" or "RapidFire: OFF"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 10
    ToggleButton.ZIndex = 11
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleButton
    RecoilToggleButton = Instance.new("TextButton")
    RecoilToggleButton.Name = "RecoilToggleButton"
    RecoilToggleButton.Parent = MainFrame
    RecoilToggleButton.BackgroundColor3 = NO_RECOIL_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    RecoilToggleButton.BorderSizePixel = 0
    RecoilToggleButton.Position = UDim2.new(0, 130, 0, 130)
    RecoilToggleButton.Size = UDim2.new(0, 115, 0, 35)
    RecoilToggleButton.Font = Enum.Font.GothamBold
    RecoilToggleButton.Text = NO_RECOIL_ENABLED and "NO RECOIL: ON" or "NO RECOIL: OFF"
    RecoilToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RecoilToggleButton.TextSize = 10
    RecoilToggleButton.ZIndex = 11
    local RecoilToggleCorner = Instance.new("UICorner")
    RecoilToggleCorner.CornerRadius = UDim.new(0, 8)
    RecoilToggleCorner.Parent = RecoilToggleButton
    SpreadToggleButton = Instance.new("TextButton")
    SpreadToggleButton.Name = "SpreadToggleButton"
    SpreadToggleButton.Parent = MainFrame
    SpreadToggleButton.BackgroundColor3 = SPREAD_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    SpreadToggleButton.BorderSizePixel = 0
    SpreadToggleButton.Position = UDim2.new(0, 250, 0, 130)
    SpreadToggleButton.Size = UDim2.new(0, 120, 0, 35)
    SpreadToggleButton.Font = Enum.Font.GothamBold
    SpreadToggleButton.Text = SPREAD_ENABLED and "Spread: ON" or "Spread: OFF"
    SpreadToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpreadToggleButton.TextSize = 10
    SpreadToggleButton.ZIndex = 11
    local SpreadToggleCorner = Instance.new("UICorner")
    SpreadToggleCorner.CornerRadius = UDim.new(0, 8)
    SpreadToggleCorner.Parent = SpreadToggleButton
    AmmoToggleButton = Instance.new("TextButton")
    AmmoToggleButton.Name = "AmmoToggleButton"
    AmmoToggleButton.Parent = MainFrame
    AmmoToggleButton.BackgroundColor3 = INFINITE_AMMO_ENABLED and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 50, 50)
    AmmoToggleButton.BorderSizePixel = 0
    AmmoToggleButton.Position = UDim2.new(0, 10, 0, 170)
    AmmoToggleButton.Size = UDim2.new(0, 115, 0, 35)
    AmmoToggleButton.Font = Enum.Font.GothamBold
    AmmoToggleButton.Text = INFINITE_AMMO_ENABLED and "InfAmmo: ON" or "InfAmmo: OFF"
    AmmoToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AmmoToggleButton.TextSize = 10
    AmmoToggleButton.ZIndex = 11
    local AmmoToggleCorner = Instance.new("UICorner")
    AmmoToggleCorner.CornerRadius = UDim.new(0, 8)
    AmmoToggleCorner.Parent = AmmoToggleButton
    -- (以下、スライダーやその他GUI要素の配置を既存コードに合わせて調整)
    local GunSliderFrame = Instance.new("Frame")
    GunSliderFrame.Name = "GunSliderFrame"
    GunSliderFrame.Parent = MainFrame
    GunSliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    GunSliderFrame.BorderSizePixel = 0
    GunSliderFrame.Position = UDim2.new(0, 10, 0, 220)
    GunSliderFrame.Size = UDim2.new(1, -20, 0, 80)
    GunSliderFrame.ZIndex = 10
    local GunSliderCorner = Instance.new("UICorner")
    GunSliderCorner.CornerRadius = UDim.new(0, 8)
    GunSliderCorner.Parent = GunSliderFrame
    GunRPMLabel = Instance.new("TextLabel")
    GunRPMLabel.Name = "GunRPMLabel"
    GunRPMLabel.Parent = GunSliderFrame
    GunRPMLabel.BackgroundTransparency = 1
    GunRPMLabel.Position = UDim2.new(0, 10, 0, 5)
    GunRPMLabel.Size = UDim2.new(1, -20, 0, 20)
    GunRPMLabel.Font = Enum.Font.Gotham
    GunRPMLabel.Text = string.format("Fire Rate Multiplier: %.1fx", FIRE_RATE_MULTIPLIER)
    GunRPMLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    GunRPMLabel.TextSize = 11
    GunRPMLabel.TextXAlignment = Enum.TextXAlignment.Left
    GunRPMLabel.ZIndex = 11
    local GunSliderContainer = Instance.new("Frame")
    GunSliderContainer.Name = "GunSliderContainer"
    GunSliderContainer.Parent = GunSliderFrame
    GunSliderContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    GunSliderContainer.BorderSizePixel = 0
    GunSliderContainer.Position = UDim2.new(0, 10, 0, 30)
    GunSliderContainer.Size = UDim2.new(1, -20, 0, 40)
    GunSliderContainer.ZIndex = 11
    local GunSliderContainerCorner = Instance.new("UICorner")
    GunSliderContainerCorner.CornerRadius = UDim.new(0, 6)
    GunSliderContainerCorner.Parent = GunSliderContainer
    GunRPMSlider = Instance.new("TextButton")
    GunRPMSlider.Name = "GunRPMSlider"
    GunRPMSlider.Parent = GunSliderContainer
    GunRPMSlider.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    GunRPMSlider.BorderSizePixel = 0
    GunRPMSlider.Position = UDim2.new(0.5, -10, 0.5, -10)
    GunRPMSlider.Size = UDim2.new(0, 20, 0, 20)
    GunRPMSlider.Text = ""
    GunRPMSlider.ZIndex = 12
    local GunSliderButtonCorner = Instance.new("UICorner")
    GunSliderButtonCorner.CornerRadius = UDim.new(0, 10)
    GunSliderButtonCorner.Parent = GunRPMSlider
    local SpreadSliderFrame = Instance.new("Frame")
    SpreadSliderFrame.Name = "SpreadSliderFrame"
    SpreadSliderFrame.Parent = MainFrame
    SpreadSliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SpreadSliderFrame.BorderSizePixel = 0
    SpreadSliderFrame.Position = UDim2.new(0, 10, 0, 310)
    SpreadSliderFrame.Size = UDim2.new(1, -20, 0, 80)
    SpreadSliderFrame.ZIndex = 10
    local SpreadSliderCorner = Instance.new("UICorner")
    SpreadSliderCorner.CornerRadius = UDim.new(0, 8)
    SpreadSliderCorner.Parent = SpreadSliderFrame
    SpreadLabel = Instance.new("TextLabel")
    SpreadLabel.Name = "SpreadLabel"
    SpreadLabel.Parent = SpreadSliderFrame
    SpreadLabel.BackgroundTransparency = 1
    SpreadLabel.Position = UDim2.new(0, 10, 0, 5)
    SpreadLabel.Size = UDim2.new(1, -20, 0, 20)
    SpreadLabel.Font = Enum.Font.Gotham
    SpreadLabel.Text = string.format("Spread Multiplier: %.1fx", SPREAD_VALUE)
    SpreadLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SpreadLabel.TextSize = 11
    SpreadLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpreadLabel.ZIndex = 11
    local SpreadSliderContainer = Instance.new("Frame")
    SpreadSliderContainer.Name = "SpreadSliderContainer"
    SpreadSliderContainer.Parent = SpreadSliderFrame
    SpreadSliderContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SpreadSliderContainer.BorderSizePixel = 0
    SpreadSliderContainer.Position = UDim2.new(0, 10, 0, 30)
    SpreadSliderContainer.Size = UDim2.new(1, -20, 0, 40)
    SpreadSliderContainer.ZIndex = 11
    local SpreadSliderContainerCorner = Instance.new("UICorner")
    SpreadSliderContainerCorner.CornerRadius = UDim.new(0, 6)
    SpreadSliderContainerCorner.Parent = SpreadSliderContainer
    SpreadSlider = Instance.new("TextButton")
    SpreadSlider.Name = "SpreadSlider"
    SpreadSlider.Parent = SpreadSliderContainer
    SpreadSlider.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    SpreadSlider.BorderSizePixel = 0
    SpreadSlider.Position = UDim2.new(0.5, -10, 0.5, -10)
    SpreadSlider.Size = UDim2.new(0, 20, 0, 20)
    SpreadSlider.Text = ""
    SpreadSlider.ZIndex = 12
    local SpreadSliderButtonCorner = Instance.new("UICorner")
    SpreadSliderButtonCorner.CornerRadius = UDim.new(0, 10)
    SpreadSliderButtonCorner.Parent = SpreadSlider
    local ResetButton = Instance.new("TextButton")
    ResetButton.Name = "ResetButton"
    ResetButton.Parent = MainFrame
    ResetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
    ResetButton.BorderSizePixel = 0
    ResetButton.Position = UDim2.new(0, 10, 0, 405)
    ResetButton.Size = UDim2.new(0, 130, 0, 30)
    ResetButton.Font = Enum.Font.Gotham
    ResetButton.Text = "Reset All Settings"
    ResetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetButton.TextSize = 11
    ResetButton.ZIndex = 11
    local ResetCorner = Instance.new("UICorner")
    ResetCorner.CornerRadius = UDim.new(0, 6)
    ResetCorner.Parent = ResetButton
    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Name = "InfoLabel"
    InfoLabel.Parent = MainFrame
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0, 150, 0, 405)
    InfoLabel.Size = UDim2.new(1, -160, 0, 30)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "Press INSERT to toggle GUI\nFire Rate: 1x-20x Speed"
    InfoLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    InfoLabel.TextSize = 9
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
    InfoLabel.ZIndex = 11
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 14
    CloseButton.ZIndex = 11
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 15)
    CloseCorner.Parent = CloseButton
    setupGUIEvents()
    setupSliderEvents()
    return true
end

-- GUIイベントに弾薬トグルを追加
function setupGUIEvents()
    if not FireRateGUI then return end
    local toggleBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("ToggleButton")
    local recoilToggleBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("RecoilToggleButton")
    local spreadToggleBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("SpreadToggleButton")
    local ammoToggleBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("AmmoToggleButton")
    local closeBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("CloseButton")
    local resetBtn = FireRateGUI:FindFirstChild("MainFrame") and FireRateGUI.MainFrame:FindFirstChild("ResetButton")
    if toggleBtn then
        toggleBtn.MouseButton1Click:Connect(function()
            FAST_FIRE_ENABLED = not FAST_FIRE_ENABLED
            modifyAllWeaponsRPM(FAST_FIRE_ENABLED)
            updateGUI()
        end)
    end
    if recoilToggleBtn then
        recoilToggleBtn.MouseButton1Click:Connect(function()
            NO_RECOIL_ENABLED = not NO_RECOIL_ENABLED
            applyRecoilControl(NO_RECOIL_ENABLED)
            updateGUI()
        end)
    end
    if spreadToggleBtn then
        spreadToggleBtn.MouseButton1Click:Connect(function()
            SPREAD_ENABLED = not SPREAD_ENABLED
            applySpreadControl(SPREAD_ENABLED)
            updateGUI()
        end)
    end
    if ammoToggleBtn then
        ammoToggleBtn.MouseButton1Click:Connect(function()
            INFINITE_AMMO_ENABLED = not INFINITE_AMMO_ENABLED
            applyInfiniteAmmo(INFINITE_AMMO_ENABLED)
            updateGUI()
        end)
    end
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            if FireRateGUI then
                FireRateGUI:Destroy()
                FireRateGUI = nil
            end
        end)
    end
    if resetBtn then
        resetBtn.MouseButton1Click:Connect(function()
            FAST_FIRE_ENABLED = false
            NO_RECOIL_ENABLED = false
            SPREAD_ENABLED = false
            INFINITE_AMMO_ENABLED = false
            restoreAllOriginalValues()
            FIRE_RATE_MULTIPLIER = 10
            SPREAD_VALUE = 1.0
            updateGUI()
        end)
    end
end

-- リセット処理に弾薬復元を追加
function restoreAllOriginalValues()
    for table, originalValue in pairs(ORIGINAL_VALUES.RPM) do
        if typeof(table) == "table" and rawget(table, "RPM") then
            rawset(table, "RPM", originalValue)
        end
    end
    for table, originalValue in pairs(ORIGINAL_VALUES.FireDelay) do
        if typeof(table) == "table" and rawget(table, "FireDelay") then
            rawset(table, "FireDelay", originalValue)
        end
    end
    for table, originalValue in pairs(ORIGINAL_VALUES.FireRate) do
        if typeof(table) == "table" and rawget(table, "FireRate") then
            rawset(table, "FireRate", originalValue)
        end
    end
    for table, values in pairs(ORIGINAL_VALUES.Spread) do
        if typeof(table) == "table" then
            if values.Spread and rawget(table, "Spread") then rawset(table, "Spread", values.Spread) end
            if values.SpreadIncrease and rawget(table, "SpreadIncrease") then rawset(table, "SpreadIncrease", values.SpreadIncrease) end
            if values.MaxSpread and rawget(table, "MaxSpread") then rawset(table, "MaxSpread", values.MaxSpread) end
            if values.MinSpread and rawget(table, "MinSpread") then rawset(table, "MinSpread", values.MinSpread) end
            if values.Accuracy and rawget(table, "Accuracy") then rawset(table, "Accuracy", values.Accuracy) end
        end
    end
    for table, values in pairs(ORIGINAL_VALUES.Recoil) do
        if typeof(table) == "table" then
            if values.XScale and rawget(table, "XScale") then rawset(table, "XScale", values.XScale) end
            if values.YScale and rawget(table, "YScale") then rawset(table, "YScale", values.YScale) end
        end
    end
    for table, value in pairs(ORIGINAL_VALUES.Ammo) do
        if typeof(table) == "table" and rawget(table, "Ammo") then
            rawset(table, "Ammo", value)
        end
    end
    for table, value in pairs(ORIGINAL_VALUES.AmmoInClip) do
        if typeof(table) == "table" and rawget(table, "AmmoInClip") then
            rawset(table, "AmmoInClip", value)
        end
    end
end

-- main関数等は既存コードを使用
