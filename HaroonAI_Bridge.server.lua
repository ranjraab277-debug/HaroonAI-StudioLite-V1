-- HAROON AI STUDIO LITE V1
-- المطلوب منك هنا فقط: ضع رابط Render وكلمة Bridge Connect Password.
-- لا تضع GEMINI API KEY هنا.
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local RENDER_URL = "https://YOUR-SERVICE.onrender.com"
local BRIDGE_CONNECT_PASSWORD = "ضع_كلمة_الـBridge_هنا"
local POLL_SECONDS = 1

local function call(method, url, data)
    local headers = {
        ["X-Bridge-Token"] = BRIDGE_CONNECT_PASSWORD,
        ["Content-Type"] = "application/json"
    }
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = method,
            Headers = headers,
            Body = data and HttpService:JSONEncode(data) or nil
        })
    end)
    if not ok then return false, tostring(res) end
    if not res.Success then return false, "HTTP "..tostring(res.StatusCode) end
    local decoded = nil
    if res.Body and res.Body ~= "" then
        pcall(function() decoded = HttpService:JSONDecode(res.Body) end)
    end
    return true, decoded
end

local function parentOf(name)
    if not name or name == "Workspace" then return Workspace end
    return Workspace:FindFirstChild(name) or Workspace
end

local function find(name)
    return Workspace:FindFirstChild(name, true)
end

local function prop(obj,key,v)
    if (key=="Size" or key=="Position") and typeof(v)=="table" then
        v=Vector3.new(v[1],v[2],v[3])
    elseif key=="Color" and typeof(v)=="table" then
        v=Color3.fromRGB(v[1],v[2],v[3])
    elseif key=="Material" and typeof(v)=="string" then
        local ok,m=pcall(function() return Enum.Material[v] end)
        if ok and m then v=m end
    end
    return pcall(function() obj[key]=v end)
end

local function execute(op)
    if op.type=="CREATE_PART" then
        local p=Instance.new("Part")
        p.Name=op.name or "HaroonPart";p.Anchored=true;p.Parent=parentOf(op.parent)
        for k,v in pairs(op.properties or {}) do prop(p,k,v) end
        return true,p:GetFullName()
    elseif op.type=="CREATE_FOLDER" then
        local f=Instance.new("Folder");f.Name=op.name or "HaroonFolder";f.Parent=parentOf(op.parent)
        return true,f:GetFullName()
    elseif op.type=="DELETE" then
        local o=find(op.name);if not o then return false,"Not found: "..tostring(op.name) end;o:Destroy();return true,"Deleted"
    elseif op.type=="MOVE" then
        local o=find(op.name);if not o or not o:IsA("BasePart") then return false,"Part not found" end
        o.Position=Vector3.new(op.position[1],op.position[2],op.position[3]);return true,"Moved"
    elseif op.type=="RESIZE" then
        local o=find(op.name);if not o or not o:IsA("BasePart") then return false,"Part not found" end
        o.Size=Vector3.new(op.size[1],op.size[2],op.size[3]);return true,"Resized"
    elseif op.type=="RENAME" then
        local o=find(op.name);if not o then return false,"Not found" end;o.Name=tostring(op.newName);return true,"Renamed"
    elseif op.type=="SET_PROPERTY" then
        local o=find(op.name);if not o then return false,"Not found" end
        for k,v in pairs(op.properties or {}) do if not prop(o,k,v) then return false,"Property failed: "..k end end
        return true,"Updated"
    end
    return false,"Unknown operation: "..tostring(op.type)
end

print("[Haroon AI] Starting connection...")
while true do
    local ok,data=call("GET",RENDER_URL.."/api/poll")
    if ok and data and data.command then
        local c=data.command;local out={}
        for _,op in ipairs(c.operations or {}) do
            local success,msg=execute(op)
            table.insert(out,{success=success,message=msg,type=op.type})
            if not success then break end
        end
        call("POST",RENDER_URL.."/api/result",{id=c.id,success=true,operations=out,finishedAt=os.time()})
    end
    task.wait(POLL_SECONDS)
end
