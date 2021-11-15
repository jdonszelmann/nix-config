
## Resources
  - official docs and things:
    + nixos manual
    + nixpkg manual
    + [nix manual](https://nixos.org/manual/nix/stable/introduction.html)
    + nixpills
    + home-manager manual
    + nixpgs search
    + nix option search?
    + search.nix.gic.io
  - Misc resources:
    + [NixOS4Noobs](https://jorel.dev/NixOS4Noobs/intro.html)
    + https://christine.website/blog/i-was-wrong-about-nix-2020-02-10
    + nix-shorts: https://github.com/justinwoo/nix-shorts/tree/master/posts
    + link dump: https://wiki.nikitavoloboev.xyz/package-managers/nix
    + https://stephank.nl/p/2020-06-01-a-nix-primer-by-a-newcomer.html
    + https://www.iohannes.us/en/commentary/nix-critique/ (not really a _resource_)
      * some of this critique seems inaccurate; see the sandbox key for [`nix.conf`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html) (the docs for it allege that with `sandbox = true` nix does use namespaces and chroots)
      * follow ups/relevant:
        - https://www.reddit.com/r/NixOS/comments/qs529l/a_critique_of_nix_package_manager/
        - https://discourse.nixos.org/t/content-addressed-nix-call-for-testers/12881
          + https://www.tweag.io/blog/2020-09-10-nix-cas/
          + https://github.com/tweag/rfcs/blob/cas-rfc/rfcs/0062-content-addressed-paths.md
    + https://christine.website/blog/how-i-start-nix-2020-03-08
    + https://markhudnall.com/2021/01/27/first-impressions-of-nix/
    + [Nix: How and Why it Works (NixCon 2019)](https://www.youtube.com/watch?v=lxtHH838yko)Nix: How and Why it Works (NixCon 2019) ([Graham Christensen](https://github.com/grahamc))
      * related: https://shealevy.com/blog/2018/08/05/understanding-nixs-string-context/
      * good overview of evaluation -> derivations -> realisations, caching, and fixed output derivations
    + [Fearless Tinkering: How NixOS Works (NixCon 2019)](https://www.youtube.com/watch?v=DK_iLg2Ekwk) ([Graham Christensen](https://github.com/grahamc))
      * some nice live demos; shows off `build-vm` and the resulting QEMU script
    + https://www.reddit.com/r/NixOS/comments/gdnzhy/question_how_nixos_options_works_underthehood/
    + [Everything You Always Wanted To Know About Nix (But Were Afraid To Ask)](https://www.youtube.com/watch?v=2mG0zM_wtYs)
      * bit more about derivations: https://shopify.engineering/what-is-nix
      * more on the "magic" behind `callPackage` [here](https://nixos.org/guides/nix-pills/callpackage-design-pattern.html#idm140737319916096) (actually getting the attrs a lambda takes is just handled by `builtins.functionArgs` which is the only really magical bit)
        - more discussion [here](https://stackoverflow.com/questions/56121361/where-is-callpackage-defined-in-the-nixpkgs-repo-or-how-to-find-nix-lambda-de) and [here](https://discourse.nixos.org/t/where-is-callpackage-defined-exactly-part-2/12524/2)
      * ATerm, the drv format: https://github.com/NixOS/nix/issues/5481
      * [covers](https://youtu.be/2mG0zM_wtYs?t=4015) how overlays work (lots of recursion!)
        - this bit is the key:
          ```nix
          let
            self =
              foldl (overlay: super: super // overlay self super)
              initialSet overlays;
            in self
          ```
       - `self` is the final set of overlays; lazy eval lets us refer to it before it's full constructed without creating cycles
       - `super` is the set of overlays _before_ the current overlay is layered on; this lets us pass along an existing attr with some tweaks, etc.
       - as a mostly unrelated tangent, [this](https://wiki.haskell.org/Foldr_Foldl_Foldl%27) covers `foldl` vs `foldl'` vs `foldr` pretty well
    + [The dark and murky past of NixOS (NixCon 2019)](https://www.youtube.com/watch?v=fsgYVi2PQr0) ([Armijn Hemel](https://github.com/armijnhemel))
    + [Nix on Darwin — History, challenges, and where it's going (NixCon 2017)](https://www.youtube.com/watch?v=73mnPBLL_20) ([Dan Peebles](https://github.com/copumpkin))
      - [Tracking Issue for Nix on macOS](https://github.com/NixOS/nixpkgs/issues/116341)
      - [PR for enabling the sanbox by default on macOS](https://github.com/NixOS/nix/pull/1821)
        * note that the PR is out of date; the sandbox is [enabled by default](https://github.com/NixOS/nix/blob/0d9e050ba719515620a2e320a7b6bba35f1d1df6/src/libstore/globals.hh#L387-L388) on Linux
    + https://github.com/hlissner/dotfiles
    + https://www.tweag.io/blog/2020-05-25-flakes/
    + https://www.youtube.com/watch?v=K54KKAx2wNc
    + [Nix Flakes (NixCon 2019)](https://www.youtube.com/watch?v=UeBX7Ide5a0) ([Eelco Dolstra](https://github.com/edolstra))
    + https://ianthehenry.com/posts/how-to-learn-nix/
    + [Assembling SoCs with Nix (NixCon 2015)](https://www.youtube.com/watch?v=0n3cAg0R22c)
  - ZFS:
    + [Ars Technica ZFS 101](https://arstechnica.com/information-technology/2020/05/zfs-101-understanding-zfs-storage-and-performance/)
    + [NixOS Wiki ZFS Page](https://nixos.wiki/wiki/ZFS)
    +
  - Custom compiler/flags:
    + on using `-march=native` or some equiv in stdenv: https://narkive.com/lkYfC9OJ.11
    + hardening compiler flags in stdenv: https://blog.mayflower.de/5800-Hardening-Compiler-Flags-for-NixOS.html
    + using clang instead of gcc: https://nixos.wiki/wiki/Using_Clang_instead_of_GCC
  - Using your own Linux kernel/patches/etc: https://nixos.wiki/wiki/Linux_kernel
  - Encryption:
    + ZFS Encryption Section of NixOS Wiki ZFS Page
    + Encrypted Root NixOS Wiki Page
    + martijnvermaat gist
    + ladinu gist (this is closest to what I ended up doing)
    + ubuntu secure boot page
    + nixos github issue about secure boot (in particular the comments about self-signing)
    + arch linux encrypted root/full disk encryption page
    + [arch linux dm-crypt Device_encryption page](https://wiki.archlinux.org/title/dm-crypt/Device_encryption)
    + [Ars Technica OpenZFS native encryption guide](https://arstechnica.com/gadgets/2021/06/a-quick-start-guide-to-openzfs-native-encryption/)
  - Storing secrets:
    + `sops`, `nix-sops` (todo: find that blog post)
    + `age`, `agenix`, `rage`, `ragenix`
    + blog post about some alternatives: https://christine.website/blog/nixos-encrypted-secrets-2021-01-20
    + or [`homeage`](https://github.com/jordanisaacs/homeage)
  - Caching/build in CI:
    + https://github.com/cachix/install-nix-action
    + https://github.com/cachix/cachix-action
  - cross compiling:
    + TODO
  - bootstrapping/bootstrapping stages:
    + TODO
  - containers:
    + https://nixos.wiki/wiki/NixOS_Containers
    + https://nixos.org/manual/nixos/stable/#ch-containers
  - direnv and friends:
    + [`lorri`](https://github.com/nix-community/lorri)
      * [lorri — Your project's nix env (NixCon 2019)](https://www.youtube.com/watch?v=WtbW0N8Cww4)
    + [`direnv`](https://github.com/direnv/direnv/wiki/Nix)
    + [`lorelei`](https://github.com/shajra/direnv-nix-lorelei)
    + [`sorri`](https://github.com/nmattia/sorri)
    + [`nix-direnv`](https://github.com/nix-community/nix-direnv)
      * has flake support (`use flake`) which is nice since it means you don't need the default.nix + shell.nix + flake.nix thing I think
        - need to use `flake-compat` for `lorri` [as described here](https://github.com/target/lorri/issues/460)
    + there's a nice [comparison table on the direnv Nix wiki page](https://github.com/direnv/direnv/wiki/Nix#some-factors-to-consider)
    + see the notes below on `lorri`, `direnv` libs, and gc-ing `nix-shell` invocations
  - Other tooling/helpers:
    + direnv
    + niv (actually just use flakes?)
    + flake-utils-plus (TODO: name)
    + home-manager
    + nixos-hardware
    + lorri
    + [`nix-tree`](https://github.com/utdemir/nix-tree)
    + [`nix-visualize`](https://github.com/craigmbooth/nix-visualize)
    + [`nix-du`](https://github.com/symphorien/nix-du)
    + [`nix-query-tree-viewer`](https://github.com/cdepillabout/nix-query-tree-viewer)
  - Other nixOS configurations:
    + Eliza Weismann (@hawkw)'s dotfiles
    + Rebecca Turner (@9999years)'s nix-config
    + Jade Lovelace's config
    + DieracDelta
    + _ other one from V
    + list of configurations on the NixOS wiki
    + other one from twitter; in FF tabs (TODO)
    + https://github.com/mitchellh/nixos-config
    + https://github.com/JorelAli/nixos/blob/master/configuration.nix


## misc/todo


https://github.com/nix-community/home-manager
https://typeof.net/Iosevka/
https://github.com/DieracDelta/flakes/blob/flakes/.github/workflows/cachix.yml
https://github.com/nmattia/niv
https://github.com/ryantm/agenix
https://github.com/nix-community/lorri
`MOZ_USE_XINPUT2=1` for Firefox (https://bugzilla.mozilla.org/show_bug.cgi?id=1438107)

enable nix sandbox on macOS?

LICENSE

look into/read:
  - https://github.com/nix-community/naersk#install
  - https://raw.githubusercontent.com/edolstra/edolstra.github.io/49a78323f6b319da6e078b4f5f6b3112a30e8db9/pubs/phd-thesis.pdf
  - https://github.com/wmertens/rfcs/blob/master/rfcs/0017-intensional-store.md

can't find an archived copy of [this](https://lawrencedunn.io/posts/2020-03-20-how-nix-instantiation-works/) :-(

IFD: https://nixos.wiki/wiki/Import_From_Derivation
  - https://fzakaria.com/2020/10/20/nix-parallelism-import-from-derivation.html

install lorri
look into 
direnv vscode: https://marketplace.visualstudio.com/items?itemName=Rubymaniac.vscode-direnv

nix gc option (for lorri, mostly) that only frees things that haven't been _used_ in 1week+, etc.
  - this'd be nice for nix-shell/lorri things; any projects that hasn't been entered in, say, a week loses its gc-root
  - somewhat relevant: https://github.com/NixOS/nix/issues/2793
  - easiest way to achieve this might be to wrap `lorri` (or whatever direnv plugin we use)'s `use_nix` function with our own thing that records, somewhere, when nix-shell based gcroots were last "entered"
    + `lorri` doesn't seem to even register a [`direnv lib bash file`](https://direnv.net/#the-stdlib) that overrides `use_nix()`; instead it seems to prefer emitting `.envrc` files with `eval "$(lorri direnv)"` (grep for `cat .direnv` on [this post](https://christine.website/blog/how-i-start-nix-2020-03-08))
    + so, we should be able to register our own direnv lib file like [this](https://github.com/shajra/direnv-nix-lorelei/blob/main/nix/direnv-nix-lorelei.nix) that records out metadata somewhere and then shells out to `eval "$(lorri direnv)"`
      * note the `writeShellCheckedShareLib`!
        - comes from [here](https://github.com/shajra/nix-project/blob/67c95bf46ee532dce68e0bbcb13bb025f0567acc/nix/lib.nix#L63)
          + [here](https://github.com/shajra/nix-project/blob/67c95bf46ee532dce68e0bbcb13bb025f0567acc/nix/default.nix#L17), gets overlaid [here](https://github.com/shajra/direnv-nix-lorelei/blob/fffccbf468d0ec473990557bc35478a675ec8663/nix/default.nix#L30)
    + then, we can also create a separate service that runs every so often and checks the metadata we record and uses it to unregister gc roots that were registered from .direnv activations that haven't been re-entered in <some time period>

install https://github.com/lf-/nix-doc with plugin stuff

nix gc enable (not on battery power)
zfs snapshot, cleanup, etc. (not on battery power, etc.; or reduced freq for snapshotting on battery power)

.cargo/config that's generated with:
  - `target.<triple>.linker` = some wrapper that shells out to ld.lld or mold ~rustflags = some wrapper that shells out to ld.lld or mold (i.e. `["-C', "link-arg=fuse-ld=lld-wrapper"]`?)~
    + note: `linker` only seems to be available for `target.<triple>` and not `target.<cfg()>`; `rustflags` is available for both and can work when `-C link-arg=` can be used to specify the desired linker
      - for us, specifying `mold` using `-C link-arg=fuse-ld=lld` is tricky; we'd need to replace the `ld.lld` binary with a wrapper, etc.
    + we don't want to use mold for release builds
      - unfortunately there doesn't seem to be a way to do this in `.cargo/config`; we can't set `rustflags` conditionally based on the release profile (see [this](https://github.com/rust-lang/cargo/issues/5777)) and the release profile doesn't include a `rustflags` key or a `linker` key (see [this](https://doc.rust-lang.org/cargo/reference/config.html#configuration-format))
      - best I can come up with is to create a wrapper that checks the paths for "release"/"debug"/"bench", etc. and shells out to `mold`/`lld` as appropriate
  - rustc-wrapper = sccache

## misc notes

nix-env uses nix (build and store and friends) to make profiles (set ~/.nix-profile, and to make symlink forests in the form of profiles in the nix store)
  - takes a bunch of derivations and gives you a profile
nixos...
nix-darwin
homemanager

build does:
  - instantiate (runs the evaluator to produce derivations)
  - realisations ("builds" the derivations)
    + these interact with the nix store
    + nix-daemon does this

build-vm gives you a handy qemu runner script (doesn't even need a bootloader)
