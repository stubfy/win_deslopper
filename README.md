# win_unslopper v0.1

Pack d'optimisation Windows 11 25H2 axe gaming — debloat, tweaks systeme, latence d'entree.

Cible : PC gaming sous Windows 11 25H2, GPU NVIDIA, NIC Intel I226-V.

---

## Contenu

| Dossier | Description |
|---------|-------------|
| `1 - Automatique` | Lanceur principal + scripts automatises |
| `2 - Windows Defender` | Desactivation Defender (Mode Sans Echec requis) |
| `3 - Windows Tweaker` | Tweaks GUI supplementaires via UWT v5 |
| `4 - Control Panel` | Reglages accessibles uniquement via l'interface Windows |
| `5 - MSI Utils` | Activation des interruptions MSI (GPU, NIC, NVMe) |
| `6 - Mouse Accel fix` | Correction courbe d'acceleration souris (scaling != 100%) |
| `7 - NVInspector` | Profils pilote NVIDIA par jeu via NVPI-R |
| `8 - Gestionnaire` | Desactivation economie d'energie USB |
| `9 - Interrupt Affinity` | Epinglage IRQ GPU sur un coeur CPU dedie |
| `10 - Network WIP` | Reglages avances carte reseau (offloads, buffers) |
| `11 - Autres` | Outils complementaires (Autoruns, DeviceCleanup, temp) |

---

## Utilisation

### Etape 1 — Tweaks automatiques

Ouvrir `src/1 - Automatique/` et executer `run_all.bat` en administrateur (double-clic).

Le script applique en une passe :
- Tweaks registre consolides (GameDVR, MMCSS, VBS, timer resolution, responsive desktop...)
- Desactivation des services inutiles (SysMain, DPS, DiagTrack, WSearch...)
- Configuration boot (disabledynamictick, useplatformclock, bootmenupolicy legacy)
- Plan d'alimentation haute performance
- DNS Cloudflare (1.1.1.1 / 1.0.0.1)
- Politiques Edge
- Debloat UWP (apps Microsoft inutiles)
- O&O ShutUp10++ en mode silencieux (240 tweaks confidentialite/telemetrie)
- SetTimerResolution au demarrage (resolution minuterie ~0.5ms)
- Suspension USB desactivee
- Desactivation Recall / IA Windows 25H2

Duree estimee : 5 a 15 minutes. Un redemarrage est propose a la fin.

Un log detaille est ecrit dans `%APPDATA%\win_unslopper\logs\win_unslopper.log`.

### Etape 2 — Redemarrer

### Etape 3 — Etapes manuelles

Effectuer dans l'ordre les dossiers `2` a `11`. Chaque dossier contient un `readme.txt` avec les instructions detaillees.

---

## Annuler les tweaks automatiques

Executer `src/1 - Automatique/restore_all.bat` en administrateur.

Restaure les services, le registre, le DNS et la configuration boot a leurs valeurs d'origine.

> Les desinstallations d'applications UWP ne sont pas reversibles automatiquement.

---

## Avertissements

- **Desactivation Defender** : necessite le Mode Sans Echec. Sur 25H2, Tamper Protection peut bloquer la modification meme en Safe Mode.
- **MSI Utils** : ne pas activer sur les controleurs audio, ELGATO ou USB legacy — risque de BSOD.
- **Interrupt Affinity** : un mauvais reglage peut augmenter la latence. Suivre le readme du dossier 9.
- **VBS/HVCI** desactive par defaut dans les tweaks registre — gain de performance, compromis securite.

---

## Structure interne de `1 - Automatique`

```
run_all.bat          Point d'entree principal (UAC auto-elevation)
restore_all.bat      Point d'entree restauration
scripts\
  run_all.ps1        Lanceur PowerShell principal
  restore_all.ps1    Restauration PowerShell
  01_backup.ps1      Restore point + export etat initial
  02_registry.ps1    Tweaks registre consolides
  03_services.ps1    Desactivation services
  04_bcdedit.ps1     Configuration boot
  05_power.ps1       Plan d'alimentation
  06_dns.ps1         DNS Cloudflare
  07_edge.ps1        Politiques Edge
  08_debloat.ps1     Suppression apps UWP
  09_oosu10.ps1      O&O ShutUp10++ silencieux
  10_timer.ps1       SetTimerResolution au demarrage
  11_usb.ps1         Suspension USB
  12_ai_disable.ps1  Desactivation IA/Recall 25H2
  13_telemetry.ps1   Telemetrie supplementaire
restore\             Scripts de restauration symetriques
tools\               Outils tiers (OOSU10.exe, SetTimerResolution.exe...)
backup\              Cree au premier run — sauvegarde etat initial
```
