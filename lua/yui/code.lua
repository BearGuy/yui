local api = vim.api
local M = {}

-- This function will use utils.get_visual_input
-- to get the input using visual mode and then generate code
-- based on the input using an llm. It will write the code
-- to the buffer where the original comment is

function M.generate_code_from_visual_input()
    local vis_text = utils.get_visual_input()
    if vis_text == nil then return end

    local code = anthropic.generate_code(vis_text)

    api.nvim_put({code}, "l", true, true)
end

