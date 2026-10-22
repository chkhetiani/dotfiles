return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    highlight = {
      pattern = [[.*<((KEYWORDS)%(\(.{-1,}\))?)\s*:]],
    },
    search = {
      pattern = [[\b(KEYWORDS)(\([^)]*\))?:]],
    },
  },
}
