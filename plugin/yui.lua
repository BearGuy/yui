vim.notify('hello there')
if vim.g.loaded_yui == 1 then
  return
end
vim.g.loaded_yui = 1

-- Function to create directory if it doesn't exist
local function create_dir_if_not_exists(dir)
    local success, err = vim.fn.mkdir(dir, 'p')
    if not success then
        vim.api.nvim_err_writeln("Error creating directory: " .. dir .. ", " .. err)
    end
end

-- Define the path to the database file
local db_dir = vim.fn.stdpath('config') .. '/plugin/yui/'
-- Create the directories if they don't exist
create_dir_if_not_exists(db_dir)

--local function setup_yui()
    --local config_dir = vim.fn.stdpath('config')
    --local plugin_dir = config_dir .. '/plugin'
    --local db_path = plugin_dir .. '/yui.db'

    ---- Create the plugin directory if it doesn't exist
    --if vim.fn.isdirectory(plugin_dir) == 0 then
        --vim.fn.mkdir(plugin_dir, 'p')
    --end

    ---- Set up the SQLite database
    ---- (Assuming you have a function to initialize the database)
    ----require('yui').init_db(db_path)
--end

---- Create an autocommand to set up Yui after PackerSync
--vim.api.nvim_create_autocmd('User', {
    --pattern = 'PackerComplete',
    --callback = function()
        --setup_yui()
    --end,
--})

--vim.api.nvim_create_user_command('Yui', 'echo Welcome to Yui!', {'bang': v:true })
