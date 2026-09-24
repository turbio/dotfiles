{ lib, ... }:
let
  hosturls = {
    ccr2004 = "http://192.168.88.1"; # TODO hard coded ips
    crs326 = "http://192.168.88.245";
    crs305 = "http://192.168.1.69";
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
    # password passed in through ROS_PASSWORD env at plan/apply time

    # for self singed
    insecure = true;
  }) hosturls;
}
