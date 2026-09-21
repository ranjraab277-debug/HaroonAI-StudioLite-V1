-- Haroon AI Studio Lite V2
-- سكربت سيرفر واحد مدمج.
-- غيّر RENDER_URL و BRIDGE_CONNECT_PASSWORD فقط.

local HttpService = game:GetService("HttpService")

local RENDER_URL = "https://YOUR-APP.onrender.com"
local BRIDGE_CONNECT_PASSWORD = "YOUR_BRIDGE_PASSWORD"

local POLL_SECONDS = 1
local MAX_RETRIES = 4

local function request(method, url, body)
	local headers = {
		["X-Bridge-Token"] = BRIDGE_CONNECT_PASSWORD,
		["Content-Type"] = "application/json"
	}
	for attempt = 1, MAX_RETRIES do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = url, Method = method, Headers = headers, Body = body or ""
			})
		end)
		if ok and response and response.Success then return true, response end
		task.wait(math.min(2 ^ attempt, 8))
	end
	return false, nil
end

local function findPath(path)
	if not path or path == "" or path == "Workspace" then return workspace end
	local current = game
	for part in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(part)
		if not current then return nil end
	end
	return current
end

local function vec3(v)
	if typeof(v) == "table" and #v >= 3 then
		return Vector3.new(tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0)
	end
end

local function setProperty(obj, prop, value)
	if prop == "Size" or prop == "Position" or prop == "Orientation" then
		value = vec3(value)
	elseif prop == "Color" and typeof(value) == "table" then
		value = Color3.new(tonumber(value[1]) or 1, tonumber(value[2]) or 1, tonumber(value[3]) or 1)
	elseif prop == "Material" and typeof(value) == "string" and Enum.Material[value] then
		value = Enum.Material[value]
	end
	return pcall(function() obj[prop] = value end)
end

local function create(className, name, parent)
	local ok, obj = pcall(function()
		local x = Instance.new(className)
		x.Name = name or className
		x.Parent = parent
		return x
	end)
	return ok and obj or nil
end

local function execute(op)
	local kind = op.op

	if kind == "CREATE_PART" then
		local parent = findPath(op.parent)
		if not parent then return false, "Parent not found" end
		local obj = create("Part", op.name, parent)
		if not obj then return false, "Create Part failed" end
		for p,v in pairs(op.properties or {}) do setProperty(obj,p,v) end
		return true, obj:GetFullName()

	elseif kind == "CREATE_FOLDER" or kind == "CREATE_MODEL" then
		local parent = findPath(op.parent)
		if not parent then return false, "Parent not found" end
		local obj = create(kind == "CREATE_FOLDER" and "Folder" or "Model", op.name, parent)
		return obj ~= nil, obj and obj:GetFullName() or "Create failed"

	elseif kind == "CREATE_SCRIPT" then
		local parent = findPath(op.parent)
		if not parent then return false, "Parent not found" end
		local className = op.scriptType == "LocalScript" and "LocalScript"
			or op.scriptType == "ModuleScript" and "ModuleScript" or "Script"
		local obj = create(className, op.name, parent)
		if not obj then return false, "Create script failed" end
		local ok = pcall(function() obj.Source = tostring(op.source or "") end)
		if not ok then obj:Destroy(); return false, "Script.Source is not available in this environment" end
		return true, obj:GetFullName()

	elseif kind == "DELETE" then
		local obj = findPath(op.target)
		if not obj or obj == game then return false, "Target not found" end
		obj:Destroy(); return true, "deleted"

	elseif kind == "MOVE" or kind == "RESIZE" then
		local obj = findPath(op.target)
		local value = vec3(kind == "MOVE" and op.position or op.size)
		if not obj or not value then return false, "Invalid target/value" end
		return setProperty(obj, kind == "MOVE" and "Position" or "Size", value), kind == "MOVE" and "moved" or "resized"

	elseif kind == "ROTATE" then
		local obj = findPath(op.target)
		local value = vec3(op.rotation)
		if not obj or not value then return false, "Invalid target/value" end
		return setProperty(obj, "Orientation", value), "rotated"

	elseif kind == "RENAME" then
		local obj = findPath(op.target)
		if not obj then return false, "Target not found" end
		obj.Name = tostring(op.name or obj.Name); return true, "renamed"

	elseif kind == "SET_PROPERTY" then
		local obj = findPath(op.target)
		if not obj then return false, "Target not found" end
		return setProperty(obj, op.property, op.value), "property set"
	end

	return false, "Unsupported operation: "..tostring(kind)
end

local function sendResult(commandId, results)
	local body = HttpService:JSONEncode({
		commandId = commandId, status = "completed", results = results
	})
	request("POST", RENDER_URL.."/api/result", body)
end

print("[Haroon AI V2] Bridge starting")

task.spawn(function()
	while true do
		local ok, response = request("GET", RENDER_URL.."/api/poll")
		if ok and response then
			local decoded, job = pcall(function() return HttpService:JSONDecode(response.Body) end)
			if decoded and job and job.commandId and job.operations then
				local results = {}
				for i,op in ipairs(job.operations) do
					local success, message = execute(op)
					results[i] = {op=op.op, success=success, message=message}
					task.wait(0.05)
				end
				sendResult(job.commandId, results)
			end
		end
		task.wait(POLL_SECONDS)
	end
end)
