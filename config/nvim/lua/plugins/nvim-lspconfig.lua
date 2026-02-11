local util = require("lspconfig.util")

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ansiblels = {
          cmd = { "ansible-language-server", "--stdio" },
          settings = {
            ansible = {
              python = { interpreterPath = "python" },
              ansible = { path = "ansible" },
              executionEnvironment = { enabled = false },
              validation = {
                enabled = true,
                lint = {
                  enabled = true,
                  path = "/usr/bin/ansible-lint",
                  arguments = { "-c", "~/.config/ansible-lint.yml" }, -- Optional: custom config
                },
              },
            },
          },
          filetypes = { "yaml.ansible" },
          root_dir = util.root_pattern("ansible.cfg", ".ansible-lint"),
          single_file_support = true,
        },
      },
    },
  },
}
