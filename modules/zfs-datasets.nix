{ lib, config, pkgs, ... }:

let
  cfg = config.zfs;

  mkService = pool: dsName: ds: let
    fullName = "${pool}/${dsName}";

    propsOpts = lib.mapAttrsToList
      (k: v: "-o ${k}=${lib.strings.escapeShellArg v}") ds.properties;
    optsStr = lib.concatStringsSep " " propsOpts;

    defaultMountpoint = "/${pool}/${dsName}";

    createCmd =
      if ds.type == "volume" then
        "zfs create -V ${ds.size} ${optsStr} ${fullName}"
      else
        "zfs create ${optsStr} ${fullName}";

    serviceName = "zfs-ensure-" + (lib.strings.replaceStrings ["/"] ["-"] fullName);

    getmpCmd = ''
      mp="$(zfs get -H -o value mountpoint ${fullName})"
    '';

    chownCmd = lib.optionalString ((ds.perms.owner != null) || (ds.perms.group != null)) ''
      if [ "$mp" != "legacy" ] && [ "$mp" != "none" ] && [ -d "$mp" ]; then
        chown ${lib.defaultTo "" ds.perms.owner}:${lib.defaultTo "" ds.perms.group} "$mp"
      fi
    '';

    chmodCmd = lib.optionalString (ds.perms.mode != null) ''
      if [ "$mp" != "legacy" ] && [ "$mp" != "none" ] && [ -d "$mp" ]; then
        chmod ${ds.perms.mode} "$mp"
      fi
    '';

    # try to set a value to the current value actually isn't a noop in some
    # cases.
    upsertOptionCmd = option: target: ''
      current="$(zfs get -H -o value ${option} ${fullName})"
      if [ "$current" != "${target}" ]; then
        zfs set ${option}=${lib.strings.escapeShellArg target} ${fullName}
      fi
    '';

    setOptionsCmd = lib.concatStringsSep "\n" (
      lib.mapAttrsToList upsertOptionCmd ds.properties
    );

    setMountpointCmd = ''
      current="$(zfs get -H -o value mountpoint ${fullName})"
      cur_canon="$(realpath -m "$current")"
      target_canon="$(realpath -m "${ds.mountpoint}")"
      if [ "$cur_canon" != "$target_canon" ]; then
        zfs set mountpoint=$target_canon ${fullName}
      fi
    '';
  in {
    ${serviceName} = {
      path = [
        config.boot.zfs.package
      ];
      description = "Ensure ZFS dataset ${fullName}";
      after = [ "zfs-import-${pool}.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        if ! zfs list -H -o name ${fullName} >/dev/null 2>&1; then
          ${createCmd}
        else
          ${setOptionsCmd}
          ${lib.optionalString (ds.mountpoint != defaultMountpoint) setMountpointCmd}
        fi
        ${getmpCmd}
        ${chownCmd}
        ${chmodCmd}
      '';
    };
  };

  # Turn the nested attrset zfs.<pool>.<dataset> into a flat list of services
  mkServices = lib.concatLists (
    lib.mapAttrsToList (pool: poolDesc:
      lib.mapAttrsToList (dsName: ds: mkService pool dsName ds) poolDesc.datasets
    ) cfg.pools
  );

  datasetModule = { poolName }: { config, name, ... }:
  let
    defaultMountpoint = "/${poolName}/${name}";
  in
  {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "filesystem" "volume" ];
        default = "filesystem";
        description = "Dataset type (filesystem or volume)";
      };

      size = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Size for ZVOLs (only valid when type = \"volume\")";
      };

      properties = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "ZFS properties to enforce via `zfs set` and passed at creation time";
      };

      mountpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if config.type == "filesystem" then defaultMountpoint
          else null;
        description = ''Mountpoint default to ("${defaultMountpoint}").'';
      };

      assertions = lib.mkOption {
          type = lib.types.listOf lib.types.unspecified;
          default = [ ];
          visible = false;
          internal = true;
        };

      perms.owner = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Username to own the dataset mountpoint (filesystems only).";
      };
      perms.group = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Group name to own the dataset mountpoint (filesystems only).";
      };
      perms.mode = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "chmod mode (e.g. 0750) for the mountpoint (filesystems only).";
      };
    };

    # Enforce invariants
    config = {
      assertions = [
        {
          assertion = !(config.properties ? mountpoint);
          message = "mountpoint should be configured with zfs.<pool>.${name}.mountpoint instead.";
        }
        {
          assertion = (config.type == "volume") || (config.size == null);
          message = "zfs.<pool>.${name}.size is only allowed when type = \"volume\".";
        }
        {
          assertion = (config.type != "volume") || (config.size != null);
          message = "zfs.<pool>.${name}.size must be specified when type = \"volume\".";
        }
        {
          assertion = (config.type == "filesystem") || (config.mountpoint == null);
          message = "mountpoint is only meaningful for filesystem datasets.";
        }
      ];
    };
  };

  poolModule = { name, ... }: {
    options.datasets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (datasetModule { poolName = name; }));
    };
  };
in
{
  options.zfs.pools = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule poolModule);
    default = { };
    description = ''
      Declarative ZFS datasets, configured like:

        zfs.pools.<pool>.datasets.<dataset> = {
          type = "filesystem";
          properties.mountpoint = "/srv";
          properties.compression = "zstd";
        };

      The dataset "<pool>/<dataset>". Nested datasets must use `/` in the dataset name.
    '';
    example = {
      datasets = {
        tank = {
          "root" = {
            properties = { mountpoint = "/"; compression = "zstd"; atime = "off"; };
          };
          "home" = {
            properties = { mountpoint = "/home"; compression = "zstd"; };
          };
          "vm" = {
            type = "volume";
            size = "200G";
            properties = { volblocksize = "16k"; compression = "zstd"; };
          };
        };
      };
    };
  };

  config = {
    systemd.services = lib.mkMerge mkServices;
  };
}
