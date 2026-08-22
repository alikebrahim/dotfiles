local definition_pointers = { "!", "&", "^" }
local similarity_pointers = { "&", "^", "+" }
local similarity_depth = 2
local search_threshold = 3

---@class WordTarget
---@field buf integer
---@field win integer
---@field srow integer
---@field scol integer
---@field erow integer
---@field ecol integer
---@field word string
---@field insert boolean

---@return WordTarget
local function capture_target()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local insert = vim.fn.mode():find("i") ~= nil
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    local srow, scol = start_pos[2], start_pos[3]
    local erow, ecol = end_pos[2], end_pos[3]
    if srow > erow or (srow == erow and scol > ecol) then
      srow, scol, erow, ecol = erow, ecol, srow, scol
    end
    local text = vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
    local word = table.concat(text, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return {
      buf = buf,
      win = win,
      srow = srow - 1,
      scol = scol - 1,
      erow = erow - 1,
      ecol = ecol,
      word = word,
      insert = false,
    }
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = vim.api.nvim_get_current_line()
  local col = cursor[2] + 1
  if col > #line then
    col = #line
  end
  if col > 0 and line:sub(col, col):match("%s") and col > 1 then
    col = col - 1
  end

  local start_col, end_col = col, col
  while start_col > 1 and line:sub(start_col - 1, start_col - 1):match("[%w'_%-]") do
    start_col = start_col - 1
  end
  while end_col <= #line and line:sub(end_col, end_col):match("[%w'_%-]") do
    end_col = end_col + 1
  end

  local word = start_col > 0 and line:sub(start_col, end_col - 1) or ""
  if word == "" then
    word = vim.fn.expand("<cword>")
  end

  return {
    buf = buf,
    win = win,
    srow = cursor[1] - 1,
    scol = math.max(start_col - 1, 0),
    erow = cursor[1] - 1,
    ecol = math.max(end_col - 1, 0),
    word = word,
    insert = insert,
  }
end

---@param target WordTarget
---@param replacement string
local function apply_word(target, replacement)
  if not vim.api.nvim_buf_is_valid(target.buf) or not replacement or replacement == "" then
    return
  end
  vim.api.nvim_buf_set_text(target.buf, target.srow, target.scol, target.erow, target.ecol, { replacement })
  if vim.api.nvim_win_is_valid(target.win) then
    pcall(vim.api.nvim_win_set_cursor, target.win, { target.srow + 1, target.scol + #replacement })
    if target.insert then
      vim.api.nvim_set_current_win(target.win)
      vim.cmd("startinsert")
    end
  end
end

---@param kind "dictionary"|"thesaurus"
local function open_word_picker(kind)
  local target = capture_target()
  local wordnet = require("blink-cmp-words.wordnet")

  Snacks.picker.pick({
    title = kind == "dictionary" and "Dictionary" or "Thesaurus",
    live = true,
    limit_live = 40,
    search = target.word,
    layout = { preset = "ivy" },
    format = "text",
    preview = "preview",
    finder = function(_, ctx)
      local query = vim.trim(ctx.filter.search or "")
      if query == "" then
        return {}
      end

      local ok, matches
      if kind == "dictionary" then
        ok, matches = pcall(wordnet.get_word_matches, query, search_threshold)
      else
        ok, matches = pcall(
          wordnet.get_similar_words_for_word,
          query,
          search_threshold,
          similarity_pointers,
          similarity_depth
        )
      end
      if not ok or type(matches) ~= "table" then
        return {}
      end

      local items = {}
      for _, match in ipairs(matches) do
        local word = match:gsub("%b()", ""):gsub("_", " ")
        items[#items + 1] = {
          text = word,
          word = word,
          resolve = function(item)
            local def_ok, definition = pcall(wordnet.get_definition_for_word, item.word, definition_pointers)
            item.preview = {
              text = def_ok and definition or "",
              ft = "markdown",
            }
          end,
        }
      end
      return items
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.word then
        vim.schedule(function()
          apply_word(target, item.word)
        end)
      end
    end,
  })
end

return {
  {
    "archie-judd/blink-cmp-words",
    keys = {
      { "<leader>zd", function() open_word_picker("dictionary") end, desc = "Dictionary", mode = { "n", "x" } },
      { "<leader>zt", function() open_word_picker("thesaurus") end, desc = "Thesaurus", mode = { "n", "x" } },
      { "<C-x><C-k>", function() open_word_picker("dictionary") end, desc = "Dictionary", mode = "i" },
      { "<C-x><C-t>", function() open_word_picker("thesaurus") end, desc = "Thesaurus", mode = "i" },
    },
  },

  {
    "saghen/blink.cmp",
    dependencies = { "archie-judd/blink-cmp-words" },
    opts = {
      sources = {
        per_filetype = {
          markdown = { inherit_defaults = true, "dictionary" },
          text = { inherit_defaults = true, "dictionary" },
          gitcommit = { inherit_defaults = true, "dictionary" },
        },
        providers = {
          dictionary = {
            name = "Dict",
            module = "blink-cmp-words.dictionary",
            min_keyword_length = 3,
            opts = {
              dictionary_search_threshold = 2,
              score_offset = 0,
              definition_pointers = definition_pointers,
            },
          },
          thesaurus = {
            name = "Thes",
            module = "blink-cmp-words.thesaurus",
            opts = {
              score_offset = 0,
              definition_pointers = definition_pointers,
              similarity_pointers = similarity_pointers,
              similarity_depth = similarity_depth,
            },
          },
        },
      },
    },
  },

  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>z", group = "words", icon = "" },
      },
    },
  },
}
