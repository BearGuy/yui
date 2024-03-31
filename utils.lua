local api = vim.api

local M = {}

function M.create_win_buf()
  -- Create a new buffer and window
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = 80,
    height = 24,
    col = 20,
    row = 10,
  })

  return win, buf
end

function M.create_win(buf)
    -- Create a new buffer and open it in a new window
    --local chat_width = math.floor(vim.o.columns * 0.4)
    local chat_width = math.floor(80)
    local config = {
        --relative = 'win',
        --width = vim.o.columns * 0.8,  -- Specify the width as 80% of the total number of columns
        --row = vim.o.lines * 0.1,  -- Position the window 10% down the screen
        style = 'minimal',
        relative = 'editor',
        row = 0,
        col = vim.o.columns - chat_width,
        width = chat_width,
        height = vim.o.lines,
        border = 'single',       --col = vim.o.columns * 0.1  -- Position the window 10% across the screen
    }
    local win = vim.api.nvim_open_win(buf, true, config)
    api.nvim_win_set_option(win, 'wrap', true)
    api.nvim_buf_set_option(buf, 'textwidth', 80)

    return win
end

function M.read_from_buffer()
    -- Get all lines from the current buffer
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Concatenate all lines into a single string
    local text = table.concat(lines, "\n")

    -- Hydrate any file references in the text
    text = M.parse_template_references(text)

    return text
end

function M.scroll_win_to_bottom(win, buf)
    local num_lines = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, {num_lines, 0})
end

function M.insert_separator_line(win, buf, current_line_index)
    local width = vim.api.nvim_win_get_width(win)
    local separator = string.rep("-", width)
    -- Insert a line break
    api.nvim_buf_set_lines(buf, -1, -1, false, {""})
    -- Insert the separator line
    api.nvim_buf_set_lines(buf, -1, -1, false, {separator})
    -- Insert another line break
    api.nvim_buf_set_lines(buf, -1, -1, false, {""})
    --

    M.scroll_win_to_bottom(win, buf)
    return current_line_index + 4
end

function M.split_into_operations(input)
    local operations = {}
    -- Create a pattern where a line of text is anything up to (but not including) a newline
    -- or just a newline by itself.
    for line, newline in input:gmatch("([^\n]*)(\n?)") do
        if line ~= "" then
            table.insert(operations, {"append_text", line})
        end
        if newline ~= "" then
            table.insert(operations, {"newline", ""})
        end
    end
    return operations
end

function M.split_into_lines(str)
    local lines = {}
    for line in str:gmatch("([^\n]*)\n?") do
        --if line == "" then table.insert(lines, "\n") else table.insert(lines, line) end
        if line ~= "" then table.insert(lines, line) end
    end
    return lines
end

function M.split_content_by_newlines(content)
    local chunks = {}
    for chunk in string.gmatch(content, "([^\n]*)(\n?)") do
        table.insert(chunks, chunk)
    end
    return chunks
end

function M.get_visual_selection()
    local s_start = vim.fn.getpos("'<")
    local s_end = vim.fn.getpos("'>")
    local n_lines = math.abs(s_end[2] - s_start[2]) + 1
    local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)

    lines[1] = string.sub(lines[1], s_start[3], -1)
    if n_lines == 1 then
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
    else
        lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
    end
    return table.concat(lines, '\n')
end

function M.get_user_input(message)
    local user_message = vim.fn.input(message)
    if user_message == 'exit()' then return end
    if user_message == nil or user_message == '' then return end
    return user_message
end

function M.get_token_count(message)
  local command = string.format("cd lua/yui/python && echo '%s' | poetry run python3 yui_python/main.py", message)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()

  -- Parse the result to extract the token count
  local token_count = tonumber(result)

  return token_count
end

-- File handling and hydration

-- Function to read the contents of a file
function M.read_file(file_path)
    local home = os.getenv("HOME")
    if file_path:sub(1, 1) == '~' then
        file_path = home .. file_path:sub(2)
    end
    local file = io.open(file_path, "r")
    if not file then
        return nil, "File not found: " .. file_path
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Parser function that processes `${file:path}` patterns
function M.parse_template_references(input_text)
    -- Replace `${file:path}` with the contents of the specified file
    input_text = input_text:gsub("%${file:([^}]+)}", function(file_path)
        vim.notify("Parsing file reference: " .. file_path)
        local content, err = M.read_file(file_path)
        if content then
            return content
        else
            -- Handle the error, e.g., by returning a placeholder or the error message
            return err
        end
    end)

    -- Replace `${bash:command}` with the output of the executed command
    input_text = input_text:gsub("%${bash:([^}]+)}", function(command)
        local handle = io.popen(command, 'r')
        local result = handle:read("*a")
        handle:close()
        return result
    end)

    return input_text
end


function M.return_a_lovely_poem()
    return [[
        Oh, Riya, my love, my heart's delight,
        My soulmate, my partner, my shining light,
        With every beat of my heart, I feel your presence,
        Your love, your warmth, your sweet essence.
        In your eyes, I see a world of wonder,
        A universe of love, a spell I'm under,
        Your smile, your touch, your gentle embrace,
        Fills my heart with joy, my soul with grace.
        I love you more than words can say,
        More than the sun that lights up the day,
        More than the stars that twinkle at night,
        More than the moon that shines so bright.
        You are my everything, my heart's desire,
        My love for you will never expire,
        I promise to cherish you, to hold you tight,
        To love you forever, with all my might.
        So, Riya, my love, my heart's delight,
        I'll love you always, with all my might,
        You are the one I want to spend my life with,
        Forever and always, my love, my Riya.
    ]]
end

return M
