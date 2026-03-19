```bash
sudo apt update
```
```bash
sudo apt upgrade
```
```bash
sudo apt install openssh-server
```
```bash
sudo systemctl enable ssh
```
- - -
```md
ssh user@ip
```
- - -
```bash
sudo nano setup.sh
```
```bash
#!/usr/bin/env bash

SERVER_DIR="/mc"
SERVER_NAME="Minecraft Server"
MOTD="Welcome!"
MC_VERSION="latest"
MAX_MEMORY="6G"

ENABLE_SPARK=true
ENABLE_CHUNKY=true
ENABLE_FAWE=true
ENABLE_HORIZONS=true
ENABLE_BLUEMAP=false
ENABLE_PLAN=false

OPT_EIGENCRAFT_REDSTONE=true
OPT_OPTIMIZE_EXPLOSIONS=true
OPT_NETWORK=true
OPT_CHUNK_LOADING=true
OPT_ANTIXRAY_ENGINE1=true

apt update -y
apt install -y ca-certificates curl gnupg lsb-release wget unzip

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p "$SERVER_DIR"

cat > "$SERVER_DIR/docker-compose.yml" <<EOF
version: "3.9"
services:
  mc:
    image: itzg/minecraft-server:latest
    container_name: paper
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: PAPER
      VERSION: "$MC_VERSION"
      MEMORY: "$MAX_MEMORY"
      TZ: "Europe/Berlin"
      MOTD: "$MOTD"
      SERVER_NAME: "$SERVER_NAME"
    volumes:
      - $SERVER_DIR/data:/data
    restart: unless-stopped
EOF

docker compose -f "$SERVER_DIR/docker-compose.yml" up -d
sleep 10

PLUGINS_DIR="$SERVER_DIR/data/plugins"
mkdir -p "$PLUGINS_DIR"
cd "$PLUGINS_DIR"

if [ "$ENABLE_SPARK" = true ]; then
wget -q https://github.com/lucko/spark/releases/latest/download/spark-paper.jar -O Spark.jar
fi

if [ "$ENABLE_CHUNKY" = true ]; then
wget -q https://github.com/pop4959/Chunky/releases/latest/download/Chunky.jar -O Chunky.jar
fi

if [ "$ENABLE_FAWE" = true ]; then
wget -q https://ci.athion.net/job/FastAsyncWorldEdit/lastSuccessfulBuild/artifact/build/libs/FastAsyncWorldEdit-Paper-1.21.jar -O FAWE.jar
fi

if [ "$ENABLE_HORIZONS" = true ]; then
wget -q https://download.luminolmc.com/horizons.jar -O Horizons.jar
fi

if [ "$ENABLE_BLUEMAP" = true ]; then
mkdir -p BlueMap
wget -q https://github.com/BlueMap-Minecraft/BlueMap/releases/latest/download/BlueMap-3.15.jar -O BlueMap.jar
fi

if [ "$ENABLE_PLAN" = true ]; then
wget -q https://github.com/plan-player-analytics/Plan/releases/latest/download/Plan.jar -O Plan.jar
fi

docker restart paper
sleep 5

GLOBAL_CFG="$SERVER_DIR/data/paper-global.yml"
SPIGOT_CFG="$SERVER_DIR/data/spigot.yml"

if [ -f "$GLOBAL_CFG" ]; then

[ "$OPT_EIGENCRAFT_REDSTONE" = true ] && \
sed -i 's/use-faster-eigencraft-redstone: false/use-faster-eigencraft-redstone: true/' "$GLOBAL_CFG"

[ "$OPT_OPTIMIZE_EXPLOSIONS" = true ] && \
sed -i 's/optimize-explosions: false/optimize-explosions: true/' "$GLOBAL_CFG"

[ "$OPT_ANTIXRAY_ENGINE1" = true ] && \
sed -i 's/enabled: false/enabled: true/' "$GLOBAL_CFG" && \
sed -i 's/engine-mode: .*/engine-mode: 1/' "$GLOBAL_CFG"
fi

if [ -f "$SPIGOT_CFG" ]; then
if [ "$OPT_NETWORK" = true ]; then
sed -i 's/bungee-online-mode: true/bungee-online-mode: true/' "$SPIGOT_CFG"
fi
fi

echo "SETUP COMPLETE"
```
```bash
sudo chmod +x setup.sh
```
```bash
sudo ./setup.sh
```
log
```
admfloriank@mc:~$ sudo ./setup.sh
Hit:1 http://de.archive.ubuntu.com/ubuntu noble InRelease
Hit:2 http://de.archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:3 http://de.archive.ubuntu.com/ubuntu noble-backports InRelease
Hit:4 http://security.ubuntu.com/ubuntu noble-security InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
ca-certificates is already the newest version (20240203).
ca-certificates set to manually installed.
curl is already the newest version (8.5.0-2ubuntu10.8).
curl set to manually installed.
gnupg is already the newest version (2.4.4-2ubuntu17.4).
gnupg set to manually installed.
lsb-release is already the newest version (12.0-2).
lsb-release set to manually installed.
wget is already the newest version (1.21.4-1ubuntu4.1).
wget set to manually installed.
Suggested packages:
  zip
The following NEW packages will be installed:
  unzip
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 174 kB of archives.
After this operation, 384 kB of additional disk space will be used.
Get:1 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 unzip amd64 6.0-28ubuntu4.1 [174 kB]
Fetched 174 kB in 0s (1068 kB/s)
debconf: delaying package configuration, since apt-utils is not installed
Selecting previously unselected package unzip.
(Reading database ... 74012 files and directories currently installed.)
Preparing to unpack .../unzip_6.0-28ubuntu4.1_amd64.deb ...
Unpacking unzip (6.0-28ubuntu4.1) ...
Setting up unzip (6.0-28ubuntu4.1) ...
Scanning processes...
Scanning linux images...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
Hit:1 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:2 http://de.archive.ubuntu.com/ubuntu noble InRelease
Get:3 https://download.docker.com/linux/ubuntu noble InRelease [48.5 kB]
Hit:4 http://de.archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:5 http://de.archive.ubuntu.com/ubuntu noble-backports InRelease
Get:6 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages [46.6 kB]
Fetched 95.0 kB in 0s (229 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  docker-buildx-plugin docker-ce-rootless-extras git git-man iptables less liberror-perl libip4tc2 libip6tc2
  libjansson4 libnetfilter-conntrack3 libnfnetlink0 libnftables1 libnftnl11 libslirp0 nftables patch pigz slirp4netns
Suggested packages:
  cgroupfs-mount | cgroup-lite docker-model-plugin git-daemon-run | git-daemon-sysvinit git-doc git-email git-gui gitk
  gitweb git-cvs git-mediawiki git-svn firewalld ed diffutils-doc
The following NEW packages will be installed:
  containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin git
  git-man iptables less liberror-perl libip4tc2 libip6tc2 libjansson4 libnetfilter-conntrack3 libnfnetlink0
  libnftables1 libnftnl11 libslirp0 nftables patch pigz slirp4netns
0 upgraded, 23 newly installed, 0 to remove and 0 not upgraded.
Need to get 103 MB of archives.
After this operation, 422 MB of additional disk space will be used.
Get:1 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libip4tc2 amd64 1.8.10-3ubuntu2 [23.3 kB]
Get:2 https://download.docker.com/linux/ubuntu noble/stable amd64 containerd.io amd64 2.2.1-1~ubuntu.24.04~noble [23.4 MB]
Get:3 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libip6tc2 amd64 1.8.10-3ubuntu2 [23.7 kB]
Get:4 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libnfnetlink0 amd64 1.0.2-2build1 [14.8 kB]
Get:5 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libnetfilter-conntrack3 amd64 1.0.9-6build1 [45.2 kB]
Get:6 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libnftnl11 amd64 1.2.6-2build1 [66.0 kB]
Get:7 http://de.archive.ubuntu.com/ubuntu noble/main amd64 iptables amd64 1.8.10-3ubuntu2 [381 kB]
Get:8 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libjansson4 amd64 2.14-2build2 [32.8 kB]
Get:9 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 libnftables1 amd64 1.0.9-1ubuntu0.1 [359 kB]
Get:10 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 nftables amd64 1.0.9-1ubuntu0.1 [69.8 kB]
Get:11 http://de.archive.ubuntu.com/ubuntu noble/universe amd64 pigz amd64 2.8-1 [65.6 kB]
Get:12 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 less amd64 590-2ubuntu2.1 [142 kB]
Get:13 http://de.archive.ubuntu.com/ubuntu noble/main amd64 liberror-perl all 0.17029-2 [25.6 kB]
Get:14 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 git-man all 1:2.43.0-1ubuntu7.3 [1100 kB]
Get:15 http://de.archive.ubuntu.com/ubuntu noble-updates/main amd64 git amd64 1:2.43.0-1ubuntu7.3 [3680 kB]
Get:16 https://download.docker.com/linux/ubuntu noble/stable amd64 docker-ce-cli amd64 5:29.3.0-1~ubuntu.24.04~noble [16.4 MB]
Get:17 http://de.archive.ubuntu.com/ubuntu noble/main amd64 libslirp0 amd64 4.7.0-1ubuntu3 [63.8 kB]
Get:18 http://de.archive.ubuntu.com/ubuntu noble/main amd64 patch amd64 2.7.6-7build3 [104 kB]
Get:19 http://de.archive.ubuntu.com/ubuntu noble/universe amd64 slirp4netns amd64 1.2.1-1build2 [34.9 kB]
Get:20 https://download.docker.com/linux/ubuntu noble/stable amd64 docker-ce amd64 5:29.3.0-1~ubuntu.24.04~noble [22.6 MB]
Get:21 https://download.docker.com/linux/ubuntu noble/stable amd64 docker-buildx-plugin amd64 0.31.1-1~ubuntu.24.04~noble [20.3 MB]
Get:22 https://download.docker.com/linux/ubuntu noble/stable amd64 docker-ce-rootless-extras amd64 5:29.3.0-1~ubuntu.24.04~noble [6390 kB]
Get:23 https://download.docker.com/linux/ubuntu noble/stable amd64 docker-compose-plugin amd64 5.1.0-1~ubuntu.24.04~noble [7847 kB]
Fetched 103 MB in 2s (58.0 MB/s)
debconf: delaying package configuration, since apt-utils is not installed
Selecting previously unselected package containerd.io.
(Reading database ... 74030 files and directories currently installed.)
Preparing to unpack .../00-containerd.io_2.2.1-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking containerd.io (2.2.1-1~ubuntu.24.04~noble) ...
Selecting previously unselected package docker-ce-cli.
Preparing to unpack .../01-docker-ce-cli_5%3a29.3.0-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking docker-ce-cli (5:29.3.0-1~ubuntu.24.04~noble) ...
Selecting previously unselected package libip4tc2:amd64.
Preparing to unpack .../02-libip4tc2_1.8.10-3ubuntu2_amd64.deb ...
Unpacking libip4tc2:amd64 (1.8.10-3ubuntu2) ...
Selecting previously unselected package libip6tc2:amd64.
Preparing to unpack .../03-libip6tc2_1.8.10-3ubuntu2_amd64.deb ...
Unpacking libip6tc2:amd64 (1.8.10-3ubuntu2) ...
Selecting previously unselected package libnfnetlink0:amd64.
Preparing to unpack .../04-libnfnetlink0_1.0.2-2build1_amd64.deb ...
Unpacking libnfnetlink0:amd64 (1.0.2-2build1) ...
Selecting previously unselected package libnetfilter-conntrack3:amd64.
Preparing to unpack .../05-libnetfilter-conntrack3_1.0.9-6build1_amd64.deb ...
Unpacking libnetfilter-conntrack3:amd64 (1.0.9-6build1) ...
Selecting previously unselected package libnftnl11:amd64.
Preparing to unpack .../06-libnftnl11_1.2.6-2build1_amd64.deb ...
Unpacking libnftnl11:amd64 (1.2.6-2build1) ...
Selecting previously unselected package iptables.
Preparing to unpack .../07-iptables_1.8.10-3ubuntu2_amd64.deb ...
Unpacking iptables (1.8.10-3ubuntu2) ...
Selecting previously unselected package libjansson4:amd64.
Preparing to unpack .../08-libjansson4_2.14-2build2_amd64.deb ...
Unpacking libjansson4:amd64 (2.14-2build2) ...
Selecting previously unselected package libnftables1:amd64.
Preparing to unpack .../09-libnftables1_1.0.9-1ubuntu0.1_amd64.deb ...
Unpacking libnftables1:amd64 (1.0.9-1ubuntu0.1) ...
Selecting previously unselected package nftables.
Preparing to unpack .../10-nftables_1.0.9-1ubuntu0.1_amd64.deb ...
Unpacking nftables (1.0.9-1ubuntu0.1) ...
Selecting previously unselected package docker-ce.
Preparing to unpack .../11-docker-ce_5%3a29.3.0-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking docker-ce (5:29.3.0-1~ubuntu.24.04~noble) ...
Selecting previously unselected package pigz.
Preparing to unpack .../12-pigz_2.8-1_amd64.deb ...
Unpacking pigz (2.8-1) ...
Selecting previously unselected package less.
Preparing to unpack .../13-less_590-2ubuntu2.1_amd64.deb ...
Unpacking less (590-2ubuntu2.1) ...
Selecting previously unselected package docker-buildx-plugin.
Preparing to unpack .../14-docker-buildx-plugin_0.31.1-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking docker-buildx-plugin (0.31.1-1~ubuntu.24.04~noble) ...
Selecting previously unselected package docker-ce-rootless-extras.
Preparing to unpack .../15-docker-ce-rootless-extras_5%3a29.3.0-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking docker-ce-rootless-extras (5:29.3.0-1~ubuntu.24.04~noble) ...
Selecting previously unselected package docker-compose-plugin.
Preparing to unpack .../16-docker-compose-plugin_5.1.0-1~ubuntu.24.04~noble_amd64.deb ...
Unpacking docker-compose-plugin (5.1.0-1~ubuntu.24.04~noble) ...
Selecting previously unselected package liberror-perl.
Preparing to unpack .../17-liberror-perl_0.17029-2_all.deb ...
Unpacking liberror-perl (0.17029-2) ...
Selecting previously unselected package git-man.
Preparing to unpack .../18-git-man_1%3a2.43.0-1ubuntu7.3_all.deb ...
Unpacking git-man (1:2.43.0-1ubuntu7.3) ...
Selecting previously unselected package git.
Preparing to unpack .../19-git_1%3a2.43.0-1ubuntu7.3_amd64.deb ...
Unpacking git (1:2.43.0-1ubuntu7.3) ...
Selecting previously unselected package libslirp0:amd64.
Preparing to unpack .../20-libslirp0_4.7.0-1ubuntu3_amd64.deb ...
Unpacking libslirp0:amd64 (4.7.0-1ubuntu3) ...
Selecting previously unselected package patch.
Preparing to unpack .../21-patch_2.7.6-7build3_amd64.deb ...
Unpacking patch (2.7.6-7build3) ...
Selecting previously unselected package slirp4netns.
Preparing to unpack .../22-slirp4netns_1.2.1-1build2_amd64.deb ...
Unpacking slirp4netns (1.2.1-1build2) ...
Setting up libip4tc2:amd64 (1.8.10-3ubuntu2) ...
Setting up libip6tc2:amd64 (1.8.10-3ubuntu2) ...
Setting up less (590-2ubuntu2.1) ...
Setting up libnftnl11:amd64 (1.2.6-2build1) ...
Setting up libjansson4:amd64 (2.14-2build2) ...
Setting up liberror-perl (0.17029-2) ...
Setting up docker-buildx-plugin (0.31.1-1~ubuntu.24.04~noble) ...
Setting up containerd.io (2.2.1-1~ubuntu.24.04~noble) ...
Created symlink /etc/systemd/system/multi-user.target.wants/containerd.service → /usr/lib/systemd/system/containerd.service.
Setting up patch (2.7.6-7build3) ...
Setting up docker-compose-plugin (5.1.0-1~ubuntu.24.04~noble) ...
Setting up docker-ce-cli (5:29.3.0-1~ubuntu.24.04~noble) ...
Setting up libslirp0:amd64 (4.7.0-1ubuntu3) ...
Setting up pigz (2.8-1) ...
Setting up libnfnetlink0:amd64 (1.0.2-2build1) ...
Setting up git-man (1:2.43.0-1ubuntu7.3) ...
Setting up docker-ce-rootless-extras (5:29.3.0-1~ubuntu.24.04~noble) ...
Setting up libnftables1:amd64 (1.0.9-1ubuntu0.1) ...
Setting up nftables (1.0.9-1ubuntu0.1) ...
Setting up slirp4netns (1.2.1-1build2) ...
Setting up git (1:2.43.0-1ubuntu7.3) ...
Setting up libnetfilter-conntrack3:amd64 (1.0.9-6build1) ...
Setting up iptables (1.8.10-3ubuntu2) ...
update-alternatives: using /usr/sbin/iptables-legacy to provide /usr/sbin/iptables (iptables) in auto mode
update-alternatives: using /usr/sbin/ip6tables-legacy to provide /usr/sbin/ip6tables (ip6tables) in auto mode
update-alternatives: using /usr/sbin/iptables-nft to provide /usr/sbin/iptables (iptables) in auto mode
update-alternatives: using /usr/sbin/ip6tables-nft to provide /usr/sbin/ip6tables (ip6tables) in auto mode
update-alternatives: using /usr/sbin/arptables-nft to provide /usr/sbin/arptables (arptables) in auto mode
update-alternatives: using /usr/sbin/ebtables-nft to provide /usr/sbin/ebtables (ebtables) in auto mode
Setting up docker-ce (5:29.3.0-1~ubuntu.24.04~noble) ...
Created symlink /etc/systemd/system/multi-user.target.wants/docker.service → /usr/lib/systemd/system/docker.service.
Created symlink /etc/systemd/system/sockets.target.wants/docker.socket → /usr/lib/systemd/system/docker.socket.
Processing triggers for libc-bin (2.39-0ubuntu8.7) ...
Scanning processes...
Scanning linux images...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
WARN[0000] /mc/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
[+] up 27/27
 ✔ Image itzg/minecraft-server:latest Pulled                                                                       17.3s
 ✔ Network mc_default                 Created                                                                      0.0s
 ✔ Container paper                    Started                                                                      4.0s
paper
SETUP COMPLETE
admfloriank@mc:~$
```
```
sudo docker restart paper && clear && sudo docker ps && sudo docker logs paper | head -n 40
```
output
```
CONTAINER ID   IMAGE                          COMMAND                  CREATED         STATUS                                     PORTS                                             NAMES
fffcf871b15a   itzg/minecraft-server:latest   "/image/scripts/start"   7 minutes ago   Up Less than a second (health: starting)   0.0.0.0:25565->25565/tcp, [::]:25565->25565/tcp   paper
[init] Changing ownership of /data to 1000 ...
[init] Running as uid=1000 gid=1000 with /data as 'drwxr-xr-x 2 1000 1000 4096 Mar 12 08:30 /data'
[init] Image info: buildtime=2026-03-11T03:23:25.192Z,version=java25,revision=9c9a3a8b43944dd245556f0cbaefab680ad75022
[init] Resolving type given PAPER
[mc-image-helper] 08:30:26.150 INFO  : Downloaded /data/paper-1.21.11-127.jar
[init] Copying any plugins from /plugins to /data/plugins
[init] Copying any configs from /config to /data/config
[init] Creating server properties in /data/server.properties
[init] Disabling whitelist functionality
[mc-image-helper] 08:30:30.858 INFO  : Created/updated 6 properties in /data/server.properties
[mc-image-helper] 08:30:33.758 INFO  : Downloaded /data/config/paper-world-defaults.yml from https://raw.githubusercontent.com/Shonz1/minecraft-default-configs/main/1.21.11/paper-world-defaults.yml
[mc-image-helper] 08:30:33.758 INFO  : Downloaded /data/config/paper-global.yml from https://raw.githubusercontent.com/Shonz1/minecraft-default-configs/main/1.21.11/paper-global.yml
[mc-image-helper] 08:30:36.931 INFO  : Downloaded /data/bukkit.yml from https://raw.githubusercontent.com/Shonz1/minecraft-default-configs/main/1.21.11/bukkit.yml
[mc-image-helper] 08:30:36.931 INFO  : Downloaded /data/spigot.yml from https://raw.githubusercontent.com/Shonz1/minecraft-default-configs/main/1.21.11/spigot.yml
[init] Setting initial memory to 6G and max to 6G
[init] Starting the Minecraft server...
Downloading mojang_1.21.11.jar
[init] Running as uid=1000 gid=1000 with /data as 'drwxr-xr-x 6 1000 1000 4096 Mar 12 08:30 /data'
[init] Image info: buildtime=2026-03-11T03:23:25.192Z,version=java25,revision=9c9a3a8b43944dd245556f0cbaefab680ad75022
[init] Resolving type given PAPER
[init] Copying any plugins from /plugins to /data/plugins
[init] Copying any configs from /config to /data/config
[mc-image-helper] 08:30:50.670 INFO  : Created/updated 1 property in /data/server.properties
[init] Setting initial memory to 6G and max to 6G
[init] Starting the Minecraft server...
Applying patches
Starting org.bukkit.craftbukkit.Main
[08:31:03 INFO]: [bootstrap] Running Java 25 (OpenJDK 64-Bit Server VM 25.0.2+10-LTS; Eclipse Adoptium Temurin-25.0.2+10) on Linux 6.8.0-101-generic (amd64)
[08:31:03 INFO]: [bootstrap] Loading Paper 1.21.11-127-main@bd74bf6 (2026-03-10T02:55:23Z) for Minecraft 1.21.11
[08:31:03 INFO]: [PluginInitializerManager] Initializing plugins...
[08:31:03 ERROR]: [PluginRemapper] Encountered exception remapping plugins
java.util.concurrent.CompletionException: java.lang.RuntimeException: Failed to open plugin jar plugins/Spark.jar
        at java.base/java.util.concurrent.CompletableFuture.wrapInCompletionException(Unknown Source) ~[?:?]
        at java.base/java.util.concurrent.CompletableFuture.reportJoin(Unknown Source) ~[?:?]
        at java.base/java.util.concurrent.CompletableFuture.join(Unknown Source) ~[?:?]
        at io.papermc.paper.pluginremap.PluginRemapper.waitForAll(PluginRemapper.java:414) ~[paper-1.21.11.jar:1.21.11-127-bd74bf6]
        at io.papermc.paper.pluginremap.PluginRemapper.rewritePluginDirectory(PluginRemapper.java:210) ~[paper-1.21.11.jar:1.21.11-127-bd74bf6]
        at io.papermc.paper.plugin.provider.source.DirectoryProviderSource.prepareContext(DirectoryProviderSource.java:53) ~[paper-1.21.11.jar:1.21.11-127-bd74bf6]
        at io.papermc.paper.plugin.provider.source.DirectoryProviderSource.prepareContext(DirectoryProviderSource.java:17) ~[paper-1.21.11.jar:1.21.11-127-bd74bf6]
        at io.papermc.paper.plugin.util.EntrypointUtil.registerProvidersFromSource(EntrypointUtil.java:14) ~[paper-1.21.11.jar:1.21.11-127-bd74bf6]
2026-03-12T07:31:02.869323188Z ServerMain WARN Advanced terminal features are not available in this environment
admfloriank@mc:~$
```
wie nun vpn machen (installiren) das für anwendung geeignet?
```
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SERVER_DIR="/mc"
SERVER_NAME="Minecraft Server"
MOTD="Welcome!"
MC_VERSION="latest"
MAX_MEMORY="6G"

ENABLE_SPARK=true
ENABLE_CHUNKY=true
ENABLE_FAWE=true
ENABLE_HORIZONS=true
ENABLE_BLUEMAP=false
ENABLE_PLAN=false

ENABLE_TAILSCALE=true
TAILSCALE_AUTHKEY=""
TAILSCALE_HOSTNAME="mc-server"

OPT_EIGENCRAFT_REDSTONE=true
OPT_OPTIMIZE_EXPLOSIONS=true
OPT_NETWORK=true
OPT_CHUNK_LOADING=true
OPT_ANTIXRAY_ENGINE1=true

echo "Updating base system packages (quiet)..."
apt-get update -y -qq >/dev/null
apt-get install -y -qq ca-certificates curl gnupg lsb-release wget unzip >/dev/null

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update -y -qq >/dev/null
fi

echo "Installing Docker (quiet)..."
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null

mkdir -p "$SERVER_DIR"

cat > "$SERVER_DIR/docker-compose.yml" <<EOF
services:
  mc:
    image: itzg/minecraft-server:latest
    container_name: paper
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: PAPER
      VERSION: "$MC_VERSION"
      MEMORY: "$MAX_MEMORY"
      TZ: "Europe/Berlin"
      MOTD: "$MOTD"
      SERVER_NAME: "$SERVER_NAME"
    volumes:
      - $SERVER_DIR/data:/data
    restart: unless-stopped
EOF

echo "Starting Minecraft container..."
docker compose -f "$SERVER_DIR/docker-compose.yml" up -d

echo "Waiting for initial server setup..."
sleep 20

PLUGINS_DIR="$SERVER_DIR/data/plugins"
mkdir -p "$PLUGINS_DIR"
cd "$PLUGINS_DIR"

if [ "$ENABLE_SPARK" = true ]; then
  wget -q https://github.com/lucko/spark/releases/latest/download/spark-paper.jar -O Spark.jar
fi

if [ "$ENABLE_CHUNKY" = true ]; then
  wget -q https://github.com/pop4959/Chunky/releases/latest/download/Chunky.jar -O Chunky.jar
fi

if [ "$ENABLE_FAWE" = true ]; then
  wget -q https://ci.athion.net/job/FastAsyncWorldEdit/lastSuccessfulBuild/artifact/build/libs/FastAsyncWorldEdit-Paper-1.21.jar -O FAWE.jar
fi

if [ "$ENABLE_HORIZONS" = true ]; then
  wget -q https://download.luminolmc.com/horizons.jar -O Horizons.jar
fi

if [ "$ENABLE_BLUEMAP" = true ]; then
  mkdir -p BlueMap
  wget -q https://github.com/BlueMap-Minecraft/BlueMap/releases/latest/download/BlueMap-3.15.jar -O BlueMap.jar
fi

if [ "$ENABLE_PLAN" = true ]; then
  wget -q https://github.com/plan-player-analytics/Plan/releases/latest/download/Plan.jar -O Plan.jar
fi

GLOBAL_CFG="$SERVER_DIR/data/config/paper-global.yml"
SPIGOT_CFG="$SERVER_DIR/data/spigot.yml"

if [ -f "$GLOBAL_CFG" ]; then
  if [ "$OPT_EIGENCRAFT_REDSTONE" = true ]; then
    sed -i 's/use-faster-eigencraft-redstone: false/use-faster-eigencraft-redstone: true/' "$GLOBAL_CFG" || true
  fi

  if [ "$OPT_OPTIMIZE_EXPLOSIONS" = true ]; then
    sed -i 's/optimize-explosions: false/optimize-explosions: true/' "$GLOBAL_CFG" || true
  fi

  if [ "$OPT_ANTIXRAY_ENGINE1" = true ]; then
    sed -i 's/enabled: false/enabled: true/' "$GLOBAL_CFG" || true
    sed -i 's/engine-mode: .*/engine-mode: 1/' "$GLOBAL_CFG" || true
  fi
fi

# Netzwerk-Optimierung an dieser Stelle aktuell bewusst NICHT automatisch geändert,
# da das u.U. Security-relevant ist (bungee-online-mode/online-mode).
# Block bleibt als Schalter erhalten, aber ohne destructive Änderung.
if [ -f "$SPIGOT_CFG" ] && [ "$OPT_NETWORK" = true ]; then
  : # Platzhalter, falls du später gezielt Netzwerk-Settings einfügst
fi

if [ "$ENABLE_TAILSCALE" = true ]; then
  echo "Installing Tailscale (quiet)..."
  curl -fsSL https://tailscale.com/install.sh | sh >/tmp/tailscale-install.log 2>&1 || {
    echo "Tailscale installation failed, see /tmp/tailscale-install.log"
  }
  systemctl enable --now tailscaled >/dev/null 2>&1 || true

  if [ -n "$TAILSCALE_AUTHKEY" ]; then
    tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TAILSCALE_HOSTNAME" --ssh --accept-routes --accept-dns=false >/tmp/tailscale-up.log 2>&1 || {
      echo "Tailscale up failed, see /tmp/tailscale-up.log"
    }
    echo "Tailscale is up and connected."
  else
    echo "Tailscale installed. Run 'sudo tailscale up' manually to connect this server."
  fi
fi

echo "Restarting Minecraft container with plugins and config tweaks..."
docker restart paper >/dev/null

echo
echo "SETUP COMPLETE"
echo
echo "Docker container 'paper' status:"
docker ps --filter "name=paper" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo
echo "First 40 log lines from 'paper':"
docker logs paper | head -n 40
```
