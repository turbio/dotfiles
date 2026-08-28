{
  pkgs,
  lib,
  config,
  repos,
  ...
}:
let
  stdenv = pkgs.stdenv;
  wallpaperbin = stdenv.mkDerivation {
    name = "wallpaper";
    src = repos.livewallpaper;
    buildInputs = with pkgs; [
      SDL2
      SDL2_gfx
      pkg-config
      clang
      xxd
    ];
    buildPhase = "cd build && make";
    installPhase = ''
      mkdir -p $out/bin
      cp walp $out/bin
      cp -r mods $out
    '';
  };
  wallpaper = stdenv.mkDerivation {
    name = "wallpaper-render";
    phases = [
      "buildPhase"
      "installPhase"
    ];

    buildPhase = ''
      ${wallpaperbin}/bin/walp \
        -p ${wallpaperbin}/mods/cave_story_island.so \
        --width 2560 \
        --height 1440 \
        --bmp out.bmp \
        --once
    '';

    installPhase = ''
      cp out.bmp $out
    '';
  };
in
{
  environment.systemPackages = [
    (pkgs.runCommandLocal "scripts" { } ''
      mkdir -p $out/bin
      cp -r ${./bin} $out/bin
    '')
  ];
  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
    XDG_CURRENT_DESKTOP = "sway";
    CLUTTER_BACKEND = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.etc = {
    "tmux.conf".source = ./config/tmux/tmux.conf;
  };

  programs.firefox.enable = true;

  programs.nixvim.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user.email = "git@turb.io";
      user.name = "turbio";
      pull.ff = "only";
      init.defaultBranch = "master";
    };
  };

  programs.zsh = {
    enable = true;
    shellInit = builtins.readFile ./config/zsh/zshrc;

    syntaxHighlighting.enable = true;
    enableBashCompletion = true;

    ohMyZsh.enable = true;
    ohMyZsh.plugins = [
      "history-substring-search"
    ];
  };

  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    terminus_font
    terminus_font_ttf
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Terminus (TTF)" ];
    serif = [ "Terminus (TTF)" ];
    sansSerif = [ "Terminus (TTF)" ];
  };
}
