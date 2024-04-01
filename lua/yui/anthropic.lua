local M = {}

local config = require("yui.config")

---@param cmd string
---@param args string[]
---@param on_stdout_chunk fun(chunk: string): nil
---@param on_complete fun(err: string?, output: string?): nil
local function exec (cmd, args, on_stdout_chunk, on_complete)
    local stdout = vim.loop.new_pipe()
    local stdout_chunks = {}
    local function on_stdout_read (_, chunk)
        if chunk then
            vim.schedule(function ()
                table.insert(stdout_chunks, chunk)
                on_stdout_chunk(chunk)
            end)
        end
    end

    local stderr = vim.loop.new_pipe()
    local stderr_chunks = {}
    local function on_stderr_read (_, chunk)
        if chunk then
            table.insert(stderr_chunks, chunk)
        end
    end

    local handle

    handle, error = vim.loop.spawn(cmd, {
        args = args,
        stdio = {nil, stdout, stderr},
    }, function (code)
        stdout:close()
        stderr:close()
        handle:close()

        vim.schedule(function ()
            if code ~= 0 then
                on_complete(vim.trim(table.concat(stderr_chunks, "")))
            else
                on_complete()
            end
        end)
    end)

    if not handle then
        on_complete(cmd .. " could not be started: " .. error)
    else
        stdout:read_start(on_stdout_read)
        stderr:read_start(on_stderr_read)
    end
end

local function log(msg)
    local log_file = "yui_error.log" -- specify your log file path
    local file = io.open(log_file, "a") -- open in append mode
    if file then
        file:write(msg .. "\n")
        file:close()
    end
end

local function request (endpoint, body, on_data, on_complete)
    local api_key = vim.g.yui_api_key
    if not api_key then
        on_complete("$ANTHROPIC_API_KEY environment variable must be set")
        return
    end

    local curl_args = {
        "--silent", "--show-error", "--no-buffer",
        "--max-time", config.timeout,
        "-L", "https://api.anthropic.com/v1/" .. endpoint,
        "-H", "x-api-key: " .. api_key,
        "-X", "POST", "-H", "content-type: application/json",
        "-H", "anthropic-version: 2023-06-01",
        "-H", "anthropic-beta: messages-2023-12-15",
        "-d", vim.json.encode(body),
    }

    --local current_message = {content = ""}
    --local function process_event(event_data)
        --if event_data.type == "content_block_delta" and event_data.delta.type == "text_delta" then
            --current_message.content = current_message.content .. event_data.delta.text
        --elseif event_data.type == "message_stop" then
            --on_data(current_message)
            --current_message = {content = ""} -- Reset for the next message
        --elseif event_data.type == "ping" then
            ---- Handle ping event if necessary, for keeping connection alive or similar
        --end
    --end
    --

    local pattern = "event: (%S+)\n(data: ([^\n]+))"
    local function on_stdout_chunk(chunk)
        for event_name, _, json_str in string.gmatch(chunk, pattern) do
            local success, json = pcall(vim.json.decode, json_str)
            if success then
                -- Successfully decoded JSON; call on_data with the JSON object
                if json then
                    on_data(json)
                end
            else
                on_complete("Failed to decode JSON: " .. json_str)
            end
        end
    end


    exec("curl", curl_args, on_stdout_chunk, on_complete)
end

---@param body table
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.chat_completions (body, on_data, on_complete)
    body = vim.tbl_extend("keep", body, {
        model = config.completions_model,
        max_tokens = 4096,
        temperature = config.temperature,
        stream = true,
        --system = [[
            --I am a helpful code and software assistant.
            --All code I provide I will cite the language like so ```python
        --]]
    })
    request("messages", body, on_data, on_complete)
end

---@param body table
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.completions (body, on_data, on_complete)
    body = vim.tbl_extend("keep", body, {
        model = config.completions_model,
        max_tokens = 2048,
        temperature = config.temperature,
        stream = true,
    })
    request("completions", body, on_data, on_complete)
end

---@param body table
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.edits (body, on_data, on_complete)
    body = vim.tbl_extend("keep", body, {
        model = config.edits_model,
        temperature = config.temperature,
    })
    request("edits", body, on_data, on_complete)
end

return M
