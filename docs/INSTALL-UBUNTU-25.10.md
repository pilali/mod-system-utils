# Installation de MOD Audio sur Ubuntu 25.10 avec JACK2

Ce guide décrit l'installation complète de MOD Audio (mod-host + mod-ui) sur Ubuntu 25.10 avec JACK2 natif pour une latence audio minimale.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis système](#prérequis-système)
- [Installation de Python 3.10](#installation-de-python-310)
- [Installation de JACK2](#installation-de-jack2)
- [Installation de mod-host](#installation-de-mod-host)
- [Installation de mod-ui](#installation-de-mod-ui)
- [Configuration des services systemd](#configuration-des-services-systemd)
- [Test et vérification](#test-et-vérification)
- [Dépannage](#dépannage)

## Vue d'ensemble

**Architecture du système :**
```
Interface Audio (ALSA) → JACK2 → mod-host → mod-ui (http://localhost:80)
                                      ↓
                                 Plugins LV2
```

**Latence obtenue :** ~10-12ms round-trip avec buffer de 256 samples @ 48kHz

## Prérequis système

### Système d'exploitation
- Ubuntu 25.10 (oracular)
- Kernel 6.17 ou supérieur

### Dépendances de base
```bash
sudo apt update
sudo apt install -y git build-essential autoconf automake libtool \
    pkg-config libjack-jackd2-dev liblilv-dev libreadline-dev \
    libargtable2-dev libfftw3-dev libjson-c-dev lv2-dev \
    jackd2 qjackctl a2jmidid curl
```

## Installation de Python 3.10

MOD UI nécessite Python 3.10 (pour compatibilité avec Tornado 4.3).

### Compilation depuis les sources

```bash
# Télécharger Python 3.10.15
cd /tmp
wget https://www.python.org/ftp/python/3.10.15/Python-3.10.15.tgz
tar -xzf Python-3.10.15.tgz
cd Python-3.10.15

# Compiler et installer
./configure --enable-optimizations --with-ensurepip=install
make -j$(nproc)
sudo make altinstall

# Vérifier l'installation
python3.10 --version  # Devrait afficher: Python 3.10.15
```

### Créer l'environnement virtuel pour mod-ui

```bash
sudo mkdir -p /usr/local/lib/mod-ui-venv
sudo python3.10 -m venv /usr/local/lib/mod-ui-venv
```

## Installation de JACK2

### Installation des paquets

```bash
sudo apt install -y jackd2 qjackctl a2jmidid
```

### Script de détection automatique d'interface audio

Ce script permet à JACK de basculer automatiquement entre les interfaces audio disponibles (utile pour les configurations avec interface externe USB).

Créer `/usr/local/bin/start-jack-auto` :

```bash
#!/bin/bash
# Script de démarrage automatique de JACK avec détection d'interface audio
# Pour MOD Audio sur Ubuntu 25.10

# Forcer la locale anglaise pour les commandes système
export LANG=C
export LC_ALL=C

# Fichier de configuration pour sauvegarder la dernière interface utilisée
CONFIG_FILE="/var/modep/data/jack-device.conf"

# Paramètres JACK par défaut
SAMPLE_RATE=48000
BUFFER_SIZE=256
PERIODS=2
PRIORITY=95

# Fonction pour vérifier si une carte audio existe
check_card_exists() {
    local card=$1
    aplay -l 2>/dev/null | grep -q "^card ${card}:"
    return $?
}

# Fonction pour détecter l'interface audio à utiliser
detect_audio_device() {
    # Priorité 1 : Dernière interface utilisée (si elle existe encore)
    if [ -f "$CONFIG_FILE" ]; then
        LAST_DEVICE=$(cat "$CONFIG_FILE")
        LAST_CARD=$(echo "$LAST_DEVICE" | sed 's/hw://')
        if check_card_exists "$LAST_CARD"; then
            echo "$LAST_DEVICE"
            return 0
        fi
    fi

    # Priorité 2 : Interface externe (hw:1) si connectée
    if check_card_exists 1; then
        echo "hw:1"
        return 0
    fi

    # Priorité 3 : Carte son intégrée (hw:0)
    if check_card_exists 0; then
        echo "hw:0"
        return 0
    fi

    # Aucune carte trouvée
    echo "ERROR: No audio interface found" >&2
    return 1
}

# Détecter l'interface audio
DEVICE=$(detect_audio_device)
if [ $? -ne 0 ]; then
    echo "FATAL: Cannot find any audio interface" >&2
    exit 1
fi

# Sauvegarder l'interface utilisée pour la prochaine fois
mkdir -p "$(dirname "$CONFIG_FILE")"
echo "$DEVICE" > "$CONFIG_FILE"

# Afficher l'interface utilisée
CARD_NUM=$(echo "$DEVICE" | sed 's/hw://')
CARD_NAME=$(aplay -l 2>/dev/null | grep "^card ${CARD_NUM}:" | head -1 | sed 's/.*: //' | cut -d',' -f1)
echo "Starting JACK with audio interface: $DEVICE ($CARD_NAME)"

# Lancer JACK avec l'interface détectée
exec /usr/bin/jackd -R -P${PRIORITY} \
    -dalsa \
    -d${DEVICE} \
    -r${SAMPLE_RATE} \
    -p${BUFFER_SIZE} \
    -n${PERIODS}
```

Installer le script :
```bash
sudo install -m 755 /usr/local/bin/start-jack-auto
```

## Installation de mod-host

### Cloner et compiler

```bash
mkdir -p ~/dev/mod-audio
cd ~/dev/mod-audio

# Cloner le dépôt officiel
git clone https://github.com/moddevices/mod-host.git
cd mod-host

# Compiler avec les flags MOD
CFLAGS="-DMOD_IO_PROCESSING_ENABLED -D__MOD_DEVICES__" make -j$(nproc)

# Installer
sudo make install
```

**Flags de compilation importants :**
- `-DMOD_IO_PROCESSING_ENABLED` : Active les ports audio I/O (in1, in2, out1, out2)
- `-D__MOD_DEVICES__` : Active le support matériel MOD Devices

### Vérifier l'installation

```bash
mod-host --version
which mod-host  # Devrait afficher: /usr/local/bin/mod-host
```

## Installation de mod-ui

### Cloner le dépôt

```bash
cd ~/dev/mod-audio
git clone https://github.com/moddevices/mod-ui.git
cd mod-ui
```

### Installer les dépendances Python

```bash
sudo /usr/local/lib/mod-ui-venv/bin/pip install --upgrade pip
sudo /usr/local/lib/mod-ui-venv/bin/pip install tornado==4.3 pyserial pystache pillow

# Installer mod-ui
sudo /usr/local/lib/mod-ui-venv/bin/pip install .
```

### Installer Browsepy (gestionnaire de fichiers MOD)

```bash
sudo /usr/local/lib/mod-ui-venv/bin/pip install git+https://github.com/mod-audio/browsepy.git
```

### Créer le lien symbolique pour mod-ui

```bash
sudo ln -sf /usr/local/lib/mod-ui-venv/bin/mod-ui /usr/local/bin/mod-ui
```

## Configuration des services systemd

### Structure des répertoires

```bash
sudo mkdir -p /var/modep/{lv2,pedalboards,user-files,data,pedalboard-tmp-data}
sudo chown -R $USER:$USER /var/modep
```

### Service jackd.service

Créer `/etc/systemd/system/jackd.service` :

```ini
[Unit]
Description=JACK Audio Connection Kit (for MOD Audio)
After=sound.target
Documentation=https://jackaudio.org/

[Service]
Type=simple
User=pilal
Group=audio
LimitRTPRIO=95
LimitMEMLOCK=infinity

# JACK auto-detection script
Environment="JACK_NO_AUDIO_RESERVATION=1"
ExecStart=/usr/local/bin/start-jack-auto

# Restart on failure
Restart=on-failure
RestartSec=3

# Logs
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Note :** Remplacez `User=pilal` par votre nom d'utilisateur.

### Service mod-host.service

Créer `/etc/systemd/system/mod-host.service` :

```ini
[Unit]
Description=MOD-Host LV2 Plugin Host (JACK2 Native)
After=jackd.service
Requires=jackd.service
Documentation=man:mod-host(1)

[Service]
Type=simple
User=pilal
Group=pilal
SupplementaryGroups=audio

# Variables d'environnement
Environment="LV2_PATH=/var/modep/lv2:/usr/local/lib/lv2:/usr/lib/lv2"
Environment="MOD_LOG=1"

# Démarrage mod-host (JACK natif)
# -v : verbose
# -n : nofork (pour systemd)
# -p : port socket commandes (5555)
# -f : port socket feedback (5556)
ExecStart=/usr/local/bin/mod-host -v -n -p 5555 -f 5556

# Redémarrage automatique
Restart=always
RestartSec=3

# Logs
StandardOutput=journal
StandardError=journal

# Working directory
WorkingDirectory=/var/modep

[Install]
WantedBy=multi-user.target
```

### Service mod-ui.service

Créer `/etc/systemd/system/mod-ui.service` :

```ini
[Unit]
Description=MOD-UI Web Interface (JACK2 Native)
After=mod-host.service jackd.service
Requires=mod-host.service
Documentation=https://github.com/moddevices/mod-ui

[Service]
Type=simple
User=pilal
Group=pilal
SupplementaryGroups=audio

# Capability pour bind port 80 sans root
AmbientCapabilities=CAP_NET_BIND_SERVICE

# Variables d'environnement Python
Environment="PYTHONPATH=/usr/local/lib/python3.10/site-packages"

# Variables d'environnement MOD-UI
Environment="MOD_DATA_DIR=/var/modep"
Environment="MOD_HTML_DIR=/usr/local/share/mod/html"
Environment="MOD_DEVICE_WEBSERVER_PORT=80"
Environment="LV2_PATH=/var/modep/lv2:/usr/local/lib/lv2:/usr/lib/lv2"
Environment="MOD_LOG=1"
Environment="MOD_USER_FILES_DIR=/var/modep/user-files"
Environment="MOD_PEDALBOARDS_DIR=/var/modep/pedalboards"
Environment="MOD_KEYS_PATH=/var/modep/data/keys"
Environment="MOD_BANKS_JSON_FILE=/var/modep/data/banks.json"
Environment="MOD_DEFAULT_PEDALBOARD=/usr/local/share/mod/default.pedalboard"

# Attente que mod-host soit prêt
ExecStartPre=/bin/sleep 5

# Démarrage mod-ui (JACK natif, sans pw-jack)
ExecStart=/usr/local/bin/mod-ui

# Redémarrage automatique
Restart=always
RestartSec=3

# Logs
StandardOutput=journal
StandardError=journal

# Working directory
WorkingDirectory=/var/modep

[Install]
WantedBy=multi-user.target
```

**⚠️ IMPORTANT :** Ne PAS définir `MOD_DEV_HOST=1` car cela empêche mod-ui de communiquer avec mod-host local.

### Service browsepy.service

Créer `/etc/systemd/system/browsepy.service` :

```ini
[Unit]
Description=Browsepy File Manager for MOD-UI
After=network.target

[Service]
Type=simple
User=pilal
Group=pilal
WorkingDirectory=/var/modep/user-files
ExecStart=/usr/local/lib/mod-ui-venv/bin/browsepy --directory /var/modep/user-files --upload /var/modep/user-files 0.0.0.0 8081
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Activer et démarrer les services

```bash
# Recharger systemd
sudo systemctl daemon-reload

# Activer les services au démarrage
sudo systemctl enable jackd.service mod-host.service mod-ui.service browsepy.service

# Démarrer les services
sudo systemctl start jackd.service
sleep 2
sudo systemctl start mod-host.service
sleep 2
sudo systemctl start mod-ui.service
sudo systemctl start browsepy.service
```

## Test et vérification

### Vérifier que JACK fonctionne

```bash
# Vérifier le statut
sudo systemctl status jackd.service

# Lister les ports JACK
jack_lsp
```

Vous devriez voir :
```
system:capture_1
system:capture_2
system:playback_1
system:playback_2
mod-host:midi_in
mod-host:in1
mod-host:in2
mod-host:out1
mod-host:out2
```

### Vérifier la communication mod-host

```bash
# Tester le socket mod-host
(timeout 3 nc localhost 5556 &) && sleep 0.2 && printf "help\0" | timeout 3 nc localhost 5555
```

Devrait afficher la liste des commandes mod-host.

### Accéder à l'interface web

Ouvrir dans un navigateur :
- **MOD UI** : http://localhost (ou http://localhost:80)
- **Browsepy** : http://localhost:8081

### Tester avec un plugin

```bash
# Ajouter un plugin via socket
(timeout 3 nc localhost 5556 &) && sleep 0.2 && printf "add http://aidadsp.cc/plugins/aidadsp-bundle/rt-neural-generic 0\0" | timeout 3 nc localhost 5555

# Vérifier que le plugin apparaît
jack_lsp | grep effect
```

## Dépannage

### JACK ne démarre pas

**Problème :** `Cannot get card index for X`

**Solution :** Vérifier les interfaces audio disponibles :
```bash
aplay -l
```

Le script `/usr/local/bin/start-jack-auto` basculera automatiquement sur hw:0 si hw:1 n'est pas disponible.

### mod-ui ne communique pas avec mod-host

**Problème :** Les modifications dans mod-ui n'ont pas d'effet.

**Vérification :**
```bash
# Vérifier que MOD_DEV_HOST n'est PAS défini
sudo systemctl cat mod-ui.service | grep MOD_DEV_HOST
```

Si présent, supprimer la ligne et redémarrer :
```bash
sudo sed -i '/MOD_DEV_HOST=1/d' /etc/systemd/system/mod-ui.service
sudo systemctl daemon-reload
sudo systemctl restart mod-ui.service
```

### Latence audio élevée

**Régler le buffer size JACK :**

Éditer `/usr/local/bin/start-jack-auto` :
```bash
BUFFER_SIZE=128  # Pour ~2.7ms @ 48kHz (plus exigeant en CPU)
BUFFER_SIZE=256  # Pour ~5.3ms @ 48kHz (recommandé)
BUFFER_SIZE=512  # Pour ~10.7ms @ 48kHz (plus stable)
```

Puis :
```bash
sudo systemctl restart jackd.service
```

### Voir les logs

```bash
# Logs JACK
sudo journalctl -u jackd.service -f

# Logs mod-host
sudo journalctl -u mod-host.service -f

# Logs mod-ui
sudo journalctl -u mod-ui.service -f
```

### Réinitialiser complètement

```bash
# Arrêter tous les services
sudo systemctl stop mod-ui.service mod-host.service jackd.service browsepy.service

# Supprimer les données temporaires
rm -rf /var/modep/pedalboard-tmp-data/*

# Redémarrer les services
sudo systemctl start jackd.service
sleep 2
sudo systemctl start mod-host.service
sleep 2
sudo systemctl start mod-ui.service
sudo systemctl start browsepy.service
```

## Performance et optimisation

### Latence typique

Avec buffer de 256 samples @ 48kHz :
- **Latence par direction** : ~5.3ms
- **Latence round-trip** : ~10-12ms
- **Charge CPU typique** : 2-6% (selon plugins)

### Plugins LV2 recommandés

- **AIDA-X** : Simulateur d'ampli par IA
- **Calf** : Suite d'effets professionnels
- **LSP** : Plugins de studio professionnels
- **MDA** : Collection d'effets classiques

Installation :
```bash
sudo apt install calf-plugins lsp-plugins-lv2 mda-lv2
```

## Références

- **MOD Audio** : https://github.com/moddevices
- **mod-host** : https://github.com/moddevices/mod-host
- **mod-ui** : https://github.com/moddevices/mod-ui
- **JACK Audio** : https://jackaudio.org/
- **LV2 Plugins** : https://lv2plug.in/

---

**Version** : 1.0
**Date** : 2025-11-17
**Testé sur** : Ubuntu 25.10 (Oracular Oriole)
**Auteur** : Documentation générée avec Claude Code
