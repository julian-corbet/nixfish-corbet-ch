# home/fish.nix — nixfish's core module: the safe-adoption pattern for
# `programs.fish.enable`, plus a typed primitive for the one piece of fish
# state home-manager's own file management can never reach: universal
# variables (`set -U`), persisted in ~/.config/fish/fish_variables, a store
# entirely separate from config.fish/conf.d that home-manager's own fish
# module never reads or writes.
#
# ── THE ADOPTION PROBLEM this module documents (does not, and cannot, ─────
# ── solve purely declaratively — read this before your first switch) ──────
#
# Turning on `programs.fish.enable = true` for the FIRST time on a machine
# whose ~/.config/fish/config.fish already exists as a plain, non-
# home-manager-owned file (the common case: a vendor package like
# cachyos-fish-config wrote it, or you hand-edited a stock template) makes
# `home-manager switch` REFUSE to activate — home-manager's own
# collision-check (`checkLinkTargets`) errors out before anything is
# touched, rather than silently overwriting anything. Verified directly
# against home-manager's own source (modules/files.nix, modules/lib/file-type.nix)
# at the revision this fleet pins.
#
# The FIX is a ONE-TIME flag on the switch itself, not a standing config
# option: `home-manager switch -b hm-bak` (standalone CLI), or
# `home-manager.backupFileExtension = "hm-bak";` if invoked via the NixOS
# module rather than the CLI directly. This moves the existing file aside as
# `config.fish.hm-bak` — diffable, reversible — rather than the alternative,
# per-file `force = true`, which is a silent one-way overwrite with NO
# backup (see file-type.nix's own option description verbatim: "this will
# silently delete the target regardless of whether it is a file or link").
# Do not reach for `force`.
#
# This is deliberately a ONE-TIME migration step, not a permanent fleet
# default: leaving a backup extension permanently configured means every
# FUTURE unrelated collision also silently grows a new `.hm-bak` file,
# accumulating cruft nobody goes back to clean up. Use the flag for the one
# switch that actually needs it, verify the backup matches what you
# expected to lose, then delete it — your own home-manager config's git
# history is the durable record after that, not a pile of `.hm-bak` files.
#
# Whatever a machine's EXISTING config.fish actually contains should be
# re-expressed as literal `programs.fish.shellInit` / `.interactiveShellInit`
# / `.functions` / `home.sessionVariables` content — including, and
# ESPECIALLY, any line that just `source`s a vendor package's own fish file
# (e.g. CachyOS's `cachyos-fish-config`): embed that source line verbatim
# rather than reimplementing the vendor's content in Nix, so it keeps
# tracking upstream updates to that package for free. This module has no
# opinion on what that content actually is — that's entirely the caller's,
# same as every other module in this family.
#
# ── GOTCHA: universal variables (`set -U`) are NOT config.fish content ────
# fish's `set -U` writes to ~/.config/fish/fish_variables, a persisted
# key-value store fish manages internally — completely separate from
# config.fish/conf.d, and never read or written by home-manager's own
# `programs.fish` module (confirmed against its source: it only ever
# touches config.fish, functions/*, completions/*, and its own
# conf.d/plugin-*.fish). You cannot "declare" that file the way config.fish
# is declared. What you CAN do: `set -U` is idempotent — setting the same
# value again converges to the same state — so declaring a `set -U` line as
# a `shellInit` COMMAND (run every startup) converges the variable without
# Nix ever needing to own the file it's stored in. `universalVariables`
# below does exactly that, so a caller doesn't have to remember to hand-write
# `set -U` lines and get the escaping right themselves.
{ lib, config, ... }:
let
  cfg = config.nixfish.fish;

  mkSetU = name: value: "set -U ${name} ${lib.escapeShellArg value}";
in
{
  options.nixfish.fish = {
    enable = lib.mkEnableOption ''
      declarative fish ownership via `programs.fish.enable` (set with
      `lib.mkDefault`, so a caller can still override it if they truly need
      to). Read this module's header before your first switch on a machine
      with an existing ~/.config/fish/config.fish — the adoption step needs
      a one-time `-b <ext>` backup flag on the switch itself, not anything
      this module can set for you
    '';

    universalVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        fish_color_normal = "F0F0F0";
        fish_color_command = "22C55E";
      };
      description = ''
        Universal variables (`set -U`) to converge on every shell startup —
        e.g. `fish_color_*`/`fish_pager_color_*` prompt theming. Rendered as
        idempotent `set -U` commands appended to `shellInit`, NOT written as
        a managed file — see this module's header for why `fish_variables`
        can't be declared the normal way. An empty attrset is a no-op.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish.enable = lib.mkDefault true;

    # `programs.fish.shellInit` is `types.lines`, which merges multiple
    # independent module contributions by concatenation (not a single
    # overriding assignment) — so this composes safely with a caller's OWN
    # separate `programs.fish.shellInit` (e.g. their vendor source line +
    # interactive tty logic) without either one clobbering the other.
    programs.fish.shellInit = lib.mkIf (cfg.universalVariables != { }) (
      lib.concatStringsSep "\n" (lib.mapAttrsToList mkSetU cfg.universalVariables)
    );
  };
}
