-- Installs everything rootfs/etc/xdg/nvim/init.lua expects to find at runtime, at the versions pinned there.
-- Run by the Dockerfile as: PASEO_NVIM_BAKE=1 nvim -u /etc/xdg/nvim/init.lua -l nvim-bake.lua
-- -l exits 1 on a Lua error here, but only reports one in init.lua, hence the init_done check.

local function fail(msg)
  error('nvim-bake: ' .. msg, 0)
end

if not (_G.paseo_bake and _G.paseo_bake.init_done) then
  fail 'init.lua did not finish, see the error above'
end

local lazy = require 'lazy'
local lazy_config = require 'lazy.core.config'
-- sync also moves lazy.nvim itself, cloned by the bootstrap, to its pin.
lazy.sync { wait = true, show = false }
for name, plugin in pairs(lazy_config.plugins) do
  if not plugin._.installed or plugin._.build_error then
    fail('plugin ' .. name .. ' failed to install or build')
  end
  local want = plugin.commit or vim.trim(vim.fn.system { 'git', '-C', plugin.dir, 'rev-parse', 'tags/' .. plugin.tag .. '^{commit}' })
  local head = vim.trim(vim.fn.system { 'git', '-C', plugin.dir, 'rev-parse', 'HEAD' })
  if head ~= want then
    fail(('plugin %s is at %s, pinned to %s'):format(name, head, plugin.commit or plugin.tag))
  end
end
lazy.load { plugins = vim.tbl_keys(lazy_config.plugins), wait = true }

vim.cmd 'MasonToolsInstallSync'
local registry = require 'mason-registry'
for _, tool in ipairs(_G.paseo_bake.tools) do
  local name, version = tool[1], tool.version
  local installed = registry.is_installed(name) and registry.get_package(name):get_installed_version()
  if installed ~= version then
    fail(('mason package %s is at %s, pinned to %s'):format(name, tostring(installed), version))
  end
end

if not require('nvim-treesitter').install(_G.paseo_bake.treesitter_parsers, { summary = true }):wait(1800000) then
  fail 'treesitter parsers failed to install'
end

local blink_done, blink_err
require('blink.cmp.fuzzy.download').ensure_downloaded(function(err)
  blink_done, blink_err = true, err
end)
vim.wait(300000, function()
  return blink_done
end)
if not blink_done or blink_err then
  fail('blink.cmp fuzzy library: ' .. tostring(blink_err or 'timed out'))
end
