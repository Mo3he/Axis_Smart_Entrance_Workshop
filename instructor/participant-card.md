# Scheda partecipante / Participant card

Stampare una per gruppo e compilare prima della sessione. / Print one per group and fill in before the session.

**Gruppo / Group:** ______

## Parametri / Parameters

| Parametro / Parameter | Placeholder | Valore / Value |
|---|---|---|
| Node-RED (questa postazione / this workstation) | `NODE_RED_IP` | |
| MQTT broker | `MQTT_BROKER_IP` | |
| AXIS Camera Station Pro | `ACS_PRO_IP` | |
| ACS Pro HTTPS port | `ACS_PRO_HTTPS_PORT` | 29204 |
| Nome trigger / Trigger name | | UnlockDoor_G__ |
| Prefisso regole ACS Pro / ACS Pro rule prefix | | G__ - |
| Telecamera / Camera (Parte 1) | `CAMERA_IP` | |
| AXIS C1410 | `C1410_IP` | |
| AXIS I8116-E | `INTERCOM_IP` | |
| Seriale intercom / Intercom serial | `INTERCOM_SERIAL` | |

## Credenziali / Credentials

| Sistema / System | Username | Password |
|---|---|---|
| Dispositivi Axis / Axis devices | | |
| AXIS Camera Station Pro | | |

## Clip audio / Audio clips

| Clip | File | Uso / Used for |
|---|---|---|
| 0 | `0-doorbell.wav` | Chiamata Intercom / Intercom call |
| 1 | `1-close-door.wav` | Porta aperta troppo a lungo / Door open too long |
| 2 | `2-door-forced.wav` | Porta forzata / Door forced |

## Link

- Node-RED: `http://NODE_RED_IP:1880`
- Dashboard: `http://NODE_RED_IP:1880/dashboard`
- VAPIX: <https://developer.axis.com/vapix/>
