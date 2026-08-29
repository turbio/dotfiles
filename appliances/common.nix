{ lib, ... }:
let
  hosturls = {
    ccr2004 = "http://192.168.88.1";
    crs326 = "http://192.168.88.245";
    crs305 = "http://192.168.1.69";
  };
in
{
  terraform.required_providers.routeros = {
    source = "terraform-routeros/routeros";
    # matches the nixpkgs-unstable plugin used by the offline validate check
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
    # password intentionally absent: ROS_PASSWORD env at plan/apply time
    # only matters if a hosturl is overridden to https (self-signed certs)
    insecure = true;
  }) hosturls;
}
