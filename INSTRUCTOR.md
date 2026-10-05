# Instructor guide

Preparation and running notes for the 60-minute lab that follows the presentation *12 - Integrazione di dispositivi*.

The participant guide is [README.it.md](README.it.md) (Italian, primary for the session) and [README.md](README.md) (English translation). Both follow the lab document *AXIS_Bootcamp_Integration_Workshop.docx*.

---

## 1. Setup at a glance

```text
                              lab network (isolated)
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ Per group: workstation running docker compose                            │
 │   - Node-RED + Dashboard 2.0   :1880  (receives ACS Pro HTTP POSTs)      │
 │   - Mosquitto broker           :1883  (receives intercom MQTT events)    │
 │                                                                          │
 │ Devices                                                                  │
 │   - AXIS Intercom   ── MQTT ──► broker (one broker only, see 1.1)        │
 │   - AXIS A1601 ── door "AEC main" ── AXIS Camera Station Pro server      │
 │   - AXIS C1410 (speaker)                                                 │
 │   - Any Axis camera for Part 1                                           │
 └──────────────────────────────────────────────────────────────────────────┘
```

Traffic that must be allowed:

| From | To | Port | Why |
|---|---|---|---|
| Workstation | Camera, C1410 | 80 (HTTP) | Parts 1, 2, 4.7 |
| Intercom | Workstation | 1883 (MQTT) | Part 3 |
| ACS Pro server | Workstation | 1880 (HTTP) | Parts 4.2-4.4 |
| Workstation | ACS Pro server | 29204 (HTTPS) | Part 4.10 |

> On Windows workstations, Docker Desktop publishes ports 1880 and 1883, but **Windows Defender Firewall may still block inbound connections**. Test from another machine before the session.

### 1.1 One group or several?

The lab document is written for one setup: one Node-RED, one broker, one intercom, one ACS Pro. With several groups, two things conflict:

1. **The intercom has one MQTT client**, so it can publish to only one broker. Options:
   - One intercom per group, each pointed at its group's workstation, or
   - One shared intercom, configured by the instructor (Parts 3.1 and 3.2 done as a demo) to publish to one broker. On every workstation set `BROKER_HOST=<that IP>` in `.env` so all Node-REDs subscribe to the same broker.
2. **ACS Pro rules are per group.** Every group creates its own action rules pointing at its own `NODE_RED_IP`, and the External HTTPS trigger names must be unique (for example `UnlockDoor_G1`, `UnlockDoor_G2`). Write the name on each card.

### 1.2 Timing

The document covers a lot for 60 minutes, especially the ACS Pro configuration in Part 4 (four action rules, CA export, TLS setup). If a dry run shows it doesn't fit:

- Create the ACS Pro action rules (4.2, 4.4, 4.9) and export the CA in advance, and let participants build only the Node-RED side.
- Do Parts 3.1/3.2 (intercom MQTT configuration) as an instructor demo.

---

## 2. Preparation

### 2.1 Workstations

On every workstation (internet access is needed the first time, to pull and build the images):

```sh
git clone https://github.com/Mo3he/Axis_Smart_Entrance_Workshop
cd Axis_Smart_Entrance_Workshop
docker compose up -d --build
```

This starts Mosquitto and Node-RED with Dashboard 2.0 preinstalled. The starter flow contains only:

- An MQTT broker connection named **Local broker** (points at the bundled Mosquitto, or at `BROKER_HOST` if set in `.env`)
- The dashboard base and theme, so participants only create the page and groups

Open `http://localhost:1880` and check that the editor loads.

> Mosquitto allows anonymous connections without TLS. That is acceptable **only** on an isolated lab network. Mention it during the MQTT part of the presentation: in production, use TLS and authentication.

### 2.2 Devices and accounts

- Use the same lab account on the camera, C1410 and intercom (write it on the cards).
- `param.cgi` (list) and `mediaclip.cgi` (play) work with an Operator account.

### 2.3 C1410 audio clips

Clips are in [instructor/clips](instructor/clips), generated with the macOS Italian voice by [instructor/make-clips.sh](instructor/make-clips.sh):

| Clip | File | Text |
|---|---|---|
| 0 | `0-doorbell.wav` | "Din don. C'è un visitatore all'ingresso." |
| 1 | `1-close-door.wav` | "Attenzione, la porta è rimasta aperta. Chiudere la porta, per favore." |
| 2 | `2-door-forced.wav` | "Allarme. Porta forzata." |

`3-surveillance.wav` and `4-one-at-a-time.wav` are spares and not used in the lab.

Participants upload the clips themselves in Part 2.4, so remove any existing clips from the C1410 first if you want the indexes to be 0, 1, 2.

### 2.4 AXIS Camera Station Pro and the A1601

1. Add the A1601 to ACS Pro and configure the door **AEC main** with a lock (or an LED on the lock output) and a **door position sensor**. Door open too long and Door forced only fire with a door position sensor.
2. Set **Open-too-long time** short (around 10 seconds) so the demo doesn't take long.
3. Create the Windows/ACS Pro account participants use for the External HTTPS trigger. It needs permission for the trigger.
4. Check the ACS Pro server certificate:
   - Export the CA (**Configuration → Security → Certificates → Certificate authority → Export → Without the private key**) and put it on a USB stick or share.
   - The server certificate is usually issued for the server's hostname. If participants connect by IP, Node-RED rejects the certificate with an `altnames` error. Either use the hostname in the URL, or have participants set **Server Name** in the Node-RED TLS configuration to the name in the certificate. Test this in the dry run.

### 2.5 Simulator

[instructor/simulator-flow.json](instructor/simulator-flow.json) simulates the two inputs, so you can test the flow without the intercom or ACS Pro:

- **Intercom: Calling / Active / Idle** publish Call/State messages in the Axis event format on `axis/intercom/B8A44F0B1CF0/event/tns:axis/Call/State`.
- **ACS: door open too long / door forced** send HTTP POSTs to `http://127.0.0.1:1880/acs/...`, exactly like the ACS Pro action rules.

Import it into the same Node-RED as the lab flow.

### 2.6 Dry run

On one workstation, import the reference solution and run the seven tests in section 6 of the guide with the real devices:

1. Import [solution/part4-5-smart-entrance.json](solution/part4-5-smart-entrance.json) (Parts 1-3 are in the same folder).
2. Replace `C1410_IP` and `ACS_PRO_IP`, enter credentials in every HTTP Request node, and upload the ACS Pro CA in the **ACS Pro CA** TLS configuration.
3. Run the tests.
4. Reset the workstation afterwards (see 3.1).

The reference solution was tested in Node-RED 4.1 with Dashboard 2.0 against the simulator and a mock speaker. The ACS Pro HTTPS call itself could not be tested without a server.

### 2.7 Cards

Fill in [instructor/participant-card.md](instructor/participant-card.md) for each group and print it.

---

## 3. During the session

- Enforce the lab rule: **Deploy → generate an event → check Debug** after every block.
- If a group falls behind, help them catch up from the reference solution in [solution/](solution).
- If the intercom or ACS Pro fails, switch to the simulator: the messages are identical.

### 3.1 Reset between sessions

On each workstation: `Reset_Workshop.bat` (Windows) or `./reset_workshop.sh` (macOS/Linux). This deletes all participant flows and restores the starter flow.

ACS Pro action rules created by participants are **not** reset by this. Remove them in ACS Pro between sessions.

---

## 4. Corrections made to the lab document

The guides in this repo are based on *AXIS_Bootcamp_Integration_Workshop.docx*, with these fixes. Apply them to the Word file too if you hand it out.

| Section | Problem in the document | Fix |
|---|---|---|
| 4.10 | The trigger URL code contains `'HYPERLINK "https://" https://'`, a Word hyperlink artifact. Pasted as is, the URL is invalid. | `msg.url = 'https://' + host + ':29204/Acs/Api/TriggerFacade/PulseTrigger?' + JSON.stringify({ triggerName });` |
| 3 | Sections are numbered 3.1, 3.2, 3.4, 3.3: the wildcard exercise comes before the subscriber it modifies. | Subscriber is 3.3, wildcards 3.4. |
| 0.1 | Broker `127.0.0.1 / localhost`. The intercom can't reach the broker at its own localhost. | Broker IP = the Node-RED machine's IP. |
| 4.5 | The explanation of "stop after first match" is written twice. | Merged into one paragraph. |
| 4.10 | "Se Basic restituisce 401..." appears twice. | Removed the duplicate. |
| 5.2 | "Aggiungi un nodo ui-page": in Dashboard 2.0, ui-page is a configuration node, not a palette node. | Created from a widget's **Group** field. |
| 4.9 | Several groups using the same trigger name `UnlockDoor` on one ACS Pro server would collide. | Name from the card, unique per group. |
| 2.3 | Files named `01_Doorbell.mp3` etc. | Uses the prepared `0-doorbell.wav` etc. Rename either side if you prefer MP3. |

---

## 5. Notes on the theory deck

- **Slide 40** shows `/axis-cgi/eventstream.cgi`. This endpoint does not appear in the VAPIX documentation. Real-time events are available through MQTT (used in this lab), the WebSocket event stream (`/vapix/ws-data-stream`), RTSP metadata, or ONVIF pull-point subscriptions.
- The lab uses the same debugging sequences as slides 15 and 26.

---

## 6. Repository contents

| Path | Purpose |
|---|---|
| [README.it.md](README.it.md), [README.md](README.md) | Participant guide (Italian, English) |
| [docker-compose.yml](docker-compose.yml), [node-red/](node-red), [mosquitto/](mosquitto) | Node-RED with Dashboard 2.0, Mosquitto broker, starter flow |
| [solution/](solution) | Reference solution for each part (instructor use) |
| [Reset_Workshop.bat](Reset_Workshop.bat), [reset_workshop.sh](reset_workshop.sh) | Reset a workstation to the starter flow |
| [instructor/simulator-flow.json](instructor/simulator-flow.json) | Intercom and ACS Pro simulator |
| [instructor/clips/](instructor/clips), [instructor/make-clips.sh](instructor/make-clips.sh) | Italian audio clips for the C1410 |
| [instructor/participant-card.md](instructor/participant-card.md) | Card template |
