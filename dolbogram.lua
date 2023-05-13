local effil = require('effil')

--// Async http request by neverlane
function requestRunner()
    return effil.thread(function(method, url, args)
        local requests = require 'requests'
        local _args = {}
        local function table_assign(target, def, deep)
            for k, v in pairs(def) do
                if target[k] == nil then
                    if type(v) == 'table' or type(v) == 'userdata' then
                        target[k] = {}
                        table_assign(target[k], v)
                    else
                        target[k] = v
                    end
                elseif deep and (type(v) == 'table' or type(v) == 'userdata') and (type(target[k]) == 'table' or type(target[k]) == 'userdata') then
                    table_assign(target[k], v, deep)
                end
            end
            return target
        end
        table_assign(_args, args, true)
        local result, response = pcall(requests.request, method, url, _args)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)
end

function handleAsyncHttpRequestThread(runner, resolve, reject)
    local status, err
    repeat
        status, err = runner:status() 
        wait(0)
    until status ~= 'running'
    if not err then
        if status == 'completed' then
            local result, response = runner:get()
            if result then
                resolve(response)
            else
                reject(response)
            end
        return
        elseif status == 'canceled' then
            return reject(status)
        end
    else
        return reject(err)
    end
end

function asyncHttpRequest(method, url, args, resolve, reject)
    assert(type(method) == 'string', '"method" expected string')
    assert(type(url) == 'string', '"url" expected string')
    assert(type(args) == 'table', '"args" expected table')
    local thread = requestRunner()(method, url, effil.table(args)) 
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    
    return {
        effilRequestThread = thread;
        luaHttpHandleThread = lua_thread.create(handleAsyncHttpRequestThread, thread, resolve, reject);
    }
end


function isIn(t, val, isKey)
    for k, v in pairs(t) do
        if (isKey and k == val) or (not isKey and v == val) then
            return true
        end
    end
end

---@enum Events
local Events = {
    'message',
    'edited_message',
    'channel_post',
    'edited_channel_post',
    'inline_query',
    'chosen_inline_result',
    'callback_query',
    'shipping_query',
    'pre_checkout_query',
    'poll',
    'poll_answer',
    'my_chat_member',
    'chat_member',
    'chat_join_request',
}

local API = {}

function API.__index(self, key)
    return API[key] or function(self, ...) API.__request(self, key, ...) end
end

---@param self table
---@param event Events
---@param callback function
function API.on(self, event, callback)
    assert(isIn(Events, event) or event == '*' or event == 'ready', 'Unknown event "'..event..'", available events: '..table.concat(Events, ', '))
    self.events[event] = callback
end

function API.__request(self, url, data, callbackOk, callbackError, httpMethod, headers)
    local url = url:find('^http') and url or self.url..url
    local callbackOk = callbackOk or function(response) assert(response.status_code == 200, response.status_code..': '..response.text) end
    local callbackError = callbackError or function(e) error(e) end

    asyncHttpRequest(httpMethod or 'POST', url, { headers = headers or { ['Content-Type'] = 'application/json' }, data = data }, callbackOk, callbackError)
end

function API.process(self)
    if self.update.send then
        self.update.send = false
        self:getUpdates(
            { offset = (self.update.id or -1) + 1 },
            function(response)
                assert(response.status_code == 200, response.status_code .. ': ' .. response.text)
                local data = decodeJson(response.text)
                for _, update in pairs(data.result) do
                    -->> get event type
                    local eventType = nil
                    for _, _eventType in ipairs(Events) do
                        if update[_eventType] then
                            eventType = _eventType
                        end
                    end

                    -->> call event
                    if type(self.events[eventType]) == 'function' then
                        self.events[eventType](update[eventType])
                    end

                    -->> call "any" event
                    if type(self.events['*']) == 'function' then
                        self.events['*'](update, encodeJson(update))
                    end

                    -->> update
                    self.update.id = update.update_id
                end
                self.update.send = true
                self.update.time = os.clock()
            end,
            function(err)
                error(err)
            end
        )
    end
end

function API.connect(self)
    local function ready(response)
        local data = decodeJson(response.text)
        assert(data.ok, 'response.text')
        self.connected = true
        if type(self.events.ready) == 'function' then
            self.events.ready(data.result)
        end
    end
    self:__request('getMe', {}, ready, function(err) error(err) end)
    if self.updateOnConnect then
        lua_thread.create(function()
            while true do
                wait(0)
                self:process()
            end
        end)
    end
end

return setmetatable({}, {
    __call = function(self, token, optionalParams)
        assert(type(token) == 'string', 'Invalid token (token must be a string)')
        return setmetatable({
            connected = false,
            token = token,
            url = 'https://api.telegram.org/bot'..token..'/',
            events = {},
            updateOnConnect = true,
            update = {
                send = true,
                id = 0,
                time = 0,
            }
        }, API)
    end,
    __index = {
        name = 'Dolbogram',
        author = 'chapo',
        url = 'https://vk.com/chaposcripts',
        version = '0.1'
    }
})
