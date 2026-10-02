# Laboratorio di integrazione dispositivi Axis: Ingresso intelligente

[English](README.md) | **Italiano**

Laboratorio pratico del corso *Integrazione di dispositivi Axis con API, MQTT e Node-RED*.
Segue i 30 minuti di presentazione teorica e dura **60 minuti**.

Collegherai quattro dispositivi Axis con Node-RED e costruirai la catena di cui parla il corso:

**evento → azione → visualizzazione**

```text
AXIS I8116-E  (citofono)           ─┐
AXIS A1210    (controller porta)   ─┼─ MQTT ─► Node-RED ─┬─► AXIS C1410 (riproduce un suono)  REST
AXIS P1475-LE (telecamera)         ─┘                    ├─► AXIS A1210 (sblocca la porta)    REST
                                                         └─► Dashboard
```

| Dispositivo | Ruolo nel laboratorio |
|---|---|
| AXIS I8116-E Network Video Intercom | Qualcuno preme il pulsante di chiamata → evento |
| AXIS A1210 Network Door Controller | Porta aperta, lasciata aperta, forzata, accesso consentito/negato → eventi. Può essere sbloccata via REST. |
| AXIS P1475-LE Bullet Camera | Persona rilevata da AXIS Object Analytics → evento |
| AXIS C1410 Network Mini Speaker | Riproduce clip audio su richiesta via REST |

---

## Prima di iniziare

È già tutto installato e in funzione. Ti servono solo:

- Un browser con **Node-RED** aperto su <http://localhost:1880>
- La tua **scheda partecipante** con indirizzi IP dei dispositivi, username/password, numeri delle clip e token della porta

Ogni volta che la guida mostra un segnaposto come `CAMERA_IP` o `C1410_IP`, sostituiscilo con il valore riportato sulla scheda.

> L'interfaccia di Node-RED è in inglese: i nomi di pulsanti e campi (**Deploy**, **Use authentication**, ...) sono quindi riportati in inglese.

### Programma

| Minuti | Parte | Argomento della presentazione |
|---|---|---|
| 0-5 | [Parte 0: Node-RED in 5 minuti](#parte-0-node-red-in-5-minuti) | Node-RED |
| 5-15 | [Parte 1: REST e autenticazione](#parte-1-rest-e-autenticazione) | API REST, codici HTTP, Digest |
| 15-25 | [Parte 2: Trovarlo nella documentazione VAPIX](#parte-2-trovarlo-nella-documentazione-vapix) | VAPIX |
| 25-35 | [Parte 3: MQTT](#parte-3-mqtt) | Publish/subscribe, topic, QoS |
| 35-48 | [Parte 4: Evento → azione](#parte-4-evento--azione) | Logica di integrazione |
| 48-60 | [Parte 5: Visualizzazione](#parte-5-visualizzazione) | Dashboard |

Ogni parte segue lo stesso metodo della presentazione: **Concetto → Esempio Axis → Configurazione → Verifica**.

> **Sei rimasto indietro?** Ogni parte ha un flow già pronto nella cartella [flows](flows). Vedi [Flow di riserva](#flow-di-riserva).

---

## Parte 0: Node-RED in 5 minuti

**Concetto.** Un *flow* di Node-RED è una catena di *nodi* collegati da *fili*. Un messaggio (`msg`) viaggia da sinistra a destra. Il suo contenuto principale è `msg.payload`.

**Configurazione.**

1. Apri <http://localhost:1880>. Sei nella scheda **Lab**.
2. Dalla palette a sinistra (categoria *common*), trascina un nodo **inject** nell'area di lavoro.
3. Trascina un nodo **debug** alla sua destra.
4. Collegali: trascina dal quadratino grigio a destra di *inject* al quadratino a sinistra di *debug*.
5. Clicca il pulsante rosso **Deploy** (in alto a destra).
6. Apri la barra laterale **Debug** (l'icona a forma di insetto a destra).
7. Clicca il pulsante quadrato sul lato sinistro del nodo *inject*.

**Verifica.** Nella barra Debug compare un numero (un timestamp). Quello è `msg.payload`.

> Ricorda: **nulla cambia finché non clicchi Deploy.**

---

## Parte 1: REST e autenticazione

**Concetto.** Una chiamata REST è una richiesta (metodo + URL + header + body) e una risposta (codice di stato + body). I dispositivi Axis usano normalmente l'autenticazione **HTTP Digest**.

**Esempio Axis.** `param.cgi` legge i parametri del dispositivo:

```text
GET http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand
```

### 1.1 Provalo nel browser

1. Apri una nuova scheda del browser e vai su `http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand`
2. Accedi con username e password della scheda.
3. Ottieni righe di testo semplice, ad esempio `root.Brand.ProdNbr=P1475-LE`.

### 1.2 La stessa chiamata da Node-RED

1. Trascina un nodo **inject** e chiamalo `Read device info`.
2. Trascina un nodo **http request** (categoria *network*) e fai doppio clic:
   - **Method**: `GET`
   - **URL**: `http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand`
   - Spunta **Use authentication**, **Type**: `digest authentication`
   - **Username** / **Password**: dalla scheda
   - **Return**: `a UTF-8 string`
   - **Name**: `GET param.cgi (camera)`
3. Trascina un nodo **debug** e imposta **Output** su `complete msg object`.
4. Collega inject → http request → debug, poi **Deploy** e clicca il pulsante dell'inject.

**Verifica.** Nella barra Debug espandi il messaggio: `statusCode` è **200** e `payload` contiene le righe `root.Brand...`.

### 1.3 Rompilo di proposito

Leggi prima il codice di stato, poi il body (come nella presentazione).

| Modifica | Risultato atteso | Cosa ti dice |
|---|---|---|
| Togli la spunta da **Use authentication**, Deploy, inject | `statusCode: 401` | Credenziali assenti o errate |
| Cambia `param.cgi` in `paramm.cgi` | `statusCode: 404` | Endpoint errato |
| Ripristina entrambe | `statusCode: 200` | |

### 1.4 Leggi qualcos'altro

Cambia `group=Brand` in `group=Properties.Firmware` e premi di nuovo inject. Ora vedi la versione del firmware.

**Ordine di debug per REST:** rete → URL → autenticazione → metodo → payload → risposta.

> **Extra (se hai tempo):** aggiungi un nodo **function** tra http request e un nuovo nodo debug per trasformare il testo in un oggetto. Il codice è in [flows/part1-rest.json](flows/part1-rest.json) (nodo *Text to object*).

---

## Parte 2: Trovarlo nella documentazione VAPIX

**Concetto.** Non serve sapere tutti gli endpoint a memoria. Serve sapere **come cercarli**.

**Il tuo compito.** Far riprodurre un suono allo speaker **C1410**.

### 2.1 Cerca nella documentazione

1. Apri <https://developer.axis.com/vapix/> e cerca **Media clip API**.
2. Trova la risposta a queste domande:
   - Come **elenco** le clip salvate sul dispositivo? *(Suggerimento: conosci già questa CGI dalla Parte 1.)*
   - Come **riproduco** una clip? Con quale **metodo** e quale **parametro**?
   - Quale **autenticazione** e quale **livello utente** sono richiesti?

### 2.2 Elenca le clip

1. Costruisci inject → http request → debug, come nella Parte 1:
   - **URL**: `http://C1410_IP/axis-cgi/param.cgi?action=list&group=MediaClip`
   - Autenticazione digest con le credenziali della scheda
2. Deploy e inject.

**Verifica.** Vedi righe come `root.MediaClip.M0.Name=...`. Il numero dopo `M` è il **numero della clip**. Confrontalo con la scheda.

### 2.3 Riproduci una clip

1. Costruisci un secondo inject → http request → debug:
   - **URL**: `http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip=0`
   - Autenticazione digest
   - **Output** del debug: `complete msg object`
2. Deploy e inject.

**Verifica.** Lo speaker riproduce il campanello e la risposta inizia con `OK`.

Ora prova un numero di clip che non esiste (ad esempio `clip=9`). Guarda il codice di stato e il body: il dispositivo ti dice cosa non va.

---

## Parte 3: MQTT

**Concetto.** I dispositivi **pubblicano** messaggi su un **broker** con un **topic**. Node-RED si **sottoscrive** ai topic che gli interessano. Publisher e subscriber non si conoscono.

**Esempio Axis.** I dispositivi in aula pubblicano su questi topic:

| Topic | Esempio di payload | Pubblicato quando |
|---|---|---|
| `lab/entrance/intercom` | `{"device":"I8116-E","event":"call"}` | Qualcuno preme il pulsante di chiamata |
| `lab/entrance/door` | `{"device":"A1210","event":"open"}` | La porta si apre (`open`), si chiude (`closed`), resta aperta troppo a lungo (`held_open`), viene forzata (`forced`), l'accesso è consentito (`access_granted`) o negato (`access_denied`) |
| `lab/entrance/camera` | `{"device":"P1475-LE","event":"person"}` | La telecamera rileva una persona nell'area d'ingresso |

### 3.1 Sottoscriviti a tutto

1. Trascina un nodo **mqtt in** (categoria *network*) e fai doppio clic:
   - **Server**: `Workshop broker` (già configurato, basta selezionarlo)
   - **Action**: `Subscribe to single topic`
   - **Topic**: `lab/#`
   - **QoS**: `1`
   - **Output**: `auto-detect (parsed JSON object, string or buffer)`
   - **Name**: `All lab events`
2. Collegalo a un nodo **debug** con **Output** `complete msg object`.
3. Deploy.

**Verifica.** Il nodo mqtt in mostra lo stato verde **connected**.

### 3.2 Genera qualche evento

Premi il pulsante di chiamata sul **citofono**, apri la **porta** o passa davanti alla **telecamera**. (Se i dispositivi sono occupati, l'istruttore può inviare eventi simulati.)

**Verifica.** Ogni messaggio mostra il `topic` e un `payload` che è già un oggetto (puoi espanderlo).

### 3.3 Gioca con i caratteri jolly

| Filtro topic | Riceve |
|---|---|
| `lab/#` | Tutto sotto `lab/` |
| `lab/entrance/door` | Solo gli eventi della porta |
| `lab/+/door` | Eventi della porta di qualsiasi sito (`+` = esattamente un livello) |

Cambia il topic, fai Deploy e osserva la differenza.

### 3.4 Facoltativo: eventi Axis "grezzi"

Cambia il topic in `axis/#`. Questi sono gli eventi nativi dei dispositivi, pubblicati con il numero di serie nel topic. Confrontali con i messaggi `lab/...`: **una buona naming convention semplifica molto l'integrazione**. Poi rimetti il topic su `lab/#`, perché gli eventi grezzi sono molto numerosi.

**Ordine di debug per MQTT:** broker → topic → messaggio → subscriber.

---

## Parte 4: Evento → azione

**Concetto.** Separa i passaggi: **ricevere** (mqtt in), **decidere** (switch), **preparare** (change), **agire** (http request).

**Obiettivo.**

| Evento | Azione sul C1410 |
|---|---|
| `call` (citofono) | Riproduci la clip 0: campanello |
| `held_open` (porta) | Riproduci la clip 1: "chiudere la porta, per favore" |
| `forced` (porta) | Riproduci la clip 2: allarme "porta forzata" |

Controlla i numeri delle clip sulla scheda.

### 4.1 Ricevere

Trascina un nodo **mqtt in**: Server `Workshop broker`, Topic `lab/entrance/#`, QoS `1`, Output `auto-detect`, Name `Entrance events`.

### 4.2 Decidere

1. Trascina un nodo **switch** (categoria *function*), collegalo dopo mqtt in e fai doppio clic:
   - **Name**: `Which event?`
   - **Property**: `msg.payload.event`
   - Regole (usa **+ add** in basso):
     1. `==` `call`
     2. `==` `held_open`
     3. `==` `forced`
   - In basso seleziona **stopping after first match**
2. Lo switch ora ha **3 uscite**, una per regola.

### 4.3 Preparare

Trascina tre nodi **change**, uno per ogni uscita dello switch. In ciascuno imposta **Set** `msg.clip` **to the value** (tipo `number`):

| Nome del nodo change | Imposta `msg.clip` a |
|---|---|
| `Clip 0: doorbell` | `0` |
| `Clip 1: close the door` | `1` |
| `Clip 2: door forced` | `2` |

### 4.4 Agire

1. Trascina **un solo** nodo http request e collega tutti e tre i nodi change al suo ingresso:
   - **Method**: `GET`
   - **URL**: `http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip={{{clip}}}`
   - Autenticazione digest con le credenziali della scheda
   - **Name**: `Play clip (C1410)`
2. Aggiungi un nodo **debug** dopo di esso e fai **Deploy**.

`{{{clip}}}` viene sostituito con il valore di `msg.clip` quando arriva il messaggio. Così un solo nodo HTTP può riprodurre qualsiasi clip.

**Verifica.** Premi il pulsante di chiamata del citofono: il tuo speaker suona il campanello. Tieni la porta aperta: dopo qualche secondo senti "chiudere la porta, per favore".

> Tutti i gruppi condividono lo stesso citofono e la stessa porta, quindi ogni speaker in aula reagirà. È il publish/subscribe in azione: un publisher, tanti subscriber.

---

## Parte 5: Visualizzazione

**Concetto.** La dashboard mostra il risultato all'utente. Costruiscila solo **dopo** aver verificato gli ingressi nel pannello debug.

La pagina dashboard **Entrance** con due gruppi (**Door** ed **Events**) è già pronta. Devi solo aggiungere i widget.

### 5.1 Mostra l'ultimo evento della porta

1. **mqtt in**: Topic `lab/entrance/door`, Server `Workshop broker`, Output `auto-detect`.
2. **change**: **Set** `msg.payload` **to** `msg.payload.event` (tipo `msg.`). Chiamalo `Keep only the event name`.
3. Widget **text** (categoria *dashboard 2*):
   - **Group**: `[Entrance] Door`
   - **Label**: `Last door event`
4. Collega mqtt in → change → text.

### 5.2 Sblocca la porta dalla dashboard

L'A1210 usa il servizio VAPIX **Door Control**. Invii un body JSON con **POST**:

```text
POST http://A1210_IP/vapix/doorcontrol
{"tdc:AccessDoor":{"Token":"DOOR_TOKEN"}}
```

`AccessDoor` sblocca la porta per un breve periodo, come farebbe un badge valido.

1. Widget **button** (categoria *dashboard 2*):
   - **Group**: `[Entrance] Door`
   - **Label**: `Unlock door`
   - **Payload**: tipo `{} JSON`, valore `{"tdc:AccessDoor":{"Token":"DOOR_TOKEN"}}` (token dalla scheda)
2. **http request**:
   - **Method**: `POST`
   - **URL**: `http://A1210_IP/vapix/doorcontrol`
   - Autenticazione digest con le credenziali della scheda
   - **Return**: `a UTF-8 string`
3. Un **debug** dopo di esso.
4. Collega button → http request → debug.

### 5.3 Registro eventi

1. **mqtt in**: Topic `lab/#`, Server `Workshop broker`, Output `auto-detect`.
2. Nodo **function** chiamato `Add to event log`, con questo codice:

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

   La function conserva gli ultimi 10 eventi nel **flow context** (memoria condivisa dai nodi di questa scheda) e inoltra l'intera lista.

3. Widget **table** (categoria *dashboard 2*):
   - **Group**: `[Entrance] Events`
   - **Action**: `Replace`
4. Collega mqtt in → function → table e fai **Deploy**.

### 5.4 Apri la dashboard

Vai su <http://localhost:1880/dashboard>.

**Verifica.**

- Clicca **Unlock door**: la serratura scatta, la barra debug mostra `statusCode: 200`.
- Apri la porta: *Last door event* diventa `open`, poi `closed`.
- Ogni evento compare nella tabella.

**Hai costruito l'intera catena: evento → azione → visualizzazione.**

---

## Flow di riserva

Se una parte non funziona e il tempo stringe, importa il flow completo e prosegui con la parte successiva.

1. Menu di Node-RED (☰, in alto a destra) → **Import** → **select a file to import**
2. Scegli il file dalla cartella [flows](flows):

   | Parte | File |
   |---|---|
   | 1 | [part1-rest.json](flows/part1-rest.json) |
   | 2 | [part2-vapix.json](flows/part2-vapix.json) |
   | 3 | [part3-mqtt.json](flows/part3-mqtt.json) |
   | 4 | [part4-event-action.json](flows/part4-event-action.json) |
   | 5 | [part5-dashboard.json](flows/part5-dashboard.json) |

3. Clicca **Import**. Il flow si apre in una nuova scheda.
4. Apri ogni nodo **http request** e:
   - Sostituisci il segnaposto (`CAMERA_IP`, `C1410_IP`, `A1210_IP`) con l'indirizzo IP della scheda
   - Inserisci **username** e **password** (le password non vengono mai salvate nei flow esportati)
5. Nella Parte 5, sostituisci anche `DOOR_TOKEN` nel pulsante **Unlock door**.
6. **Deploy**.

> Se due schede sono sottoscritte allo stesso topic, reagiscono entrambe. Clic destro sulla scheda che non ti serve → **Disable**, poi Deploy.

---

## Bonus (se finisci prima, o dopo il corso)

### B1. Deterrenza con la telecamera

Aggiungi una quarta regola `== person` allo switch **Which event?** e un nodo change che imposta `msg.clip` a `3` ("area videosorvegliata").

### B2. Rilevamento del tailgating

Un accesso valido fa entrare **una** persona. Se la telecamera vede due persone entro 10 secondi da `access_granted`, qualcuno è entrato senza badge. Aggiungi un nodo function dopo `Entrance events`:

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

Collega la sua uscita a **Play clip (C1410)**. La clip 4 è "una persona alla volta, per favore".

### B3. Ponte verso il mondo OT (Modbus / OPC UA)

La presentazione ha introdotto Modbus e OPC UA. Node-RED può fare da gateway tra i due mondi:

1. ☰ → **Manage palette** → **Install** `node-red-contrib-modbus` (serve l'accesso a internet).
2. Aggiungi un nodo **Modbus-Flex-Server** (un PLC simulato).
3. Scrivi lo stato della porta nel holding register 0 (`1` = aperta, `0` = chiusa) con un nodo **Modbus-Write**.
4. Rileggilo con un nodo **Modbus-Read**, come farebbe un sistema di supervisione dell'edificio.

Lo stesso principio vale per OPC UA (`node-red-contrib-opcua`).

---

## Risoluzione dei problemi

| Sintomo | Controlla |
|---|---|
| `statusCode: 401` | Username/password, e **Type** deve essere `digest authentication` |
| `statusCode: 404` | Percorso dell'URL (errori di battitura, `axis-cgi` invece di `vapix`) |
| `statusCode: 400` | Parametri o body JSON (ad esempio numero di clip o token della porta errati) |
| Timeout / `ECONNREFUSED` / `EHOSTUNREACH` | Indirizzo IP del dispositivo e rete |
| mqtt in mostra **disconnected** | Il Server deve essere `Workshop broker`. Chiedi all'istruttore se il broker è attivo. |
| mqtt in è **connected** ma non arriva nulla | Filtro del topic (`lab/#`), poi genera un evento |
| `msg.payload.event` è `undefined` | L'**Output** di mqtt in deve essere `auto-detect` (JSON interpretato) |
| Lo speaker non suona | Numero della clip sulla scheda, e prova l'URL della Parte 2 |
| La dashboard non mostra nulla | Hai cliccato **Deploy**? Il widget è nel **Group** giusto? |
| Due schede reagiscono allo stesso evento | Disabilita la scheda che non ti serve (clic destro sulla scheda → Disable) |

---

## Riferimenti

### Chiamate API usate nel laboratorio

| Scopo | Metodo | Endpoint | Documentazione VAPIX |
|---|---|---|---|
| Leggere parametri | GET | `/axis-cgi/param.cgi?action=list&group=<gruppo>` | Parameter management |
| Elencare le clip audio | GET | `/axis-cgi/param.cgi?action=list&group=MediaClip` | [Media clip API](https://developer.axis.com/vapix/audio-systems/media-clip-api/) |
| Riprodurre una clip audio | GET | `/axis-cgi/mediaclip.cgi?action=play&clip=<n>` | [Media clip API](https://developer.axis.com/vapix/audio-systems/media-clip-api/) |
| Sblocco momentaneo della porta | POST | `/vapix/doorcontrol` con `{"tdc:AccessDoor":{"Token":"<token>"}}` | [Door control service](https://developer.axis.com/vapix/physical-access-control/door-control-service/) |

### Topic MQTT

| Topic | `device` | Valori di `event` |
|---|---|---|
| `lab/entrance/intercom` | `I8116-E` | `call` |
| `lab/entrance/door` | `A1210` | `open`, `closed`, `held_open`, `forced`, `access_granted`, `access_denied` |
| `lab/entrance/camera` | `P1475-LE` | `person` |

---

Istruttori: vedere [INSTRUCTOR.md](INSTRUCTOR.md) per la preparazione.
