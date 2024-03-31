--local openai = require("yui.openai")
local anthropic = require("yui.anthropic")
local utils = require("yui.utils")
local db = require("yui.db")


local M = {}


local buf = vim.api.nvim_create_buf(false, true)
local win = nil

vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')


function new_chat()
    return {
        id = nil,
        name = '',
        line = '',
        line_index = 0,
        total_tokens = 0,
        system = [[
            I am a helpful code and software assistant.
            All code I provide I will cite the language like so ```python
        ]],
        messages = {}
    }
end

local current_chat = new_chat()

--- Function for generating a new chat session
--- and continuously sending messages until the user exits
function M.new_chat_session()
    user_message = utils.get_user_input("User: ")
    if user_message == nil then return end

    M.show_chat_win()

    M.add_message_to_chat(user_message)
end

function M.new_chat_session_with_vis_selection()
    local vis_text = utils.get_visual_selection()

    user_message = utils.get_user_input("User: ")
    if user_message == nil then return end

    M.show_chat_win()

    user_message = user_message .. vis_text

    M.add_message_to_chat(user_message)
end

function M.new_message_from_buffer()
    local text = utils.read_from_buffer()

    M.show_chat_win()

    M.add_message_to_chat(text)
end

function M.add_user_message(user_message)
    table.insert(current_chat.messages, {role = 'user', content = user_message })
    db.ChatDB.messages:add(current_chat.id, 'user', user_message)

    user_message = '**User:** ' .. user_message

    M.render_message_to_window(win, buf, user_message)
    current_chat.line_index = utils.insert_separator_line(win, buf, current_chat.line_index)
    current_chat.line = ''
end

function M.add_message_to_chat(user_message)
    M.add_user_message(user_message)

    response_message = ''

    current_chat.line = '**AI:** '
    local function on_data(data)
        --vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'Error: ' .. data })
        --if data.choices and data.choices[1] and data.choices[1].delta and data.choices[1].delta['content'] then
        if data.delta and data.delta.text then
            --local content = data.choices[1].delta['content']
            local content = data.delta.text
            response_message = response_message .. content

            M.render_message_to_window(win, buf, content)
        end

        if data.error then
            err = data.error['message']
            vim.notify('Error: ' .. err)
        end
    end

    local function on_complete(err)
        if err then
            vim.notify('Error: ' .. err)
        end

        current_chat.line = ''
        current_chat.line_index = utils.insert_separator_line(win, buf, current_chat.line_index)

        table.insert(current_chat.messages, {role = 'assistant', content = response_message })
        db.ChatDB.messages:add(current_chat.id, 'assistant', response_message)

    end

    anthropic.chat_completions({
        system = current_chat.system,
        messages = current_chat.messages
    }, on_data, on_complete)
end

function M.show_chat_win()
    if win == nil then
        win = utils.create_win(buf)
    elseif vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_set_current_win(win)
    else
        win = utils.create_win(buf)
    end
end

function M.clear_chat_win()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

function M.create_chat()
  vim.ui.input({
    prompt = "Enter a new chat name: ",
    default = "New Chat",
    completion = "custom",
    highlight = function(input)
      if string.len(input) > 8 then
        return { { 0, 8, "InputHighlight" } }
      else
        return {}
      end
    end,
  }, function(chatName)
    if chatName then
      local resp = db.ChatDB.chats:add(chatName)

      current_chat.id = resp
      current_chat.name = chatName

      M.new_chat_session()
    else
      print "You cancelled"
    end
  end)
end

function M.list_chats()
    local chats = db.ChatDB.chats:get_all()
    local chatList = {}
    for _, chat in ipairs(chats) do
        table.insert(chatList, string.format("%d: %s", chat.id, chat.name))
    end
    vim.ui.select(chatList, {
        prompt = "Select a chat",
        format_item = function(item)
          return item
        end,
    }, function(selectedChat, idx)
      if selectedChat then
        local id, name = string.match(selectedChat, "(%d+): (.+)")
        print("You selected chat " .. name .. " with id " .. id .. " at index " .. idx)

        current_chat.id = id
        current_chat.name = name

        M.load_chat(current_chat.id)
      else
        print "You cancelled"
      end
    end)
end

function M.load_chat(chat_id)
  local chat = db.ChatDB.chats:get(chat_id)
  print(chat.name)

  local messages = db.ChatDB.messages:get({chat_id = chat_id}) -- Assuming messages:get accepts a filter.

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  current_chat = new_chat()
  current_chat.id = chat.id
  current_chat.name = chat.name
  current_chat.tokens = chat.tokens

  M.show_chat_win()

  for _, message in ipairs(messages) do

    --token_count = utils.get_token_count(message.message)

    table.insert(current_chat.messages, {
        role = message.sender,
        content = message.message,
        tokens = token_count
    })

    message_text = ''
    if message.sender == "user" then
        message_text = "**User:** " .. message.message
    elseif message.sender == "assistant" then
        message_text = "**AI:** " .. message.message
    end


    M.render_message_to_window(win, buf, message_text)

    current_chat.line = ''
    current_chat.line_index = utils.insert_separator_line(win, buf, current_chat.line_index)
  end

  -- Scroll to the bottom of the buffer to see the latest messages.
  utils.scroll_win_to_bottom(win, buf)
end

function M.delete_chat()
  deleted_chat = current_chat

  user_message = utils.get_user_input("Are you sure you want to delete? ")
  if user_message == nil then return end
  if user_message == 'n' then return end

  local resp = db.ChatDB.chats:delete(deleted_chat.id)

  print("Chat " .. deleted_chat.name .. " deleted")

  M.clear_chat_win()

  current_chat = new_chat()
end

function M.render_message_to_window(win, buf, content)
    local chunks = utils.split_into_operations(content)

    for i, chunk in ipairs(chunks) do
        operation = chunk[1]
        if operation == 'newline' then
            -- If chunk is newline character, increment current_line_index and clear current_line
            current_chat.line_index = current_chat.line_index + 1
            current_chat.line = ''
            vim.api.nvim_buf_set_lines(buf, current_chat.line_index, current_chat.line_index + 1, false, {current_chat.line})

            utils.scroll_win_to_bottom(win, buf)
        elseif operation == 'append_text' then
            -- If chunk is not newline character, append chunk to current line
            current_chat.line = current_chat.line .. chunk[2]
            vim.api.nvim_buf_set_lines(buf, current_chat.line_index, current_chat.line_index + 1, false, {current_chat.line})
        end
    end
end

return M
