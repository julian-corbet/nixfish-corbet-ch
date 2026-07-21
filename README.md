# nixfish

The safe-adoption pattern for declarative shell config over Nix.

## Vision

`programs.fish.enable = true` already exists in home-manager — the
mechanism for declarative fish isn't missing. What's missing is the part
nobody writes down: on a real machine, `~/.config/fish/config.fish` is
almost never empty. A vendor package (CachyOS's `cachyos-fish-config`, for
one) may already own it; you may have hand-edited it for years. Flip
`programs.fish.enable` on blind and `home-manager switch` does the right
thing — it refuses to activate rather than silently destroying anything —
but that's a wall, not a plan. **nixfish** is the plan: the documented,
verified adoption sequence (a one-time backup flag, never a permanent
config option), plus the one piece of fish state that genuinely can't be
declared the normal way — universal variables (`set -U`), which live in a
separate persisted file home-manager's own fish module never touches.

It's deliberately **not** coupled to [nixarch](https://github.com/julian-corbet/nixarch-corbet-ch)
or [nixremote](https://github.com/julian-corbet/nixremote-corbet-ch) — the
adoption problem this solves has nothing to do with Arch, Wayland, or app
forwarding specifically. It needs to reach anything with a shell, including
machines with no home-manager at all (see Roadmap) — so it only depends on
`nixpkgs`.

## Status

**Pre-alpha.** One real module (`fish`), extracted from and documenting a
real migration (CachyOS's vendor fish config + a personal dotfile pile,
both currently living as plain hand-maintained files, being moved to Nix
for the first time). Honest gaps:

- No test suite yet.
- The core claim — that a pre-existing `config.fish` makes `home-manager
  switch` refuse rather than silently overwrite, and that `-b <ext>` is the
  correct non-destructive fix rather than `force = true` — was verified by
  reading home-manager's actual module source at the pinned revision this
  fleet uses, not assumed from documentation. It has not yet been exercised
  against every home-manager version in the wild.
- `universalVariables` converges `set -U` state via a `shellInit` command,
  not a managed file — this is correct because `set -U` is idempotent, but
  it means nixfish never "owns" `fish_variables` the way it owns
  `config.fish`, and can't detect drift in it the way a managed file would.

## Usage

```nix
{
  imports = [ inputs.nixfish.homeManagerModules.fish ];

  nixfish.fish = {
    enable = true;
    universalVariables = {
      fish_color_normal = "F0F0F0";
      fish_color_command = "22C55E";
    };
  };

  # Your own content, composed alongside nixfish's (types.lines merges
  # multiple contributions — this doesn't clobber the universalVariables
  # above):
  programs.fish.shellInit = ''
    source /usr/share/cachyos-fish-config/cachyos-config.fish
  '';
  programs.fish.functions.mybuild.body = "...";
}
```

**First-time adoption on a machine with an existing `config.fish`:**

```
home-manager switch --flake .#you@host -b hm-bak
```

Then — before doing anything else — diff `~/.config/fish/config.fish.hm-bak`
against what you expected to have ported into Nix, confirm your vendor
source line and your own functions/aliases/tty logic all still work in a
fresh shell, and only then delete the backup file. Don't leave
`backupFileExtension` configured as a standing default afterward — see this
module's header for why.

## Roadmap

Planned, explicitly not built yet, and not guaranteed to happen — recorded
honestly rather than left implicit:

- **A NixOS/plain-shell-only sibling with no home-manager dependency**, for
  machines where home-manager itself would be disproportionate weight (e.g.
  a minimal survival-mode VPS). Deliberately not built as part of this
  project yet — for the one fleet case that prompted this question
  (nixvps's sub-1GB/256MB-floor nodes), a couple of `environment.
  interactiveShellInit` lines directly in that project's own modules was
  judged the right-sized answer, with no cross-repo dependency on nixfish
  at all. If a genuinely reusable "declarative shell, zero home-manager"
  pattern emerges from more than one such case, it belongs here.
- Declarative `bash` adoption (`programs.bash` has the identical
  wholesale-ownership model and the identical `-b`/`force` mechanics — the
  same adoption-sequence documentation applies, just not yet written up as
  its own option surface here).
- Integration tests exercising the actual collision/backup behavior against
  a real pre-existing file, not just eval-time type checks.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point; exports `homeManagerModules.fish`. |
| `home/fish.nix` | The module itself — see its header comment for the full adoption sequence and the universal-variables gotcha. |
| `experiments/` | Throwaway trials — see [`experiments/README.md`](experiments/README.md). |
| `studies/` | Written-up findings — see [`studies/README.md`](studies/README.md). |

## Related projects

nixfish is one of several small, independently-usable open-source projects
sharing a common design system: [nixarch](https://github.com/julian-corbet/nixarch-corbet-ch)
(declarative Arch/CachyOS via system-manager + home-manager), nixvps (tiny
sub-1GB NixOS VPS profiles), nixram (RAM/memory tuning), nixnas (a NixOS
distro build), nixremote (cross-machine native app forwarding). nixfish's
own niche is narrower than any of them — just the safe-adoption pattern for
a shell config that already exists somewhere else — which is exactly what
lets it serve all of them without any of them depending on each other.

## License

[MIT License](LICENSE) © 2026 Julian Corbet
