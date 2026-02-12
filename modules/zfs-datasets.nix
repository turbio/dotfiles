{
  lib,
  config,
  ...
}:

let
  cfg = config.zfs;

  mkService =
    pool: dsName: ds:
    let
      fullName = "${pool}/${dsName}";

      propsOpts = lib.mapAttrsToList (k: v: "-o ${k}=${lib.strings.escapeShellArg v}") ds.properties;
      optsStr = lib.concatStringsSep " " propsOpts;

      defaultMountpoint = "/${pool}/${dsName}";

      createCmd =
        if ds.type == "volume" then
          "zfs create -V ${ds.size} ${optsStr} ${fullName}"
        else
          "zfs create ${optsStr} ${fullName}";

      serviceName = "zfs-ensure-" + (lib.strings.replaceStrings [ "/" ] [ "-" ] fullName);

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

      setOptionsCmd = lib.concatStringsSep "\n" (lib.mapAttrsToList upsertOptionCmd ds.properties);

      setMountpointCmd = ''
        current="$(zfs get -H -o value mountpoint ${fullName})"
        cur_canon="$(realpath -m "$current")"
        target_canon="$(realpath -m "${ds.mountpoint}")"
        if [ "$cur_canon" != "$target_canon" ]; then
          zfs set mountpoint=$target_canon ${fullName}
        fi
      '';
    in
    {
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
            :;
            ${createCmd}
          else
            :;
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
    lib.mapAttrsToList (
      pool: poolDesc: lib.mapAttrsToList (dsName: ds: mkService pool dsName ds) poolDesc.datasets
    ) cfg.pools
  );

  datasetModule =
    { poolName }:
    { name, ... }@datasetArgs:
    let
      defaultMountpoint = "/${poolName}/${name}";
      datasetModuleConfig = datasetArgs.config;
    in
    {
      options = {
        type = lib.mkOption {
          type = lib.types.enum [
            "filesystem"
            "volume"
          ];
          default = "filesystem";
          description = "Dataset type (filesystem or volume)";
        };

        size = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          description = "Size for ZVOLs (only valid when type = \"volume\")";
          default = null;
        };

        properties = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "ZFS properties to enforce via `zfs set` and passed at creation time";
        };

        mountpoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = if datasetModuleConfig.type == "filesystem" then defaultMountpoint else null;
          description = ''Mountpoint default to ("${defaultMountpoint}").'';
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
      };
    };

  poolModule =
    { name, ... }:
    {
      options.datasets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (datasetModule {
            poolName = name;
          })
        );
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
            properties = {
              mountpoint = "/";
              compression = "zstd";
              atime = "off";
            };
          };
          "home" = {
            properties = {
              mountpoint = "/home";
              compression = "zstd";
            };
          };
          "vm" = {
            type = "volume";
            size = "200G";
            properties = {
              volblocksize = "16k";
              compression = "zstd";
            };
          };
        };
      };
    };
  };

  config = {
    assertions =
      let
        datasetAsserts = poolname: name: dataset: [
          {
            assertion = dataset.type == "volume" -> dataset.size != null;
            message = "size must be set for volume datasets.";
          }
          {
            assertion = dataset.type == "filesystem" -> dataset.size == null;
            message = "size cannot be set for filesystem datasets.";
          }
          {
            assertion = !dataset.properties ? mountpoint;
            message = "mountpoint should be configured with zfs.${poolname}.${name}.mountpoint instead.";
          }
          {
            assertion = dataset.type == "filesystem" -> dataset.mountpoint != null;
            message = "mountpoint is only meaningful for filesystem datasets.";
          }
          {
            assertion =
              (dataset.perms ? owner && dataset.perms.owner != null)
              -> (lib.hasAttr dataset.perms.owner config.users.users);
            message = ''
              user "${dataset.perms.owner}" in zfs.${poolname}.${name}.perms.owner must be an existing system user.
              expected to find the user in users.users.<user>.
            '';
          }
          {
            assertion =
              (dataset.perms ? group && dataset.perms.group != null)
              -> (lib.hasAttr dataset.perms.group config.users.groups);
            message = ''
              group "${dataset.perms.group}" in zfs.${poolname}.${name}.perms.group must be an existing system group.
              expected to find the group in users.groups.<group>.
            '';
          }
        ];
      in
      cfg.pools
      |> lib.mapAttrsToList (
        pool: poolConfig:
        (lib.mapAttrsToList (dataset: datasetConfig: datasetAsserts pool dataset datasetConfig))
          poolConfig.datasets
      )
      |> lib.flatten;

    systemd.services = lib.mkMerge mkServices;
  };
}
