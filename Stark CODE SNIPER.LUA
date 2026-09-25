```
--[[
  STARK SNIPER V2 — tight capture + no lag type
  - ONLY writes after: code / riddle / code is / riddle is / the code is / the riddle is
  - Riddle & code paths never mix
  - Sammy filter toggle in Settings
  - Small GUI (290x385)
]]

repeat task.wait() until game:IsLoaded()
if getgenv().StarkArcSniper then return warn("[K2] Already running") end
getgenv().StarkArcSniper = true

if not table.clear then function table.clear(t) for k in pairs(t) do t[k]=nil end end end

_G.ScriptEnabled = true
_G.AutoWriteEnabled = false
_G.AutoSubmitEnabled = false
_G.RiddleSolverEnabled = false
_G.SammyFilterEnabled = true
_G.SubmitAfterCount = 1
_G.SubmitAttempts = 3
_G.AnchorEnabled = false
_G.AutoBuyEnabled = false

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Theme = {
	Void = Color3.fromRGB(3, 8, 14),
	Panel = Color3.fromRGB(10, 18, 28),
	PanelSoft = Color3.fromRGB(16, 28, 42),
	Card = Color3.fromRGB(14, 24, 38),
	Cyan = Color3.fromRGB(170, 230, 230),
	Teal = Color3.fromRGB(70, 190, 170),
	Violet = Color3.fromRGB(130, 140, 200),
	Green = Color3.fromRGB(110, 230, 180),
	Amber = Color3.fromRGB(255, 190, 90),
	Red = Color3.fromRGB(255, 110, 120),
	Text = Color3.fromRGB(230, 245, 245),
	Muted = Color3.fromRGB(130, 155, 165),
	ToggleOff = Color3.fromRGB(35, 50, 60),
}
local FT, FB, FM = Enum.Font.GothamBold, Enum.Font.Gotham, Enum.Font.GothamMedium
local TIQ = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TIS = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TIB = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TIL = TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
	return c
end
local function stroke(p, col, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or Theme.Cyan
	s.Thickness = th or 1
	s.Transparency = tr or 0.4
	s.Parent = p
	return s
end

local pendingQueue, pendingSeen, collectedCodes, collectedSeen = {}, {}, {}, {}
local writeBusy = false
local ScreenGui, MainFrame, Orb
local StatusDot, StatusTitle, StatusSub, QueueLabel, CollectedLabel, activityHost, sammyLogHost
local ActivityList = {}
local currentTab = "Main"
local isMinimized = false
local introDone = false

-- capture mode: nil | "code" | "riddle"
local captureMode = nil
local captureUntil = 0
local bufferedParts = {}
local lastSammyText, lastSammyAt = "", 0
local lastQueuedAt = 0

local function pushActivity(text, color)
	if not activityHost then return end
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -4, 0, 14)
	row.BackgroundTransparency = 1
	row.Font = FM
	row.TextSize = 9
	row.TextColor3 = color or Theme.Muted
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = "●  " .. text
	row.TextTransparency = 1
	row.Parent = activityHost
	table.insert(ActivityList, 1, row)
	while #ActivityList > 4 do
		local o = table.remove(ActivityList)
		if o then o:Destroy() end
	end
	for i, r in ipairs(ActivityList) do
		r.LayoutOrder = i
		TS:Create(r, TIS, { TextTransparency = math.min(0.1 + (i - 1) * 0.18, 0.75) }):Play()
	end
end

local function pushSammyLog(text)
	-- removed
end
	text = tostring(text or ""):gsub("%s+", " "):sub(1, 100)
	if text == "" then return end
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -4, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.Font = FB
	row.TextSize = 9
	row.TextColor3 = Theme.Amber
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextWrapped = true
	row.Text = "• " .. text
	row.LayoutOrder = -math.floor(os.clock() * 1000)
	row.Parent = sammyLogHost
	local labels = {}
	for _, k in ipairs(sammyLogHost:GetChildren()) do
		if k:IsA("TextLabel") then table.insert(labels, k) end
	end
	table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #labels > 10 do
		local old = table.remove(labels, 1)
		if old then old:Destroy() end
	end
end

local function setStatus(title, sub, mode)
	if StatusTitle then StatusTitle.Text = title end
	if StatusSub then StatusSub.Text = sub or "" end
	if StatusDot then
		local c = Theme.Cyan
		if mode == "ok" then c = Theme.Green
		elseif mode == "err" then c = Theme.Red
		elseif mode == "wait" then c = Theme.Muted
		elseif mode == "arm" then c = Theme.Amber
		end
		StatusDot.BackgroundColor3 = c
	end
end

local RIDDLE_ANSWERS = {
	["10th machine"] = "NEWYEARSMACHINE", ["10th mutation"] = "PHANTOM",
	["11th machine"] = "DUELSMACHINE", ["11th mutation"] = "CRYSTAL",
	["12th machine"] = "CUPIDSMACHINE", ["13th machine"] = "TRADEMACHINE",
	["14th machine"] = "DIVINEFUSE", ["15th machine"] = "EGGINCUBATOR",
	["16th machine"] = "CYBERCRAFTMACHINE", ["17th machine"] = "SUMMERFUSE",
	["18th machine"] = "LOSTRADERS", ["1st machine"] = "RAINBOWMACHINE",
	["1st mutation"] = "BLOODROT", ["1st trait"] = "LIGHTNING", ["1st trait created"] = "LIGHTNING",
	["2nd machine"] = "BUBBLEGUMMACHINE", ["2nd mutation"] = "CANDY",
	["3rd machine"] = "FUSEMACHINE", ["3rd mutation"] = "LAVA",
	["4th machine"] = "CRAFTMACHINE", ["4th mutation"] = "GALAXY",
	["5th machine"] = "WITCHFUSE", ["5th mutation"] = "YINYANG",
	["67"] = "67", ["6th machine"] = "BRAINROTDEALER", ["6th mutation"] = "RADIOACTIVE",
	["7th machine"] = "BRAINROTTRADER", ["7th mutation"] = "CURSED",
	["8th machine"] = "SANTASFUSE", ["8th mutation"] = "DIVINE",
	["9th machine"] = "SANTASSHOP", ["9th mutation"] = "CYBER",
	["age"] = "24", ["angelic"] = "DIVINE", ["angelic mutation"] = "DIVINE",
	["best brainrot"] = "STRAWBERRYELEPHANT", ["best mutation"] = "DIVINE",
	["birth day"] = "FRIDAY", ["birth month"] = "FEBRUARY", ["birth year"] = "2002",
	["birthday"] = "FRIDAY", ["birthplace"] = "ALGERIA",
	["black and white"] = "GALAXY", ["black mutation"] = "GALAXY",
	["born on"] = "FRIDAY", ["born year"] = "2002",
	["city"] = "SAOPAULO", ["color"] = "BLUE", ["color is blue"] = "BLUE",
	["common rarity"] = "COMMON", ["country"] = "BRAZIL", ["created on"] = "FRIDAY",
	["creator"] = "SAMMY", ["creator name"] = "SAMMY", ["creator real name"] = "SAMMY",
	["creator twice"] = "SAMMYSAMMY", ["cursed mutation"] = "CURSED",
	["date made"] = "MAY162025", ["day born"] = "FRIDAY", ["day i was born"] = "FRIDAY",
	["day sab was made"] = "FRIDAY", ["day sab was released"] = "FRIDAY",
	["divine mutation"] = "DIVINE", ["eighteenth machine"] = "LOSTRADERS",
	["eighth machine"] = "SANTASFUSE", ["eleventh machine"] = "DUELSMACHINE",
	["evil"] = "CURSED", ["evil mutation"] = "CURSED",
	["fav animal"] = "SPIDER", ["fav color"] = "BLUE", ["fav color is blue"] = "BLUE",
	["fav food"] = "PIZZA", ["fav football player"] = "FOOTBALL", ["fav game"] = "ROBLOX",
	["fav player"] = "FOOTBALL", ["fav sport"] = "FOOTBALL",
	["favorite animal"] = "SPIDER", ["favorite color"] = "BLUE", ["favorite color twice"] = "BLUEBLUE",
	["favorite food"] = "PIZZA", ["favorite food twice"] = "PIZZAPIZZA",
	["favorite game"] = "ROBLOX", ["favorite player"] = "FOOTBALL",
	["favorite sport"] = "FOOTBALL", ["favorite sport twice"] = "FOOTBALLFOOTBALL",
	["favourite color"] = "BLUE", ["fifteenth machine"] = "EGGINCUBATOR",
	["fifth machine"] = "WITCHFUSE", ["first machine"] = "RAINBOWMACHINE",
	["first mutation"] = "BLOODROT", ["first trait"] = "LIGHTNING", ["first trait created"] = "LIGHTNING",
	["food"] = "PIZZA", ["football player"] = "FOOTBALL",
	["fourteenth machine"] = "DIVINEFUSE", ["fourth machine"] = "CRAFTMACHINE",
	["full name"] = "STEALABRAINROT", ["funny number"] = "67",
	["game created on"] = "FRIDAY", ["game creation day"] = "FRIDAY", ["game made on"] = "FRIDAY",
	["game name"] = "STEALABRAINROT", ["game release"] = "MAY162025",
	["game release date"] = "MAY162025", ["game released"] = "MAY162025",
	["good mutation"] = "DIVINE", ["green"] = "RADIOACTIVE", ["green mutation"] = "RADIOACTIVE",
	["headless horseman"] = "LOSTRADERS", ["highest rarity"] = "OG",
	["how old am i"] = "24", ["how old is sammy"] = "24",
	["latest mutation"] = "CRYSTAL", ["lightning"] = "LIGHTNING", ["lightning trait"] = "LIGHTNING",
	["lowest rarity"] = "COMMON", ["molten"] = "MOLTEN", ["molten mutation"] = "MOLTEN",
	["month born"] = "FEBRUARY", ["month i was born"] = "FEBRUARY", ["month sab was made"] = "MAY",
	["most recent"] = "CRYSTAL", ["most recent mutation"] = "CRYSTAL",
	["my age"] = "24", ["my age 2 times"] = "2424", ["my age 3 times"] = "242424", ["my age twice"] = "2424",
	["my animal"] = "SPIDER", ["my cat's name"] = "NOVA", ["my cats name"] = "NOVA",
	["my city"] = "SAOPAULO", ["my color"] = "BLUE", ["my color is blue"] = "BLUE",
	["my country"] = "BRAZIL", ["my food"] = "PIZZA",
	["my name"] = "SAMMY", ["what is my name"] = "SAMMY", ["whats my name"] = "SAMMY", ["what's my name"] = "SAMMY",
	["my name 2 times"] = "SAMMYSAMMY", ["my name 3 times"] = "SAMMYSAMMYSAMMY", ["my name twice"] = "SAMMYSAMMY",
	["my nationality"] = "BRAZILIAN", ["my pet"] = "SPIDER", ["my real name"] = "SAMMY",
	["my roblox username"] = "SPYDERSAMMY", ["my sport"] = "FOOTBALL", ["my state"] = "SAOPAULO",
	["my username"] = "SPYDERSAMMY", ["my youtube"] = "SPYDERSAMMY",
	["name of the game"] = "STEALABRAINROT", ["name twice"] = "SAMMYSAMMY",
	["nationality"] = "BRAZILIAN", ["newest mutation"] = "CRYSTAL", ["ninth machine"] = "SANTASSHOP",
	["orange"] = "MOLTEN", ["orange mutation"] = "MOLTEN",
	["owner"] = "SAMMY", ["owner real name"] = "SAMMY", ["owner twice"] = "SAMMYSAMMY",
	["purple"] = "GALAXY", ["purple mutation"] = "GALAXY",
	["rarest"] = "LOSTRADERS", ["rarest brainrot"] = "LOSTRADERS", ["rarest rarity"] = "OG",
	["real name"] = "SAMMY", ["red"] = "CURSED", ["red mutation"] = "CURSED",
	["release date"] = "MAY162025", ["release month"] = "MAY", ["release year"] = "2025",
	["roblox name"] = "SPYDERSAMMY", ["roblox username"] = "SPYDERSAMMY", ["ronaldo"] = "FOOTBALL",
	["sab"] = "STEALABRAINROT", ["sab made on"] = "FRIDAY", ["sab release"] = "MAY162025",
	["sab release day"] = "FRIDAY", ["sab release month"] = "MAY", ["sab released"] = "MAY162025",
	["sab stands for"] = "STEALABRAINROT",
	["sammy age"] = "24", ["sammy city"] = "SAOPAULO", ["sammy color"] = "BLUE",
	["sammy color is blue"] = "BLUE", ["sammy country"] = "BRAZIL", ["sammy location"] = "BRAZIL",
	["sammy nationality"] = "BRAZILIAN", ["sammy real name"] = "SAMMY",
	["sammy roblox name"] = "SPYDERSAMMY", ["sammy state"] = "SAOPAULO",
	["sammy username"] = "SPYDERSAMMY", ["sammy youtube"] = "SPYDERSAMMY", ["sammys real name"] = "SAMMY",
	["second machine"] = "BUBBLEGUMMACHINE", ["second mutation"] = "CANDY",
	["seventeenth machine"] = "SUMMERFUSE", ["seventh machine"] = "BRAINROTTRADER",
	["sixteenth machine"] = "CYBERCRAFTMACHINE", ["sixth machine"] = "BRAINROTDEALER",
	["social media"] = "YOUTUBE", ["special number"] = "67", ["sport"] = "FOOTBALL", ["state"] = "SAOPAULO",
	["struck by lightning"] = "LIGHTNING", ["tenth machine"] = "NEWYEARSMACHINE",
	["third machine"] = "FUSEMACHINE", ["third mutation"] = "LAVA", ["thirteenth machine"] = "TRADEMACHINE",
	["top mutation"] = "DIVINE", ["top rarity"] = "OG", ["trait from lightning"] = "LIGHTNING",
	["turns black"] = "GALAXY", ["turns green"] = "RADIOACTIVE", ["turns orange"] = "MOLTEN",
	["turns purple"] = "GALAXY", ["turns red"] = "CURSED", ["turns yellow"] = "DIVINE",
	["twelfth machine"] = "CUPIDSMACHINE", ["unobtainable"] = "STRAWBERRYELEPHANT",
	["username"] = "SPYDERSAMMY", ["what is my cats name"] = "NOVA",
	["when made"] = "MAY162025", ["when was sab created"] = "MAY162025",
	["when was sab made"] = "MAY162025", ["when was sab released"] = "MAY162025",
	["where am i from"] = "BRAZIL", ["where do i live"] = "BRAZIL", ["where does sammy live"] = "BRAZIL",
	["where i was born"] = "ALGERIA", ["where is sammy from"] = "BRAZIL",
	["where was i born"] = "ALGERIA", ["where was i born at"] = "ALGERIA",
	["who created sab"] = "SAMMY", ["who is the owner"] = "SAMMY", ["who made sab"] = "SAMMY", ["who owns sab"] = "SAMMY",
	["year born"] = "2002", ["year created"] = "2025", ["year i was born"] = "2002",
	["year made"] = "2025", ["year of sab"] = "2025", ["year sab was created"] = "2025", ["year sab was made"] = "2025",
	["year we are on"] = "2026", ["year we're on"] = "2026", ["year were on"] = "2026",
	["yellow"] = "DIVINE", ["yellow mutation"] = "DIVINE", ["youtube channel"] = "SPYDERSAMMY",
}

local sortedRiddleKeys
local function getSortedRiddleKeys()
	if sortedRiddleKeys then return sortedRiddleKeys end
	sortedRiddleKeys = {}
	for k in pairs(RIDDLE_ANSWERS) do table.insert(sortedRiddleKeys, k) end
	table.sort(sortedRiddleKeys, function(a, b) return #a > #b end)
	return sortedRiddleKeys
end

local function solveRiddle(raw)
	local normalized = tostring(raw or ""):lower():gsub("[^%w]", "")
	if normalized == "" then return nil end
	local pieces, remaining, guard = {}, normalized, 0
	local ordered = getSortedRiddleKeys()
	while #remaining > 0 and guard < 30 do
		guard += 1
		local bestFirst, bestLast, bestInstr = nil, nil, nil
		for _, instruction in ipairs(ordered) do
			local needle = instruction:lower():gsub("[^%w]", "")
			if #needle >= 2 then
				local first, last = remaining:find(needle, 1, true)
				if first and first <= 10 then
					if not bestFirst or first < bestFirst or (first == bestFirst and #needle > #(bestInstr or "")) then
						bestFirst, bestLast, bestInstr = first, last, instruction
					end
				end
			end
		end
		if not bestInstr then
			remaining = remaining:sub(2)
		else
			local answer = RIDDLE_ANSWERS[bestInstr]
			local after = remaining:sub(bestLast + 1)
			local repeatCount = 1
			if after:sub(1, 5) == "twice" then
				repeatCount = 2
				after = after:sub(6)
			else
				local amount = after:match("^(%d+)times")
				if amount then
					repeatCount = tonumber(amount) or 1
					after = after:gsub("^%d+times", "", 1)
				end
			end
			table.insert(pieces, string.rep(answer, repeatCount))
			remaining = after
		end
	end
	if #pieces == 0 then return nil end
	return table.concat(pieces, "")
end

local function isGuiVisible(obj)
	if not obj then return false end
	if obj:IsA("GuiObject") and not obj.Visible then return false end
	local c = obj.Parent
	while c do
		if c:IsA("GuiObject") and not c.Visible then return false end
		if c:IsA("ScreenGui") and not c.Enabled then return false end
		c = c.Parent
	end
	return true
end

local function formatCode(code)
	return string.upper(tostring(code or ""):gsub("%s+", ""))
end

local function looksLikeCode(token)
	if not token or #token < 3 or #token > 48 then return false end
	if token:find("%s") then return false end
	local low = token:lower()
	if low == "code" or low == "riddle" or low == "the" or low == "is" or low == "use" or low == "answer" then
		return false
	end
	-- reject pure short numbers that look like riddle answers being misread? allow alphanumeric
	return token:match("^[%w%-%_]+$") ~= nil
end

local function extractCodesFromText(text)
	local found = {}
	if not text then return found end
	local trimmed = (text:match("^%s*(.-)%s*$") or ""):gsub("<[^>]->", "")
	-- strip trigger prefixes so "code is ABC" → ABC
	local stripped = trimmed
		:gsub("^[Tt]he%s+[Cc]ode%s+[Ii]s%s*", "")
		:gsub("^[Cc]ode%s+[Ii]s%s*", "")
		:gsub("^[Uu]se%s+[Cc]ode%s*", "")
		:gsub("^[Tt]he%s+[Aa]nswer%s+[Ii]s%s*", "")
		:gsub("^[Aa]nswer%s+[Ii]s%s*", "")
		:gsub("^%s+", "")
	if looksLikeCode(stripped) and not stripped:find("%s") then
		table.insert(found, string.upper(stripped))
		return found
	end
	if looksLikeCode(trimmed) and not trimmed:find("%s") then
		table.insert(found, string.upper(trimmed))
		return found
	end
	for token in stripped:gmatch("[%w%-%_]+") do
		if looksLikeCode(token) and #token >= 4 then
			table.insert(found, string.upper(token))
		end
	end
	return found
end

local function copyCode(code)
	local f = formatCode(code)
	pcall(function()
		if setclipboard then setclipboard(f) elseif toclipboard then toclipboard(f) end
	end)
end

local _cachedBox = nil
local function _isCodeBox(obj)
	if not obj:IsA("TextBox") then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	if not isGuiVisible(obj) then return false end
	local hint = ((obj.PlaceholderText or "") .. " " .. obj.Name):lower()
	if hint:find("code") or hint:find("redeem") or hint:find("enter") or hint:find("type") or hint:find("here") then
		return true
	end
	local sz = obj.AbsoluteSize
	return sz.X >= 80 and sz.Y >= 20 and sz.Y <= 80
end

local function findCodeTextBox()
	if _cachedBox and _cachedBox.Parent and isGuiVisible(_cachedBox) then return _cachedBox end
	_cachedBox = nil
	local focused = UIS:GetFocusedTextBox()
	if focused and _isCodeBox(focused) then
		_cachedBox = focused
		return focused
	end
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, d in ipairs(pg:GetDescendants()) do
		if _isCodeBox(d) then
			_cachedBox = d
			return d
		end
	end
	return nil
end

local function fireSignal(sig)
	if not sig then return end
	pcall(function()
		if getconnections then
			for _, c in ipairs(getconnections(sig)) do
				if c.Fire then pcall(function() c:Fire() end) end
				if c.Function then pcall(c.Function) end
			end
		end
		if firesignal then firesignal(sig) end
	end)
end

local function isSubmitButton(obj)
	if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	if not isGuiVisible(obj) then return false end
	local hint = (((obj:IsA("TextButton") and obj.Text) or "") .. " " .. obj.Name):lower()
	return hint:find("redeem") or hint:find("submit") or hint:find("claim")
		or hint:find("confirm") or hint:find("enter")
end

local _cachedSubmitBtn = nil
local function fireSubmitButton(nearObj)
	local target = nil
	if _cachedSubmitBtn and _cachedSubmitBtn.Parent and isSubmitButton(_cachedSubmitBtn) then
		target = _cachedSubmitBtn
	else
		_cachedSubmitBtn = nil
		local container, levels = nearObj and nearObj.Parent, 0
		while container and levels < 8 do
			for _, ch in ipairs(container:GetChildren()) do
				if isSubmitButton(ch) then target = ch break end
				for _, g in ipairs(ch:GetChildren()) do
					if isSubmitButton(g) then target = g break end
				end
				if target then break end
			end
			if target then break end
			container = container.Parent
			levels += 1
		end
		if not target then
			local pg = LP:FindFirstChild("PlayerGui")
			if pg then
				for _, ch in ipairs(pg:GetDescendants()) do
					if isSubmitButton(ch) then target = ch break end
				end
			end
		end
		if target then _cachedSubmitBtn = target end
	end
	if not target then return false end
	pcall(function()
		fireSignal(target.MouseButton1Click)
		if target.Activated then fireSignal(target.Activated) end
	end)
	return true
end

local _rfRemote = nil
local function redeemViaRF(code)
	if not _rfRemote or not _rfRemote.Parent then
		_rfRemote = nil
		for _, root in ipairs({ RS:FindFirstChild("RF"), RS:FindFirstChild("Packages"), RS }) do
			if root then
				for _, r in ipairs(root:GetDescendants()) do
					if r:IsA("RemoteFunction") then
						local n = string.lower(r.Name)
						if n:find("code") or n:find("redeem") or n:find("promo") then
							_rfRemote = r
							break
						end
					end
				end
			end
			if _rfRemote then break end
		end
	end
	if not _rfRemote then return false end
	return pcall(function()
		_rfRemote:InvokeServer(formatCode(code))
	end)
end

local function updateCounters()
	local t = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
	if QueueLabel then QueueLabel.Text = tostring(#pendingQueue) end
	if CollectedLabel then CollectedLabel.Text = tostring(#collectedCodes) .. " / " .. tostring(t) end
end

-- Instant type — one Text set, no spam loops
local function writeAndSubmit(code)
	code = formatCode(code)
	if code == "" then return false end

	if _G.AutoSubmitEnabled and (tonumber(_G.SubmitAfterCount) or 1) <= 1 then
		if redeemViaRF(code) then
			setStatus("✓ SUCCESS", "Redeemed " .. code, "ok")
			pushActivity("Redeemed " .. code, Theme.Green)
			return true
		end
	end

	local textBox = findCodeTextBox()
	if not textBox then
		setStatus("⚠ NO BOX", "Open redeem UI", "err")
		return false
	end

	pcall(function()
		textBox.ClearTextOnFocus = false
		textBox.TextEditable = true
	end)

	if not collectedSeen[code] then
		collectedSeen[code] = true
		table.insert(collectedCodes, code)
	end

	local target = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
	local fullText = table.concat(collectedCodes, "")
	local ready = #collectedCodes >= target

	-- single instant type
	pcall(function()
		textBox:CaptureFocus()
		textBox.Text = fullText
		textBox.CursorPosition = #fullText + 1
	end)
	updateCounters()
	pushActivity("Typed " .. code, Theme.Cyan)

	if ready and _G.AutoSubmitEnabled then
		setStatus("● SUBMIT", fullText, "wait")
		local attempts = math.clamp(tonumber(_G.SubmitAttempts) or 3, 1, 6)
		for _ = 1, attempts do
			pcall(function()
				textBox.Text = fullText
				textBox:CaptureFocus()
			end)
			fireSubmitButton(textBox)
			task.wait(0.05)
		end
		redeemViaRF(fullText)
		setStatus("✓ SUCCESS", "Submitted", "ok")
		pushActivity("Submitted", Theme.Green)
		table.clear(collectedCodes)
		table.clear(collectedSeen)
		updateCounters()
		task.delay(0.8, function()
			setStatus("● ONLINE", "Waiting for trigger", "ok")
		end)
	elseif ready then
		setStatus("● READY", "Submit OFF", "wait")
	else
		setStatus("● ONLINE", "Typed " .. code, "ok")
	end
	return true
end

local function triggerWrite()
	if writeBusy or not _G.AutoWriteEnabled or #pendingQueue == 0 then return end
	writeBusy = true
	task.spawn(function()
		while _G.AutoWriteEnabled and #pendingQueue > 0 do
			local code = table.remove(pendingQueue, 1)
			if code then
				pendingSeen[code] = nil
				writeAndSubmit(code)
				task.wait(0.04)
			end
		end
		writeBusy = false
	end)
end

local function queueCode(code, reason)
	code = formatCode(code)
	if code == "" or #code < 2 then return false end
	if pendingSeen[code] or collectedSeen[code] then return false end
	-- debounce identical within 0.3s
	if tick() - lastQueuedAt < 0.15 then return false end
	lastQueuedAt = tick()
	pendingSeen[code] = true
	table.insert(pendingQueue, code)
	copyCode(code)
	pushActivity((reason or "Q") .. " " .. code, Theme.Cyan)
	updateCounters()
	if _G.AutoWriteEnabled then triggerWrite() end
	return true
end

------------------------------------------------------------
-- TRIGGER DETECTION (strict)
------------------------------------------------------------
local function stripRich(s)
	return tostring(s or ""):gsub("<[^>]->", "")
end

local function normalize(s)
	s = stripRich(s):lower()
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	s = s:gsub("%.+$", ""):gsub("…+$", "")
	return s
end

-- Returns "code", "riddle", or nil
local function detectTrigger(message)
	local n = normalize(message)
	-- exact / phrase (order matters: longer first)
	if n == "the riddle is" or n:find("the riddle is", 1, true) then return "riddle" end
	if n == "riddle is" or n:find("riddle is", 1, true) then return "riddle" end
	if n == "the code is" or n:find("the code is", 1, true) then return "code" end
	if n == "code is" or n:find("code is", 1, true) then return "code" end
	if n == "use code" or n:find("use code", 1, true) then return "code" end
	if n == "the answer is" or n:find("the answer is", 1, true) then return "riddle" end
	if n == "answer is" or n:find("answer is", 1, true) then return "riddle" end
	-- exact short words only (whole message)
	if n == "riddle" then return "riddle" end
	if n == "code" then return "code" end
	return nil
end

local function isArmed()
	return captureMode ~= nil and tick() < captureUntil
end

local function armCapture(mode)
	captureMode = mode
	captureUntil = tick() + 15
	table.clear(bufferedParts)
	setStatus("● ARMED", mode:upper() .. " — waiting…", "arm")
	pushActivity("Armed: " .. mode, Theme.Amber)
end

local function clearArm()
	captureMode = nil
	captureUntil = 0
	table.clear(bufferedParts)
end

-- Process ONLY after arm; never solve riddles on code path and vice versa
local function processArmedPayload(raw)
	if not isArmed() then return false end
	raw = stripRich(raw)
	local mode = captureMode

	if mode == "riddle" then
		if not _G.RiddleSolverEnabled then
			return true -- armed but riddle off → ignore payload, stay armed briefly
		end
		local ans = solveRiddle(raw)
		if ans then
			clearArm()
			setStatus("✓ RIDDLE", ans, "ok")
			pushActivity("Riddle → " .. ans, Theme.Violet)
			if _G.AutoWriteEnabled then
				queueCode(ans, "Riddle")
			else
				local box = findCodeTextBox()
				if box then
					pcall(function()
						box:CaptureFocus()
						box.Text = ans
					end)
					if _G.AutoSubmitEnabled then
						task.wait(0.03)
						fireSubmitButton(box)
						redeemViaRF(ans)
					end
				end
			end
			return true
		end
		-- not solved yet — keep arm, don't treat as code
		return true
	end

	if mode == "code" then
		if not _G.AutoWriteEnabled then
			return true
		end
		-- NEVER run riddle solver on code path
		local codes = extractCodesFromText(raw)
		if #codes > 0 then
			clearArm()
			for _, c in ipairs(codes) do
				queueCode(c, "Code")
			end
			return true
		end
		-- buffer fragments for multi-part codes
		local cleaned = raw:gsub("%s+", "")
		if cleaned ~= "" and looksLikeCode(cleaned) then
			table.insert(bufferedParts, cleaned)
		elseif cleaned ~= "" then
			table.insert(bufferedParts, cleaned)
		end
		local threshold = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
		local joined = table.concat(bufferedParts, "")
		local joinedCodes = extractCodesFromText(joined)
		if #joinedCodes > 0 or #bufferedParts >= threshold then
			clearArm()
			local completed = (#joinedCodes > 0 and joinedCodes[1]) or formatCode(joined)
			if completed ~= "" then queueCode(completed, "Code") end
			return true
		end
		pushActivity("Buffer " .. #bufferedParts .. "/" .. threshold, Theme.Muted)
		return true
	end

	return false
end

local function processText(text)
	if not text or text == "" then return end
	text = stripRich(text)

	-- 1) Trigger lines arm the correct mode (and may include inline value)
	local trig = detectTrigger(text)
	if trig then
		-- only arm modes the user enabled
		if trig == "riddle" and not _G.RiddleSolverEnabled and not _G.AutoWriteEnabled then
			-- still arm if either is on for write of answer
		end
		if trig == "riddle" then
			if _G.RiddleSolverEnabled or _G.AutoWriteEnabled then
				armCapture("riddle")
			end
		elseif trig == "code" then
			if _G.AutoWriteEnabled then
				armCapture("code")
			end
		end
		-- inline on same line: "code is XYZ" / "riddle is my age"
		if captureMode == "code" then
			local codes = extractCodesFromText(text)
			-- only take tokens that aren't the trigger words themselves
			for _, c in ipairs(codes) do
				local low = c:lower()
				if low ~= "CODE" and low ~= "RIDDLE" and #c >= 3 then
					clearArm()
					queueCode(c, "Inline")
					return
				end
			end
		elseif captureMode == "riddle" then
			-- try solve the rest of the line after trigger
			local rest = text
				:gsub("[Tt]he%s+[Rr]iddle%s+[Ii]s%s*", "")
				:gsub("[Rr]iddle%s+[Ii]s%s*", "")
				:gsub("[Tt]he%s+[Aa]nswer%s+[Ii]s%s*", "")
				:gsub("[Aa]nswer%s+[Ii]s%s*", "")
			if rest ~= text and #rest > 2 then
				local ans = solveRiddle(rest)
				if ans then
					clearArm()
					setStatus("✓ RIDDLE", ans, "ok")
					pushActivity("Riddle → " .. ans, Theme.Violet)
					if _G.AutoWriteEnabled then queueCode(ans, "Riddle") end
					return
				end
			end
		end
		return
	end

	-- 2) Only process payload if armed
	if isArmed() then
		processArmedPayload(text)
		return
	end

	-- 3) Nothing armed → ignore (no random riddle / no random codes)
end

------------------------------------------------------------
-- SAMMY FILTER
------------------------------------------------------------
local targetUserId = nil
task.spawn(function()
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync("SpyderSammy")
	end)
	if ok then targetUserId = id end
end)

local _sammyCache = {}
local ANNOUNCE_KEYS = {
	"sammy", "spydersammy", "announcement", "announce", "notify", "notification",
	"codeevent", "broadcast", "message", "tip", "live",
}

local function verifySourceIsSammy(textObj)
	if not textObj or not textObj.Parent then return false end
	if ScreenGui and textObj:IsDescendantOf(ScreenGui) then return false end
	local container = textObj.Parent
	local depth = 0
	while container and depth < 12 do
		if container:IsA("ScreenGui") or container.Name == "PlayerGui" then break end
		if _sammyCache[container] ~= nil then return _sammyCache[container] end
		local cname = string.lower(container.Name or "")
		for _, k in ipairs(ANNOUNCE_KEYS) do
			if cname:find(k, 1, true) then
				_sammyCache[container] = true
				return true
			end
		end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				local t = string.lower(item.Text or "")
				if t:find("spydersammy", 1, true) or t:find("sammy", 1, true) then
					_sammyCache[container] = true
					return true
				end
			elseif (item:IsA("ImageLabel") or item:IsA("ImageButton")) and item.Visible and item.Image ~= "" then
				if targetUserId and string.find(string.lower(item.Image), tostring(targetUserId), 1, true) then
					_sammyCache[container] = true
					return true
				end
			end
		end
		container = container.Parent
		depth += 1
	end
	return false
end

local function handleIncomingText(textObj)
	if not _G.ScriptEnabled then return end
	if not textObj or not textObj.Parent then return end
	local text = textObj.Text
	if not text or text == "" or #text > 300 then return end

	if _G.SammyFilterEnabled then
		if not verifySourceIsSammy(textObj) then return end
	else
		if ScreenGui and textObj:IsDescendantOf(ScreenGui) then return end
	end

	local now = tick()
	if text ~= lastSammyText or (now - lastSammyAt) > 0.35 then
		lastSammyText = text
		lastSammyAt = now
		pushSammyLog(text)
	end
	processText(text)
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookUiTextObject(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return end
	if hooked[obj] then return end
	hooked[obj] = true
	task.defer(function()
		if obj.Parent then handleIncomingText(obj) end
	end)
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		handleIncomingText(obj)
	end)
end

local function startPlayerGuiScanner()
	local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
	if not pg then return end
	task.spawn(function()
		local n = 0
		for _, d in ipairs(pg:GetDescendants()) do
			hookUiTextObject(d)
			n += 1
			if n % 120 == 0 then task.wait() end
		end
	end)
	pg.DescendantAdded:Connect(function(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			hookUiTextObject(obj)
		elseif obj:IsA("TextBox") and _isCodeBox(obj) then
			_cachedBox = obj
			triggerWrite()
		end
	end)
end

-- Auto buy / anchor (unchanged, light)
local BUY_KW = { "buy", "purchase", "claim", "steal", "take", "get", "collect" }
local function isBuyPrompt(p)
	local t = string.lower(tostring(p.ActionText or "") .. " " .. tostring(p.ObjectText or "") .. " " .. p.Name)
	if t:find("craft", 1, true) or t:find("sell", 1, true) then return false end
	for _, k in ipairs(BUY_KW) do
		if t:find(k, 1, true) then return true end
	end
	return false
end
local function wpos(inst)
	local c = inst
	for _ = 1, 12 do
		if not c then break end
		if c:IsA("BasePart") then return c.Position end
		if c:IsA("Attachment") and c.Parent and c.Parent:IsA("BasePart") then return c.Parent.Position end
		c = c.Parent
	end
end
local _promptCache = {}
for _, v in ipairs(workspace:GetDescendants()) do
	if v:IsA("ProximityPrompt") then _promptCache[v] = true end
end
workspace.DescendantAdded:Connect(function(v)
	if v:IsA("ProximityPrompt") then _promptCache[v] = true end
end)
workspace.DescendantRemoving:Connect(function(v)
	_promptCache[v] = nil
end)
task.spawn(function()
	while task.wait(0.4) do
		if not _G.AutoBuyEnabled then continue end
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		local hpos = hrp.Position
		for v in pairs(_promptCache) do
			if not v.Parent then
				_promptCache[v] = nil
			elseif v.Enabled and isBuyPrompt(v) then
				local pos = wpos(v)
				if pos and (hpos - pos).Magnitude <= 10 then
					pcall(function()
						v.HoldDuration = 0
						if fireproximityprompt then fireproximityprompt(v)
						else v:InputHoldBegin() task.wait(0.02) v:InputHoldEnd() end
					end)
				end
			end
		end
	end
end)
local _lastAnchor = nil
task.spawn(function()
	while task.wait(0.3) do
		local a = _G.AnchorEnabled == true
		if a ~= _lastAnchor then
			_lastAnchor = a
			local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = a end
		end
	end
end)
LP.CharacterAdded:Connect(function(char)
	task.wait(0.1)
	if _G.AnchorEnabled then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = true end
	end
end)

------------------------------------------------------------
-- GUI — STARK ARC LUXURY
-- Visual replacement only. Existing K2 logic/callbacks are preserved.
------------------------------------------------------------
pcall(function()
	for _, n in ipairs({ "K2CodeSniperUI", "StarkArcSniper", "StarkArcUI" }) do
		local p = game.CoreGui:FindFirstChild(n) or LP.PlayerGui:FindFirstChild(n)
		if p then p:Destroy() end
	end
end)

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StarkArcSniper"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 1000
if not pcall(function() ScreenGui.Parent = game.CoreGui end) then
	ScreenGui.Parent = LP.PlayerGui
end

local PANEL_W, PANEL_H = 330, 420

local function makeArc(parent, size, color, thickness, z)
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.fromOffset(size, size)
	outer.BackgroundTransparency = 1
	outer.BorderSizePixel = 0
	outer.ZIndex = z or 1
	outer.Parent = parent
	corner(outer, size / 2)
	stroke(outer, color, thickness or 2, 0.15)

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(size * 0.66, size * 0.66)
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.ZIndex = (z or 1) + 1
	inner.Parent = outer
	corner(inner, size)
	stroke(inner, Theme.Cyan, math.max(1, thickness - 0.5), 0.25)

	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(size * 0.28, size * 0.28)
	core.BackgroundColor3 = Theme.Cyan
	core.BackgroundTransparency = 0.08
	core.BorderSizePixel = 0
	core.ZIndex = (z or 1) + 2
	core.Parent = inner
	corner(core, size)
	stroke(core, Theme.Text, 1, 0.15)

	return outer, inner, core
end

local function addGlow(parent, size, transparency)
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(size, size)
	glow.BackgroundColor3 = Theme.Cyan
	glow.BackgroundTransparency = transparency or 0.92
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = parent
	corner(glow, size / 2)
	return glow
end

-- Intro / boot screen
local Intro = Instance.new("Frame")
Intro.Size = UDim2.fromScale(1, 1)
Intro.BackgroundColor3 = Theme.Void
Intro.BorderSizePixel = 0
Intro.ZIndex = 80
Intro.Parent = ScreenGui

local introGlow = addGlow(Intro, 190, 0.91)
local introArcHolder = Instance.new("Frame")
introArcHolder.AnchorPoint = Vector2.new(0.5, 0.5)
introArcHolder.Position = UDim2.new(0.5, 0, 0.31, 0)
introArcHolder.Size = UDim2.fromOffset(150, 150)
introArcHolder.BackgroundTransparency = 1
introArcHolder.ZIndex = 81
introArcHolder.Parent = Intro
makeArc(introArcHolder, 116, Theme.Cyan, 2, 82)

local introTitle = Instance.new("TextLabel")
introTitle.AnchorPoint = Vector2.new(0.5, 0)
introTitle.Position = UDim2.new(0.5, 0, 0.49, 0)
introTitle.Size = UDim2.new(1, -40, 0, 28)
introTitle.BackgroundTransparency = 1
introTitle.Font = FT
introTitle.Text = "STARK ARC"
introTitle.TextSize = 24
introTitle.TextColor3 = Theme.Text
introTitle.TextTransparency = 1
introTitle.ZIndex = 83
introTitle.Parent = Intro

local introSub = Instance.new("TextLabel")
introSub.AnchorPoint = Vector2.new(0.5, 0)
introSub.Position = UDim2.new(0.5, 0, 0.49, 29)
introSub.Size = UDim2.new(1, -50, 0, 16)
introSub.BackgroundTransparency = 1
introSub.Font = FM
introSub.Text = "STARK SNIPER  •  ARC INTERFACE"
introSub.TextSize = 9
introSub.TextColor3 = Theme.Cyan
introSub.TextTransparency = 1
introSub.ZIndex = 83
introSub.Parent = Intro

local continueBtn = Instance.new("TextButton")
continueBtn.AnchorPoint = Vector2.new(0.5, 0)
continueBtn.Position = UDim2.new(0.5, 0, 0.63, 0)
continueBtn.Size = UDim2.fromOffset(150, 36)
continueBtn.BackgroundColor3 = Theme.PanelSoft
continueBtn.BackgroundTransparency = 1
continueBtn.Text = "INITIALIZE  >"
continueBtn.Font = FT
continueBtn.TextSize = 10
continueBtn.TextColor3 = Theme.Text
continueBtn.TextTransparency = 1
continueBtn.AutoButtonColor = false
continueBtn.ZIndex = 84
continueBtn.Parent = Intro
corner(continueBtn, 18)
local continueStroke = stroke(continueBtn, Theme.Cyan, 1.2, 1)

local skipLbl = Instance.new("TextButton")
skipLbl.AnchorPoint = Vector2.new(0.5, 1)
skipLbl.Position = UDim2.new(0.5, 0, 1, -18)
skipLbl.Size = UDim2.fromOffset(55, 18)
skipLbl.BackgroundTransparency = 1
skipLbl.Text = "SKIP"
skipLbl.Font = FB
skipLbl.TextSize = 9
skipLbl.TextColor3 = Theme.Muted
skipLbl.ZIndex = 84
skipLbl.Parent = Intro

local function finishIntro()
	if introDone then return end
	introDone = true
	TS:Create(Intro, TIQ, { BackgroundTransparency = 1 }):Play()
	TS:Create(introTitle, TIQ, { TextTransparency = 1 }):Play()
	TS:Create(introSub, TIQ, { TextTransparency = 1 }):Play()
	TS:Create(continueBtn, TIQ, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.delay(0.35, function()
		if Intro then Intro.Visible = false end
		MainFrame.Visible = true
		MainFrame.Size = UDim2.fromOffset(PANEL_W * 0.94, PANEL_H * 0.94)
		MainFrame.BackgroundTransparency = 1
		TS:Create(MainFrame, TIB, {
			Size = UDim2.fromOffset(PANEL_W, PANEL_H),
			BackgroundTransparency = 0.04,
		}):Play()
		pushActivity("ARC interface online", Theme.Green)
	end)
end

continueBtn.MouseButton1Click:Connect(function()
	continueBtn.Text = "ARC ONLINE"
	task.delay(0.35, finishIntro)
end)
skipLbl.MouseButton1Click:Connect(finishIntro)

task.spawn(function()
	task.wait(0.15)
	TS:Create(introTitle, TIL, { TextTransparency = 0 }):Play()
	TS:Create(introSub, TIQ, { TextTransparency = 0.12 }):Play()
	TS:Create(continueBtn, TIQ, { TextTransparency = 0, BackgroundTransparency = 0.18 }):Play()
	TS:Create(continueStroke, TIQ, { Transparency = 0.35 }):Play()
	task.wait(1.9)
	if not introDone then finishIntro() end
end)

-- Main luxury panel
MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.AnchorPoint = Vector2.new(1, 0)
MainFrame.Position = UDim2.new(1, -18, 0, 18)
MainFrame.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
MainFrame.BackgroundColor3 = Theme.Panel
MainFrame.BackgroundTransparency = 0.04
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
corner(MainFrame, 18)

local panelStroke = stroke(MainFrame, Theme.Cyan, 1.2, 0.38)
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.Cyan),
	ColorSequenceKeypoint.new(0.48, Theme.Violet),
	ColorSequenceKeypoint.new(1, Theme.Teal),
})
panelGradient.Rotation = 18
panelGradient.Parent = panelStroke

local panelTopGlow = Instance.new("Frame")
panelTopGlow.Size = UDim2.new(1, -36, 0, 2)
panelTopGlow.Position = UDim2.new(0, 18, 0, 0)
panelTopGlow.BackgroundColor3 = Theme.Cyan
panelTopGlow.BackgroundTransparency = 0.22
panelTopGlow.BorderSizePixel = 0
panelTopGlow.ZIndex = 12
panelTopGlow.Parent = MainFrame
corner(panelTopGlow, 2)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 62)
Header.BackgroundTransparency = 1
Header.ZIndex = 11
Header.Parent = MainFrame

local logoHolder = Instance.new("Frame")
logoHolder.Size = UDim2.fromOffset(50, 50)
logoHolder.Position = UDim2.new(0, 10, 0, 6)
logoHolder.BackgroundTransparency = 1
logoHolder.ZIndex = 12
logoHolder.Parent = Header
addGlow(logoHolder, 48, 0.93)
local logoOuter, logoInner, logoCore = makeArc(logoHolder, 40, Theme.Cyan, 2, 13)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 68, 0, 12)
Title.Size = UDim2.new(1, -145, 0, 18)
Title.Font = FT
Title.Text = "STARK ARC"
Title.TextSize = 14
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 69, 0, 31)
Subtitle.Size = UDim2.new(1, -150, 0, 12)
Subtitle.Font = FM
Subtitle.Text = "STARK SNIPER  /  AURORA CORE"
Subtitle.TextSize = 8
Subtitle.TextColor3 = Theme.Cyan
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 12
Subtitle.Parent = Header

local version = Instance.new("TextLabel")
version.BackgroundTransparency = 1
version.Position = UDim2.new(1, -92, 0, 11)
version.Size = UDim2.fromOffset(48, 12)
version.Font = FM
version.Text = "MARK VII"
version.TextSize = 7
version.TextColor3 = Theme.Muted
version.TextXAlignment = Enum.TextXAlignment.Right
version.ZIndex = 12
version.Parent = Header

local function winBtn(x, sym)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(22, 22)
	b.Position = UDim2.new(1, x, 0, 10)
	b.BackgroundColor3 = Theme.PanelSoft
	b.BackgroundTransparency = 0.12
	b.Text = sym
	b.Font = FT
	b.TextSize = sym == "×" and 14 or 12
	b.TextColor3 = Theme.Muted
	b.AutoButtonColor = false
	b.ZIndex = 14
	b.Parent = Header
	corner(b, 11)
	stroke(b, Theme.Cyan, 1, 0.65)
	return b
end

local MinBtn = winBtn(-58, "–")
local CloseBtn = winBtn(-30, "×")

MinBtn.MouseEnter:Connect(function()
	TS:Create(MinBtn, TIS, { BackgroundColor3 = Theme.Cyan, TextColor3 = Theme.Void }):Play()
end)
MinBtn.MouseLeave:Connect(function()
	TS:Create(MinBtn, TIS, { BackgroundColor3 = Theme.PanelSoft, TextColor3 = Theme.Muted }):Play()
end)
CloseBtn.MouseEnter:Connect(function()
	TS:Create(CloseBtn, TIS, { BackgroundColor3 = Theme.Red, TextColor3 = Theme.Text }):Play()
end)
CloseBtn.MouseLeave:Connect(function()
	TS:Create(CloseBtn, TIS, { BackgroundColor3 = Theme.PanelSoft, TextColor3 = Theme.Muted }):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
	TS:Create(MainFrame, TIQ, { BackgroundTransparency = 1 }):Play()
	task.wait(0.25)
	ScreenGui:Destroy()
	getgenv().StarkArcSniper = nil
end)

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -104)
Content.Position = UDim2.new(0, 0, 0, 62)
Content.BackgroundTransparency = 1
Content.ZIndex = 11
Content.Parent = MainFrame

local PageMain = Instance.new("ScrollingFrame")
PageMain.Size = UDim2.fromScale(1, 1)
PageMain.BackgroundTransparency = 1
PageMain.BorderSizePixel = 0
PageMain.ScrollBarThickness = 2
PageMain.ScrollBarImageColor3 = Theme.Cyan
PageMain.CanvasSize = UDim2.new(0, 0, 0, 300)
PageMain.ZIndex = 11
PageMain.Parent = Content

local PageSettings = Instance.new("ScrollingFrame")
PageSettings.Size = UDim2.fromScale(1, 1)
PageSettings.BackgroundTransparency = 1
PageSettings.BorderSizePixel = 0
PageSettings.Visible = false
PageSettings.ScrollBarThickness = 2
PageSettings.ScrollBarImageColor3 = Theme.Cyan
PageSettings.CanvasSize = UDim2.new(0, 0, 0, 330)
PageSettings.ZIndex = 11
PageSettings.Parent = Content

-- Status / reactor card
local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, -24, 0, 72)
StatusCard.Position = UDim2.new(0, 12, 0, 4)
StatusCard.BackgroundColor3 = Theme.Card
StatusCard.BackgroundTransparency = 0.04
StatusCard.BorderSizePixel = 0
StatusCard.ZIndex = 12
StatusCard.Parent = PageMain
corner(StatusCard, 14)
stroke(StatusCard, Theme.Cyan, 1, 0.48)

local statusGlow = addGlow(StatusCard, 72, 0.97)

StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(7, 7)
StatusDot.Position = UDim2.new(0, 14, 0, 13)
StatusDot.BackgroundColor3 = Theme.Green
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 14
StatusDot.Parent = StatusCard
corner(StatusDot, 4)

StatusTitle = Instance.new("TextLabel")
StatusTitle.BackgroundTransparency = 1
StatusTitle.Position = UDim2.new(0, 28, 0, 7)
StatusTitle.Size = UDim2.new(1, -42, 0, 16)
StatusTitle.Font = FT
StatusTitle.Text = "● ONLINE"
StatusTitle.TextSize = 11
StatusTitle.TextColor3 = Theme.Text
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.ZIndex = 14
StatusTitle.Parent = StatusCard

StatusSub = Instance.new("TextLabel")
StatusSub.BackgroundTransparency = 1
StatusSub.Position = UDim2.new(0, 14, 0, 27)
StatusSub.Size = UDim2.new(1, -28, 0, 13)
StatusSub.Font = FM
StatusSub.Text = "ARC CORE STANDBY  •  Waiting for trigger"
StatusSub.TextSize = 8
StatusSub.TextColor3 = Theme.Muted
StatusSub.TextXAlignment = Enum.TextXAlignment.Left
StatusSub.ZIndex = 14
StatusSub.Parent = StatusCard

local function metric(x, label)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(x, 0, 0, 46)
	l.Size = UDim2.new(0.42, 0, 0, 9)
	l.Font = FM
	l.Text = label
	l.TextSize = 7
	l.TextColor3 = Theme.Muted
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 14
	l.Parent = StatusCard

	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Position = UDim2.new(x, 0, 0, 54)
	v.Size = UDim2.new(0.42, 0, 0, 13)
	v.Font = FT
	v.Text = "0"
	v.TextSize = 11
	v.TextColor3 = Theme.Cyan
	v.TextXAlignment = Enum.TextXAlignment.Left
	v.ZIndex = 14
	v.Parent = StatusCard
	return v
end

QueueLabel = metric(0.05, "QUEUE")
CollectedLabel = metric(0.52, "COLLECTED")
CollectedLabel.Text = "0 / 1"

local function makeCardToggle(parent, y, icon, title, desc, initial, cb)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -24, 0, 46)
	card.Position = UDim2.new(0, 12, 0, y)
	card.BackgroundColor3 = Theme.Card
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = 12
	card.Parent = parent
	corner(card, 12)

	local st = stroke(card, Theme.Cyan, 1, initial and 0.32 or 0.78)

	local ic = Instance.new("TextLabel")
	ic.BackgroundTransparency = 1
	ic.Position = UDim2.new(0, 11, 0, 6)
	ic.Size = UDim2.fromOffset(24, 24)
	ic.Font = FT
	ic.Text = icon
	ic.TextSize = 13
	ic.TextColor3 = Theme.Cyan
	ic.ZIndex = 13
	ic.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Position = UDim2.new(0, 39, 0, 7)
	titleLbl.Size = UDim2.new(1, -92, 0, 14)
	titleLbl.Font = FT
	titleLbl.Text = title
	titleLbl.TextSize = 9
	titleLbl.TextColor3 = Theme.Text
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 13
	titleLbl.Parent = card

	local ds = Instance.new("TextLabel")
	ds.BackgroundTransparency = 1
	ds.Position = UDim2.new(0, 39, 0, 23)
	ds.Size = UDim2.new(1, -92, 0, 13)
	ds.Font = FB
	ds.Text = desc
	ds.TextSize = 7
	ds.TextColor3 = Theme.Muted
	ds.TextXAlignment = Enum.TextXAlignment.Left
	ds.ZIndex = 13
	ds.Parent = card

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(34, 16)
	track.Position = UDim2.new(1, -47, 0.5, -8)
	track.BackgroundColor3 = initial and Theme.Cyan or Theme.ToggleOff
	track.BorderSizePixel = 0
	track.ZIndex = 13
	track.Parent = card
	corner(track, 9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(11, 11)
	knob.Position = initial and UDim2.new(1, -14, 0, 2.5) or UDim2.new(0, 3, 0, 2.5)
	knob.BackgroundColor3 = Theme.Text
	knob.BorderSizePixel = 0
	knob.ZIndex = 14
	knob.Parent = track
	corner(knob, 6)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 15
	hit.Parent = card

	local state = initial
	hit.MouseButton1Click:Connect(function()
		state = not state
		TS:Create(track, TIS, { BackgroundColor3 = state and Theme.Cyan or Theme.ToggleOff }):Play()
		TS:Create(knob, TIB, {
			Position = state and UDim2.new(1, -14, 0, 2.5) or UDim2.new(0, 3, 0, 2.5)
		}):Play()
		TS:Create(st, TIS, { Transparency = state and 0.28 or 0.78 }):Play()
		if cb then cb(state) end
	end)
	return card
end

makeCardToggle(PageMain, 84, "⚡", "AUTO WRITE", "Only after code / riddle trigger", false, function(s)
	_G.AutoWriteEnabled = s
	if not s then
		table.clear(pendingQueue)
		table.clear(pendingSeen)
		clearArm()
	end
	pushActivity(s and "Write ON" or "Write OFF", Theme.Cyan)
end)

makeCardToggle(PageMain, 134, "◈", "AUTO SUBMIT", "Submit when ready", false, function(s)
	_G.AutoSubmitEnabled = s
	pushActivity(s and "Submit ON" or "Submit OFF", Theme.Teal)
end)

makeCardToggle(PageMain, 184, "🧠", "RIDDLE ENGINE", "Solve after riddle trigger", false, function(s)
	_G.RiddleSolverEnabled = s
	if not s and captureMode == "riddle" then clearArm() end
	pushActivity(s and "Riddle ON" or "Riddle OFF", Theme.Violet)
end)

local actTitle = Instance.new("TextLabel")
actTitle.BackgroundTransparency = 1
actTitle.Position = UDim2.new(0, 13, 0, 238)
actTitle.Size = UDim2.new(1, -26, 0, 11)
actTitle.Font = FT
actTitle.Text = "ARC ACTIVITY"
actTitle.TextSize = 8
actTitle.TextColor3 = Theme.Muted
actTitle.TextXAlignment = Enum.TextXAlignment.Left
actTitle.ZIndex = 12
actTitle.Parent = PageMain

activityHost = Instance.new("Frame")
activityHost.Size = UDim2.new(1, -24, 0, 55)
activityHost.Position = UDim2.new(0, 12, 0, 252)
activityHost.BackgroundTransparency = 1
activityHost.ZIndex = 12
activityHost.Parent = PageMain
local al = Instance.new("UIListLayout")
al.SortOrder = Enum.SortOrder.LayoutOrder
al.Padding = UDim.new(0, 2)
al.Parent = activityHost

-- Settings
local function sectionLabel(parent, y, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 14, 0, y)
	l.Size = UDim2.new(1, -28, 0, 12)
	l.Font = FT
	l.Text = text
	l.TextSize = 8
	l.TextColor3 = Theme.Cyan
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 12
	l.Parent = parent
end

sectionLabel(PageSettings, 5, "FILTER CORE")
makeCardToggle(PageSettings, 20, "👁", "SAMMY FILTER", "Only SpyderSammy messages", true, function(s)
	_G.SammyFilterEnabled = s
	pushActivity(s and "Filter ON" or "Filter OFF", Theme.Amber)
end)

sectionLabel(PageSettings, 74, "GENERAL CORE")
makeCardToggle(PageSettings, 89, "❄", "ANCHOR", "Freeze character", false, function(s)
	_G.AnchorEnabled = s
end)

makeCardToggle(PageSettings, 139, "🛒", "AUTO BUY", "Buy · 10 studs", false, function(s)
	_G.AutoBuyEnabled = s
end)

sectionLabel(PageSettings, 193, "SUBMISSION CORE")

local function stepper(parent, y, label, getV, setV, minV, maxV)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -24, 0, 38)
	f.Position = UDim2.new(0, 12, 0, y)
	f.BackgroundColor3 = Theme.Card
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.ZIndex = 12
	f.Parent = parent
	corner(f, 12)
	stroke(f, Theme.Cyan, 1, 0.76)

	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Position = UDim2.new(0, 11, 0, 0)
	lb.Size = UDim2.new(0.5, 0, 1, 0)
	lb.Font = FM
	lb.Text = label
	lb.TextSize = 9
	lb.TextColor3 = Theme.Text
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.ZIndex = 13
	lb.Parent = f

	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(94, 28)
	box.Position = UDim2.new(1, -105, 0.5, -14)
	box.BackgroundColor3 = Theme.PanelSoft
	box.BorderSizePixel = 0
	box.ZIndex = 13
	box.Parent = f
	corner(box, 10)
	stroke(box, Theme.Cyan, 1, 0.72)

	local val = Instance.new("TextLabel")
	val.Size = UDim2.fromScale(1, 1)
	val.BackgroundTransparency = 1
	val.Font = FT
	val.Text = tostring(getV())
	val.TextSize = 11
	val.TextColor3 = Theme.Cyan
	val.ZIndex = 14
	val.Parent = box

	local mi = Instance.new("TextButton")
	mi.Size = UDim2.fromOffset(28, 28)
	mi.BackgroundTransparency = 1
	mi.Text = "−"
	mi.Font = FT
	mi.TextSize = 14
	mi.TextColor3 = Theme.Muted
	mi.ZIndex = 15
	mi.Parent = box

	local pl = Instance.new("TextButton")
	pl.Size = UDim2.fromOffset(28, 28)
	pl.Position = UDim2.new(1, -28, 0, 0)
	pl.BackgroundTransparency = 1
	pl.Text = "+"
	pl.Font = FT
	pl.TextSize = 14
	pl.TextColor3 = Theme.Muted
	pl.ZIndex = 15
	pl.Parent = box

	mi.MouseButton1Click:Connect(function()
		setV(math.max(minV, getV() - 1))
		val.Text = tostring(getV())
		updateCounters()
	end)

	pl.MouseButton1Click:Connect(function()
		setV(math.min(maxV, getV() + 1))
		val.Text = tostring(getV())
		updateCounters()
	end)
end

stepper(PageSettings, 209, "Submit After", function()
	return _G.SubmitAfterCount
end, function(v)
	_G.SubmitAfterCount = v
end, 1, 20)

stepper(PageSettings, 253, "Attempts", function()
	return _G.SubmitAttempts
end, function(v)
	_G.SubmitAttempts = v
end, 1, 6)

local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Position = UDim2.new(0, 14, 0, 300)
info.Size = UDim2.new(1, -28, 0, 38)
info.Font = FB
info.TextSize = 8
info.TextColor3 = Theme.Muted
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = "TRIGGERS\ncode · riddle · code is · riddle is · the code is · the riddle is"
info.ZIndex = 12
info.Parent = PageSettings

-- Bottom navigation
local Nav = Instance.new("Frame")
Nav.Size = UDim2.new(1, -24, 0, 30)
Nav.Position = UDim2.new(0, 12, 1, -40)
Nav.BackgroundColor3 = Theme.Card
Nav.BackgroundTransparency = 0.02
Nav.BorderSizePixel = 0
Nav.ZIndex = 14
Nav.Parent = MainFrame
corner(Nav, 12)
stroke(Nav, Theme.Cyan, 1, 0.62)

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(0.5, -7, 0, 2)
tabIndicator.Position = UDim2.new(0, 5, 1, -4)
tabIndicator.BackgroundColor3 = Theme.Cyan
tabIndicator.BorderSizePixel = 0
tabIndicator.ZIndex = 15
tabIndicator.Parent = Nav
corner(tabIndicator, 2)

local function navTab(text, xScale)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -5, 1, -4)
	b.Position = UDim2.new(xScale, 2.5, 0, 2)
	b.BackgroundTransparency = 1
	b.Font = FT
	b.TextSize = 8
	b.Text = text
	b.TextColor3 = Theme.Muted
	b.ZIndex = 15
	b.AutoButtonColor = false
	b.Parent = Nav
	return b
end

local navMain = navTab("◉  ARC", 0)
local navSet = navTab("⚙  SETTINGS", 0.5)

local function selectTab(name)
	currentTab = name
	PageMain.Visible = name == "Main"
	PageSettings.Visible = name == "Settings"
	navMain.TextColor3 = name == "Main" and Theme.Text or Theme.Muted
	navSet.TextColor3 = name == "Settings" and Theme.Text or Theme.Muted
	TS:Create(tabIndicator, TIS, {
		Position = name == "Main"
			and UDim2.new(0, 5, 1, -4)
			or UDim2.new(0.5, 2.5, 1, -4),
	}):Play()
end

navMain.MouseButton1Click:Connect(function() selectTab("Main") end)
navSet.MouseButton1Click:Connect(function() selectTab("Settings") end)

-- Minimized ARC reactor
Orb = Instance.new("TextButton")
Orb.Size = UDim2.fromOffset(48, 48)
Orb.AnchorPoint = Vector2.new(1, 0)
Orb.Position = UDim2.new(1, -18, 0, 18)
Orb.BackgroundColor3 = Theme.Panel
Orb.BackgroundTransparency = 0.04
Orb.Text = ""
Orb.AutoButtonColor = false
Orb.Visible = false
Orb.ZIndex = 20
Orb.Parent = ScreenGui
corner(Orb, 24)
stroke(Orb, Theme.Cyan, 1.5, 0.25)

local orbGlow = addGlow(Orb, 44, 0.91)
local orbOuter, orbInner, orbCore = makeArc(Orb, 32, Theme.Cyan, 1.7, 21)

local function setMinimized(state)
	isMinimized = state
	if state then
		TS:Create(MainFrame, TIQ, {
			Size = UDim2.fromOffset(46, 46),
			BackgroundTransparency = 1
		}):Play()
		task.wait(0.18)
		MainFrame.Visible = false
		Orb.Visible = true
		Orb.Size = UDim2.fromOffset(36, 36)
		TS:Create(Orb, TIB, { Size = UDim2.fromOffset(48, 48) }):Play()
	else
		Orb.Visible = false
		MainFrame.Visible = true
		MainFrame.Size = UDim2.fromOffset(PANEL_W * 0.94, PANEL_H * 0.94)
		MainFrame.BackgroundTransparency = 1
		TS:Create(MainFrame, TIB, {
			Size = UDim2.fromOffset(PANEL_W, PANEL_H),
			BackgroundTransparency = 0.04,
		}):Play()
	end
end

MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
Orb.MouseButton1Click:Connect(function() setMinimized(false) end)

-- Dragging for both the full panel and the minimized ARC
do
	local dragging, start, startPos, dragTarget

	local function beginDrag(target, input)
		dragging = true
		dragTarget = target
		start = input.Position
		startPos = target.Position
	end

	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(MainFrame, input)
		end
	end)

	Orb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(Orb, input)
		end
	end)

	Header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			dragTarget = nil
		end
	end)

	Orb.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			dragTarget = nil
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and dragTarget
			and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - start
			dragTarget.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + d.X,
				startPos.Y.Scale,
				startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- Subtle ARC animation; purely visual.
task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		local t = tick()
		if panelGradient then panelGradient.Rotation = (18 + t * 7) % 360 end
		if panelTopGlow then panelTopGlow.BackgroundTransparency = 0.16 + math.sin(t * 1.6) * 0.08 end
		if logoOuter then logoOuter.Rotation = (t * 18) % 360 end
		if logoInner then logoInner.Rotation = (-t * 24) % 360 end
		if orbOuter then orbOuter.Rotation = (t * 20) % 360 end
		if orbInner then orbInner.Rotation = (-t * 28) % 360 end
		if StatusDot then StatusDot.BackgroundTransparency = 0.08 + math.sin(t * 1.7) * 0.12 end
		task.wait(0.05)
	end
end)

startPlayerGuiScanner()
print("[Stark Sniper] Stark ARC luxury GUI loaded — logic preserved")
