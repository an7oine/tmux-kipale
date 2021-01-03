# Musiikki-ohjelman tilatiedot ja ohjaus Tmuxin kautta

## Järjestelmävaatimukset
* Mac OS -ympäristö
* tmux >= 3.0

## Asennus
Lisätään liitännäinen Tmuxin asetuksiin:
```
# .tmux.conf
set -g @kipale-valikkonappain m

set -g @plugin 'an7oine/tmux-kipale'
```
Näppäillään `<prefix> + I` liitännäisten asentamiseksi.

## Käyttö
Esittäjän ja kappaleen nimi näkyy tilatietopalkissa.
Näppäilemällä `<prefix> + M` avautuu valikko, josta musiikin toistoa voidaan ohjata.
