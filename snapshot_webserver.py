#!/usr/bin/env python3
import os
import stat
import subprocess
import base64
import pwd
import grp
from pathlib import Path
from typing import List, Dict, Set

# -----------------------------
# Hilfsfunktionen
# -----------------------------

def run(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def sh_quote(path: str) -> str:
    """
    Shell-sichere Single-Quote-Notation.
    """
    return "'" + path.replace("'", "'\"'\"'") + "'"

def detect_installed_packages() -> Set[str]:
    """
    Liest alle installierten Pakete und filtert die relevanten Web-/PHP-Pakete heraus.
    Apache2 wird immer mit aufgenommen.
    """
    pkgs = set()

    # Apache ist Pflicht
    pkgs.add("apache2")

    try:
        res = run(["dpkg-query", "-f", "${binary:Package}\n", "-W"], check=True)
        lines = res.stdout.splitlines()
    except Exception as e:
        print(f"[WARN] Konnte dpkg-query nicht ausführen: {e}")
        return pkgs

    prefixes = [
        "apache2",
        "libapache2-mod",
        "php",
        "php-",
        "php8",
        "php7",
    ]

    for name in lines:
        name = name.strip()
        if not name:
            continue
        for p in prefixes:
            if name.startswith(p):
                pkgs.add(name)
                break

    return pkgs

def detect_document_roots() -> List[str]:
    """
    Versucht DocumentRoots aus Apache-Konfiguration zu ermitteln.
    Fallback: /var/www/html
    """
    roots: Set[str] = set()

    # 1) Versuche, sites-enabled zu parsen
    sites_dir = Path("/etc/apache2/sites-enabled")
    if sites_dir.is_dir():
        for conf in sites_dir.glob("*.conf"):
            try:
                with conf.open("r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        if line.lower().startswith("documentroot"):
                            parts = line.split(None, 1)
                            if len(parts) == 2:
                                root = parts[1].strip('"').strip("'")
                                if root:
                                    roots.add(os.path.abspath(root))
            except Exception as e:
                print(f"[WARN] Konnte {conf} nicht lesen: {e}")

    # Fallback
    if not roots:
        roots.add("/var/www/html")

    return sorted(roots)

def collect_file_info(docroots: List[str]) -> Dict[str, Dict]:
    """
    Läuft rekursiv über alle DocRoots und sammelt Informationen
    zu Dateien und Verzeichnissen.
    """
    files: Dict[str, Dict] = {}
    dirs: Dict[str, Dict] = {}

    for root in docroots:
        root_path = Path(root)
        if not root_path.exists():
            print(f"[WARN] DocumentRoot {root} existiert nicht, wird übersprungen.")
            continue

        for dirpath, dirnames, filenames in os.walk(root):
            # Verzeichnis-Infos
            st = os.stat(dirpath)
            mode = stat.S_IMODE(st.st_mode)
            try:
                user = pwd.getpwuid(st.st_uid).pw_name
            except KeyError:
                user = str(st.st_uid)
            try:
                group = grp.getgrgid(st.st_gid).gr_name
            except KeyError:
                group = str(st.st_gid)

            dirs[dirpath] = {
                "mode": mode,
                "user": user,
                "group": group,
            }

            # Datei-Infos
            for fname in filenames:
                fpath = os.path.join(dirpath, fname)
                try:
                    stf = os.stat(fpath)
                except FileNotFoundError:
                    continue

                if not stat.S_ISREG(stf.st_mode):
                    continue

                mode_f = stat.S_IMODE(stf.st_mode)
                try:
                    user_f = pwd.getpwuid(stf.st_uid).pw_name
                except KeyError:
                    user_f = str(stf.st_uid)
                try:
                    group_f = grp.getgrgid(stf.st_gid).gr_name
                except KeyError:
                    group_f = str(stf.st_gid)

                with open(fpath, "rb") as rf:
                    content = rf.read()
                b64 = base64.b64encode(content).decode("ascii")

                files[fpath] = {
                    "mode": mode_f,
                    "user": user_f,
                    "group": group_f,
                    "b64": b64,
                }

    return {"files": files, "dirs": dirs}

def write_setup_sh(
    out_path: Path,
    packages: Set[str],
    docroots: List[str],
    files_info: Dict[str, Dict],
):
    """
    Erzeugt die setup.sh, die:
      - Apache und gefundene Pakete installiert
      - DocRoots und Dateien wiederherstellt
      - Rechte (chmod/chown) setzt
    """
    dirs: Dict[str, Dict] = files_info["dirs"]
    files: Dict[str, Dict] = files_info["files"]

    with out_path.open("w", encoding="utf-8") as sh:
        sh.write("#!/usr/bin/env bash\n")
        sh.write("set -euo pipefail\n\n")
        sh.write("# Dieses Skript wurde automatisch erzeugt.\n")
        sh.write("# Es installiert Apache + erkannte Pakete\n")
        sh.write("# und stellt die Webserver-Dateien wieder her.\n\n")

        # Root-Check
        sh.write("if [[ $EUID -ne 0 ]]; then\n")
        sh.write('  echo "Bitte als root ausführen (z.B. mit: sudo bash setup.sh)" >&2\n')
        sh.write("  exit 1\n")
        sh.write("fi\n\n")

        # Pakete
        pkg_list = " ".join(sorted(packages))
        sh.write("echo \"[INFO] Aktualisiere Paketindex und installiere Pakete...\"\n")
        sh.write("apt-get update\n")
        sh.write(f"DEBIAN_FRONTEND=noninteractive apt-get install -y {pkg_list}\n\n")

        # DocRoots als Kommentar
        sh.write("# Bekannte DocumentRoots:\n")
        for root in docroots:
            sh.write(f"#   - {root}\n")
        sh.write("\n")

        # Verzeichnisse anlegen (aufsteigend nach Pfadtiefe)
        sh.write("echo \"[INFO] Lege Verzeichnisse an und setze Rechte...\"\n")
        for d in sorted(dirs.keys(), key=lambda p: len(p.split(os.sep))):
            info = dirs[d]
            q = sh_quote(d)
            mode = info["mode"]
            user = info["user"]
            group = info["group"]
            sh.write(f"mkdir -p {q}\n")
            sh.write(f"chmod {mode:04o} {q} || true\n")
            sh.write(f"chown {user}:{group} {q} || true\n")
        sh.write("\n")

        # Dateien schreiben
        sh.write("echo \"[INFO] Schreibe Dateien...\"\n")
        for path, info in files.items():
            q = sh_quote(path)
            mode = info["mode"]
            user = info["user"]
            group = info["group"]
            b64 = info["b64"]

            sh.write(f"# Datei: {path}\n")
            sh.write(f"base64 -d > {q} << 'EOF_B64'\n")
            # Base64 in Zeilen aufsplitten für bessere Lesbarkeit
            for i in range(0, len(b64), 76):
                sh.write(b64[i:i+76] + "\n")
            sh.write("EOF_B64\n")
            sh.write(f"chmod {mode:04o} {q} || true\n")
            sh.write(f"chown {user}:{group} {q} || true\n\n")

        sh.write("echo \"[INFO] Setup abgeschlossen.\"\n")

    os.chmod(out_path, 0o755)


def main():
    print("[INFO] Ermittele installierte Webserver-Pakete...")
    pkgs = detect_installed_packages()
    print(f"[INFO] Erkannte Pakete: {', '.join(sorted(pkgs))}")

    print("[INFO] Ermittele DocumentRoots...")
    docroots = detect_document_roots()
    print(f"[INFO] Erkannte DocumentRoots: {', '.join(docroots)}")

    print("[INFO] Sammle Dateien und Verzeichnisinformationen...")
    info = collect_file_info(docroots)

    out_path = Path("setup.sh").resolve()
    print(f"[INFO] Erzeuge {out_path} ...")
    write_setup_sh(out_path, pkgs, docroots, info)

    print(f"[OK] Fertig. setup.sh wurde erzeugt: {out_path}")
    print("[HINWEIS] setup.sh auf Zielsystem einfach als root ausführen: sudo ./setup.sh")


if __name__ == "__main__":
    main()
