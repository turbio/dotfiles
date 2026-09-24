# the single terraform root: every appliance, one state, one plan.
{ lib, ... }:
let
  combine = import ./combine.nix { inherit lib; };
  devices = [
    "ccr2004"
    "crs326"
    "crs305"
  ];
in
{
  resource =
    devices
    |> map (d: combine d (import (./. + "/${d}.nix") { inherit lib; }).resource)
    |> lib.foldl' lib.recursiveUpdate { };
}
