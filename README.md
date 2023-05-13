# dolbogram-lua-telegram-bot-api

## Examples  
### Echo bot
```lua
local Telegram = require('dolbobot')
local bot = Telegram('YOUR_TOKEN_HERE')
bot:connect()

bot:on('ready', function(me)
    print('Bot started!', ('ID: %s, Name: %s, Username: %s'):format(me.id, me.first_name, me.username))
end)

bot:on('message', function(message)
    msg('New message from ID:', message.from.id, 'Text: ', message.text)
    bot:sendMessage{chat_id = message.from.id, text = message.text}
end)

function main()
    while not isSampAvailable() do wait(0) end
    while true do
        wait(0)
        bot:process()
    end
end
```

### Buttons
```lua
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

function msg(...) sampAddChatMessage(table.concat({...}, '  '), -1) end

local Telegram = require('dolbogram')
local bot = Telegram('TOKEN')

bot:connect()

bot:on('ready', function(data)
    msg('Bot started, name: ', data.first_name)
end)

bot:on('*', function(data, json)
    msg('Any event handler was called!', json)
end)

bot:on('message', function(message)
    msg('New message from ID:', message.from.id, 'Text: ', message.text)
    if message.text == '/start' then
        bot:sendMessage{chat_id = message.from.id, text = u8('Тыкай на кнопочки'), reply_markup = {
            keyboard = {
                { { text = u8('Ник') }, { text = u8('Айди') } },
                { { text = u8('Сервер') } }
            }
        }}
    elseif message.text == u8('Ник') then
        bot:sendMessage{chat_id = message.from.id, text = u8('Твой ник: '..sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))}
    elseif message.text == u8('Айди') then
        bot:sendMessage{chat_id = message.from.id, text = u8('Твой айди: '..select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))}
    elseif message.text == u8('Сервер') then
        bot:sendMessage{chat_id = message.from.id, text = u8('Какую инфу о сервере ты хочешь узнать?'), reply_markup = {
            inline_keyboard = {
                { { text = u8('Название'), callback_data = 'server:name' }, { text = u8('Адрес'), callback_data = 'server:address' } },
                { { text = u8('Кол-во игроков'), callback_data = 'server:playersCount' } },
            }
        }}
    else
        bot:sendMessage{chat_id = message.from.id, text = u8('Я не понимаю че тебе надо, дурила')}
    end
end)

bot:on('callback_query', function(query)
    if query.data == 'server:name' then
        bot:sendMessage{chat_id = query.from.id, text = u8(sampGetCurrentServerName())}
    elseif query.data == 'server:address' then
        bot:sendMessage{chat_id = query.from.id, text = u8('IP:PORT: ' .. table.concat({sampGetCurrentServerAddress()}, ':'))}
    elseif query.data == 'server:playersCount' then
       
        bot:sendMessage{chat_id = query.from.id, text = u8('На сервере: '..sampGetPlayerCount(false) .. '\nВ зоне стрима: '..sampGetPlayerCount(true))}
    end
end)

function main()
    while not isSampAvailable() do wait(0) end
    wait(-1)
end
```
