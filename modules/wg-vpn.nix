# It's the [wireguard module from nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-24.11/nixos/modules/services/networking/wireguard.nix)
# but better cause like I want:
# - a hub-and-spoke vpn w/ opportunistic lan peering
#   - all statically configured in nix
#   - mDNS to find my local frens
# - internet ingress routing - internet traffic can be selectively port
#   forwarded through the designated router to any machine
#
# not trying to:
# - do any fancy tailscale-y nat traversal
# - handle internet egress, ingress and intranet only
#
# A VPN maps to a single Wireguard interface on each machine with a peer for
# each potential connection. Mostly it's just dynamically poking Wireguard's
# allowed-ips to switch pathing.
#
# A single machine may be designated as a router
#
# multi router choice? could loop!
#
# Wireguard's "Cryptokey Routing"
#
#          internet ingress
#                  |
#                  v
#     .-[router]----------------.
#     |                         |
#     | - ingress routing table |
#     |                         |
#     '-------------------------'
#        ^
#        |
# .-[client]-.
# |          |
# '----------'
#
# forked from https://github.com/NixOS/nixpkgs/blob/26d499fc9f1d567283d5d56fcf367edd815dba1d/nixos/modules/services/networking/wireguard.nix
{
  config,
  lib,
  options,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.services.wgvpn;
  opt = options.services.wgvpn;

  kernel = config.boot.kernelPackages;

  # interface options

  networkOpts =
    { ... }:
    {

      options = {
        subnet = mkOption {
          example = "192.168.0.0/24";
          default = null;
          type = types.str;
          description = "Subnet of this network";
        };

        generatePrivateKeyFile = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Automatically generate a private key with {command}`wg genkey`, at
            the privateKeyFile location if it does not exist.
          '';
        };

        privateKeyFile = mkOption {
          example = "/private/wireguard_key";
          type = with types; nullOr str;
          default = null;
          description = ''
            Private key file of this machine`.
          '';
        };

        listenPort = mkOption {
          default = null;
          type = with types; nullOr int;
          example = 51820;
          description = ''
            16-bit port for listening. Optional; if not specified,
            automatically generated based on interface name.
          '';
        };

        mtu = mkOption {
          default = null;
          type = with types; nullOr int;
          example = 1280;
          description = ''
            Set the maximum transmission unit in bytes for the wireguard
            interface. Beware that the wireguard packets have a header that may
            add up to 80 bytes to the mtu. By default, the MTU is (1500 - 80) =
            1420. However, if the MTU of the upstream network is lower, the MTU
            of the wireguard network has to be adjusted as well.
          '';
        };

        forwardPorts = mkOption {
          default = [ ];
          description = ''
            List of port forwarding rules for external traffic inbound to the
            router
          '';
          type = with types; listOf (submodule forwardOpts);
        };

        hosts = mkOption {
          default = [ ];
          description = ''
            List of all hosts in the network
          '';
          type = with types; listOf (submodule hostOpts);
        };
      };
    };

  # peer options

  forwardOpts = self: {
    options = {
      destinationHost = mkOption {
        type = types.str;
        description = "hostname of the destination machine";
      };
      destinationPort = mkOption {
        type = types.int;
        description = "port of the destination machine";
      };
      sourceHost = mkOption {
        type = types.str;
        description = "hostname of the source machine";
      };
      sourcePort = mkOption {
        type = types.int;
        description = "port of the source machine";
      };
      proto = mkOption {
        type = types.str;
        default = "tcp";
        example = "tcp";
        description = "protocol of the port forwarding rule";
      };
    };
  };

  hostOpts = self: {
    options = {
      hostname = mkOption {
        type = types.str;
        description = "Machine hostname";
      };

      pubkey = mkOption {
        example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
        type = types.singleLineStr;
        description = "The base64 public key of the peer.";
      };

      allowedIPs = mkOption {
        example = "192.168.0.5";
        type = types.str;
        description = ''
          ip address assignment to this machine
        '';
      };

      endpoint = mkOption {
        default = null;
        example = "demo.wireguard.io:12913";
        type = with types; nullOr str;
        description = ''
          Endpoint IP or hostname where this machine can be reached.
        '';
      };
    };
  };

  generateKeyServiceUnit =
    name: values:
    assert values.generatePrivateKeyFile;
    nameValuePair "wireguard-${name}-key" {
      description = "WireGuard Tunnel - ${name} - Key Generator";
      wantedBy = [ "wireguard-${name}.service" ];
      requiredBy = [ "wireguard-${name}.service" ];
      before = [ "wireguard-${name}.service" ];
      path = with pkgs; [ wireguard-tools ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -e

        # If the parent dir does not already exist, create it.
        # Otherwise, does nothing, keeping existing permissions intact.
        mkdir -p --mode 0755 "${dirOf values.privateKeyFile}"

        if [ ! -f "${values.privateKeyFile}" ]; then
          # Write private key file with atomically-correct permissions.
          (set -e; umask 077; wg genkey > "${values.privateKeyFile}")
        fi
      '';
    };

  peerUnitServiceName =
    interfaceName: peerName: dynamicRefreshEnabled:
    let
      refreshSuffix = optionalString dynamicRefreshEnabled "-refresh";
    in
    "wireguard-${interfaceName}-peer-${peerName}${refreshSuffix}";

  generatePeerUnit =
    {
      interfaceName,
      interfaceCfg,
      peer,
    }:
    let
      psk =
        if peer.presharedKey != null then
          pkgs.writeText "wg-psk" peer.presharedKey
        else
          peer.presharedKeyFile;
      src = interfaceCfg.socketNamespace;
      dst = interfaceCfg.interfaceNamespace;
      ip = nsWrap "ip" src dst;
      wg = nsWrap "wg" src dst;
      dynamicRefreshEnabled = peer.dynamicEndpointRefreshSeconds != 0;
      # We generate a different name (a `-refresh` suffix) when `dynamicEndpointRefreshSeconds`
      # to avoid that the same service switches `Type` (`oneshot` vs `simple`),
      # with the intent to make scripting more obvious.
      serviceName = peerUnitServiceName interfaceName peer.name dynamicRefreshEnabled;
    in
    nameValuePair serviceName {
      description =
        "WireGuard Peer - ${interfaceName} - ${peer.name}"
        + optionalString (peer.name != peer.publicKey) " (${peer.publicKey})";
      requires = [ "wireguard-${interfaceName}.service" ];
      wants = [ "network-online.target" ];
      after = [
        "wireguard-${interfaceName}.service"
        "network-online.target"
      ];
      wantedBy = [ "wireguard-${interfaceName}.service" ];
      environment.DEVICE = interfaceName;
      environment.WG_ENDPOINT_RESOLUTION_RETRIES = "infinity";
      path = with pkgs; [
        iproute2
        wireguard-tools
      ];

      serviceConfig =
        if !dynamicRefreshEnabled then
          {
            Type = "oneshot";
            RemainAfterExit = true;
          }
        else
          {
            Type = "simple"; # re-executes 'wg' indefinitely
            # Note that `Type = "oneshot"` services with `RemainAfterExit = true`
            # cannot be used with systemd timers (see `man systemd.timer`),
            # which is why `simple` with a loop is the best choice here.
            # It also makes starting and stopping easiest.
            #
            # Restart if the service exits (e.g. when wireguard gives up after "Name or service not known" dns failures):
            Restart = "always";
            RestartSec =
              if null != peer.dynamicEndpointRefreshRestartSeconds then
                peer.dynamicEndpointRefreshRestartSeconds
              else
                peer.dynamicEndpointRefreshSeconds;
          };
      unitConfig = lib.optionalAttrs dynamicRefreshEnabled {
        StartLimitIntervalSec = 0;
      };

      script =
        let
          wg_setup = concatStringsSep " " (
            [ ''${wg} set ${interfaceName} peer "${peer.publicKey}"'' ]
            ++ optional (psk != null) ''preshared-key "${psk}"''
            ++ optional (peer.endpoint != null) ''endpoint "${peer.endpoint}"''
            ++ optional (
              peer.persistentKeepalive != null
            ) ''persistent-keepalive "${toString peer.persistentKeepalive}"''
            ++ optional (peer.allowedIPs != [ ]) ''allowed-ips "${concatStringsSep "," peer.allowedIPs}"''
          );
          route_setup = optionalString interfaceCfg.allowedIPsAsRoutes (
            concatMapStringsSep "\n" (
              allowedIP:
              ''${ip} route replace "${allowedIP}" dev "${interfaceName}" table "${interfaceCfg.table}" ${
                optionalString (interfaceCfg.metric != null) "metric ${toString interfaceCfg.metric}"
              }''
            ) peer.allowedIPs
          );
        in
        ''
          ${wg_setup}
          ${route_setup}

          ${optionalString (peer.dynamicEndpointRefreshSeconds != 0) ''
            # Re-execute 'wg' periodically to notice DNS / hostname changes.
            # Note this will not time out on transient DNS failures such as DNS names
            # because we have set 'WG_ENDPOINT_RESOLUTION_RETRIES=infinity'.
            # Also note that 'wg' limits its maximum retry delay to 20 seconds as of writing.
            while ${wg_setup}; do
              sleep "${toString peer.dynamicEndpointRefreshSeconds}";
            done
          ''}
        '';

      postStop =
        let
          route_destroy = optionalString interfaceCfg.allowedIPsAsRoutes (
            concatMapStringsSep "\n" (
              allowedIP:
              ''${ip} route delete "${allowedIP}" dev "${interfaceName}" table "${interfaceCfg.table}"''
            ) peer.allowedIPs
          );
        in
        ''
          ${wg} set "${interfaceName}" peer "${peer.publicKey}" remove
          ${route_destroy}
        '';
    };

  # the target is required to start new peer units when they are added
  generateInterfaceTarget =
    name: values:
    let
      mkPeerUnit =
        peer: (peerUnitServiceName name peer.name (peer.dynamicEndpointRefreshSeconds != 0)) + ".service";
    in
    nameValuePair "wireguard-${name}" rec {
      description = "WireGuard Tunnel - ${name}";
      wantedBy = [ "multi-user.target" ];
      wants = [ "wireguard-${name}.service" ] ++ map mkPeerUnit values.peers;
      after = wants;
    };

  generateInterfaceUnit =
    name: values:
    # exactly one way to specify the private key must be set
    #assert (values.privateKey != null) != (values.privateKeyFile != null);
    let
      privKey =
        if values.privateKeyFile != null then
          values.privateKeyFile
        else
          pkgs.writeText "wg-key" values.privateKey;
      src = values.socketNamespace;
      dst = values.interfaceNamespace;
      ipPreMove = nsWrap "ip" src null;
      ipPostMove = nsWrap "ip" src dst;
      wg = nsWrap "wg" src dst;
      ns = if dst == "init" then "1" else dst;

    in
    nameValuePair "wireguard-${name}" {
      description = "WireGuard Tunnel - ${name}";
      after = [ "network-pre.target" ];
      wants = [ "network.target" ];
      before = [ "network.target" ];
      environment.DEVICE = name;
      path = with pkgs; [
        kmod
        iproute2
        wireguard-tools
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = concatStringsSep "\n" (
        optional (!config.boot.isContainer) "modprobe wireguard || true"
        ++ [
          values.preSetup
          ''${ipPreMove} link add dev "${name}" type wireguard''
        ]
        ++ optional (
          values.interfaceNamespace != null && values.interfaceNamespace != values.socketNamespace
        ) ''${ipPreMove} link set "${name}" netns "${ns}"''
        ++ optional (values.mtu != null) ''${ipPostMove} link set "${name}" mtu ${toString values.mtu}''
        ++ (map (ip: ''${ipPostMove} address add "${ip}" dev "${name}"'') values.ips)
        ++ [
          (concatStringsSep " " (
            [ ''${wg} set "${name}" private-key "${privKey}"'' ]
            ++ optional (values.listenPort != null) ''listen-port "${toString values.listenPort}"''
            ++ optional (values.fwMark != null) ''fwmark "${values.fwMark}"''
          ))
          ''${ipPostMove} link set up dev "${name}"''
          values.postSetup
        ]
      );

      postStop = ''
        ${values.preShutdown}
        ${ipPostMove} link del dev "${name}"
        ${values.postShutdown}
      '';
    };

  nsWrap =
    cmd: src: dst:
    let
      nsList = filter (ns: ns != null) [
        src
        dst
      ];
      ns = last nsList;
    in
    if (length nsList > 0 && ns != "init") then ''ip netns exec "${ns}" "${cmd}"'' else cmd;
in

{

  ###### interface

  options = {
    services.wgvpn = {
      enable = mkOption {
        description = ''
          Whether to enable WireGuard VPN service.
        '';
        type = types.bool;
        default = false;
      };

      networks = mkOption {
        description = ''
          configuraation of the WireGuard networks managed by this services.

          Each network has a hub-and-spoke topology with a single router.
          The router is the only machine that can route to the internet.
          All other machines are clients and can only route to the router.
        '';
        default = { };
        type = with types; attrsOf (submodule networkOpts);
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable (
    let
      all_peers = flatten (
        mapAttrsToList (
          interfaceName: interfaceCfg:
          map (peer: { inherit interfaceName interfaceCfg peer; }) interfaceCfg.peers
        ) cfg.interfaces
      );
    in
    {

      assertions =
        (attrValues (
          mapAttrs (name: value: {
            assertion = (value.privateKey != null) != (value.privateKeyFile != null);
            message = "Either networking.wireguard.interfaces.${name}.privateKey or networking.wireguard.interfaces.${name}.privateKeyFile must be set.";
          }) cfg.interfaces
        ))
        ++ (attrValues (
          mapAttrs (name: value: {
            assertion = value.generatePrivateKeyFile -> (value.privateKey == null);
            message = "networking.wireguard.interfaces.${name}.generatePrivateKeyFile must not be set if networking.wireguard.interfaces.${name}.privateKey is set.";
          }) cfg.interfaces
        ))
        ++ map (
          { interfaceName, peer, ... }:
          {
            assertion = (peer.presharedKey == null) || (peer.presharedKeyFile == null);
            message = "networking.wireguard.interfaces.${interfaceName} peer «${peer.publicKey}» has both presharedKey and presharedKeyFile set, but only one can be used.";
          }
        ) all_peers;

      boot.extraModulePackages = optional (versionOlder kernel.kernel.version "5.6") kernel.wireguard;
      boot.kernelModules = [ "wireguard" ];
      environment.systemPackages = [ pkgs.wireguard-tools ];

      systemd.services =
        (mapAttrs' generateInterfaceUnit cfg.interfaces)
        // (listToAttrs (map generatePeerUnit all_peers))
        // (mapAttrs' generateKeyServiceUnit (
          filterAttrs (name: value: value.generatePrivateKeyFile) cfg.interfaces
        ));

      systemd.targets = mapAttrs' generateInterfaceTarget cfg.interfaces;
    }
  );

}
