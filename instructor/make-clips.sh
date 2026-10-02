#!/bin/sh
# Generates the Italian audio clips for the AXIS C1410 with the built-in macOS voice "Alice".
# Upload them in this order so the clip numbers match the participant card (0, 1, 2, 3, 4).
set -e
cd "$(dirname "$0")"
mkdir -p clips

make_clip() {
    say -v Alice -o "clips/$1.aiff" "$2"
    afconvert -f WAVE -d LEI16@16000 -c 1 "clips/$1.aiff" "clips/$1.wav"
    rm "clips/$1.aiff"
    echo "clips/$1.wav: $2"
}

make_clip 0-doorbell "Din don. C'è un visitatore all'ingresso."
make_clip 1-close-door "Attenzione, la porta è rimasta aperta. Chiudere la porta, per favore."
make_clip 2-door-forced "Allarme. Porta forzata."
make_clip 3-surveillance "Attenzione. Quest'area è videosorvegliata."
make_clip 4-one-at-a-time "Una persona alla volta, per favore."
