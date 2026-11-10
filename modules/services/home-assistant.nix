{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.home-assistant;
  cfg-svc = config.polaris.services;
  hass = config.services.home-assistant;
  idp = libx.idp {
    inherit (cfg-svc.kanidm) domain;
    inherit (cfg) client_id;
  };
  catppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "home-assistant";
    tag = "v2.1.3";
    hash = "sha256-+m6lWer9a4AwmTgckhSHOKd0Oo6x9N0jjza4/F0ye3E=";
  };
in
{
  options.polaris.services.home-assistant = {
    enable = lib.mkEnableOption "home assistant";
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ass.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant.polaris";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 8123;
    };
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };
    matter = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 5580;
      };
      threadRadio = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "serial device of a radio running openthread rcp firmware";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      package =
        (pkgs.home-assistant.override {
          packageOverrides = _: super: {
            # XXX: mtls endpoint mock tests fail
            google-cloud-texttospeech = super.google-cloud-texttospeech.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "get_mtls_endpoint_and_cert_source" ];
            });
          };
        }).overrideAttrs
          { doInstallCheck = false; }; # (same as the module default)
      extraComponents = [
        "default_config"
        "prometheus"
        "met"
        "esphome"
        "radio_browser"
        # zigbee via the official HA dongles (ZBT-1 / ZBT-2)
        "zha"
        "homeassistant_sky_connect"
        "homeassistant_connect_zbt2"
        # matter / thread
        "matter"
        "thread"
        "otbr"
        # generic
        "mqtt"
        "homekit_controller"
        "upnp"
        "dlna_dmr"
        "ffmpeg"
        # helpers / building blocks (the dependency-free ones like template, tod, moon work regardless)
        "local_calendar"
        "local_todo"
        "workday"
        "holiday"
        "season"
        "utility_meter"
        "rest"
        "command_line"
        "scrape"
        "sql"
        "feedreader"
        "generic" # generic/rtsp cameras
        "wake_on_lan"
        "ping"
        # presence / ble
        "bthome"
        "private_ble_device"
        # local voice (whisper/piper/openwakeword)
        "wyoming"
        # weather (nl)
        "buienradar"
        # monitoring
        "gatus"
        "version"
        "systemmonitor"
        "fastdotcom"
        "tailscale"
        "github"
        # self-hosted services
        "nextcloud"
        "caldav"
        "webdav" # backup target
        "immich"
        "paperless_ngx"
        "ntfy"
        # lights
        "hue"
        "tradfri"
        "lifx"
        "nanoleaf"
        "wiz"
        "wled"
        "yeelight"
        "govee_light_local"
        # plugs/switches/sensors
        "tplink"
        "shelly"
        "tuya"
        "switchbot"
        "broadlink"
        "unifi"
        "unifiprotect"
        "unifi_access"
        # "xiaomi_miio"
        "xiaomi_ble"
        "ibeacon"
        # media
        "cast"
        "spotify"
        "apple_tv"
        "androidtv_remote"
        "androidtv" # adb/fire tv
        "nfandroidtv" # notifications
        # android
        "android_ip_webcam"
        "samsungtv"
        "webostv"
        # transport
        "nederlandse_spoorwegen"
        # appliances
        "smartthings"
        "ipp"
        "brother"
        # google
        "google_assistant"
        "google_assistant_sdk"
        "nest"
        "google"
        "google_tasks"
        "google_health"
        "google_drive"
        "google_photos"
        "google_mail"
        "google_translate"
        "google_generative_ai_conversation"
        "google_sheets"
        "google_cloud" # tts/stt
        "google_air_quality"
        "google_weather"
        "google_travel_time"
        "youtube"
        # ai
        "anthropic"
        "mcp_server"
        "mcp"
      ];
      # faster zlib for aiohttp
      extraPackages =
        ps: with ps; [
          zlib-ng
          isal
        ];
      customComponents = [
        pkgs.home-assistant-custom-components.auth_oidc
        pkgs.home-assistant-custom-components.scene_presets
        # ikea bilresa
        (pkgs.buildHomeAssistantComponent rec {
          owner = "Vituhlos";
          domain = "ikea_bilresa";
          version = "0.6.1";
          src = pkgs.fetchFromGitHub {
            inherit owner;
            repo = "ha-ikea-bilresa";
            tag = "v${version}";
            hash = "sha256-NEZrbT4AJQnp3QD/nYor0YA+hE8CdIUu+VKxXExTbzQ=";
          };
        })
        # XXX: backport of the 2026.11 tailscale integration
        # drop once nixpkgs has home-assistant >= 2026.11 (NixOS/nixpkgs#583840)
        (pkgs.buildHomeAssistantComponent rec {
          owner = "home-assistant";
          domain = "tailscale";
          version = "2026.11.1";
          src = pkgs.fetchFromGitHub {
            inherit owner;
            repo = "core";
            tag = version;
            sparseCheckout = [ "homeassistant/components/tailscale" ];
            hash = "sha256-WjLkobiOM11UQEtasLo82yQig3t+HJxj+bqzWZE7tRY=";
          };
          sourceRoot = "${src.name}/homeassistant/components/tailscale";
          dependencies = [ pkgs.home-assistant.python3Packages.tailscale ];
          nativeBuildInputs = [ pkgs.jq ];
          postPatch = ''
            # 2026.11 setup/unload return None (and use the new *_or_raise helper), 2026.10 wants a bool
            substituteInPlace __init__.py \
              --replace-fail "    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)" \
                             "    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
                return True" \
              --replace-fail "await hass.config_entries.async_unload_platforms_or_raise(entry, PLATFORMS)" \
                             "return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)"
            jq '. + {version: "${version}"}' manifest.json > m && mv m manifest.json
            mkdir translations
            jq '.config.step |= (.user.data |= (del(.api_key) + {oauth_client_id: "OAuth client ID", oauth_client_secret: "OAuth client secret"})
                               | .reauth_confirm.data |= (del(.api_key) + {oauth_client_id: "OAuth client ID", oauth_client_secret: "OAuth client secret"}))' \
              ${pkgs.home-assistant}/${pkgs.home-assistant.python3Packages.python.sitePackages}/homeassistant/components/tailscale/translations/en.json \
              > translations/en.json
          '';
        })
      ];
      config = {
        homeassistant = {
          auth_providers = [ ]; # nuke passwd
          time_zone = lib.mkForce null;
        };
        default_config = { };
        frontend.themes = "!include_dir_merge_named themes";
        prometheus.requires_auth = true;
        # XXX: http settings wont actually be respected, except first launch
        # womp womp
        http = {
          server_host = [
            "0.0.0.0"
            "::"
          ];
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = [
            "127.0.0.1"
            "::1"
          ]
          ++ lib.concatMap (
            host:
            lib.optionals (host ? internal) [
              host.internal.ipv4
              host.internal.ipv6
            ]
          ) (lib.attrValues config.polaris.hosts);
          ip_ban_enabled = true;
          login_attempts_threshold = 5;
        };
        auth_oidc = {
          inherit (cfg) client_id;
          client_secret = "!secret oidc_client_secret";
          discovery_url = idp.oidc_discovery;
          display_name = "Kanidm";
          id_token_signing_alg = "ES256";
          features = {
            automatic_person_creation = true;
            force_https = true;
          };
          roles = {
            user = "home-assistant.access@${cfg-svc.kanidm.domain}";
            admin = "home-assistant.admin@${cfg-svc.kanidm.domain}";
          };
        };
        # allow managing these from the ui
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };

    systemd.services.home-assistant.path = [
      pkgs.openssl
    ];
    systemd.services.home-assistant.preStart = lib.mkAfter ''
      # set default external_url and locale
      #
      f=${hass.configDir}/.storage/core.config
      if [ -f "$f" ]; then
        ${lib.getExe pkgs.jq} --arg url "https://${cfg.domain}" '
          .data.external_url = $url
          | .data.language = "en-GB"
          | .data.unit_system_v2 = "metric"
          | .data.currency = "EUR"
        ' "$f" > "$f.tmp"
        chmod 600 "$f.tmp"
        mv "$f.tmp" "$f"
      fi

      # seed a long-lived access token for prometheus into the auth store
      #
      f=${hass.configDir}/.storage/auth
      id=prometheus
      [ -f "$f" ] || echo '{"version":1,"minor_version":1,"key":"auth","data":{"users":[],"groups":[],"credentials":[],"refresh_tokens":[]}}' > "$f"
      key=$(cat ${config.sops.secrets."home-assistant/metricsJwtKey".path})
      ${lib.getExe pkgs.jq} --arg id "$id" --arg key "$key" --arg token "$(openssl rand -hex 64)" --arg now "$(date -Iseconds)" '
        .data.users |= map(select(.id != $id)) + [{
          id: $id, name: "Prometheus", group_ids: ["system-read-only"],
          is_owner: false, is_active: true, system_generated: true, local_only: false
        }]
        | .data.refresh_tokens |= map(select(.id != $id)) + [{
          id: $id, user_id: $id, client_id: null, client_name: "Prometheus", client_icon: null,
          token_type: "long_lived_access_token", created_at: $now, access_token_expiration: 315360000,
          token: $token, jwt_key: $key, last_used_at: null, last_used_ip: null, expire_at: null, credential_id: null
        }]
      ' "$f" > "$f.tmp"
      chmod 600 "$f.tmp"
      mv "$f.tmp" "$f"

      # apply the declarative credentials
      # (see sops.templates."home-assistant.credentials.json")
      g=${config.sops.templates."home-assistant.credentials.json".path}
      f=${hass.configDir}/.storage/application_credentials
      [ -f "$f" ] || echo '{"version":1,"minor_version":1,"key":"application_credentials","data":{"items":[]}}' > "$f"
      # (same id as the ui creates, so existing config entries' auth_implementation keeps matching)
      ${lib.getExe pkgs.jq} --slurpfile g "$g" '
        def cred_id: (.domain + "." + .client_id) | ascii_downcase | gsub("[^a-z0-9]+"; "_") | ltrimstr("_") | rtrimstr("_");
        ($g[0].application_credentials | map(. + {id: cred_id})) as $creds
        | .data.items |= (map(select(.id as $id | $creds | map(.id) | index($id) | not)) + $creds)
      ' "$f" > "$f.tmp"
      chmod 600 "$f.tmp"
      mv "$f.tmp" "$f"
      f=${hass.configDir}/.storage/core.config_entries
      if [ -f "$f" ]; then
        ${lib.getExe pkgs.jq} --slurpfile g "$g" '
          $g[0].config_entries as $ce
          | .data.entries |= map(if $ce[.domain] then .data += $ce[.domain] else . end)
        ' "$f" > "$f.tmp"
        chmod 600 "$f.tmp"
        mv "$f.tmp" "$f"
      fi

      # default every user's profile to en-GB with a 24h clock
      # (only fields the user hasn't picked themselves; the frontend applies each field separately)
      for id in $(${lib.getExe pkgs.jq} -r '.data.users[] | select((.system_generated | not) and .is_active) | .id' ${hass.configDir}/.storage/auth); do
        u=${hass.configDir}/.storage/frontend.user_data_$id
        [ -f "$u" ] || echo "{\"version\":1,\"minor_version\":1,\"key\":\"frontend.user_data_$id\",\"data\":{}}" > "$u"
        ${lib.getExe pkgs.jq} '
          .data.language = ((.data.language // {})
            | if (.language // "") == "" then .language = "en-GB" else . end
            | if (.time_format // "language") == "language" then .time_format = "24" else . end)
        ' "$u" > "$u.tmp"
        chmod 600 "$u.tmp"
        mv "$u.tmp" "$u"
      done
    '';

    # required by the matter integration (ws://localhost:<matter.port>/ws)
    services.matterjs-server = {
      enable = true;
      port = cfg.matter.port;
    };

    # thread border router, required by the otbr integration (http://127.0.0.1:8081)
    services.openthread-border-router = lib.mkIf (cfg.matter.threadRadio != null) {
      enable = true;
      backboneInterfaces = [
        cfg.lanInterface
      ];
      radio = {
        device = cfg.matter.threadRadio;
        baudRate = 460800; # (zbt-1 openthread rcp firmware)
        flowControl = true;
      };
    };

    # route between lan and thread mesh
    networking.firewall.extraForwardRules =
      let
        wpan = config.services.openthread-border-router.interfaceName;
      in
      lib.mkIf (cfg.matter.threadRadio != null) ''
        iifname "${cfg.lanInterface}" oifname "${wpan}" accept
        iifname "${wpan}" oifname "${cfg.lanInterface}" accept
      '';

    # let thread devices reach the matter controller
    networking.firewall.interfaces.${config.services.openthread-border-router.interfaceName} =
      lib.mkIf (cfg.matter.threadRadio != null)
        {
          allowedUDPPortRanges = [
            {
              from = 1024;
              to = 65535;
            }
          ];
        };

    networking.firewall.interfaces.${cfg.lanInterface} = {
      allowedUDPPorts = [
        # mdns, used for local discovery (hue, cast, homekit, matter, etc.)
        5353
      ];
      allowedTCPPorts = [
        # direct lan accesss
        cfg.port
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${hass.configDir}/.storage 0700 hass hass - -"
      "f ${hass.configDir}/.storage/onboarding 0600 hass hass - ${
        builtins.toJSON {
          version = 4;
          minor_version = 1;
          key = "onboarding";
          data.done = [
            "user"
            "core_config"
            "analytics"
            "integration"
          ];
        }
      }"
      "f ${hass.configDir}/automations.yaml 0644 hass hass - []"
      "f ${hass.configDir}/scenes.yaml 0644 hass hass - []"
      "f ${hass.configDir}/scripts.yaml 0644 hass hass - {}"
      # themes (see frontend.themes)
      "d ${hass.configDir}/themes 0755 hass hass - -"
      "L+ ${hass.configDir}/themes/catppuccin.yaml - - - - ${catppuccin}/themes/catppuccin.yaml"
    ];

    # confgure caddy
    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      listenAddresses = config.polaris.services.caddy.internalListenAddresses;
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        respond /api/prometheus* 404
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    # metricsToken: a jwt signed with metricsJwtKey, with iss = "prometheus"
    polaris.services.monitoring.exports.home-assistant = {
      inherit (cfg) port;
      path = "/api/prometheus";
      bearerTokenSecret = "home-assistant/metricsToken";
    };

    sops = {
      secrets = {
        "home-assistant/metricsJwtKey" = {
          owner = "hass";
          restartUnits = [ "home-assistant.service" ];
        };
        "home-assistant/clientSecret" = { };

        # integration credentials (see home-assistant.credentials.json)
        "home-assistant/google/healthClientId" = { };
        "home-assistant/google/healthClientSecret" = { };
        "home-assistant/google/assistantSdkClientId" = { };
        "home-assistant/google/assistantSdkClientSecret" = { };
        "home-assistant/google/geminiApiKey" = { };
        "home-assistant/google/mapsApiKey" = { }; # maps platform (weather, air quality)
        "home-assistant/tailscale/oauthClientId" = { };
        "home-assistant/tailscale/oauthClientSecret" = { };
      };

      templates."home-assistant.secrets.yaml" = {
        path = "${hass.configDir}/secrets.yaml";
        owner = "hass";
        group = "hass";
        mode = "0400";
        content = ''
          oidc_client_secret: "${config.sops.placeholder."home-assistant/clientSecret"}"
        '';
      };

      # applied to .storage in preStart
      templates."home-assistant.credentials.json" = {
        owner = "hass";
        group = "hass";
        mode = "0400";
        restartUnits = [ "home-assistant.service" ];
        content =
          let
            p = s: config.sops.placeholder."home-assistant/${s}";
          in
          builtins.toJSON {
            # oauth clients (settings -> application credentials)
            application_credentials = [
              {
                domain = "google_health";
                name = "Home Assistant Client";
                client_id = p "google/healthClientId";
                client_secret = p "google/healthClientSecret";
              }
              {
                domain = "google_assistant_sdk";
                name = "Google Assistant";
                client_id = p "google/assistantSdkClientId";
                client_secret = p "google/assistantSdkClientSecret";
              }
            ];
            # data fields merged into *existing* config entries of these domains
            config_entries = {
              google_generative_ai_conversation.api_key = p "google/geminiApiKey";
              google_weather.api_key = p "google/mapsApiKey";
              google_air_quality.api_key = p "google/mapsApiKey";
              tailscale = {
                oauth_client_id = p "tailscale/oauthClientId";
                oauth_client_secret = p "tailscale/oauthClientSecret";
              };
            };
          };
      };
    };
  };
}
