{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.neovim;
in {
  options.modules.neovim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf cfg.enable {
    # Telescope's find_files/live_grep use fd/rg as backends; make them
    # available system-wide (not just on nvim's PATH), see modules/shared/search.
    modules.search.enable = lib.mkDefault true;

    home-manager.users.${user} = {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;

        # Plugins are installed and pinned here; the Lua below just calls
        # each one's setup() — no plugin manager (lazy.nvim etc.) needed,
        # Nix already puts every plugin on the runtimepath.
        plugins = with pkgs.vimPlugins; [
          (nvim-treesitter.withPlugins (p: [
            p.nix
            p.lua
            p.go
            p.gomod
            p.gowork
            p.gosum
            p.bash
            p.markdown
            p.markdown_inline
            p.yaml
            p.toml
            p.json
            p.vim
            p.vimdoc
          ]))
          nvim-lspconfig
          blink-cmp
          telescope-nvim
          plenary-nvim
          which-key-nvim
          lualine-nvim
          nvim-web-devicons
          tokyonight-nvim
          # nvim-side of modules/shared/tmux's vim-tmux-navigator: ships its
          # own default C-h/j/k/l mappings on load, no setup() call needed.
          vim-tmux-navigator
        ];

        # LSP servers only — general-purpose CLI tools (rg/fd) live in
        # modules/shared/search instead, so they're on the whole PATH.
        extraPackages = with pkgs; [
          nixd
          gopls
          lua-language-server
          typescript-language-server
        ];
      };

      # Vendored, human-edited Lua config — the user reads/owns this file
      # directly; Nix's only job above is installing pinned plugins/servers.
      xdg.configFile."nvim/init.lua".source = ./config/init.lua;
    };
  };
}
