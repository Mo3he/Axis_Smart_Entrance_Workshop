# AXIS Smart Entrance

**Laboratorio hands-on • 60 minuti**

[English](README.md) | **Italiano**

**Obiettivo:** costruire da zero un'integrazione che riceve eventi dai dispositivi, esegue un'azione e rende visibile il risultato. Ogni blocco segue la stessa sequenza: **concetto → configurazione → test → verifica**.

## Architettura del laboratorio

```text
AXIS A1601 ──► AXIS Camera Station Pro ── HTTP POST ──┐
                                                       ├──► Node-RED ──┬──► AXIS C1410 (clip audio, VAPIX)
AXIS Intercom ── MQTT (Call/State) ──► broker ────────┘                ├──► Dashboard
                                                                        └──► ACS Pro (HTTPS) ──► sblocco porta
```

### Obiettivo del laboratorio

- Costruire manualmente, partendo da una pagina Node-RED vuota, una piccola integrazione Smart Entrance.
- Imparare progressivamente a leggere un messaggio, chiamare un'API Axis, consultare la documentazione VAPIX e ricevere eventi MQTT.
- Collegare poi ACS Pro, AXIS Intercom, AXIS C1410 e dashboard in un unico flow **evento → azione → visualizzazione**.

> **Regola del laboratorio:** dopo ogni blocco, **Deploy → genera un evento → controlla il Debug** → solo dopo passa allo step successivo.

### Struttura didattica

| Parte | Cosa impari | Difficoltà |
|---|---|---|
| [0](#parte-0-node-red-in-5-minuti) | Node-RED: nodi, fili, `msg.payload`, Deploy e Debug | ● |
| [1](#parte-1-rest-e-autenticazione) | REST, URL, HTTP status code e autenticazione Digest | ●● |
| [2](#parte-2-vapix-e-clip-audio-sul-c1410) | VAPIX: cercare la documentazione e gestire clip audio sul C1410 | ●●● |
| [3](#parte-3-mqtt) | MQTT: broker, topic, payload e wildcard; evento Call/State dell'Intercom | ●●● |
| [4](#parte-4-integrare-acs-pro--intercom--c1410) | Integrazione reale: ACS Pro + Intercom + C1410 + unlock via ACS Pro | ●●●● |
| [5](#parte-5-dashboard-node-red) | Dashboard Node-RED: ultimo evento, log e comando sblocco | ●●●●● |

> **Importante:** il flow finale non viene importato. Tutti i nodi principali vengono creati da zero seguendo la guida.

---

## 0. Prima di iniziare

Il laboratorio segue una difficoltà crescente: prima impari a muoverti in Node-RED, poi verifichi REST e autenticazione, cerchi le API nella documentazione VAPIX e infine lavori con MQTT. Solo quando questi elementi sono chiari costruisci l'integrazione completa nella Parte 4.

### 0.1 Cosa serve

- Node-RED raggiungibile dal browser, normalmente su `http://NODE_RED_IP:1880`.
- Un broker MQTT raggiungibile da Node-RED e dall'AXIS Intercom (in questo laboratorio gira sulla stessa macchina di Node-RED).
- AXIS Camera Station Pro con AXIS A1601 già aggiunto e la porta **AEC main** disponibile per il test.
- AXIS Intercom configurabile con MQTT.
- AXIS C1410 Network Mini Speaker raggiungibile via browser.
- IP, username e password di laboratorio per ogni dispositivo.
- Tre file audio brevi forniti dal formatore: campanello, porta da chiudere, porta forzata.

### Parametri del laboratorio

Usa sempre i valori della scheda del partecipante. I valori riportati qui servono solo per mostrare il formato.

| Parametro | Placeholder | Esempio |
|---|---|---|
| Node-RED | `NODE_RED_IP` | `172.20.148.200` |
| ACS Pro | `ACS_PRO_IP` | `172.20.148.213` |
| ACS Pro HTTPS | `ACS_PRO_HTTPS_PORT` | `29204` |
| C1410 | `C1410_IP` | da scheda laboratorio |
| Telecamera (Parte 1) | `CAMERA_IP` | da scheda laboratorio |
| Intercom | `INTERCOM_IP` | da scheda laboratorio |
| Intercom seriale | `INTERCOM_SERIAL` | `B8A44F0B1CF0` |
| MQTT broker | `MQTT_BROKER_IP` | lo stesso IP di Node-RED (`NODE_RED_IP`) |

---

## Parte 0: Node-RED in 5 minuti

Un flow Node-RED è semplicemente una sequenza di nodi collegati. Un messaggio viaggia da sinistra a destra e, nella maggior parte dei casi, il dato che interessa è `msg.payload`. In questo laboratorio costruirai il flow partendo da una tab vuota.

### 0.1 Crea il primo flow

1. Apri Node-RED nel browser: `http://NODE_RED_IP:1880`.
2. Crea una nuova tab chiamata `Smart Entrance`.
3. Dal palette trascina un nodo **Inject**.
4. Trascina un nodo **Debug** alla sua destra.
5. Collega l'uscita di Inject all'ingresso di Debug.
6. Apri Debug e imposta l'output su `complete msg object`.
7. Fai **Deploy**.
8. Premi il pulsante sul nodo Inject.

> **Verifica:** nel pannello Debug deve comparire il messaggio e `msg.payload` deve contenere il valore generato da Inject.

### 0.2 Impara la regola più importante

Quando modifichi un nodo, fai sempre **Deploy** prima di testare. Sembra banale, ma Node-RED non è telepatico e questa guida preferisce non affidarsi alla magia.

| Elemento | Cosa significa |
|---|---|
| Inject | Genera o simula un messaggio |
| Wire | Trasporta il messaggio al nodo successivo |
| Debug | Mostra cosa sta realmente viaggiando nel flow |
| `msg.payload` | Contenuto principale del messaggio |
| Deploy | Applica le modifiche del flow |

---

## Parte 1: REST e autenticazione

Prima di costruire l'integrazione bisogna saper verificare una richiesta HTTP senza coinvolgere ancora MQTT, ACS Pro o dashboard. In questa parte lavorerai prima su endpoint semplici, poi sull'autenticazione e infine sullo status code.

### 1.1 Testa una API Axis dal browser

```text
http://CAMERA_IP/axis-cgi/param.cgi?action=list&group=Brand
```

1. Sostituisci `CAMERA_IP` con l'IP di una telecamera Axis del laboratorio.
2. Apri l'URL nel browser.
3. Inserisci le credenziali richieste.
4. Controlla il risultato: devono comparire righe di testo del tipo `root.Brand.ProdNbr=...`

> **Verifica:** hai appena fatto una richiesta GET. Il browser ha gestito per te l'autenticazione e ha mostrato il body della risposta.

### 1.2 Rifai la stessa chiamata in Node-RED

1. Crea un nodo **Inject** chiamato `Read device info`.
2. Crea un nodo **HTTP Request**.
3. Imposta **Method** = `GET`.
4. Inserisci la stessa URL usata nel browser.
5. Attiva **Use authentication**.
6. Seleziona `digest authentication`.
7. Inserisci username e password della scheda.
8. Imposta **Return** = `a UTF-8 string`.
9. Crea un nodo **Debug** con **Output** = `complete msg object`.
10. Collega Inject → HTTP Request → Debug e fai **Deploy**.

### 1.3 Capire gli errori

| Modifica | Risultato atteso | Significato |
|---|---|---|
| Disabilita autenticazione | `401` | Credenziali mancanti o metodo di auth errato |
| Scrivi `paramm.cgi` al posto di `param.cgi` | `404` | Endpoint errato |
| Ripristina tutto | `200` | Richiesta corretta |

> **Metodo di troubleshooting:** segui sempre questo ordine: rete → URL → autenticazione → metodo → payload → risposta.

---

## Parte 2: VAPIX e clip audio sul C1410

Qui impari a cercare una API invece di memorizzarla. La documentazione VAPIX del **Media clip API** permette di elencare, caricare, riprodurre, aggiornare, scaricare e rimuovere clip audio sul dispositivo.

### 2.1 Apri la documentazione corretta

1. Apri <https://developer.axis.com/vapix/>.
2. Cerca **Media clip API**.
3. Individua le tre informazioni che servono oggi: come **elencare** le clip, come **caricare** una clip e come **riprodurla**.

Non cercare di memorizzare i comandi. Impara a ritrovarli.

> **Riferimento rapido:** per gestire clip audio si usa `/axis-cgi/mediaclip.cgi`. La documentazione indica `GET` per tutte le azioni tranne `upload`, che usa `POST` con `multipart/form-data`.

### 2.2 Prima controlla cosa c'è già sullo speaker

```text
http://C1410_IP/axis-cgi/param.cgi?action=list&group=MediaClip
```

1. Crea Inject → HTTP Request → Debug, come nella Parte 1.
2. Imposta l'URL sopra con `C1410_IP`.
3. Usa `digest authentication`.
4. Fai **Deploy** e premi Inject.
5. Nel Debug cerca righe come `root.MediaClip.M0.Name=...`

> **Verifica:** annota il numero della clip che utilizzerai. L'indice `M0`/`M1`/`M2` corrisponde al numero da usare nell'API di play.

### 2.3 Le tre clip del laboratorio

Per ridurre il lavoro cognitivo dei partecipanti, i file audio vengono preparati dal formatore e consegnati nel materiale del laboratorio. Il partecipante si concentra sull'integrazione, non sulla produzione audio.

| Clip | File | Nome | Uso | Indice consigliato |
|---|---|---|---|---|
| 0 | `0-doorbell.wav` | Doorbell | Chiamata Intercom | 0 |
| 1 | `1-close-door.wav` | CloseDoor | Porta aperta troppo a lungo | 1 |
| 2 | `2-door-forced.wav` | DoorForced | Porta forzata | 2 |

> **Formato audio:** il C1410 supporta `.au`, `.mp3`, `.opus`, `.vorbis` e `.wav`. Per il laboratorio usare MP3 o WAV per mantenere la procedura semplice.

### 2.4 Carica le clip dal web interface del C1410

1. Apri `https://C1410_IP` nel browser.
2. Accedi con le credenziali del laboratorio.
3. Apri **Audio → Audio clips**.
4. Seleziona **Add clip**.
5. Carica `0-doorbell.wav` e assegnagli il nome `Doorbell`.
6. Ripeti per `1-close-door.wav` (`CloseDoor`) e `2-door-forced.wav` (`DoorForced`).
7. Riproduci ciascuna clip dal menu Audio clips per verificarne il contenuto.
8. Annota gli indici realmente assegnati dal dispositivo.

> **Verifica:** le tre clip devono essere visibili nella libreria Audio clips e riproducibili manualmente.

### 2.5 Riproduci una clip con VAPIX

```text
http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip=0
```

1. Crea un secondo Inject → HTTP Request → Debug.
2. Imposta **Method** = `GET`.
3. Inserisci l'URL sopra.
4. Usa `digest authentication`.
5. Fai **Deploy** e premi Inject.

> **Verifica:** il C1410 deve riprodurre la clip 0 e il Debug deve mostrare una risposta HTTP `200` con body che inizia con `OK`.

---

## Parte 3: MQTT

Ora impari il secondo metodo di trasporto usato dal laboratorio. MQTT separa **publisher**, **broker** e **subscriber**. Sul dispositivo Axis configurerai il client MQTT e la pubblicazione dell'evento di chiamata.

### 3.1 Configura il broker sull'Intercom

1. Apri la pagina web dell'Intercom.
2. Vai alle impostazioni **MQTT** del dispositivo.
3. Abilita il client MQTT.
4. Inserisci l'IP del broker (`MQTT_BROKER_IP`, cioè l'IP della macchina Node-RED).
5. Usa porta `1883` per MQTT over TCP, salvo diversa indicazione sulla scheda.
6. Inserisci username e password MQTT se il broker le richiede (nel laboratorio non servono).
7. Assegna un **Client ID** riconoscibile, per esempio `INTERCOM_SERIAL`.
8. Salva e verifica che lo stato del client risulti **Connected**.

> **Riferimento:** AXIS OS usa `1883` come porta predefinita per MQTT over TCP e `8883` per MQTT over SSL.

### 3.2 Pubblica l'evento Call/State

Il laboratorio utilizza l'evento Axis `tnsaxis:Call/State`. Il dato che interessa è `CallState`, che nel ciclo di chiamata assume gli stati `Idle`, `Calling` e `Active`.

1. Nella configurazione **MQTT publication** dell'Intercom abilita la pubblicazione degli eventi.
2. Imposta il topic prefix del laboratorio su `axis/intercom`.
3. Abilita l'inclusione del numero seriale nel topic.
4. Abilita l'inclusione del condition/event topic e degli ONVIF namespaces, in modo da ottenere il topic completo dell'evento.
5. Verifica che il topic risultante abbia questa struttura:

```text
axis/intercom/INTERCOM_SERIAL/event/tns:axis/Call/State
```

> **Verifica:** nel laboratorio di esempio il topic reale è `axis/intercom/B8A44F0B1CF0/event/tns:axis/Call/State`. Non scrivere il seriale fisso nel flow: usa `axis/intercom/#` per rendere il subscriber riutilizzabile.

### 3.3 Crea il primo subscriber in Node-RED

1. Trascina un nodo **mqtt in**.
2. Seleziona il broker locale (**Local broker**, già configurato).
3. **Topic** = `axis/intercom/#`.
4. **QoS** = `1`.
5. **Output** = `auto-detect`.
6. Trascina un **Debug** a destra e imposta `complete msg object`.
7. Collega mqtt in → Debug.
8. Fai **Deploy**.

> **Verifica:** premendo il pulsante di chiamata dell'Intercom, il Debug deve mostrare topic e payload. Il payload deve contenere `message.data.CallState`:
>
> ```text
> msg.payload.message.data.CallState
> ```

### 3.4 Sperimenta i wildcard MQTT

| Filtro topic | Cosa riceve |
|---|---|
| `axis/intercom/#` | Tutti i topic sotto `axis/intercom/`, a qualsiasi livello di profondità |
| `axis/intercom/INTERCOM_SERIAL/event/tns:axis/Call/State` | Solo gli eventi Call/State dell'intercom specificato |
| `axis/intercom/+/event/tns:axis/Call/State` | Gli eventi Call/State di qualsiasi intercom. Il simbolo `+` corrisponde esattamente a un livello del topic |

Un topic filter stabilisce quali messaggi MQTT il nodo mqtt in riceve. I wildcard permettono di sottoscrivere più topic senza doverli indicare uno per uno.

**Esercizio:** modifica il campo Topic del nodo mqtt in usando, uno alla volta, i filtri della tabella. Dopo ogni modifica fai **Deploy** e genera una chiamata dall'intercom. Osserva nel pannello Debug quali messaggi arrivano e confronta le differenze.

> **Nota:** nei filtri MQTT, `#` corrisponde a zero o più livelli e deve essere l'ultimo elemento del filtro; `+` corrisponde a un solo livello.

---

## Parte 4: Integrare ACS Pro + Intercom + C1410

Da qui inizia il flow applicativo completo. Costruirai i collegamenti tra ACS Pro, AXIS Intercom e AXIS C1410 usando HTTP, MQTT e VAPIX. La dashboard verrà aggiunta solo dopo aver verificato gli eventi nel Debug.

### 4.1 Prepara la struttura della tab Node-RED

1. Crea una nuova tab chiamata `AXIS Smart Entrance - ACS Pro bridge`.
2. Dividi visivamente il canvas in quattro aree: **ACS Pro events**, **Intercom MQTT**, **Speaker actions**, **Door unlock** (puoi usare nodi **comment** come titoli).
3. Lascia spazio a destra per il nodo di logging che verrà creato più avanti.
4. Non creare ancora la dashboard. La dashboard arriva nella Parte 5.

### 4.2 Porta → ACS Pro → Node-RED: Door open too long

1. In ACS Pro vai in **Configuration → Recording and events → Action rules**.
2. Crea una nuova Action Rule.
3. Sotto **Triggers** scegli **Device event** e seleziona l'AXIS A1601.
4. Come evento seleziona **Door open too long**.
5. Aggiungi l'azione **Send HTTP Notification**.
6. Come URL inserisci `http://NODE_RED_IP:1880/acs/door-open-too-long`.
7. In **Advanced** imposta **Method** = `POST` e salva la regola.

### 4.3 Crea il receiver HTTP in Node-RED

1. Trascina un nodo **HTTP In**.
2. **Method** = `POST`.
3. **URL** = `/acs/door-open-too-long`.
4. Collega il nodo a un **Function** node.
5. Imposta il Function node a **2 output**: il primo continua nel flow, il secondo risponde ad ACS Pro.
6. Nel Function node incolla il codice seguente:

   ```javascript
   const res = { ...msg, payload: 'OK', statusCode: 200 };
   msg.payload = { source: 'AXIS Camera Station Pro', event: 'door_open_too_long', severity: 'warning' };
   return [msg, res];
   ```

7. Collega l'output 1 al percorso che porterà al logging.
8. Collega l'output 2 a un nodo **HTTP Response**.
9. Nel nodo HTTP Response usa status `200` e content-type `text/plain`.

### 4.4 Ripeti per Door forced

1. In ACS Pro crea una seconda Action Rule con trigger **AXIS A1601 → Door forced**.
2. Aggiungi **Send HTTP Notification**.
3. URL = `http://NODE_RED_IP:1880/acs/door-forced`, Method = `POST`.
4. In Node-RED crea **HTTP In** con `POST` e URL `/acs/door-forced`.
5. Collega un Function node a 2 output e incolla il codice seguente:

   ```javascript
   const res = { ...msg, payload: 'OK', statusCode: 200 };
   msg.payload = { source: 'AXIS Camera Station Pro', event: 'door_forced', severity: 'critical' };
   return [msg, res];
   ```

6. Collega l'output 1 al percorso che porterà al logging.
7. Collega l'output 2 a **HTTP Response** con status `200` e content-type `text/plain`.
8. Fai **Deploy** e prova entrambi gli eventi della porta prima di proseguire.

### 4.5 Intercom → Node-RED: tre stati

1. Usa il nodo mqtt in creato nella Parte 3 oppure creane uno nuovo con topic `axis/intercom/#` e QoS `1`.
2. Collega il nodo mqtt in a un nodo **Switch**.
3. Nel campo **Property** dello Switch usa `msg.payload.message.data.CallState`.
4. Crea tre regole: `== Calling`, `== Active`, `== Idle`.
5. In basso seleziona **stopping after first match**.

**Cosa significa il quinto passaggio:** lo Switch valuta le regole in ordine e, appena trova una corrispondenza, invia il messaggio solo a quell'uscita e si ferma. Così un singolo `CallState` non viene inoltrato anche agli altri rami. Non serve fare nulla di speciale sul messaggio: l'impostazione decide solo quante uscite usare. Nel JSON del flow questa opzione corrisponde a `checkall = false`.

### 4.6 Normalizza i tre eventi

1. Dopo ogni uscita dello Switch inserisci un nodo **Change**.
2. Nel nodo Change crea una sola regola: **Set** `msg.payload`.
3. Come tipo seleziona **JSON**.
4. Usa questi valori:

   | Uscita | Valore JSON |
   |---|---|
   | Calling | `{"source":"AXIS Intercom","event":"Chiamata in arrivo","severity":"info"}` |
   | Active | `{"source":"AXIS Intercom","event":"Chiamata accettata","severity":"info"}` |
   | Idle | `{"source":"AXIS Intercom","event":"Chiamata interrotta","severity":"info"}` |

5. Collega l'uscita dei tre Change al percorso di logging che creerai nel punto 4.8.

Da questo punto in poi, gli eventi Intercom hanno la stessa struttura degli eventi provenienti da ACS Pro: `source`, `event` e `severity`.

### 4.7 Aggiungi le azioni audio al C1410

1. Sul C1410 verifica di avere le tre clip caricate nella Parte 2 e annota i numeri assegnati dal dispositivo.
2. Non creare un nuovo Switch e non aggiungere nuovi Change node per l'audio. Riutilizza direttamente i nodi già presenti: il Change del ramo **Calling** e i due Function node degli eventi ACS Pro.
3. Dal Change del ramo Calling collega un **HTTP Request** per riprodurre la clip **Doorbell**.
4. Dal Function di 4.3 collega un HTTP Request per riprodurre la clip **Please close the door**.
5. Dal Function di 4.4 collega un HTTP Request per riprodurre la clip **Door forced alarm**.
6. In ciascun HTTP Request imposta **Method** = `GET`.
7. Usa un URL del tipo `http://C1410_IP/axis-cgi/mediaclip.cgi?action=play&clip=CLIP_NUMBER` e sostituisci `CLIP_NUMBER` con il numero reale della clip.
8. Configura l'autenticazione del C1410 come **Digest**.
9. Aggiungi un Debug dopo ciascun HTTP Request e verifica una risposta HTTP `200` con body `OK`.

Tre HTTP Request separati rendono immediatamente leggibile il collegamento evento → clip e non richiedono un ulteriore Switch o Change.

### 4.8 Crea un unico nodo di logging

1. Crea un Function node chiamato `Normalize + append event log` e imposta **2 output**.
2. Incolla il codice seguente:

   ```javascript
   let p = msg.payload;
   if (typeof p === 'string') {
       try { p = JSON.parse(p); }
       catch (e) { p = { detail: p }; }
   }
   if (!p || typeof p !== 'object') p = { detail: String(p) };
   const event = p.event || 'unknown';
   const entry = {
       time: new Date().toLocaleString('it-IT'),
       source: p.source || 'unknown',
       event,
       severity: p.severity || 'info',
       detail: p.detail || ''
   };
   let log = flow.get('eventLog') || [];
   log.unshift(entry);
   log = log.slice(0, 25);
   flow.set('eventLog', log);
   msg.payload = entry;
   return [msg, { payload: log }];
   ```

3. Collega tutti gli eventi normalizzati (i due Function ACS Pro e i tre Change dell'Intercom) all'ingresso di questo Function.

Cosa fa il codice, riga per riga:

1. `let p = msg.payload` legge il contenuto principale del messaggio ricevuto.
2. `typeof p === 'string'` controlla se il payload è arrivato come testo invece che come oggetto.
3. `JSON.parse(p)` prova a convertire il testo JSON in un oggetto utilizzabile dal flow.
4. `catch(e)` gestisce un JSON non valido senza bloccare il flow e conserva il testo nel campo `detail`.
5. Il controllo successivo gestisce payload vuoti o di tipo inatteso creando un oggetto di ripiego.
6. `const event` e `const entry` estraggono e organizzano i dati da visualizzare: evento, sorgente, severità, dettaglio e timestamp.
7. `flow.get('eventLog')` recupera lo storico dal flow context; `log.unshift(entry)` mette il nuovo evento in cima.
8. `log.slice(0, 25)` limita lo storico agli ultimi 25 eventi e `flow.set(...)` salva la lista aggiornata.
9. `msg.payload = entry` prepara il singolo evento per il primo output.
10. `return [msg, { payload: log }]` crea due uscite: la prima contiene l'ultimo evento, la seconda l'intero storico.

### 4.9 Crea lo sblocco porta tramite ACS Pro

1. In ACS Pro vai in **Configuration → Recording and events → Action rules**.
2. Crea una nuova Action Rule.
3. Sotto **Triggers** seleziona **External HTTPS**.
4. Imposta **Trigger name** = `UnlockDoor` (o il nome indicato sulla scheda, se più gruppi condividono lo stesso server ACS Pro).
5. Salva il trigger.
6. Nella stessa regola aggiungi l'azione **Access Control**.
7. Seleziona la porta da comandare. Il nome visualizzato dipende dalla configurazione del sito.
8. Come Action seleziona **Access**.
9. Salva la regola e verifica che il trigger `UnlockDoor` e l'azione Access Control siano presenti nella stessa Action Rule.

### 4.10 Costruisci il comando HTTPS in Node-RED

Prima di configurare il nodo TLS, esporta la CA dal server ACS Pro:

1. In ACS Pro vai in **Configuration → Security → Certificates**.
2. Nella sezione **Certificate authority** fai clic su **Export**.
3. Scegli **Without the private key** e salva il certificato in formato `.cer` o `.crt`. Per Node-RED serve solo la parte pubblica della CA: non esportare la chiave privata.

Poi in Node-RED:

1. Crea un nodo **Inject** per il test.
2. Crea un Function node chiamato `Build ACS Pro trigger URL`.
3. Incolla il codice seguente e sostituisci solo `ACS_PRO_IP` con l'IP del server ACS Pro:

   ```javascript
   const host = 'ACS_PRO_IP';
   const triggerName = 'UnlockDoor';
   msg.method = 'GET';
   msg.url = 'https://' + host + ':29204/Acs/Api/TriggerFacade/PulseTrigger?' + JSON.stringify({ triggerName });
   msg.payload = '';
   return msg;
   ```

   La porta HTTPS utilizzata in questo laboratorio è `29204`: mantieni questo valore.

4. Collega il Function a un nodo **HTTP Request**.
5. Nel nodo HTTP Request lascia **Method** = `- set by msg.method -`, perché il metodo è già impostato da `msg.method`.
6. Attiva **Enable secure (SSL/TLS) connection**, crea una configurazione TLS e nel campo **CA Certificate** carica il file `.crt`/`.cer` esportato da ACS Pro.
7. Attiva **Use authentication**, tipo `basic authentication`, e inserisci username e password di un account ACS Pro valido. Se Basic restituisce HTTP `401` o la richiesta non viene autenticata, prova Digest.
8. Aggiungi un **Debug** dopo HTTP Request con **Output** = `complete msg object`.
9. Fai **Deploy** e verifica che l'attivazione del trigger produca l'azione Access Control sulla porta selezionata.

---

## Parte 5: Dashboard Node-RED

La dashboard viene costruita per ultima, quando gli eventi sono già verificati nel Debug. In questo modo si evita di usare la UI come strumento di troubleshooting: prima si verifica il dato, poi lo si rende visibile.

### 5.1 Verifica Dashboard 2.0

1. Apri il menu ☰ di Node-RED.
2. Vai in **Manage palette**.
3. Controlla che `@flowfuse/node-red-dashboard` sia installato (nell'ambiente del laboratorio è preinstallato). Se manca: **Install**, cerca il pacchetto e installalo.

> **Verifica:** nel palette devono comparire i nodi della categoria *dashboard 2*, come **button**, **text** e **table**.

### 5.2 Crea la pagina Smart Entrance

1. Aggiungi un widget qualsiasi della categoria dashboard 2 e, dal campo **Group**, crea una nuova pagina (**ui-page**):
   - Nome pagina = `Smart Entrance`
   - Path = `/smart-entrance`
2. Crea un **ui-group** chiamato `Eventi ingresso`.
3. Crea un secondo ui-group chiamato `Comandi`.

### 5.3 Visualizza l'ultimo evento

1. Trascina un nodo **text** nel gruppo `Eventi ingresso`.
2. **Label** = `Ultimo evento`.
3. Imposta il formato sul campo desiderato, ad esempio:

   ```text
   {{msg.payload.time}} · {{msg.payload.source}} · {{msg.payload.event}}
   ```

4. Collega l'**output 1** di `Normalize + append event log` al nodo text.

> **Verifica:** quando arriva un nuovo evento, il testo deve aggiornarsi senza refresh manuale della pagina.

### 5.4 Crea il registro degli eventi

1. Trascina un nodo **table** nel gruppo `Eventi ingresso`.
2. **Label** = `Registro eventi (ultimi 25)`.
3. **Max rows** = `25`.
4. **Action** = `Replace`.
5. Collega l'**output 2** di `Normalize + append event log` alla table.

> **Verifica:** ogni evento nuovo deve essere inserito in cima al registro, mantenendo al massimo 25 righe.

### 5.5 Aggiungi il pulsante di sblocco

1. Trascina un nodo **button** nel gruppo `Comandi`.
2. **Label** = `Richiedi sblocco porta`.
3. **Payload** = `unlock`.
4. **Topic** = `command`.
5. Collega il pulsante al Function `Build ACS Pro trigger URL` creato nella Parte 4.
6. Fai **Deploy**.

> **Verifica:** premendo il pulsante il flow deve chiamare ACS Pro e la porta **AEC main** deve eseguire l'azione Access.

### 5.6 Apri la dashboard

```text
http://NODE_RED_IP:1880/dashboard
```

> **Risultato:** la dashboard finale mostra l'ultimo evento, il log degli ultimi 25 eventi e il comando di sblocco porta.

---

## 6. Collaudo finale

Esegui i test in questo ordine. Non testare tutto insieme: il laboratorio deve permettere di capire esattamente quale blocco ha smesso di funzionare.

| Test | Azione | Risultato atteso |
|---|---|---|
| 1 | C1410: play clip 0 da Node-RED | Lo speaker riproduce Doorbell |
| 2 | Intercom: genera Calling | Dashboard: Chiamata in arrivo + clip 0 |
| 3 | Intercom: genera Active | Dashboard: Chiamata accettata |
| 4 | Intercom: genera Idle | Dashboard: Chiamata interrotta |
| 5 | A1601: Door open too long | ACS Pro → HTTP → Node-RED → log + clip 1 |
| 6 | A1601: Door forced | ACS Pro → HTTP → Node-RED → log + clip 2 |
| 7 | Dashboard: Richiedi sblocco porta | Node-RED → HTTPS → ACS Pro → AEC main → Access |

> **Definition of done:** il laboratorio è completo quando tutti i sette test producono il risultato atteso e ogni passaggio è visibile nel Debug o nella dashboard.

### 6.1 Troubleshooting rapido

| Sintomo | Controlla prima | Poi |
|---|---|---|
| HTTP 401 | Digest authentication + credenziali | Utente e password del dispositivo |
| HTTP 404 | URL e path | `axis-cgi` vs `vapix` |
| HTTP 400 | Parametri/query/body | Numero della clip, URL del trigger, JSON |
| MQTT disconnected | Broker/porta | Username/password e rete |
| MQTT connected ma non arriva nulla | `axis/intercom/#` | Genera Calling/Active/Idle |
| `CallState` undefined | Output mqtt in = `auto-detect` | Path `msg.payload.message.data.CallState` |
| Lo speaker non suona | Indice della clip | Test play clip diretto (Parte 2.5) |
| ACS Pro non chiama Node-RED | URL `http://NODE_RED_IP:1880/acs/...` e metodo POST | Firewall tra ACS Pro e Node-RED |
| Sblocco ACS non funziona | URL/porta `29204` o porta assegnata | TLS + account ACS Pro |
| Errore certificato (`self-signed`, `altnames`) | CA corretta caricata nel nodo TLS | Nel nodo TLS imposta **Server Name** uguale al nome nel certificato ACS Pro |
| Dashboard vuota | Deploy + group corretto | Filo dall'output giusto |

---

## 7. Riferimenti

- AXIS VAPIX Developer Documentation: <https://developer.axis.com/vapix/>
- Media clip API: <https://developer.axis.com/vapix/audio-systems/media-clip-api/>
- Intercom Call service API: <https://developer.axis.com/vapix/intercom/call-service-api/>
- AXIS OS Web interface help - LTS 2026: <https://help.axis.com/en-us/axis-os-web-interface-help-lts-2026>
- AXIS Camera Station Pro User manual: <https://help.axis.com/en-US/axis-camera-station-pro>
- AXIS C1410 Network Mini Speaker: <https://help.axis.com/en-us/axis-c1410>

> **Nota sulle versioni:** i nomi dei menu possono variare leggermente tra release di AXIS OS, AXIS Camera Station Pro e Node-RED Dashboard. I concetti, gli endpoint e la logica del flow restano quelli documentati o verificati nel laboratorio.

---

Formatori: vedere [INSTRUCTOR.md](INSTRUCTOR.md) per la preparazione.
