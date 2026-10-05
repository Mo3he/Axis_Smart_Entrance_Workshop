# Instructor guide

Preparation and running notes for the 60-minute lab that follows the presentation *12 - Integrazione di dispositivi*.

The participant guide is [README.it.md](README.it.md) (Italian, primary for the session) and [README.md](README.md) (English translation). Both follow the lab document *AXIS_Bootcamp_Integration_Workshop.docx*.

---

## 1. Setup at a glance

```text
                              lab network (isolated)
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ Per group (4+ groups):                                                   │
 │   Windows workstation with Docker Desktop                                │
 │     - Node-RED + Dashboard 2.0 :1880  (receives ACS Pro HTTP POSTs)      │
 │     - Mosquitto broker         :1883  (receives this group's intercom)   │
 │   AXIS I8116-E  ── MQTT ──► this group's broker                          │
 │   AXIS C1410                                                             │
 │                                                                          │
 │ Shared                                                                   │
 │   - AXIS Camera Station Pro server                                       │
 │   - AXIS A1601 ── door "AEC main"                                        │
 │   - AXIS P1475-LE (camera for Part 1)                                    │
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

### 1.1 Running 4+ groups

Each group has its own intercom and C1410 and its own Node-RED + broker, so Parts 0-3 are fully independent. Only ACS Pro and the A1601 door are shared:

- **Intercom:** each group points its I8116-E at its own workstation IP (Part 3.1). Leave `BROKER_HOST` unset in `.env`.
- **Door events:** every group creates its own *Door open too long* and *Door forced* rules, each sending to its own `NODE_RED_IP`. One door event therefore reaches every group at the same time, and every C1410 in the room reacts. That is expected, and a good illustration of one event with many subscribers.
- **Unlock trigger:** External HTTPS trigger names must be unique on the server. Each group uses `UnlockDoor_G<n>` (on the card).
- **Rule names:** each group prefixes its rules with `G<n> -` so you can find and delete them afterwards.
- **Who opens the door:** only the instructor (or one person) triggers the physical door events in Part 4, announced to the room, so groups aren't testing over each other.

### 1.2 Timing

Participants create the ACS Pro rules themselves (four action rules, CA import, TLS setup), which is a lot for 60 minutes. Time Part 4 in the dry run. If it doesn't fit, fall back to one of these on the day:

- Hand out the exported CA file at the start instead of having each group export it.
- Have groups that fall behind import [solution/part4-5-smart-entrance.json](solution/part4-5-smart-entrance.json) and only fill in IPs, credentials and the CA.

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

Then check that the ports are reachable **from another machine** (Windows Defender Firewall may block them). In PowerShell on a second PC:

```powershell
Test-NetConnection <workstation IP> -Port 1880
Test-NetConnection <workstation IP> -Port 1883
```

Both must show `TcpTestSucceeded : True`. If not, allow inbound TCP 1880 and 1883 in Windows Defender Firewall on the workstation.

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

Participants upload the clips to their own C1410 in Part 2.4, so remove any existing clips from every C1410 first if you want the indexes to be 0, 1, 2. Put the three files on each workstation (for example on the desktop).

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

### 2.6 Dry run checklist

The reference solution was tested in Node-RED 4.1 with Dashboard 2.0 against the simulator and a mock speaker. These parts can only be verified with the real hardware, so check them first:

- [ ] The I8116-E publishes `Call/State` with the expected topic, and the payload path is `msg.payload.message.data.CallState` (Part 3).
- [ ] ACS Pro *Send HTTP Notification* with method POST reaches `http://<workstation>:1880/acs/...` and gets a 200 back (Parts 4.2-4.4).
- [ ] The External HTTPS trigger works from Node-RED: CA accepted, hostname or **Server Name** correct, Basic or Digest authentication (Part 4.10).
- [ ] Two groups with their own `UnlockDoor_G<n>` triggers can both unlock AEC main.
- [ ] Time a full run of Part 4 by someone who hasn't seen it before.

Then run the full acceptance test on one workstation:

1. Import [solution/part4-5-smart-entrance.json](solution/part4-5-smart-entrance.json) (Parts 1-3 are in the same folder).
2. Replace `C1410_IP`, `ACS_PRO_IP` and the trigger name, enter credentials in every HTTP Request node, and upload the ACS Pro CA in the **ACS Pro CA** TLS configuration.
3. Run the seven tests in section 6 of the guide.
4. Reset the workstation afterwards (see 3.1) and delete the test rules in ACS Pro.

### 2.7 Cards

Fill in [instructor/participant-card.md](instructor/participant-card.md) for each group and print it.

---

## 3. During the session

- Enforce the lab rule: **Deploy → generate an event → check Debug** after every block.
- If a group falls behind, help them catch up from the reference solution in [solution/](solution).
- If the intercom or ACS Pro fails, switch to the simulator: the messages are identical.

### 3.1 Reset between sessions

On each workstation: `Reset_Workshop.bat` (Windows) or `./reset_workshop.sh` (macOS/Linux). This deletes all participant flows and restores the starter flow.

ACS Pro action rules created by participants are **not** reset by this. Remove them in ACS Pro between sessions: they all start with `G<n> -`.

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
| 4.9 | Several groups using the same trigger name `UnlockDoor` on one ACS Pro server would collide. | `UnlockDoor_G<n>` from the card, unique per group. Rule names prefixed with `G<n> -`. |
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
