# MOD System Utils

Configuration système et scripts pour MOD Audio sur Ubuntu 25.10 avec JACK2.

## Description

Ce dépôt contient tous les fichiers de configuration nécessaires pour installer et exécuter MOD Audio (mod-host + mod-ui) sur Ubuntu 25.10 avec JACK2 natif (sans PipeWire bridge).

## Contenu

### `/systemd/`

Services systemd pour gérer les composants MOD Audio :
- **jackd.service** : Service JACK2 Audio avec détection automatique d'interface
- **mod-host.service** : Service LV2 plugin host
- **mod-ui.service** : Service interface web MOD
- **browsepy.service** : Service gestionnaire de fichiers

### `/scripts/`

Scripts utilitaires :
- **start-jack-auto** : Script de détection et démarrage automatique de JACK avec bascule d'interface audio

### `/docs/`

Documentation complète :
- **INSTALL-UBUNTU-25.10.md** : Guide d'installation complet pas à pas

## Installation rapide

```bash
# Cloner ce dépôt
git clone https://github.com/pilali/mod-system-utils.git
cd mod-system-utils

# Copier les services systemd
sudo cp systemd/*.service /etc/systemd/system/

# Installer le script JACK
sudo install -m 755 scripts/start-jack-auto /usr/local/bin/

# Adapter les noms d'utilisateur
sudo sed -i "s/User=pilal/User=$USER/g" /etc/systemd/system/*.service

# Recharger et activer les services
sudo systemctl daemon-reload
sudo systemctl enable jackd.service mod-host.service mod-ui.service browsepy.service
```

Pour une installation complète depuis zéro, consultez [docs/INSTALL-UBUNTU-25.10.md](docs/INSTALL-UBUNTU-25.10.md).

## Architecture

```
Interface Audio (ALSA)
    ↓
JACK2 (détection auto hw:0/hw:1)
    ↓
mod-host (LV2 plugin host)
    ↓
mod-ui (Web interface :80)
```

**⚠️ CHANGEMENT MAJEUR :** Cette version utilise **JACK2 natif** au lieu du bridge PipeWire-JACK pour obtenir une latence minimale (~10-12ms round-trip).

## Caractéristiques

- ✅ Latence audio ~10-12ms round-trip (256 samples @ 48kHz)
- ✅ Détection automatique d'interface audio (USB/intégrée)
- ✅ JACK2 natif (pas de PipeWire bridge)
- ✅ Services systemd avec auto-restart
- ✅ Support complet LV2 plugins
- ✅ Interface web sur port 80
- ✅ Browsepy pour gestion de fichiers

## Configuration requise

- Ubuntu 25.10 (Oracular Oriole)
- Kernel 6.17+
- Python 3.10
- JACK2
- Interface audio ALSA compatible

## Dépendances

Voir [docs/INSTALL-UBUNTU-25.10.md](docs/INSTALL-UBUNTU-25.10.md) pour la liste complète des dépendances et instructions d'installation.

## Utilisation

### Démarrer les services

```bash
sudo systemctl start jackd.service
sudo systemctl start mod-host.service
sudo systemctl start mod-ui.service
sudo systemctl start browsepy.service
```

### Accéder à l'interface

- **MOD UI** : http://localhost
- **Browsepy** : http://localhost:8081

### Voir les logs

```bash
# Logs JACK
sudo journalctl -u jackd.service -f

# Logs mod-host
sudo journalctl -u mod-host.service -f

# Logs mod-ui
sudo journalctl -u mod-ui.service -f
```

### Changer d'interface audio

Le script `start-jack-auto` détecte automatiquement l'interface audio prioritaire :
1. Dernière interface utilisée (si disponible)
2. Interface externe USB (hw:1)
3. Carte son intégrée (hw:0)

Pour forcer une interface :
```bash
echo "hw:1" | sudo tee /var/modep/data/jack-device.conf
sudo systemctl restart jackd.service
```

## Dépannage

Consultez la section [Dépannage](docs/INSTALL-UBUNTU-25.10.md#dépannage) de la documentation complète.

### Problèmes courants

**mod-ui ne communique pas avec mod-host :**
```bash
# Vérifier que MOD_DEV_HOST n'est PAS défini
sudo grep MOD_DEV_HOST /etc/systemd/system/mod-ui.service

# Si présent, le supprimer
sudo sed -i '/MOD_DEV_HOST=1/d' /etc/systemd/system/mod-ui.service
sudo systemctl daemon-reload
sudo systemctl restart mod-ui.service
```

**JACK ne démarre pas :**
```bash
# Vérifier les interfaces disponibles
aplay -l

# Voir les logs
sudo journalctl -u jackd.service -n 50
```

**Bascule automatique d'interface :**
Le script `start-jack-auto` bascule automatiquement entre les interfaces. Après branchement/débranchement d'une interface USB, redémarrez simplement :
```bash
sudo systemctl restart jackd.service
```

## Différences avec PipeWire

Cette configuration utilise **JACK2 natif** au lieu de PipeWire avec bridge JACK :

| Aspect | PipeWire-JACK Bridge | JACK2 Natif |
|--------|---------------------|-------------|
| Latence | ~42-64ms (1024 samples) | ~10-12ms (256 samples) |
| Commande | `pw-jack mod-host` | `mod-host` directement |
| Variable ENV | `XDG_RUNTIME_DIR=/run/user/1000` | `JACK_NO_AUDIO_RESERVATION=1` |
| Stabilité | Bon | Excellent |
| Intégration | Partage avec PipeWire | JACK exclusif |

## Compilation de mod-host

Si vous recompilez mod-host, utilisez ces flags :

```bash
CFLAGS="-DMOD_IO_PROCESSING_ENABLED -D__MOD_DEVICES__" make -j$(nproc)
sudo make install
```

Ces flags activent :
- `-DMOD_IO_PROCESSING_ENABLED` : Ports audio I/O (in1, in2, out1, out2)
- `-D__MOD_DEVICES__` : Support matériel MOD Devices

## Licence

Configuration système pour MOD Audio, distribué sous les mêmes termes que les projets upstream.

## Références

- [MOD Audio](https://github.com/moddevices)
- [mod-host](https://github.com/moddevices/mod-host)
- [mod-ui](https://github.com/moddevices/mod-ui)
- [JACK Audio](https://jackaudio.org/)

## Auteur

Configuration et documentation par pilali avec l'assistance de Claude Code.

---

**Version** : 2.0 (JACK2 Native)
**Date** : 2025-11-17
**Testé sur** : Ubuntu 25.10
