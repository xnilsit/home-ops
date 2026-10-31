-- Neovim for Paseo terminals, started from kickstart.nvim
-- (nvim-lua/kickstart.nvim@8e35dbedb7966e3a95e1f26f9fc1179ab6c68db4).
--
-- Nvim reads this from $XDG_CONFIG_DIRS when ~/.config/nvim has no init.lua,
-- so a config on the home volume still takes precedence.
--
-- Plugins, Mason packages and treesitter parsers are installed into
-- /usr/local/share/nvim when the image is built (containers/paseo/nvim-bake.lua)
-- and are read-only at runtime: nothing is downloaded or compiled on startup.

local share = '/usr/local/share/nvim'
local baking = vim.env.PASEO_NVIM_BAKE == '1'

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- [[ Setting options ]]
vim.opt.shortmess:append 'sI'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.showmode = false
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split'
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.hlsearch = true
vim.opt.expandtab = true

-- The terminal is the only way out of the pod: yank through OSC 52, paste
-- from Nvim's own register as the browser terminal does not answer OSC 52 reads.
do
  local osc52 = require 'vim.ui.clipboard.osc52'
  local function paste()
    return { vim.fn.split(vim.fn.getreg '"', '\n'), vim.fn.getregtype '"' }
  end
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = { ['+'] = osc52.copy '+', ['*'] = osc52.copy '*' },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end

vim.diagnostic.config {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = {
    source = 'if_many',
    spacing = 2,
  },
}

vim.filetype.add {
  extension = {
    jinja = 'jinja',
    jinja2 = 'jinja',
    j2 = 'jinja',
  },
  pattern = {
    ['.*/tasks/.*.yaml'] = 'yaml.ansible',
    ['.*/tasks/.*.yml'] = 'yaml.ansible',
    ['.*/inventory.yml'] = 'yaml.ansible',
    ['.*/ansible/roles/.*.yml'] = 'yaml.ansible',
  },
}

-- [[ Basic Keymaps ]]
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>dn', function()
  vim.diagnostic.jump { count = 1 }
end, { desc = 'Jump to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>dN', function()
  vim.diagnostic.jump { count = -1 }
end, { desc = 'Jump to previous [D]iagnostic message' })
vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1 }
end, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1 }
end, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>t', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit nvim' })
vim.keymap.set('n', '<leader>Q', '<cmd>q!<CR>', { desc = 'Force Quit nvim' })

vim.keymap.set('n', '<leader>bd', '<cmd>bd<CR>', { desc = 'Delete buffer' })

vim.keymap.set('v', '<leader>y', '"+y', { desc = 'Yank to system' })
vim.keymap.set('n', '<leader>p', '"+p', { desc = 'Paste from system' })
vim.keymap.set('v', ',y', '"+y', { desc = '[y]ank system (SpaceVim compat)' })
vim.keymap.set('n', ',p', '"+p', { desc = '[p]aste system after cursor (SpaceVim compat)' })
vim.keymap.set('n', ',P', '"+P', { desc = '[P]aste system before cursor (SpaceVim compat)' })
vim.keymap.set('v', ',d', '"+d', { desc = '[d]elete to system clipboard' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<leader>wh', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<leader>wl', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<leader>wj', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<leader>wk', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<leader>wq', '<C-w>q', { desc = 'Close window' })
vim.keymap.set('n', '<leader>ws', '<C-w>s', { desc = 'Split window horizontally' })
vim.keymap.set('n', '<leader>wv', '<C-w>v', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>wc', '<C-w>c', { desc = 'Close window' })
vim.keymap.set('n', '<leader>wo', '<C-w>o', { desc = 'Close other windows' })

local function require_opened_file()
  if vim.fn.expand '%:t' == '' then
    print 'No file opened'
    return false
  end
  return true
end

vim.keymap.set('n', '<leader>yfa', function()
  if require_opened_file() then
    vim.fn.setreg('+', vim.fn.expand '%:p')
  end
end, { desc = '[Y]ank [F]ile [A]bsolute' })

vim.keymap.set('n', '<leader>yfr', function()
  if require_opened_file() then
    vim.fn.setreg('+', vim.fn.expand '%')
  end
end, { desc = '[Y]ank [F]ile [R]elative' })

vim.keymap.set('n', '<leader>yfn', function()
  if require_opened_file() then
    vim.fn.setreg('+', vim.fn.expand '%:t')
  end
end, { desc = '[Y]ank [F]ile [N]ame' })

vim.keymap.set('n', '<leader>yfp', function()
  if not require_opened_file() then
    return
  end
  local git_root = vim.fn.systemlist 'git rev-parse --show-toplevel'
  if vim.v.shell_error ~= 0 then
    print 'Not in a git repo'
    return
  end
  local file_path = vim.fn.expand '%:p'
  vim.fn.setreg('+', file_path:sub(#git_root[1] + 2))
end, { desc = '[Y]ank [F]ile [P]roject' })

vim.keymap.set('n', '<leader>yfc', function()
  if require_opened_file() then
    vim.fn.setreg('+', vim.fn.readfile(vim.fn.expand '%:p'))
  end
end, { desc = '[Y]ank [F]ile [C]ontent' })

-- [[ Basic Autocommands ]]
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'json',
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})

-- [[ Tools baked into the image ]]
local treesitter_parsers = {
  'bash',
  'c',
  'diff',
  'dockerfile',
  'git_rebase',
  'hcl',
  'helm',
  'html',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'python',
  'query',
  'terraform',
  'toml',
  'vim',
  'vimdoc',
  'yaml',
}

local servers = {
  awk_ls = {},
  bashls = {},
  docker_compose_language_service = {},
  dockerls = {},
  helm_ls = {
    settings = {
      ['helm-ls'] = {
        logLevel = 'info',
        valuesFiles = {
          mainValuesFile = 'values.yaml',
          lintOverlayValuesFile = 'values.lint.yaml',
          additionalValuesFilesGlobPattern = '*values*.yaml',
        },
        yamlls = {
          enabled = true,
          diagnosticsLimit = 50,
          showDiagnosticsDirectly = false,
          path = 'yaml-language-server',
          config = {
            schemas = {
              kubernetes = { 'templates/**' },
            },
            completion = true,
            hover = true,
          },
        },
      },
    },
  },
  jsonls = {},
  lua_ls = {
    -- Both default to its install dir, read-only here.
    cmd = {
      'lua-language-server',
      '--logpath=' .. vim.fn.stdpath 'cache' .. '/lua_ls/log',
      '--metapath=' .. vim.fn.stdpath 'cache' .. '/lua_ls/meta',
    },
    settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
      },
    },
  },
  marksman = {
    -- .NET aborts without libicu, which the image does not ship.
    cmd_env = { DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = '1' },
  },
  ruff = {
    on_attach = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  },
  ts_ls = {},
  typos_lsp = {
    init_options = {
      diagnosticSeverity = 'hint',
      language = 'en',
    },
  },
  yamlls = {},
}

-- Mason packages for the servers above and conform's formatters; Renovate bumps the versions.
local tools = {
  -- renovate: datasource=npm depName=awk-language-server
  { 'awk-language-server', version = '0.10.6' },
  -- renovate: datasource=npm depName=bash-language-server
  { 'bash-language-server', version = '5.8.1' },
  -- renovate: datasource=npm depName=@microsoft/compose-language-service
  { 'docker-compose-language-service', version = '1.0.0' },
  -- renovate: datasource=npm depName=dockerfile-language-server-nodejs
  { 'dockerfile-language-server', version = '0.15.0' },
  -- renovate: datasource=github-releases depName=mrjosh/helm-ls
  { 'helm-ls', version = 'v0.5.4' },
  -- renovate: datasource=npm depName=vscode-langservers-extracted
  { 'json-lsp', version = '4.10.0' },
  -- renovate: datasource=github-releases depName=LuaLS/lua-language-server
  { 'lua-language-server', version = '3.19.2' },
  -- renovate: datasource=github-releases depName=artempyanykh/marksman versioning=loose
  { 'marksman', version = '2026-02-08' },
  -- renovate: datasource=github-releases depName=astral-sh/ruff
  { 'ruff', version = '0.17.3' },
  -- renovate: datasource=npm depName=typescript-language-server
  { 'typescript-language-server', version = '6.0.2' },
  -- renovate: datasource=github-releases depName=tekumara/typos-vscode
  { 'typos-lsp', version = 'v0.1.57' },
  -- renovate: datasource=npm depName=yaml-language-server
  { 'yaml-language-server', version = '2.0.0' },
  -- renovate: datasource=pypi depName=mdformat
  { 'mdformat', version = '1.0.0' },
  -- renovate: datasource=npm depName=@fsouza/prettierd
  { 'prettierd', version = '0.29.0' },
  -- renovate: datasource=github-releases depName=JohnnyMorganz/StyLua
  { 'stylua', version = 'v2.6.0' },
  -- renovate: datasource=github-releases depName=tamasfe/taplo
  { 'taplo', version = '0.10.0' },
  -- nvim-treesitter's main branch builds parsers with it.
  -- renovate: datasource=github-releases depName=tree-sitter/tree-sitter
  { 'tree-sitter-cli', version = 'v0.27.1' },
  -- renovate: datasource=pypi depName=yamlfix
  { 'yamlfix', version = '1.19.1' },
}

-- Every plugin, dependencies included, is pinned here and nowhere else; Renovate bumps the commits and tags.
-- blink.cmp follows releases, as it fetches the prebuilt fuzzy library matching its tag.
local plugin_pins = {
  -- renovate: datasource=git-refs depName=https://github.com/folke/lazy.nvim branch=stable
  ['folke/lazy.nvim'] = { commit = '85c7ff3711b730b4030d03144f6db6375044ae82' },
  -- renovate: datasource=git-refs depName=https://github.com/NMAC427/guess-indent.nvim branch=main
  ['nmac427/guess-indent.nvim'] = { commit = '84a4987ff36798c2fc1169cbaff67960aed9776f' },
  -- renovate: datasource=git-refs depName=https://github.com/lewis6991/gitsigns.nvim branch=main
  ['lewis6991/gitsigns.nvim'] = { commit = '1e9d0fbfe7ff848bc402d2c2e2854fb4eff2dce7' },
  -- renovate: datasource=git-refs depName=https://github.com/folke/which-key.nvim branch=main
  ['folke/which-key.nvim'] = { commit = '3aab2147e74890957785941f0c1ad87d0a44c15a' },
  -- renovate: datasource=git-refs depName=https://github.com/folke/tokyonight.nvim branch=main
  ['folke/tokyonight.nvim'] = { commit = 'cdc07ac78467a233fd62c493de29a17e0cf2b2b6' },
  -- renovate: datasource=git-refs depName=https://github.com/folke/todo-comments.nvim branch=main
  ['folke/todo-comments.nvim'] = { commit = '31e3c38ce9b29781e4422fc0322eb0a21f4e8668' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-lua/plenary.nvim branch=master
  ['nvim-lua/plenary.nvim'] = { commit = '74b06c6c75e4eeb3108ec01852001636d85a932b' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-mini/mini.nvim branch=main
  ['nvim-mini/mini.nvim'] = { commit = '6d5a29e86a7352739506c28e0bc50fe214b5216f' },
  -- renovate: datasource=github-tags depName=lukas-reineke/indent-blankline.nvim
  ['lukas-reineke/indent-blankline.nvim'] = { tag = 'v3.10.1' },
  -- renovate: datasource=git-refs depName=https://github.com/mason-org/mason.nvim branch=main
  ['mason-org/mason.nvim'] = { commit = '2a6940af80375532e5e9e7c1f2fc6319a1b7a69d' },
  -- renovate: datasource=github-releases depName=saghen/blink.cmp
  ['saghen/blink.cmp'] = { tag = 'v1.10.2' },
  -- renovate: datasource=github-tags depName=L3MON4D3/LuaSnip
  ['L3MON4D3/LuaSnip'] = { tag = 'v2.5.0' },
  -- renovate: datasource=git-refs depName=https://github.com/rafamadriz/friendly-snippets branch=main
  ['rafamadriz/friendly-snippets'] = { commit = 'b2ea5c41a150ba72fb656eedb4ed0a86d138d945' },
  -- renovate: datasource=git-refs depName=https://github.com/folke/lazydev.nvim branch=main
  ['folke/lazydev.nvim'] = { commit = 'ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-telescope/telescope.nvim branch=master
  ['nvim-telescope/telescope.nvim'] = { commit = '40aedd8a68c78a656a10a8d62d80c54af59420fb' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-telescope/telescope-fzf-native.nvim branch=main
  ['nvim-telescope/telescope-fzf-native.nvim'] = { commit = 'b25b749b9db64d375d782094e2b9dce53ad53a40' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-telescope/telescope-ui-select.nvim branch=master
  ['nvim-telescope/telescope-ui-select.nvim'] = { commit = '6e51d7da30bd139a6950adf2a47fda6df9fa06d2' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-tree/nvim-web-devicons branch=master
  ['nvim-tree/nvim-web-devicons'] = { commit = 'ec309a0eaff6ea967e58c275996155ab5c16938d' },
  -- renovate: datasource=git-refs depName=https://github.com/radyz/telescope-gitsigns branch=main
  ['radyz/telescope-gitsigns'] = { commit = 'e568da4b8b6da800bd9274f7b509c0da81fc8615' },
  -- renovate: datasource=git-refs depName=https://github.com/debugloop/telescope-undo.nvim branch=main
  ['debugloop/telescope-undo.nvim'] = { commit = '928d0c2dc9606e01e2cc547196f48d2eaecf58e5' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-treesitter/nvim-treesitter branch=main
  ['nvim-treesitter/nvim-treesitter'] = { commit = 'a2f694478be07f89c2d03cc17858a8745a400c4b' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-treesitter/nvim-treesitter-textobjects branch=main
  ['nvim-treesitter/nvim-treesitter-textobjects'] = { commit = '5c7b0263797dfd1bd6202f2b219f3b53a80b2187' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-treesitter/nvim-treesitter-context branch=master
  ['nvim-treesitter/nvim-treesitter-context'] = { commit = '8decd73460d26ef0a0befb745d022dd1fc2c38b8' },
  -- renovate: datasource=git-refs depName=https://github.com/kiyoon/treesitter-indent-object.nvim branch=master
  ['kiyoon/treesitter-indent-object.nvim'] = { commit = '35e5037acd7e16fabfb2b3e506b3bbcf123f615e' },
  -- renovate: datasource=git-refs depName=https://github.com/nvim-neo-tree/neo-tree.nvim branch=main
  ['nvim-neo-tree/neo-tree.nvim'] = { commit = 'bb9779f532ef9ec62486a840fb5db44591aeff0f' },
  -- renovate: datasource=git-refs depName=https://github.com/MunifTanjim/nui.nvim branch=main
  ['MunifTanjim/nui.nvim'] = { commit = '10fc361835c856ba4233ef5ea135b919bf3dce97' },
  -- renovate: datasource=git-refs depName=https://github.com/vladdoster/remember.nvim branch=master
  ['vladdoster/remember.nvim'] = { commit = '83bc26a11af95527554a5a0168ee042808535bd8' },
  -- renovate: datasource=git-refs depName=https://github.com/fedepujol/move.nvim branch=main
  ['fedepujol/move.nvim'] = { commit = '599b14047b82e92874b9a408e4df228b965c3a1d' },
  -- renovate: datasource=git-refs depName=https://github.com/gbprod/yanky.nvim branch=main
  ['gbprod/yanky.nvim'] = { commit = 'adcabd8512bead30184916fa9277e73c021ef099' },
  -- renovate: datasource=git-refs depName=https://github.com/neovim/nvim-lspconfig branch=master
  ['neovim/nvim-lspconfig'] = { commit = '460bb34e7be114f1fda7815781696bc701e60f83' },
  -- renovate: datasource=git-refs depName=https://github.com/mason-org/mason-lspconfig.nvim branch=main
  ['mason-org/mason-lspconfig.nvim'] = { commit = 'cd6c64d85c9871aaf759d26f2371029d6d674a48' },
  -- renovate: datasource=git-refs depName=https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim branch=main
  ['WhoIsSethDaniel/mason-tool-installer.nvim'] = { commit = '443f1ef8b5e6bf47045cb2217b6f748a223cf7dc' },
  -- renovate: datasource=git-refs depName=https://github.com/towolf/vim-helm branch=master
  ['towolf/vim-helm'] = { commit = '2c8525fd98e57472769d137317bca83e477858ce' },
  -- renovate: datasource=git-refs depName=https://github.com/j-hui/fidget.nvim branch=main
  ['j-hui/fidget.nvim'] = { commit = '9e0201673e08e997e7cf52afca5565c70bd117f3' },
  -- renovate: datasource=git-refs depName=https://github.com/stevearc/conform.nvim branch=master
  ['stevearc/conform.nvim'] = { commit = '016802de402556da54c36bd7359b441266b01cdd' },
  -- renovate: datasource=git-refs depName=https://github.com/numToStr/Comment.nvim branch=master
  ['numToStr/Comment.nvim'] = { commit = 'e30b7f2008e52442154b66f7c519bfd2f1e32acb' },
  -- renovate: datasource=git-refs depName=https://github.com/folke/trouble.nvim branch=main
  ['folke/trouble.nvim'] = { commit = 'bd67efe408d4816e25e8491cc5ad4088e708a69a' },
  -- renovate: datasource=git-refs depName=https://github.com/danymat/neogen branch=main
  ['danymat/neogen'] = { commit = '23e7e9f883d01289ebd90e98025acc860ea26366' },
}

local function pin(spec)
  if type(spec) == 'string' then
    spec = { spec }
  end
  local plugin_pin = assert(plugin_pins[spec[1]], 'no pin for ' .. spec[1])
  spec = vim.tbl_extend('force', spec, plugin_pin)
  if type(spec.dependencies) == 'string' then
    spec.dependencies = { spec.dependencies }
  end
  if spec.dependencies then
    spec.dependencies = vim.tbl_map(pin, spec.dependencies)
  end
  return spec
end

-- Read by nvim-bake.lua.
_G.paseo_bake = {
  tools = tools,
  treesitter_parsers = treesitter_parsers,
}

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = share .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  vim.fn.system { 'git', '-C', lazypath, 'checkout', plugin_pins['folke/lazy.nvim'].commit }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup(vim.tbl_map(pin, {
  'folke/lazy.nvim',
  'nmac427/guess-indent.nvim',

  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      spec = {
        { '<leader>T', group = '[T]ypo' },
        { '<leader>b', group = '[B]uffer' },
        { '<leader>c', group = '[C]ode' },
        { '<leader>d', group = '[D]ocument' },
        { '<leader>f', group = '[F]ile Tree (SpaceVim compat)' },
        { '<leader>l', group = '[L]azy / [L]sp' },
        { '<leader>r', group = '[R]refactor' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>w', group = '[W]indows' },
        { '<leader>y', group = '[Y]ank' },
        { '<leader>yf', group = '[Y]ank [F]ile' },
      },
    },
  },

  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'tokyonight-night'
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  {
    'nvim-mini/mini.nvim',
    event = 'VeryLazy',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },

  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {},
  },

  {
    'mason-org/mason.nvim',
    config = function()
      require('mason').setup {
        install_root_dir = share .. '/mason',
        max_concurrent_installers = 8,
        providers = {
          'mason.providers.client',
          'mason.providers.registry-api',
        },
      }
      vim.keymap.set('n', '<leader>lm', '<cmd>Mason<cr>', { silent = true, noremap = true, desc = '[L]azy [M]ason' })
    end,
  },

  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        build = 'make install_jsregexp',
        dependencies = { 'rafamadriz/friendly-snippets' },
        config = function()
          local ls = require 'luasnip'
          ls.setup {
            enable_autosnippets = true,
          }
          vim.keymap.set({ 'i' }, '<C-K>', function()
            ls.expand()
          end, { silent = true })
          vim.keymap.set({ 'i', 's' }, '<C-L>', function()
            ls.jump(1)
          end, { silent = true })
          vim.keymap.set({ 'i', 's' }, '<C-J>', function()
            ls.jump(-1)
          end, { silent = true })
          vim.keymap.set({ 'i', 's' }, '<C-E>', function()
            if ls.choice_active() then
              ls.change_choice(1)
            end
          end, { silent = true })
          require('luasnip.loaders.from_vscode').lazy_load()
        end,
      },
      'folke/lazydev.nvim',
    },
    opts = {
      keymap = {
        preset = 'default',
      },
      appearance = {
        nerd_font_variant = 'mono',
      },
      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },
      snippets = { preset = 'luasnip' },
      fuzzy = {
        implementation = 'prefer_rust_with_warning',
        -- The library is fetched at build time, the plugin directory is read-only afterwards.
        prebuilt_binaries = { download = baking },
      },
      signature = { enabled = true },
    },
  },

  {
    'nvim-telescope/telescope.nvim',
    event = 'VeryLazy',
    branch = 'master',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
      'nvim-telescope/telescope-ui-select.nvim',
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
      {
        'radyz/telescope-gitsigns',
        dependencies = {
          'lewis6991/gitsigns.nvim',
        },
      },
    },
    config = function()
      require('telescope').setup {
        pickers = {
          find_files = {
            find_command = { 'rg', '--files', '--hidden', '--follow', '--glob', '!.git' },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      pcall(require('telescope').load_extension, 'gitsigns')
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<c-p>', builtin.find_files, { desc = '[S]earch [F]iles (Spacevim compat)' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sag', builtin.live_grep, { desc = '[S]earch by [G]rep (Spacevim compat)' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>sj', builtin.jumplist, { desc = '[S]earch [J]ump List' })
      vim.keymap.set('n', '<leader>sb', builtin.git_branches, { desc = '[S]earch [B]ranches' })
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fs.dirname(vim.env.MYVIMRC) }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  {
    'debugloop/telescope-undo.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    keys = {
      { '<leader>u', '<cmd>Telescope undo<cr>', desc = 'undo history' },
    },
    config = function()
      require('telescope').load_extension 'undo'
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-textobjects',
        branch = 'main',
      },
      'nvim-treesitter/nvim-treesitter-context',
    },
    config = function()
      -- Also prepends the install dir to the runtimepath. Parsers are not
      -- installed on demand, the directory is read-only at runtime.
      require('nvim-treesitter').setup { install_dir = share .. '/site' }

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          if not pcall(vim.treesitter.start, args.buf) then
            return
          end
          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if vim.treesitter.query.get(lang, 'indents') then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      local select = require 'nvim-treesitter-textobjects.select'
      local move = require 'nvim-treesitter-textobjects.move'
      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }
      vim.keymap.set({ 'x', 'o' }, 'af', function()
        select.select_textobject('@function.outer', 'textobjects')
      end, { desc = 'Select function (outer)' })
      vim.keymap.set({ 'x', 'o' }, 'if', function()
        select.select_textobject('@function.inner', 'textobjects')
      end, { desc = 'Select function (inner)' })
      vim.keymap.set({ 'x', 'o' }, 'ac', function()
        select.select_textobject('@class.outer', 'textobjects')
      end, { desc = 'Select class (outer)' })
      vim.keymap.set({ 'x', 'o' }, 'ic', function()
        select.select_textobject('@class.inner', 'textobjects')
      end, { desc = 'Select class (inner)' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']m', function()
        move.goto_next_start('@function.outer', 'textobjects')
      end, { desc = 'Goto next function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
        move.goto_next_start('@class.outer', 'textobjects')
      end, { desc = 'Goto next class start' })

      require('treesitter-context').setup {
        max_lines = 0,
        min_window_height = 20,
        line_numbers = true,
        multiline_threshold = 20,
        trim_scope = 'outer',
        mode = 'cursor',
        zindex = 20,
      }
    end,
  },

  {
    'kiyoon/treesitter-indent-object.nvim',
    keys = {
      {
        'aI',
        function()
          require('treesitter_indent_object.textobj').select_indent_outer()
        end,
        mode = { 'x', 'o' },
        desc = 'Select context-aware indent (outer)',
      },
      {
        'ai',
        function()
          require('treesitter_indent_object.textobj').select_indent_outer(true)
        end,
        mode = { 'x', 'o' },
        desc = 'Select context-aware indent (outer, line-wise)',
      },
      {
        'iI',
        function()
          require('treesitter_indent_object.textobj').select_indent_inner()
        end,
        mode = { 'x', 'o' },
        desc = 'Select context-aware indent (inner, partial range)',
      },
      {
        'ii',
        function()
          require('treesitter_indent_object.textobj').select_indent_inner(true, 'V')
        end,
        mode = { 'x', 'o' },
        desc = 'Select context-aware indent (inner, entire range) in line-wise visual mode',
      },
    },
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    lazy = true,
    keys = { '<leader>ft' },
    config = function()
      require('neo-tree').setup {
        close_if_last_window = true,
        window = {
          mappings = {
            ['n'] = 'add',
            ['N'] = 'add',
            ['.'] = 'toggle_hidden',
            ['l'] = 'open',
            ['L'] = 'expand_all_nodes',
            ['h'] = 'close_node',
            ['H'] = 'close_all_nodes',
          },
        },
      }
      local neo_tree = require 'neo-tree.command'
      vim.keymap.set('n', '<leader>ft', function()
        neo_tree.execute { toggle = true }
      end, { noremap = true, silent = true, desc = '[F]ile [T]ree' })
    end,
  },

  {
    'vladdoster/remember.nvim',
    lazy = false,
    opts = { open_folds = true },
  },

  {
    'fedepujol/move.nvim',
    keys = {
      {
        mode = { 'n' },
        '<C-S-j>',
        function()
          vim.cmd.MoveLine(1)
        end,
        desc = 'Move line down',
      },
      {
        mode = { 'n' },
        '<C-S-k>',
        function()
          vim.cmd.MoveLine(-1)
        end,
        desc = 'Move line up',
      },
      { mode = { 'v' }, '<C-S-j>', ':MoveBlock(1)<CR>', desc = 'Move block down' },
      { mode = { 'v' }, '<C-S-k>', ':MoveBlock(-1)<CR>', desc = 'Move block up' },
    },
    opts = {
      line = { enable = true, indent = true },
      block = { enable = true, indent = true },
      word = { enable = true },
      char = { enable = false },
    },
  },

  {
    'gbprod/yanky.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
      ring = { storage = 'shada' },
    },
    keys = {
      {
        '<leader>sy',
        function()
          require('telescope').extensions.yank_history.yank_history {}
        end,
        desc = '[S]earch yank history',
      },
    },
  },

  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'mason-org/mason.nvim',
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'towolf/vim-helm',
      {
        'j-hui/fidget.nvim',
        opts = {
          notification = {
            override_vim_notify = true,
          },
        },
      },
      'saghen/blink.cmp',
    },
    config = function()
      local function rename_with(transform)
        vim.lsp.buf.rename(transform(vim.fn.expand '<cword>'))
      end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          map('<leader>sws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[S]earch [W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename, '[R]efactor [N]ame')
          map('<leader>ru', function()
            rename_with(string.upper)
          end, '[R]efactor [U]ppercase')
          map('<leader>rl', function()
            rename_with(string.lower)
          end, '[R]efactor [L]owercase')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          map('K', vim.lsp.buf.hover, 'Hover Documentation')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      require('mason-tool-installer').setup { ensure_installed = tools, run_on_start = false }
      require('mason-lspconfig').setup {
        automatic_enable = vim.tbl_keys(servers),
      }
      for server_name, config in pairs(servers) do
        vim.lsp.config(server_name, config)
      end

      vim.keymap.set('n', '<leader>li', '<cmd>checkhealth vim.lsp<cr>', { desc = '[L]sp [I]nfo' })
    end,
  },

  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    'stevearc/conform.nvim',
    event = 'BufRead',
    config = function()
      local conform = require 'conform'
      conform.setup {
        notify_on_error = false,
        format_on_save = function(bufnr)
          if vim.tbl_contains({ 'yaml', 'yaml.ansible' }, vim.bo[bufnr].filetype) then
            return nil
          end
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return nil
          end
          if vim.api.nvim_buf_get_name(bufnr):match '/node_modules/' then
            return nil
          end
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end,
        formatters_by_ft = {
          toml = { 'taplo' },
          yaml = { 'yamlfix' },
          lua = { 'stylua' },
          markdown = { 'mdformat' },
          python = { 'ruff_format' },
          javascript = { 'prettierd' },
        },
      }

      vim.api.nvim_create_user_command('FormatDisable', function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, {
        desc = 'Disable autoformat-on-save',
        bang = true,
      })
      vim.api.nvim_create_user_command('FormatEnable', function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, {
        desc = 'Re-enable autoformat-on-save',
      })

      vim.keymap.set('n', '<leader>bf', function()
        conform.format { async = true, lsp_format = 'fallback' }
      end, { desc = 'Format [B]uffer' })
    end,
  },

  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup {
        mappings = {
          basic = true,
          extra = false,
        },
      }
      local ft = require 'Comment.ft'
      ft.hcl = { '#%s', '/*%s*/' }

      local api = require 'Comment.api'
      local esc = vim.api.nvim_replace_termcodes('<ESC>', true, false, true)
      vim.keymap.set({ 'x', 'n' }, '<leader>cs', function()
        vim.api.nvim_feedkeys(esc, 'nx', false)
        local err = vim.fn.execute 'lua require("Comment.api").toggle.blockwise(vim.fn.visualmode())'
        if err:find 'Comment.nvim' then
          api.toggle.linewise(vim.fn.visualmode())
        end
      end, { desc = 'Toggle [C]omment [S]exy', silent = true })
      vim.keymap.set('n', '<leader>cl', api.toggle.linewise.current, { desc = 'Toggle [C]omment [L]ine' })
      vim.keymap.set('x', '<leader>cl', function()
        vim.api.nvim_feedkeys(esc, 'nx', false)
        api.toggle.linewise(vim.fn.visualmode())
      end, { desc = 'Toggle [C]omment [L]ine' })
    end,
  },

  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  {
    'danymat/neogen',
    config = function()
      local neogen = require 'neogen'
      neogen.setup {
        enabled = true,
        input_after_comment = true,
      }
      vim.keymap.set('n', '<leader>cd', function()
        neogen.generate {}
      end, { noremap = true, silent = true, desc = '[C]ode [D]ocstring' })
    end,
  },
}), {
  root = share .. '/lazy',
  -- Versions come from plugin_pins, the lockfile is only lazy.nvim's bookkeeping.
  lockfile = vim.fn.stdpath 'state' .. '/lazy/lazy-lock.json',
  install = { missing = baking },
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
  -- Keep $XDG_CONFIG_DIRS and $XDG_DATA_DIRS, where this config and the parsers live.
  performance = { rtp = { reset = false } },
})

local lazy = require 'lazy'
vim.keymap.set('n', '<leader>lh', lazy.health, { desc = '[L]azy [H]ealth' })
vim.keymap.set('n', '<leader>ll', lazy.log, { desc = '[L]azy [L]og' })
vim.keymap.set('n', '<leader>ld', lazy.debug, { desc = '[L]azy [D]ebug' })
vim.keymap.set('n', '<leader>lp', lazy.profile, { desc = '[L]azy [P]rofile' })

_G.paseo_bake.init_done = true

-- vim: ts=2 sts=2 sw=2 et
