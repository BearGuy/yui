local sqlite = require "sqlite.db" --- for constructing sql databases
local tbl = require "sqlite.tbl" --- for constructing sql tables

--- sqlite builtin helper functions
local julianday, strftime = sqlite.lib.julianday, sqlite.lib.strftime

---@alias SenderType '"user"' | '"gpt"'

--[[ Datashapes ---------------------------------------------

---@class Chat
---@field id number: unique id

---@class ChatMessage
---@field id number: unique id
---@field chat_id number: foreign key referencing Chat.id.
---@field sender SenderType: the sender of the message.
---@field message string: the message content.
---@field timestamp string: the time the message was sent.

--]]

--[[ sqlite classes ------------------------------------------

---@class ChatTable: sqlite_tbl

---@class ChatMessageTable: sqlite_tbl

---@class ChatDatabase: sqlite_db
---@field chats ChatTable
---@field messages ChatMessageTable

--]]

---@type ChatTable
local chats = tbl("chats", {
  id = true,
  name = { "text", required = true },
  tokens = { "integer", required = true, default = 0}
})

---@type ChatMessageTable
local messages = tbl("messages", {
  id = true,
  chat_id = { "integer", required = true, reference = "chats.id", on_delete = "null" },
  sender = { "text", required = true },
  message = { "text", required = true },
  timestamp = { "text", required = true, default = strftime("%s", "now") },
})

---@type ChatDatabase
local ChatDB = sqlite {
  uri = "~/.config/nvim/lua/yui/yui.db",
  chats = chats,
  messages = messages,
}

function messages:add(chat_id, sender, message)
  local resp, err = messages:__insert {
    chat_id = chat_id,
    sender = sender,
    message = message,
  }

  if err then
    print("Error inserting message: ", err)
  --else
    --print(resp)
  end
  return resp
end

function messages:get(chat_id)
  return messages:__get({ where = {chat_id = chat_id} })
end

function chats:add(name)
  local resp, err = chats:insert {
    name = name
  }

  if err then
    print("Error inserting chat: ", err)
  --else
    --print(resp)
  end
  return resp
end

function chats:get_all()
  return chats:__get {}
end

function chats:get(chat_id)
  local resp, err = chats:__get({ where = {id = chat_id} })

  if err then
      print(err)
  end

  return resp[1]
end

--function chats:edit_tokens(chat_id)

--end

function chats:update_tokens(chat_id, tokens)
  local row = chats:where { id = chat_id }
  local resp, err = chats:update {
    where = { id = id },
    set = { count = row.tokens+ tokens},
  }

  if err then
      print(err)
  end
  print(resp)
  return resp
end

function chats:delete(chat_id)
  resp = messages:remove { chat_id = chat_id }
  return chats:remove { id = chat_id }
end

local M = {}

M.ChatDB = ChatDB

return M
