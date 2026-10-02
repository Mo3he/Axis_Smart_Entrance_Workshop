# Axis Device Integration Lab: Smart Entrance

**English** | [Italiano](README.it.md)

Hands-on lab for the course *Integrazione di dispositivi Axis con API, MQTT e Node-RED*.
It follows the 30-minute theory presentation and takes **60 minutes**.

You will connect four Axis devices with Node-RED and build the chain the course is about:

**event → action → visualization**

```text
AXIS I8116-E  (intercom)        ─┐
AXIS A1210    (door controller) ─┼─ MQTT ─► Node-RED ─┬─► AXIS C1410 (plays a sound)   REST
AXIS P1475-LE (camera)          ─┘                    ├─► AXIS A1210 (unlocks a door)  REST
                                                      └─► Dashboard
```

| Device | Role in the lab |
|---|---|
| AXIS I8116-E Network Video Intercom | Someone presses the call button → event |
| AXIS A1210 Network Door Controller | Door opened, held open, forced, access granted/denied → events. Can be unlocked over REST. |
| AXIS P1475-LE Bullet Camera | Person detected by AXIS Object Analytics → event |
| AXIS C1410 Network Mini Speaker | Plays audio clips on request over REST |

---

## Before you start

Everything is already installed and running. You only need:

- A browser with **Node-RED** open at <http://localhost:1880>
- Your **participant card** with device IP addresses, username/password, clip numbers and the door token

Every time this guide shows a placeholder such as `CAMERA_IP` or `C1410_IP`, replace it with the value from your card.

### Agenda

| Time | Part | Topic from the presentation |
|---|---|---|
| 0-5 | [Part 0: Node-RED in 5 minutes](#part-0-node-red-in-5-minutes) | Node-RED |
| 5-15 | [Part 1: REST and authentication](#part-1-rest-and-authentication) | REST API, HTTP codes, Digest |
| 15-25 | [Part 2: Find it in the VAPIX documentation](#part-2-find-it-in-the-vapix-documentation) | VAPIX |
| 25-35 | [Part 3: MQTT](#part-3-mqtt) | Publish/subscribe, topics, QoS |
| 35-48 | [Part 4: Event → action](#part-4-event--action) | Integration logic |
| 48-60 | [Part 5: Visualization](#part-5-visualization) | Dashboard |

Each part follows the same method as the presentation: **Concept → Axis example → Build → Verify**.

> **Falling behind?** Every part has a ready-made flow in the [flows](flows) folder. See [Fallback flows](#fallback-flows).

---

## Part 0: Node-RED in 5 minutes

**Concept.** A Node-RED *flow* is a chain of *nodes* connected by *wires*. A message (`msg`) travels from left to right. Its main content is `msg.payload`.

**Build.**

1. Open <http://localhost:1880>. You are on the **Lab** tab.
2. From the palette on the left (category *common*), drag an **inject** node onto the canvas.
3. Drag a **debug** node to the right of it.
4. Connect them: drag from the small grey square on the right of *inject* to the square on the left of *debug*.
5. Click the red **Deploy** button (top right).
6. Open the **Debug** sidebar (the bug icon on the right).
7. Click the square button on the left side of the *inject* node.

**Verify.** A number (a timestamp) appears in the Debug sidebar. That is `msg.payload`.

> Remember: **nothing changes until you click Deploy.**

---

## Part 1: REST and authentication

**Concept.** A REST call is a request (method + URL + headers + body) and a response (status code + body). Axis devices normally use **HTTP Digest** authentication.

**Axis example.** `param.cgi` reads device parameters:

```text
GET http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand
```

### 1.1 Try it in the browser

1. Open a new browser tab and go to `http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand`
2. Log in with the username and password from your card.
3. You get plain text lines, for example `root.Brand.ProdNbr=P1475-LE`.

### 1.2 Same call from Node-RED

1. Drag an **inject** node, name it `Read device info`.
2. Drag an **http request** node (category *network*) and double-click it:
   - **Method**: `GET`
   - **URL**: `http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand`
   - Tick **Use authentication**, **Type**: `digest authentication`
   - **Username** / **Password**: from your card
   - **Return**: `a UTF-8 string`
   - **Name**: `GET param.cgi (camera)`
3. Drag a **debug** node, set **Output** to `complete msg object`.
4. Wire inject → http request → debug, then **Deploy** and click the inject button.

**Verify.** In the Debug sidebar, expand the message: `statusCode` is **200** and `payload` contains the `root.Brand...` lines.

### 1.3 Break it on purpose

Read the status code first, then the body (as in the presentation).

| Change | Expected result | What it tells you |
|---|---|---|
| Untick **Use authentication**, Deploy, inject | `statusCode: 401` | Credentials missing or wrong |
| Change `param.cgi` to `paramm.cgi` | `statusCode: 404` | Wrong endpoint |
| Restore both | `statusCode: 200` | |

### 1.4 Read something else

Change `group=Brand` to `group=Properties.Firmware` and inject again. You now see the firmware version.

**Debugging order for REST:** network → URL → authentication → method → payload → response.

> **Extra (if you have time):** add a **function** node between http request and a new debug node to turn the text into an object. The code is in [flows/part1-rest.json](flows/part1-rest.json) (node *Text to object*).

---

## Part 2: Find it in the VAPIX documentation

**Concept.** You don't need to know every endpoint by heart. You need to know how to **look it up**.

**Your task.** Make the **C1410** speaker play a sound.

### 2.1 Search the documentation

1. Open <https://developer.axis.com/vapix/> and search for **Media clip API**.
2. Find the answers to these questions:
   - How do I **list** the clips stored on the device? *(Hint: you already know this CGI from Part 1.)*
   - How do I **play** a clip? Which **method** and which **parameter**?
   - Which **authentication** and **user level** are required?

### 2.2 List the clips

1. Build inject → http request → debug, as in Part 1:
   - **URL**: `http://C1410_IP/axis-cgi/param.cgi?action=list&group=MediaClip`
   - Digest authentication with the credentials from your card
2. Deploy and inject.

**Verify.** You see lines such as `root.MediaClip.M0.Name=...`. The number after `M` is the **clip number**. Compare it with your card.

### 2.3 Play a clip

1. Build a second inject → http request → debug:
   - **URL**: `http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip=0`
   - Digest authentication
   - Debug **Output**: `complete msg object`
2. Deploy and inject.

**Verify.** The speaker plays the doorbell sound and the response starts with `OK`.

Now try a clip number that does not exist (for example `clip=9`). Look at the status code and the body: the device tells you what went wrong.

---

## Part 3: MQTT

**Concept.** Devices **publish** messages to a **broker** on a **topic**. Node-RED **subscribes** to the topics it is interested in. Publisher and subscriber don't know each other.

**Axis example.** The devices in this room publish to these topics:

| Topic | Payload example | Published when |
|---|---|---|
| `lab/entrance/intercom` | `{"device":"I8116-E","event":"call"}` | Someone presses the call button |
| `lab/entrance/door` | `{"device":"A1210","event":"open"}` | Door opens (`open`), closes (`closed`), is held open too long (`held_open`), is forced (`forced`), access is granted (`access_granted`) or denied (`access_denied`) |
| `lab/entrance/camera` | `{"device":"P1475-LE","event":"person"}` | The camera detects a person in the entrance area |

### 3.1 Subscribe to everything

1. Drag an **mqtt in** node (category *network*) and double-click it:
   - **Server**: `Workshop broker` (already configured, just select it)
   - **Action**: `Subscribe to single topic`
   - **Topic**: `lab/#`
   - **QoS**: `1`
   - **Output**: `auto-detect (parsed JSON object, string or buffer)`
   - **Name**: `All lab events`
2. Wire it to a **debug** node with **Output** `complete msg object`.
3. Deploy.

**Verify.** The mqtt in node shows a green **connected** status.

### 3.2 Make some events

Press the call button on the **intercom**, open the **door**, or walk in front of the **camera**. (If the devices are busy, the instructor can send simulated events.)

**Verify.** Each message shows `topic` and a `payload` that is already an object (you can expand it).

### 3.3 Play with wildcards

| Topic filter | Receives |
|---|---|
| `lab/#` | Everything under `lab/` |
| `lab/entrance/door` | Only door events |
| `lab/+/door` | Door events from any site (`+` = exactly one level) |

Change the topic, Deploy, and watch the difference.

### 3.4 Optional: raw Axis events

Change the topic to `axis/#`. These are the devices' own events, published with their serial number in the topic. Compare them with the `lab/...` messages: **a good naming convention makes integration much easier**. Change the topic back to `lab/#` afterwards, because raw events are very verbose.

**Debugging order for MQTT:** broker → topic → message → subscriber.

---

## Part 4: Event → action

**Concept.** Separate the steps: **receive** (mqtt in), **decide** (switch), **prepare** (change), **act** (http request).

**Goal.**

| Event | Action on the C1410 |
|---|---|
| `call` (intercom) | Play clip 0: doorbell |
| `held_open` (door) | Play clip 1: "please close the door" |
| `forced` (door) | Play clip 2: "door forced" alarm |

Check the clip numbers on your card.

### 4.1 Receive

Drag an **mqtt in** node: Server `Workshop broker`, Topic `lab/entrance/#`, QoS `1`, Output `auto-detect`, Name `Entrance events`.

### 4.2 Decide

1. Drag a **switch** node (category *function*), wire it after mqtt in, and double-click it:
   - **Name**: `Which event?`
   - **Property**: `msg.payload.event`
   - Rules (use **+ add** at the bottom):
     1. `==` `call`
     2. `==` `held_open`
     3. `==` `forced`
   - At the bottom, select **stopping after first match**
2. The switch now has **3 outputs**, one per rule.

### 4.3 Prepare

Drag three **change** nodes, one per switch output. In each one, set **Set** `msg.clip` **to the value** (type `number`):

| Change node name | Set `msg.clip` to |
|---|---|
| `Clip 0: doorbell` | `0` |
| `Clip 1: close the door` | `1` |
| `Clip 2: door forced` | `2` |

### 4.4 Act

1. Drag **one** http request node and wire all three change nodes into it:
   - **Method**: `GET`
   - **URL**: `http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip={{{clip}}}`
   - Digest authentication with the credentials from your card
   - **Name**: `Play clip (C1410)`
2. Add a **debug** node after it and **Deploy**.

`{{{clip}}}` is replaced with the value of `msg.clip` when the message arrives. This way one HTTP node can play any clip.

**Verify.** Press the intercom call button: your speaker plays the doorbell. Keep the door open: after a few seconds you hear "please close the door".

> All groups share the same intercom and door, so every speaker in the room will react. That is publish/subscribe in action: one publisher, many subscribers.

---

## Part 5: Visualization

**Concept.** The dashboard shows the result to the user. Build it only **after** you have verified the input in the debug panel.

The dashboard page **Entrance** with two groups (**Door** and **Events**) is already prepared. You only add widgets.

### 5.1 Show the last door event

1. **mqtt in**: Topic `lab/entrance/door`, Server `Workshop broker`, Output `auto-detect`.
2. **change**: **Set** `msg.payload` **to** `msg.payload.event` (type `msg.`). Name it `Keep only the event name`.
3. **text** widget (category *dashboard 2*):
   - **Group**: `[Entrance] Door`
   - **Label**: `Last door event`
4. Wire mqtt in → change → text.

### 5.2 Unlock the door from the dashboard

The A1210 uses the VAPIX **Door Control** service. You send a JSON body with **POST**:

```text
POST http://A1210_IP/vapix/doorcontrol
{"tdc:AccessDoor":{"Token":"DOOR_TOKEN"}}
```

`AccessDoor` unlocks the door for a short time, like a valid card would.

1. **button** widget (category *dashboard 2*):
   - **Group**: `[Entrance] Door`
   - **Label**: `Unlock door`
   - **Payload**: type `{} JSON`, value `{"tdc:AccessDoor":{"Token":"DOOR_TOKEN"}}` (token from your card)
2. **http request**:
   - **Method**: `POST`
   - **URL**: `http://A1210_IP/vapix/doorcontrol`
   - Digest authentication with the credentials from your card
   - **Return**: `a UTF-8 string`
3. **debug** after it.
4. Wire button → http request → debug.

### 5.3 Event log

1. **mqtt in**: Topic `lab/#`, Server `Workshop broker`, Output `auto-detect`.
2. **function** node named `Add to event log`, with this code:

   ```javascript
   const log = flow.get('log') || [];
   log.unshift({
       time: new Date().toLocaleTimeString('it-IT'),
       device: msg.payload.device,
       event: msg.payload.event
   });
   msg.payload = log.slice(0, 10);
   flow.set('log', msg.payload);
   return msg;
   ```

   The function keeps the last 10 events in **flow context** (memory shared by the nodes on this tab) and sends the whole list on.

3. **table** widget (category *dashboard 2*):
   - **Group**: `[Entrance] Events`
   - **Action**: `Replace`
4. Wire mqtt in → function → table and **Deploy**.

### 5.4 Open the dashboard

Go to <http://localhost:1880/dashboard>.

**Verify.**

- Click **Unlock door**: the lock clicks, the debug sidebar shows `statusCode: 200`.
- Open the door: *Last door event* changes to `open`, then `closed`.
- Every event appears in the table.

**You have built the full chain: event → action → visualization.**

---

## Fallback flows

If a part does not work and time is running out, import the finished flow and continue with the next part.

1. Node-RED menu (☰, top right) → **Import** → **select a file to import**
2. Choose the file from the [flows](flows) folder:

   | Part | File |
   |---|---|
   | 1 | [part1-rest.json](flows/part1-rest.json) |
   | 2 | [part2-vapix.json](flows/part2-vapix.json) |
   | 3 | [part3-mqtt.json](flows/part3-mqtt.json) |
   | 4 | [part4-event-action.json](flows/part4-event-action.json) |
   | 5 | [part5-dashboard.json](flows/part5-dashboard.json) |

3. Click **Import**. The flow opens on a new tab.
4. Open every **http request** node and:
   - Replace the placeholder (`CAMERA_IP`, `C1410_IP`, `A1210_IP`) with the IP address from your card
   - Enter the **username** and **password** (passwords are never stored in exported flows)
5. In Part 5, also replace `DOOR_TOKEN` in the **Unlock door** button.
6. **Deploy**.

> If two tabs subscribe to the same topic, both react. Right-click a tab you don't need → **Disable**, then Deploy.

---

## Bonus (if you finish early, or after the course)

### B1. Camera deterrence

Add a fourth rule `== person` to the **Which event?** switch, and a change node that sets `msg.clip` to `3` ("this area is under video surveillance").

### B2. Tailgating detection

A valid access lets **one** person in. If the camera sees two people within 10 seconds after `access_granted`, someone followed without a card. Add a function node after `Entrance events`:

```javascript
const now = Date.now();
if (msg.payload.event === 'access_granted') {
    flow.set('grantedAt', now);
    flow.set('people', 0);
    return null;
}
if (msg.payload.event === 'person' && now - (flow.get('grantedAt') || 0) < 10000) {
    const people = (flow.get('people') || 0) + 1;
    flow.set('people', people);
    if (people === 2) {
        msg.clip = 4;
        return msg;
    }
}
return null;
```

Wire its output to **Play clip (C1410)**. Clip 4 is "one person at a time, please".

### B3. Bridge to the OT world (Modbus / OPC UA)

The presentation covered Modbus and OPC UA. Node-RED can act as a gateway between the two worlds:

1. ☰ → **Manage palette** → **Install** `node-red-contrib-modbus` (needs internet access).
2. Add a **Modbus-Flex-Server** node (a simulated PLC).
3. Write the door state into holding register 0 (`1` = open, `0` = closed) with a **Modbus-Write** node.
4. Read it back with a **Modbus-Read** node, as a building management system would.

The same idea works with OPC UA (`node-red-contrib-opcua`).

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `statusCode: 401` | Username/password, and **Type** must be `digest authentication` |
| `statusCode: 404` | URL path (typos, `axis-cgi` vs `vapix`) |
| `statusCode: 400` | Parameters or JSON body (for example a wrong clip number or door token) |
| Request times out / `ECONNREFUSED` / `EHOSTUNREACH` | Device IP address and network |
| mqtt in shows **disconnected** | Server must be `Workshop broker`. Ask the instructor if the broker is running. |
| mqtt in is **connected** but no messages | Topic filter (`lab/#`), then generate an event |
| `msg.payload.event` is `undefined` | **Output** of mqtt in must be `auto-detect` (parsed JSON) |
| Speaker does not play | Clip number on your card, and test the URL from Part 2 |
| Dashboard shows nothing | Did you click **Deploy**? Is the widget in the right **Group**? |
| Two tabs react to the same event | Disable the tab you don't need (right-click the tab → Disable) |

---

## Reference

### API calls used in this lab

| Purpose | Method | Endpoint | VAPIX documentation |
|---|---|---|---|
| Read parameters | GET | `/axis-cgi/param.cgi?action=list&group=<group>` | Parameter management |
| List audio clips | GET | `/axis-cgi/param.cgi?action=list&group=MediaClip` | [Media clip API](https://developer.axis.com/vapix/audio-systems/media-clip-api/) |
| Play an audio clip | GET | `/axis-cgi/mediaclip.cgi?action=play&clip=<n>` | [Media clip API](https://developer.axis.com/vapix/audio-systems/media-clip-api/) |
| Momentary door unlock | POST | `/vapix/doorcontrol` with `{"tdc:AccessDoor":{"Token":"<token>"}}` | [Door control service](https://developer.axis.com/vapix/physical-access-control/door-control-service/) |

### MQTT topics

| Topic | `device` | `event` values |
|---|---|---|
| `lab/entrance/intercom` | `I8116-E` | `call` |
| `lab/entrance/door` | `A1210` | `open`, `closed`, `held_open`, `forced`, `access_granted`, `access_denied` |
| `lab/entrance/camera` | `P1475-LE` | `person` |

---

Instructors: see [INSTRUCTOR.md](INSTRUCTOR.md) for preparation.
