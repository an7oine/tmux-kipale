#!/usr/bin/env bash

if [ $# -eq 0 ]; then
  # Ei annettu komentoa, kytketään liitännäinen päälle.

  # Tilarivi.
  status_right=$(tmux show-option -gqv "status-right")
  tmux set-option -g status-right \
    "#(\"${BASH_SOURCE[0]}\" esittaja_ja_kappale)$status_right"

  # Valikkonäppäin.
  valikkonappain=$(tmux show-option -gqv "@kipale-valikkonappain")
  [ -n "$valikkonappain" ] && tmux bind-key $valikkonappain \
    "run-shell '\"${BASH_SOURCE[0]}\" nayta_valikko'"

  # Hakunäppäin.
  hakunappain=$(tmux show-option -gqv "@kipale-hakunappain")
  [ -n "$hakunappain" ] && tmux bind-key $hakunappain \
    "run-shell '\"${BASH_SOURCE[0]}\" avaa_kappalehaku'"

  # Optimointi: poistutaan ennen funktioiden määrittelyä.
  exit
fi


# Päätellään ohjattavan ohjelman nimi:
# - Mac OS 10.15 Catalina tai uudempi: "Musiikki.app"
# - Mac OS 10.14 Mojava tai vanhempi: "iTunes.app"
[ -e "$( which sw_vers 2>/dev/null )" ] || {
  echo "Liitännäinen toimii vain Mac OS -ympäristössä!"
  exit 0
}
if [ "$( sort -V <<<$'10.15\n'"$( sw_vers -productVersion )" |head -n1 )" == "10.15" ]
  then OHJELMA=Music; BINAARI=/System/Applications/Music.app
  else OHJELMA=iTunes; BINAARI=/Applications/iTunes.app
fi


# Ohjaustoiminnot.
komento() {
  osascript <<EOF
tell application "$OHJELMA" to $*
EOF
}
toisto_tauko() {
  komento playpause
}
edellinen() {
  komento previous track
}
seuraava() {
  komento next track
}
vaihda_silmukointi() {
  case "$2" in
    ($1) komento set song repeat to off ;;
    (one) komento set song repeat to one ;;
    (all) komento set song repeat to all ;;
  esac
}
vaihda_sekoitus() {
  case "$1" in
    (true) komento set shuffle enabled to false ;;
    (false) komento set shuffle enabled to true ;;
  esac
}
soita_kappale() {
  komento play tracks whose persistent ID is \"$*\" >/dev/null
}


# Tilarivin tiedot.
esittaja_ja_kappale() {
  local esittaja
  local kappale
  { read -r esittaja; read -r kappale; } < <( osascript <<EOF
tell application "$OHJELMA"
  return (artist of current track & "\n" & name of current track)
  set tulokset to ""
  repeat with tulos in (tracks whose artist contains "$*" or name contains "$*" or album contains "$*")
    set tulokset to tulokset & artist of tulos & ": " & name of tulos & "\n" & persistent id of tulos & "\n"
  end repeat
  return tulokset
end tell
EOF
  )
  #local esittaja=$(komento artist of the current track)
  #local kappale=$(komento name of the current track)
  [ -n "$esittaja" -o -n "$kappale" ] \
  && echo "♫ ${esittaja:-–}: ${kappale:-–} "
}


# Soitettavan kappaleen valinta.
valitse_kappale() {
  local otsikko="$1"
  local arr=("")
  local pikanappaimet=1234567890qwertyuiopåasdfghjklöäzxcvbnmQWERTYUIOPÅASDFGHJKLÖÄZXCVBNM
  local pikanappain=0
  while read -r kuvaus && read -r id; do
    if [ -z "$id" ]; then
      if [ -n "$kuvaus" ]
      then arr+=("-#[nodim]$kuvaus" "" "")
      else arr+=("")
      fi
      continue
    fi
    arr+=(
      "$kuvaus"
      "${pikanappaimet:pikanappain:1}"
      "run -b '\"${BASH_SOURCE[0]}\" soita_kappale $id'"
    )
    ((pikanappain+=1))
  done
  if [ "${#arr[@]}" -eq 0 ]; then
    tmux display-message "Kappaletta ei löytynyt!"
  else
    testaa() {
      for n; do echo \"$n\"; done
    }
    tmux display-menu -T "#[align=centre fg=green]Valitse kappale" -x R -y P "${arr[@]}"
  fi
}


# Kappalehaku.
avaa_kappalehaku() {
  tmux command-prompt -p "Hae kappaletta nimellä:" \
    "run -b '\"${BASH_SOURCE[0]}\" hae_kappaletta \"%%\"'"
}
hae_kappaletta() {
  valitse_kappale < <( osascript <<EOF
tell application "$OHJELMA"
  set tulokset to ""
  repeat with tulos in (tracks whose artist contains "$*" or name contains "$*" or album contains "$*")
    set tulokset to tulokset & artist of tulos & ": " & name of tulos & "\n" & persistent id of tulos & "\n"
  end repeat
  return tulokset
end tell
EOF
  )
}


# Esittäjän / albumin selaus.
selaa_esittajaa() {
  valitse_kappale < <( osascript <<EOF
tell application "$OHJELMA"
  set e to artist of current track
  set tulokset to "Esittäjä: " & artist of current track & "\n\n\n\n"
  repeat with tulos in (tracks whose artist is e)
    set tulokset to tulokset & "[" & album of tulos & "] " & name of tulos & "\n" & persistent id of tulos & "\n"
  end repeat
  return tulokset
end tell
EOF
  )
}
selaa_albumia() {
  valitse_kappale < <( osascript <<EOF
tell application "$OHJELMA"
  set (e, a) to (artist, album) of current track
  set tulokset to "Esittäjä: " & artist of current track & "\n\nLevy: " & album of current track & "\n\n\n\n"
  repeat with tulos in (tracks whose artist is e and album is a)
    set tulokset to tulokset & name of tulos & "\n" & persistent id of tulos & "\n"
  end repeat
  return tulokset
end tell
EOF
  )
}


# Valikko.
nayta_valikko() { # Avaa Musiikki, ellei se ole jo auki.
  open -g "${BINAARI}"

  local silmukointi sekoitus esittaja kappale albumi
  {
    read -r silmukointi; read -r sekoitus;
    read -r esittaja; read -r kappale; read -r albumi;
  } < <( osascript 2>&1 <<EOF
tell application "$OHJELMA"
  set (sr, se) to (song repeat, shuffle enabled)
  try
    set (e, k, a) to (artist, name, album) of current track
  on error
    set (e, k, a) to ("", "", "")
  end try
  log sr
  log se
  log e
  log k
  log a
end tell
EOF
  )

  silmukka_all="$(case "$silmukointi" in
    (all) echo "#[fg=cyan]Älä toista kappaleita uudelleen" ;;
    (*) echo "Toista kaikkia kappaleita" ;;
  esac)"
  silmukka_one="$(case "$silmukointi" in
    (one) echo "#[fg=cyan]Älä toista kappaletta uudelleen" ;;
    (*) echo "Toista yksittäistä kappaletta" ;;
  esac)"
  sekoitus_nimio="$(case "$sekoitus" in
    (true) echo "#[fg=cyan]Poista sekoitus käytöstä" ;;
    (false) echo "Ota sekoitus käyttöön" ;;
  esac)"

  hakunappain=$(tmux show-option -gqv "@kipale-hakunappain")

  tmux display-menu -T "#[align=centre fg=green]Musiikki" -x R -y P \
    "" \
    "-#[nodim]Kappale: $kappale" "" "" \
    "$( [ -z "$esittaja" ] && echo "-" )#[nodim]Esittäjä: $esittaja" "s" \
      "run -b '\"${BASH_SOURCE[0]}\" selaa_esittajaa'" \
    "$( [ -z "$albumi" ] && echo "-" )#[nodim]Levy: $albumi" "d" \
      "run -b '\"${BASH_SOURCE[0]}\" selaa_albumia'" \
    "" \
    "Toisto/tauko" Space "run -b '\"${BASH_SOURCE[0]}\" valikko toisto_tauko'" \
    "Edellinen"    h "run -b '\"${BASH_SOURCE[0]}\" valikko edellinen'" \
    "Seuraava"     l "run -b '\"${BASH_SOURCE[0]}\" valikko seuraava'" \
    "" \
    "$silmukka_one" 1 \
      "run -b '\"${BASH_SOURCE[0]}\" valikko vaihda_silmukointi $silmukointi one'" \
    "$silmukka_all" 2 \
      "run -b '\"${BASH_SOURCE[0]}\" valikko vaihda_silmukointi $silmukointi all'" \
    "$sekoitus_nimio" 3 \
      "run -b '\"${BASH_SOURCE[0]}\" valikko vaihda_sekoitus $sekoitus'" \
    "" \
    "$( [ -n "$hakunappain" ] && echo "[$hakunappain] " )Hae..." "f" \
      "run -b '\"${BASH_SOURCE[0]}\" avaa_kappalehaku'"
}


# Suoritetaan annettu toiminto; avataan valikko uudelleen.
valikko() {
  eval "${@}"
  nayta_valikko
}


# Suoritetaan annettu toiminto.
eval "${@}"
