{ lib, ... }:
let
  inventory = import ../lib/inventory.nix;
  hosturls = {
    ccr2004 = "http://${inventory.appliances.ccr2004.lan.ip4}";
    crs326 = "http://${inventory.appliances.crs326.lan.ip4}";
    crs305 = "http://${inventory.appliances.crs305.wan.ip4}";
  };
in
{
  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    version = ">= 1.99.0";
  };

  variable = {
    username = {
      type = "string";
      default = "admin";
    };
  }
  // lib.mapAttrs' (
    d: url:
    lib.nameValuePair "${d}_hosturl" {
      type = "string";
      default = url;
    }
  ) hosturls;

  provider.routeros = lib.mapAttrsToList (d: _: {
    alias = d;
    hosturl = "\${var.${d}_hosturl}";
    username = "\${var.username}";
    insecure = true;
  }) hosturls;
}
