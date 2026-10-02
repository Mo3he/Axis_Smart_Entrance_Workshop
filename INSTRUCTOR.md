# Instructor guide

Preparation and running notes for the 60-minute lab that follows the 30-minute presentation *12 - Integrazione di dispositivi* (90 minutes in total).

The participant guide is [README.md](README.md) (English) and [README.it.md](README.it.md) (Italian).

---

## 1. Setup at a glance

```text
                       lab network (isolated)
   ┌───────────────────────────────────────────────────────────┐
   │  Instructor laptop        Workstations (1 per group)      │
   │  - Mosquitto :1883        - Node-RED + Dashboard :1880    │
   │  - Node-RED (simulator)                                   │
   │                                                           │
   │  Shared devices                    One per group          │
   │  - AXIS P1475-LE  (camera)         - AXIS C1410 (speaker) │
   │  - AXIS I8116-E   (intercom)                              │
   │  - AXIS A1210     (door controller + lock/LED + contact)  │
   └───────────────────────────────────────────────────────────┘
```

- **Shared devices** publish events to the broker. Every group subscribes to the same topics.
- **Each group has its own C1410** and plays clips on it. When the intercom rings, every speaker in the room reacts. That is intended: it shows that one publisher can have many subscribers.
- Participants call devices directly over HTTP from their workstation, so workstations must reach every device on port 80. Devices must reach the broker on port 1883.

### Hardware checklist

| Item | Qty | Notes |
|---|---|---|
| AXIS P1475-LE | 1 | Pointed at the "entrance" area, AXIS Object Analytics enabled |
| AXIS I8116-E | 1 | Call button used as event source |
| AXIS A1210 | 1 | With a lock **or an LED/buzzer** on the lock output, so unlocking is visible, and a **door contact** (reed switch, or a switch on the door monitor input) so `open`/`closed`/`held_open`/`forced` can be triggered on a desk |
| AXIS C1410 | 1 per group | |
| PoE switch | 1 | All on one isolated network |
| Workstations | 1 per group | Docker Desktop installed |
| Instructor laptop | 1 | Docker Desktop installed |

---

## 2. Preparation (the day before)

### 2.1 Broker (instructor laptop)

```sh
cd instructor
docker compose up -d
```

Note the laptop's IP address on the lab network. This is `BROKER_HOST` everywhere below.

> The broker allows anonymous connections without TLS. That is acceptable **only** on an isolated lab network. In production, use TLS and authentication on the broker and on the devices (a good point to make during the MQTT part of the presentation).

### 2.2 Workstations

On every workstation (needs internet access the first time, to pull and build the image):

```sh
git clone https://github.com/Mo3he/Axis_Smart_Entrance_Workshop
cd Axis_Smart_Entrance_Workshop
cp .env.example .env        # Windows: copy .env.example .env
# edit .env: BROKER_HOST=<instructor laptop IP>
docker compose up -d --build
```

Open <http://localhost:1880>. You should see the **Lab** tab with the comment *Start here*.

To verify the broker connection: import [flows/part3-mqtt.json](flows/part3-mqtt.json), Deploy, and check that the mqtt in node shows **connected**. Then run `Reset_Workshop.bat` (or `./reset_workshop.sh`) to return to the clean starter flow.

### 2.3 Device accounts

Create the same account on all devices, for example `lab` with an **Operator** role. Write it on the participant cards.

- `param.cgi` (list) and `mediaclip.cgi` (play) work with Operator.
- If the A1210 rejects `AccessDoor` with 401/403 for an Operator, give the `lab` account Administrator rights **on the A1210 only**.

### 2.4 MQTT on the shared devices

On the **I8116-E**, **A1210** and **P1475-LE**: **System → MQTT → MQTT client**

- **Host**: `BROKER_HOST`, **Port**: `1883`, **Protocol**: MQTT over TCP
- Save, then **Connect**

### 2.5 Event rules that publish the lab topics

Participants use clean, readable topics (`lab/entrance/...`) instead of the raw Axis event topics. Create these rules in **System → Events → Rules → Add a rule**, each with the action **Send MQTT publish message**:

- **Use device topic prefix**: off
- **QoS**: 1
- **Retain**: off

| Device | Condition (pick the matching one in the UI) | Topic | Payload |
|---|---|---|---|
| I8116-E | Call button pressed / call started | `lab/entrance/intercom` | `{"device":"I8116-E","event":"call"}` |
| A1210 | Door monitor: door open | `lab/entrance/door` | `{"device":"A1210","event":"open"}` |
| A1210 | Door monitor: door closed (inverted "open" condition) | `lab/entrance/door` | `{"device":"A1210","event":"closed"}` |
| A1210 | Door alarm: door open too long | `lab/entrance/door` | `{"device":"A1210","event":"held_open"}` |
| A1210 | Door alarm: door forced open | `lab/entrance/door` | `{"device":"A1210","event":"forced"}` |
| A1210 | Access granted | `lab/entrance/door` | `{"device":"A1210","event":"access_granted"}` |
| A1210 | Access denied | `lab/entrance/door` | `{"device":"A1210","event":"access_denied"}` |
| P1475-LE | AXIS Object Analytics scenario (Object in area, Human) | `lab/entrance/camera` | `{"device":"P1475-LE","event":"person"}` |

Condition names vary by device and AXIS OS version. In the VAPIX door control model these are the `DoorPhysicalState` (Open/Closed) and `DoorAlarm` (DoorForcedOpen/DoorOpenTooLong) events. Verify each rule by watching `lab/#` in MQTT Explorer or in the simulator Node-RED.

**Payloads must be valid JSON** with exactly these keys and values. The participant flows switch on `msg.payload.event`.

### 2.6 Optional: raw event publication (Part 3.4)

To let participants compare the clean topics with native Axis events, enable **MQTT → Event publication** on one or two devices with a few conditions. They appear under `axis/<serial>/event/...`. Keep the list short, because raw events are verbose.

### 2.7 A1210 door

1. Configure one door with a lock (or an LED) and a door monitor input.
2. Set **Open too long time** to about **10 seconds**, so the `held_open` demo doesn't take long.
3. Read the door token and write it on the cards as `DOOR_TOKEN`:

   ```sh
   curl --anyauth -u lab:PASSWORD -s \
     -H "Content-Type: application/json" \
     -d '{"tdc:GetDoorInfoList":{}}' \
     http://A1210_IP/vapix/doorcontrol
   ```

   The response contains `"DoorInfo":[{"token":"...", "Name":"..."}]`.

4. Test the unlock call used in Part 5:

   ```sh
   curl --anyauth -u lab:PASSWORD -s \
     -H "Content-Type: application/json" \
     -d '{"tdc:AccessDoor":{"Token":"DOOR_TOKEN"}}' \
     http://A1210_IP/vapix/doorcontrol
   ```

   An empty JSON object means success, and the lock output switches.

Reference: [Door control service](https://developer.axis.com/vapix/physical-access-control/door-control-service/). The A1210 is listed as supporting `/vapix/doorcontrol`.

### 2.8 C1410 audio clips

Five Italian clips are ready in [instructor/clips](instructor/clips). They were generated with the macOS Italian voice; [instructor/make-clips.sh](instructor/make-clips.sh) regenerates them.

| Clip | File | Text | Meaning |
|---|---|---|---|
| 0 | `0-doorbell.wav` | "Din don. C'è un visitatore all'ingresso." | Ding dong, a visitor is at the entrance |
| 1 | `1-close-door.wav` | "Attenzione, la porta è rimasta aperta. Chiudere la porta, per favore." | The door was left open, please close it |
| 2 | `2-door-forced.wav` | "Allarme. Porta forzata." | Alarm, door forced |
| 3 | `3-surveillance.wav` | "Attenzione. Quest'area è videosorvegliata." | This area is under video surveillance |
| 4 | `4-one-at-a-time.wav` | "Una persona alla volta, per favore." | One person at a time, please |

On **every C1410**: **Audio → Audio clips → Add clip**, upload the files **in order 0 to 4** on a device with no other clips. Then confirm the numbering:

```text
http://C1410_IP/axis-cgi/param.cgi?action=list&group=MediaClip
```

`MediaClip.M0` must be the doorbell, `M1` "close the door", and so on. If a speaker already has clips, either remove them first or write the actual numbers on that group's card.

### 2.9 Simulator

The simulator publishes the same messages as the real devices. Use it for testing, and during the lab when a device is busy or broken.

1. On the instructor laptop, also start the participant stack with `BROKER_HOST` set to the laptop's own LAN IP (not `localhost`, because Node-RED runs inside a container):

   ```sh
   docker compose up -d --build
   ```

2. Import [instructor/simulator-flow.json](instructor/simulator-flow.json) and Deploy.
3. Click the inject buttons (*Intercom: call*, *Door: held open*, ...) or *Random events: start* for a stream every 8 seconds.

### 2.10 Dry run

On one workstation, import all five fallback flows, fill in IPs, credentials and the door token, then test every part with the real devices. Run `Reset_Workshop.bat` afterwards.

### 2.11 Cards

Fill in [instructor/participant-card.md](instructor/participant-card.md) for each group and print it.

---

## 3. During the session

| Time | Part | Instructor |
|---|---|---|
| 0-5 | Part 0 | Check that everyone has Node-RED open and has deployed once |
| 5-15 | Part 1 | Make sure everyone gets a **401** on purpose. It is the most useful error to recognize. |
| 15-25 | Part 2 | Let them search the docs for 2-3 minutes before giving the hint |
| 25-35 | Part 3 | Press the intercom button and open the door for the room, or use the simulator |
| 35-48 | Part 4 | Trigger `call`, `held_open` and `forced` several times so every group can test |
| 48-60 | Part 5 | Point groups that fall behind to the fallback flows |

Tips:

- If a group is more than 5 minutes behind, have them import the fallback flow for the current part instead of debugging.
- Speakers will all play at once in Part 4. Lower the C1410 volume beforehand.
- If a device fails, switch to the simulator: participants can't tell the difference, because the topics and payloads are identical.

### Reset between sessions

On each workstation: `Reset_Workshop.bat` (Windows) or `./reset_workshop.sh` (macOS/Linux). This deletes all participant flows and restores the starter flow with the preconfigured broker and dashboard.

---

## 4. Notes on the theory deck

- **Slide 40** shows `/axis-cgi/eventstream.cgi`. This endpoint does not appear in the VAPIX documentation. Real-time events are available through MQTT (used in this lab), the WebSocket event stream (`/vapix/ws-data-stream`), RTSP metadata, or ONVIF pull-point subscriptions. Correct it before the session, otherwise participants will search for it during Part 2.
- **Timing:** 52 slides in 30 minutes is about 35 seconds per slide. The OPC UA/Modbus section (slides 27-35) is only used in bonus B3. Shortening it to 2-3 slides leaves more time for REST and MQTT, which the lab depends on.
- The lab uses the same debugging sequences as slides 15 and 26, so you can refer back to them when participants get stuck.

---

## 5. Repository contents

| Path | Purpose |
|---|---|
| [README.md](README.md), [README.it.md](README.it.md) | Participant guide (English, Italian) |
| [docker-compose.yml](docker-compose.yml), [node-red/](node-red) | Participant Node-RED with Dashboard 2.0 and the preconfigured starter flow |
| [flows/](flows) | Fallback flow for each part |
| [Reset_Workshop.bat](Reset_Workshop.bat), [reset_workshop.sh](reset_workshop.sh) | Reset a workstation to the starter flow |
| [instructor/docker-compose.yml](instructor/docker-compose.yml) | Mosquitto broker |
| [instructor/simulator-flow.json](instructor/simulator-flow.json) | Event simulator |
| [instructor/clips/](instructor/clips), [instructor/make-clips.sh](instructor/make-clips.sh) | Italian audio clips for the C1410 |
| [instructor/participant-card.md](instructor/participant-card.md) | Card template |
