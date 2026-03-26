return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {},
        ruff = {
          init_options = {
            settings = {
              logLevel = "error",
            },
          },
        },
        bashls = {},
      },
      setup = {
        ruff = function()
          vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("user_ruff_attach", { clear = true }),
            callback = function(args)
              local client = vim.lsp.get_client_by_id(args.data.client_id)
              if client and client.name == "ruff" then
                -- Prefer hover and type details from Pyright when both are attached.
                client.server_capabilities.hoverProvider = false
              end
            end,
          })
        end,
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "shellcheck",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_fix", "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        zsh = { "shellcheck" },
      },
    },
  },
}
