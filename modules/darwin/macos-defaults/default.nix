{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.macos-defaults;
in {
  options.modules.macos-defaults.enable = lib.mkEnableOption "macOS system defaults";

  # These options are all Darwin-only (`system.defaults.*`, `system.keyboard.*`),
  # so this module belongs in modules/darwin, not modules/shared — see
  # modules/CLAUDE.md. It's the declarative equivalent of the old flake's GNOME
  # dconf module (modules.gnome on the NixOS side, never ported here) plus its
  # keyd capslock remap.
  config = lib.mkIf cfg.enable {
    system.defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        ApplePressAndHoldEnabled = true; # accent popover
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        "com.apple.trackpad.scaling" = 1.0;
      };

      dock = {
        autohide = false;
        show-recents = false;
        tilesize = 48;
      };

      controlcenter.BatteryShowPercentage = true;

      finder = {
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf"; # search the current folder by default
        ShowPathbar = true;
        _FXShowPosixPathInTitle = true;
      };

      trackpad = {
        Clicking = true; # tap to click
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = false;
      };

      screencapture = {
        location = "~/Pictures/Screenshots";
        type = "png";
      };
    };

    # Old flake's keyd config did a dual-role overload (tap = Esc, hold = Ctrl).
    # macOS's built-in remap can only do a flat swap, not the tap/hold split —
    # flagging that as a known gap versus the old behavior.
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    system.activationScripts.postActivation.text = ''
    # Following line should allow us to avoid a logout/login cycle when changing settings
    sudo -u ${user} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    # nix-darwin's power.sleep.display (systemsetup -setDisplaySleep) only
    # ever affects AC power, even run manually with sudo — verified it
    # silently leaves battery's value untouched. pmset -b/-c set each power
    # source independently and actually work.
    pmset -b displaysleep 5
    pmset -c displaysleep 10
    '';
  };
}
