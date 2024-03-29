# My Dotfiles!
There are many like it but these are mine.

Okay but hear me out, they're actually pretty nifty. These dotfiles configure all my computers, desktops and [servers](https://turb.io) alike. Mostly it's just a bunch of [nix](https://nixos.org/), the specific config is determined by the hostname (through the power of flakes!) with individual host configs under `/hosts`.

<p float="left">
  <a href="/hosts/balrog"><img src="/hosts/balrog/balrog.png" width="48" /></a>
  <a href="/hosts/gero"><img src="/hosts/gero/gero.png" width="48" /></a>
  <a href="/hosts/itoh"><img src="/hosts/itoh/itoh.png" width="48" /></a>
</p>

![screenshot of sway desktop](/screenshot.png)

To actually get this whole thing installed from a live image ya wanna go through the regular nixos install steps *BUT* run
```
sudo nixos-install --flake /mnt/etc/nixos#<hostname>
```
when it's time to build the system.
