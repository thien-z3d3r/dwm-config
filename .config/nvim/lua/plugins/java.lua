return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local default_markers = {
        ".git",
        "mvnw",
        "gradlew",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
      }
      opts.root_dir = function(path)
        local root = vim.fs.root(path, default_markers)
        if not root and path and path ~= "" then
          root = vim.fs.dirname(path)
        end
        return root or vim.fn.getcwd()
      end
      opts.project_name = function(root_dir)
        local name = root_dir and vim.fs.basename(root_dir)
        if not name or name == "" or name == "/" then
          name = "default"
        end
        return name
      end
    end,
  },
}
