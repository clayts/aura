-- Neovim, set up like Zed in home/zeditor.nix: soft wrap, hard tabs, format on
-- save, inline diagnostics, git in the gutter and no line numbers. Plugins and
-- language servers come from Nix, in home/neovim/default.nix

local aura = require("aura")

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Options

vim.o.number = false
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.wrap = true
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.smoothscroll = true
vim.o.scrolloff = 3
vim.o.sidescrolloff = 8
vim.o.expandtab = false
vim.o.tabstop = 4
vim.o.shiftwidth = 0
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split"
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.splitkeep = "screen"
vim.o.virtualedit = "block"
vim.o.undofile = true
vim.o.confirm = true
vim.o.updatetime = 250
vim.o.timeoutlen = 500
vim.o.clipboard = "unnamedplus"
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.ruler = false
vim.o.title = true
vim.o.titlestring = "%t — %{fnamemodify(getcwd(), ':~')}"
vim.opt.shortmess:append("I")
vim.opt.fillchars = { eob = " ", fold = " " }
vim.o.winborder = "rounded"
vim.o.pumheight = 12
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldtext = ""
vim.o.foldlevelstart = 99

vim.cmd.colorscheme("custom")
vim.cmd.packadd("nvim.undotree")

-- Autocommands

local autocmd = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup("aura", {})

autocmd("TextYankPost", {
	group = group,
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Back to where the cursor was, when a file is opened again
autocmd("BufReadPost", {
	group = group,
	callback = function(args)
		local name = vim.api.nvim_buf_get_name(args.buf)
		if name:match("COMMIT_EDITMSG$") or name:match("git%-rebase%-todo$") then
			return
		end
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- Files changed outside Neovim are reloaded, as Zed does
autocmd({ "FocusGained", "BufEnter" }, {
	group = group,
	callback = function()
		if vim.fn.getcmdwintype() == "" then
			vim.cmd.checktime()
		end
	end,
})

-- Tree-sitter highlighting and indents, for each language that has a parser
autocmd("FileType", {
	group = group,
	callback = function(args)
		if vim.api.nvim_buf_line_count(args.buf) > 50000 or not pcall(vim.treesitter.start, args.buf) then
			return
		end
		local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
		if lang and vim.treesitter.query.get(lang, "indents") then
			vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

-- Projects: each file's project, the nearest folder above it with a .envrc,
-- flake.nix or .git, becomes the working directory, so the pickers search it,
-- and its direnv is loaded, as Zed's load_direnv does. Language servers
-- restart when it changes PATH, to use the project's own
local function project(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if vim.bo[buf].buftype ~= "" or name == "" or vim.fn.isdirectory(name) == 1 then
		return
	end
	local root = vim.fs.root(buf, { ".envrc", "flake.nix", ".git" })
	if root and root ~= vim.fn.getcwd() then
		vim.cmd.cd(vim.fn.fnameescape(root))
	end
end

local function direnv()
	vim.system({ aura.direnv, "export", "json" }, { text = true, cwd = vim.fn.getcwd() }, function(result)
		vim.schedule(function()
			if result.stderr:match("is blocked") then
				vim.notify("direnv: .envrc is blocked; run direnv allow", vim.log.levels.WARN)
			end
			if result.code ~= 0 or vim.trim(result.stdout) == "" then
				return
			end
			for name, value in pairs(vim.json.decode(result.stdout)) do
				vim.env[name] = value ~= vim.NIL and value or nil
			end
			local names = {}
			for _, client in ipairs(vim.lsp.get_clients()) do
				names[client.name] = true
			end
			if next(names) then
				vim.cmd.lsp({ args = { "restart", unpack(vim.tbl_keys(names)) } })
			end
		end)
	end)
end

autocmd("BufEnter", {
	group = group,
	nested = true, -- for DirChanged
	callback = function(args)
		project(args.buf)
	end,
})
autocmd({ "VimEnter", "DirChanged" }, { group = group, callback = direnv })

-- A folder, as in nvim-gtk ~/Projects/foo or Open With from Files, becomes the
-- working directory, and opens in the file explorer, in place of netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
autocmd("BufEnter", {
	group = group,
	callback = function(args)
		local path = vim.api.nvim_buf_get_name(args.buf)
		if path == "" or vim.fn.isdirectory(path) == 0 then
			return
		end
		local function open()
			if vim.api.nvim_buf_is_valid(args.buf) then
				vim.api.nvim_buf_delete(args.buf, { force = true })
			end
			vim.cmd.cd(vim.fn.fnameescape(path))
			MiniFiles.open(path)
		end
		if vim.v.vim_did_enter == 1 then
			vim.schedule(open)
		else
			autocmd("VimEnter", { group = group, once = true, callback = open })
		end
	end,
})

-- Insert mode, ready to type, as in Zed, on starting and in a new tab, but not
-- for a folder or a read-only file. Files opened later, often by jumping to a
-- definition or a search result, open as usual, in normal mode
local function insert(buf)
	local bo = vim.bo[buf]
	if
		bo.buftype == ""
		and bo.modifiable
		and not bo.readonly
		and vim.fn.isdirectory(vim.api.nvim_buf_get_name(buf)) == 0
	then
		vim.cmd.startinsert()
	end
end
autocmd("VimEnter", {
	group = group,
	callback = function()
		insert(vim.api.nvim_get_current_buf())
	end,
})
autocmd("TabNewEntered", {
	group = group,
	callback = function(args)
		insert(args.buf)
	end,
})

-- Trailing whitespace goes on save, as in Zed, unless formatting is off
autocmd("BufWritePre", {
	group = group,
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if vim.g.autoformat == false or vim.bo[args.buf].binary or ft == "markdown" or ft == "diff" then
			return
		end
		local view = vim.fn.winsaveview()
		vim.cmd([[keeppatterns silent! %s/\s\+$//e]])
		vim.fn.winrestview(view)
	end,
})

-- mini.nvim

require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Only warnings and errors pop up: not language servers' progress, which
-- basedpyright reports on every change, nor their info messages
require("mini.notify").setup({ lsp_progress = { enable = false } })
vim.notify = MiniNotify.make_notify({ INFO = { duration = 0 } })

require("mini.statusline").setup({
	content = {
		active = function()
			local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
			return MiniStatusline.combine_groups({
				{ hl = mode_hl, strings = { mode } },
				{
					hl = "MiniStatuslineDevinfo",
					strings = {
						MiniStatusline.section_git({ trunc_width = 40 }),
						MiniStatusline.section_diff({ trunc_width = 75 }),
					},
				},
				"%<",
				{ hl = "MiniStatuslineFilename", strings = { MiniStatusline.section_filename({ trunc_width = 140 }) } },
				"%=",
				{
					hl = "MiniStatuslineDevinfo",
					strings = {
						MiniStatusline.section_diagnostics({ trunc_width = 75 }),
						MiniStatusline.section_lsp({ trunc_width = 75 }),
					},
				},
				{
					hl = "MiniStatuslineFileinfo",
					strings = { MiniStatusline.section_searchcount({ trunc_width = 75 }), "%l:%v" },
				},
			})
		end,
	},
})

-- Pickers open in the middle of the window
require("mini.pick").setup({
	window = {
		config = function()
			local height = math.floor(0.6 * vim.o.lines)
			local width = math.min(120, math.floor(0.7 * vim.o.columns))
			return {
				anchor = "NW",
				height = height,
				width = width,
				row = math.floor(0.5 * (vim.o.lines - height)),
				col = math.floor(0.5 * (vim.o.columns - width)),
			}
		end,
		prompt_prefix = "  ",
	},
})
vim.ui.select = MiniPick.ui_select
require("mini.extra").setup()

require("mini.files").setup({
	-- Hidden files are shown, but not .git, as in Zed
	content = {
		filter = function(entry)
			return entry.name ~= ".git"
		end,
	},
	windows = { preview = true, width_preview = 60 },
})

require("mini.diff").setup({
	view = { style = "sign", signs = { add = "▎", change = "▎", delete = "▁" } },
})
require("mini.git").setup()

local hipatterns = require("mini.hipatterns")
hipatterns.setup({
	highlighters = {
		fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
		hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
		todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
		note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
		hex_color = hipatterns.gen_highlighter.hex_color(),
	},
})

local ai = require("mini.ai")
ai.setup({
	n_lines = 500,
	custom_textobjects = {
		F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
		c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
	},
})
require("mini.surround").setup()
require("mini.pairs").setup()

local clue = require("mini.clue")
clue.setup({
	triggers = {
		{ mode = "n", keys = "<Leader>" },
		{ mode = "x", keys = "<Leader>" },
		{ mode = "n", keys = "g" },
		{ mode = "x", keys = "g" },
		{ mode = "n", keys = "'" },
		{ mode = "n", keys = "`" },
		{ mode = "x", keys = "'" },
		{ mode = "x", keys = "`" },
		{ mode = "n", keys = '"' },
		{ mode = "x", keys = '"' },
		{ mode = "i", keys = "<C-r>" },
		{ mode = "c", keys = "<C-r>" },
		{ mode = "n", keys = "<C-w>" },
		{ mode = "n", keys = "z" },
		{ mode = "x", keys = "z" },
		{ mode = "n", keys = "[" },
		{ mode = "n", keys = "]" },
		{ mode = "i", keys = "<C-x>" },
	},
	clues = {
		{ mode = "n", keys = "<Leader>g", desc = "+Git" },
		{ mode = "n", keys = "<Leader>t", desc = "+Toggle" },
		clue.gen_clues.builtin_completion(),
		clue.gen_clues.g(),
		clue.gen_clues.marks(),
		clue.gen_clues.registers(),
		clue.gen_clues.windows(),
		clue.gen_clues.z(),
		clue.gen_clues.square_brackets(),
	},
	window = { delay = 300, config = { width = "auto" } },
})

-- Completion

-- Neovim's API, for lua_ls, in Neovim's own config
require("lazydev").setup()

-- Neovim's own completion, as you type, from the language servers, then words
-- in open buffers. Neovim GTK draws its menu as a GTK popup
vim.o.autocomplete = true
vim.o.complete = "o,.^5,w^5,b^5"
vim.opt.shortmess:append("c")
local gui = vim.g.GtkGuiLoaded == 1
-- The selected item's docs: in a terminal, beside the menu, as Neovim draws
-- them; in Neovim GTK, in its popup, below
vim.o.completeopt = gui and "menuone,noselect" or "menuone,noselect,popup"
MiniIcons.tweak_lsp_kind("prepend")

autocmd("LspAttach", {
	group = group,
	callback = function(args)
		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
		if client:supports_method("textDocument/completion") then
			-- Accepting an item applies its snippet, imports and other edits
			vim.lsp.completion.enable(true, client.id, args.buf)
		end
	end,
})

-- Tab takes the selected item, or else the first, or jumps on in a snippet
vim.keymap.set({ "i", "s" }, "<Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return vim.fn.complete_info({ "selected" }).selected == -1 and "<C-n><C-y>" or "<C-y>"
	elseif vim.snippet.active({ direction = 1 }) then
		return "<Cmd>lua vim.snippet.jump(1)<CR>"
	end
	return "<Tab>"
end, { expr = true })

-- A function's signature, on typing ( or , in a call
autocmd("InsertCharPre", {
	group = group,
	callback = function()
		if vim.v.char ~= "(" and vim.v.char ~= "," then
			return
		end
		if next(vim.lsp.get_clients({ bufnr = 0, method = "textDocument/signatureHelp" })) then
			vim.schedule(function()
				vim.lsp.buf.signature_help({ focusable = false, silent = true })
			end)
		end
	end,
})

-- In Neovim GTK, an item's docs, which language servers send when asked for
-- that item, go to its popup, by the PopupmenuInfo message that
-- home/neovim/neovim-gtk/completion-docs.patch adds
local function docs(item)
	local doc = item.documentation
	doc = type(doc) == "table" and doc.value or doc or ""
	-- Markdown's code fences and escapes, which the popup would show as they are
	doc = vim.trim((doc:gsub("```%w*\n?", ""):gsub("\\(%p)", "%1")))
	local detail = vim.trim(item.detail or "")
	if detail ~= "" and not doc:find(detail, 1, true) then
		return vim.trim(detail .. "\n\n" .. doc)
	end
	return doc
end

if gui then
	autocmd("CompleteChanged", {
		group = group,
		callback = function(args)
			local lsp = vim.tbl_get(vim.v.event, "completed_item", "user_data", "nvim", "lsp")
			local ui = vim.api.nvim_list_uis()[1]
			if not lsp or not ui then
				return
			end
			local selected = vim.fn.complete_info({ "selected" }).selected
			local function show(item)
				local text = docs(item)
				if text ~= "" and vim.fn.complete_info({ "selected" }).selected == selected then
					vim.rpcnotify(ui.chan, "Gui", "PopupmenuInfo", selected, text)
				end
			end
			local client = vim.lsp.get_client_by_id(lsp.client_id)
			local item = lsp.completion_item
			if item.documentation or not (client and client:supports_method("completionItem/resolve")) then
				show(item)
				return
			end
			client:request("completionItem/resolve", item, function(err, result)
				if not err and result then
					vim.schedule(function()
						show(result)
					end)
				end
			end, args.buf)
		end,
	})
end

-- Formatting, on save, by a formatter or else the language server

require("conform").setup({
	formatters_by_ft = (function()
		local formatters = {
			nix = { "nixfmt" },
			lua = { "stylua" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			python = { "ruff_organize_imports", "ruff_format" },
		}
		for _, ft in ipairs({
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"vue",
			"svelte",
			"css",
			"scss",
			"less",
			"json",
			"jsonc",
			"yaml",
			"markdown",
			"graphql",
		}) do
			formatters[ft] = { "prettier" }
		end
		return formatters
	end)(),
	-- Prettier uses tabs, as Zed's hard_tabs does, unless the project says
	formatters = {
		prettier = { prepend_args = { "--config-precedence", "prefer-file", "--use-tabs" } },
	},
	default_format_opts = { lsp_format = "fallback" },
	format_on_save = function()
		if vim.g.autoformat ~= false then
			return { timeout_ms = 2000 }
		end
	end,
})
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

-- Language servers, with nvim-lspconfig's settings and these

vim.diagnostic.config({
	severity_sort = true,
	signs = false,
	underline = true,
	virtual_text = { spacing = 2, prefix = "●" },
	float = { source = "if_many" },
})

-- Leaves formatting to another server or a formatter
local function no_formatting(client)
	client.server_capabilities.documentFormattingProvider = false
	client.server_capabilities.documentRangeFormattingProvider = false
end

vim.lsp.config("nixd", {
	-- Only its errors, as Neovim logs whatever it prints
	cmd = { "nixd", "--semantic-tokens=true", "--log=error" },
	settings = { nixd = aura.nixd },
})
vim.lsp.config("lua_ls", {
	settings = { Lua = { format = { enable = false } } },
})
vim.lsp.config("basedpyright", {
	settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
})
vim.lsp.config("ruff", {
	on_init = function(client)
		client.server_capabilities.hoverProvider = false
	end,
})
vim.lsp.config("rust_analyzer", {
	settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})
vim.lsp.config("vtsls", { on_init = no_formatting })
vim.lsp.config("html", { on_init = no_formatting })
vim.lsp.config("cssls", { on_init = no_formatting })
vim.lsp.config("jsonls", {
	on_init = no_formatting,
	settings = { json = { schemas = require("schemastore").json.schemas(), validate = { enable = true } } },
})
vim.lsp.config("lemminx", {
	settings = { xml = { validation = { noGrammar = "ignore" } } },
})
vim.lsp.config("yamlls", {
	settings = {
		yaml = {
			schemaStore = { enable = false, url = "" },
			schemas = require("schemastore").yaml.schemas(),
		},
	},
})

vim.lsp.enable({
	"nixd",
	"lua_ls",
	"bashls",
	"basedpyright",
	"ruff",
	"rust_analyzer",
	"gopls",
	"vtsls",
	"eslint",
	"superhtml",
	"html",
	"cssls",
	"jsonls",
	"emmet_language_server",
	"yamlls",
	"taplo",
	"lemminx",
	"marksman",
})

autocmd("LspAttach", {
	group = group,
	callback = function(args)
		local buf = args.buf
		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf, desc = "Go to definition" })
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf, desc = "Go to declaration" })
		-- Lists, which Neovim puts in the quickfix list, in a picker instead
		local function pick(lhs, scope, desc)
			vim.keymap.set("n", lhs, function()
				MiniExtra.pickers.lsp({ scope = scope })
			end, { buffer = buf, desc = desc })
		end
		pick("grr", "references", "References")
		pick("gri", "implementation", "Implementations")
		pick("gO", "document_symbol", "Symbols")

		-- Other uses of the symbol under the cursor are highlighted, as in Zed
		if client:supports_method("textDocument/documentHighlight", buf) then
			local highlight = vim.api.nvim_create_augroup("aura.highlight." .. buf, { clear = false })
			vim.api.nvim_clear_autocmds({ group = highlight, buffer = buf })
			autocmd({ "CursorHold", "CursorHoldI" }, {
				group = highlight,
				buffer = buf,
				callback = vim.lsp.buf.document_highlight,
			})
			autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
				group = highlight,
				buffer = buf,
				callback = vim.lsp.buf.clear_references,
			})
		end
	end,
})

-- Keys

local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

map("n", "<Esc>", "<Cmd>nohlsearch<CR>")
map({ "n", "i", "x" }, "<C-s>", "<Cmd>write<CR>", "Save")
-- Alt-/ comments, as in Micro
vim.keymap.set("n", "<M-/>", "gcc", { remap = true, desc = "Comment line" })
vim.keymap.set("x", "<M-/>", "gc", { remap = true, desc = "Comment selection" })

map("n", "<Leader>f", function()
	MiniPick.builtin.files()
end, "Files")
map("n", "<Leader>/", function()
	MiniPick.builtin.grep_live()
end, "Search")
map("n", "<Leader>*", function()
	MiniPick.builtin.grep({ pattern = vim.fn.expand("<cword>") })
end, "Search word")
map("n", "<Leader>b", function()
	MiniPick.builtin.buffers()
end, "Buffers")
map("n", "<Leader>r", function()
	MiniExtra.pickers.oldfiles()
end, "Recent files")
map("n", "<Leader>d", function()
	MiniExtra.pickers.diagnostic()
end, "Diagnostics")
map("n", "<Leader>s", function()
	MiniExtra.pickers.lsp({ scope = "document_symbol" })
end, "Symbols")
map("n", "<Leader>S", function()
	MiniExtra.pickers.lsp({ scope = "workspace_symbol_live" })
end, "Project symbols")
map("n", "<Leader>h", function()
	MiniPick.builtin.help()
end, "Help")
map("n", "<Leader>k", function()
	MiniExtra.pickers.keymaps()
end, "Keys")
map("n", "<Leader>'", function()
	MiniPick.builtin.resume()
end, "Last picker")
map("n", "<Leader>e", function()
	local file = vim.api.nvim_buf_get_name(0)
	MiniFiles.open(vim.uv.fs_stat(file) and file or nil)
end, "Explore files")
map("n", "<Leader>n", "<Cmd>tabnew<CR>", "New tab")
map("n", "<Leader>u", "<Cmd>Undotree<CR>", "Undo history")
map({ "n", "x" }, "<Leader>=", function()
	require("conform").format({ async = true })
end, "Format")

map("n", "<Leader>gh", function()
	MiniExtra.pickers.git_hunks()
end, "Hunks")
map("n", "<Leader>gd", function()
	MiniDiff.toggle_overlay(0)
end, "Diff in the file")
map({ "n", "x" }, "<Leader>gb", function()
	MiniGit.show_at_cursor()
end, "Blame, or what's at the cursor")

map("n", "<Leader>tf", function()
	vim.g.autoformat = vim.g.autoformat == false
	vim.api.nvim_echo({ { "Format on save " .. (vim.g.autoformat and "on" or "off") } }, false, {})
end, "Format on save")
map("n", "<Leader>ti", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, "Inlay hints")
map("n", "<Leader>tw", "<Cmd>set wrap!<CR>", "Wrap")
