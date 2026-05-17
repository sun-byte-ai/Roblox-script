-- Ultimate Stealth Regen & Anti-Critical Protection (Fixed Sync)
-- Sửa lỗi đồng bộ máu / Chống xung đột dữ liệu / Kháng bạo kích

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local enabled = false
local loopThread = nil
local damageHook = nil

local currentCharacter = nil
local humanoid = nil
local lastHealth = 100
local isProcessingDamage = false -- Khóa bảo vệ tránh xung đột loop và hook

-- Hàm đồng bộ lại máu an toàn cho toàn bộ script
local function syncHealth(targetHealth)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = targetHealth
		lastHealth = targetHealth
	end
end

local function updateHumanoid(char)
	if not char then return end
	
	-- Dọn dẹp hook cũ trước khi tạo nhân vật mới để tránh rò rỉ bộ nhớ
	if damageHook then 
		damageHook:Disconnect() 
		damageHook = nil 
	end

	humanoid = char:WaitForChild("Humanoid", 5)
	if humanoid then
		lastHealth = humanoid.Health
		
		-- Lắng nghe thay đổi máu
		damageHook = humanoid.HealthChanged:Connect(function(currentHealth)
			if not enabled or isProcessingDamage then return end
			
			-- Phát hiện dính sát thương
			if currentHealth < lastHealth then
				isProcessingDamage = true -- Bật khóa an toàn
				
				local damageTaken = lastHealth - currentHealth
				local maxHp = humanoid.MaxHealth
				local DAMAGE_MULTIPLIER = 0.25 -- Chỉ nhận 25% sát thương gốc
				local CRIT_THRESHOLD = 0.40
				
				local healthToRestore = 0
				
				-- 1. Xử lý khi sát thương quá lớn hoặc máu quá thấp (Sắp chết)
				if damageTaken >= (maxHp * CRIT_THRESHOLD) or currentHealth <= 10 then
					-- Ép giảm chấn thương: Đòn đánh chỉ được gây tối đa 12% tổng máu
					local safeDamage = maxHp * 0.12
					healthToRestore = damageTaken - safeDamage
					
					-- Nếu máu tụt quá sâu gần bằng 0, kích hoạt Cổng Cứu Sinh lập tức
					if currentHealth <= 3 then
						currentHealth = 15 -- Ép nền máu giả định trước khi cộng bù
					end
				else
					-- 2. Xử lý sát thương thông thường
					healthToRestore = damageTaken * (1 - DAMAGE_MULTIPLIER)
				end
				
				-- Giới hạn lượng hồi phục tối đa một nhịp để qua mặt bộ lọc của Server
				local safeRestore = math.clamp(healthToRestore, 0, maxHp * 0.35)
				local finalHealth = math.clamp(currentHealth + safeRestore, 3, maxHp)
				
				-- Đồng bộ kết quả vào hệ thống
				syncHealth(finalHealth)
				
				isProcessingDamage = false -- Mở khóa an toàn
			elseif currentHealth > lastHealth then
				-- Nếu máu tự tăng (nhờ hệ thống hoặc bình máu của game), cập nhật mốc đối chiếu
				lastHealth = currentHealth
			end
		end)
	end
end

-- Theo dõi nhân vật hồi sinh
currentCharacter = lp.Character
if currentCharacter then updateHumanoid(currentCharacter) end

lp.CharacterAdded:Connect(function(newChar)
	currentCharacter = newChar
	task.wait(0.3) -- Đợi nhân vật khởi tạo hoàn chỉnh các thuộc tính vật lý
	updateHumanoid(newChar)
end)

-- Giao diện UI
local gui = Instance.new("ScreenGui")
gui.Name = "System_RenderCore" 
gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)

local button = Instance.new("TextButton")
button.Parent = gui
button.Size = UDim2.new(0, 70, 0, 70)
button.Position = UDim2.new(1, -85, 0.35, 0)
button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
button.Text = "OFF"
button.TextScaled = true
button.TextColor3 = Color3.new(1, 1, 1)
button.BorderSizePixel = 0
button.Active = true
button.Draggable = true 

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

-- VÒNG LẶP HỒI MÁU NỀN TỰ ĐỘNG (Đã sửa lỗi đồng bộ)
local function startSecureLoop()
	while enabled do
		task.wait(0.15) -- Giờ nghỉ của nhịp Server (Bypass Anti-cheat cực tốt)
		
		if not enabled then break end
		
		-- Chỉ hồi phục nền nếu hệ thống không trong trạng thái xử lý dính đòn
		if not isProcessingDamage and currentCharacter and currentCharacter:IsDescendantOf(workspace) and humanoid then
			local currentHp = humanoid.Health
			local maxHp = humanoid.MaxHealth
			
			if currentHp > 0 and currentHp < maxHp then
				local missingHp = maxHp - currentHp
				local maxSafeDelta = maxHp * 0.30 -- Giới hạn 30% tổng máu mỗi nhịp hồi nền
				
				local finalHeal = math.min(missingHp, maxSafeDelta)
				if finalHeal > 0 then
					syncHealth(math.clamp(currentHp + finalHeal, 0, maxHp))
				end
			end
		end
	end
end

-- Cơ chế kích hoạt nút bấm
button.MouseButton1Click:Connect(function()
	enabled = not enabled

	if enabled then
		button.Text = "ON"
		button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
		
		if humanoid then lastHealth = humanoid.Health end
		loopThread = task.spawn(startSecureLoop)
	else
		button.Text = "OFF"
		button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		isProcessingDamage = false
	end
end)
