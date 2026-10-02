# Participant card / Scheda partecipante

Print one per group and fill in before the session. / Stampare una per gruppo e compilare prima della sessione.

**Group / Gruppo:** ______

## Devices / Dispositivi

| Device / Dispositivo | Placeholder | IP address / Indirizzo IP |
|---|---|---|
| AXIS P1475-LE (camera / telecamera) | `CAMERA_IP` | |
| AXIS C1410 (your speaker / il tuo speaker) | `C1410_IP` | |
| AXIS A1210 (door controller / controller porta) | `A1210_IP` | |
| AXIS I8116-E (intercom / citofono) | - | |

| | |
|---|---|
| Username | |
| Password | |
| Door token / Token della porta (`DOOR_TOKEN`) | |

## Audio clips on the C1410 / Clip audio sul C1410

| Clip | Content / Contenuto |
|---|---|
| 0 | Doorbell / Campanello: "Din don. C'è un visitatore all'ingresso." |
| 1 | "Attenzione, la porta è rimasta aperta. Chiudere la porta, per favore." |
| 2 | "Allarme. Porta forzata." |
| 3 | "Attenzione. Quest'area è videosorvegliata." |
| 4 | "Una persona alla volta, per favore." |

## MQTT

| | |
|---|---|
| Broker | Already configured in Node-RED as `Workshop broker` / Già configurato in Node-RED come `Workshop broker` |
| Topics | `lab/entrance/intercom`, `lab/entrance/door`, `lab/entrance/camera` |

## Links

- Node-RED: <http://localhost:1880>
- Dashboard: <http://localhost:1880/dashboard>
- VAPIX: <https://developer.axis.com/vapix/>
