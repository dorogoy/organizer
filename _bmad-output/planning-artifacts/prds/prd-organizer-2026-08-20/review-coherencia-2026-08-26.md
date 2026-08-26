# Revisión de coherencia — PRD `prd-organizer-2026-08-20`

**Fecha:** 2026-08-26 · **Herramienta:** `bmad-review` · **Enfoque solicitado:** coherencia interna

**Contenido:** docs (PRD, define comportamiento) · **Lentes ejecutados:** adversarial, edge-case-hunter, structure · **Omitidos:** verification-gap (solo código con tests), prose (no es copy-edit) · **Persistent facts:** ningún `project-context.md` encontrado.

**Veredicto sintético:** el PRD es fuerte en tono, trazabilidad y filosofía, pero la coherencia tiene 3 focos calientes reales: (1) la **aritmética del Focus Chunk** (bolsa de 5 min, piso de cobertura de FR-31, curación de zonas), (2) **reglas de composición sin definir en el límite** (energía 🟡, bolsillos cortos vs checkpoint, origen de re-slices, snowball) y (3) **afirmaciones absolutas falsables** ("no keyboard required", "single record of parameters", registro de excepciones E1/E2 exhaustivo).

---

## Lente: Adversarial — 16 hallazgos

**ADR-1 · FR-31 vs §3/§10.1/A12 — piso de cobertura cuenta entradas no elegibles.** El piso "≥45 entradas → 28 Focus Chunks sin repetir" incluye tareas de 3 min y mensuales que no pueden ocupar el slot "1" (10–15 min, solo Épico/zona activa): en A12 hay solo 20 entradas semanales de 10–15 min y una zona con 3 no cubre sus 7 días.
→ Reformular el piso en unidades elegibles (≥7 entradas 10–15 min por zona) y decidir si el cluster `fondo` puede proveer Focus Chunks. **Sin fix:** semanas enteras repiten Focus Chunk; la verificación "checkable by counting" pasa mientras la garantía fracasa.

**ADR-2 · §3/§10.1 "Epic seeds" vs FR-11/E1 — vocabulario muerto.** El glosario declara dos clases de plantilla, pero ninguna superficie usa jamás una Epic seed: FR-11 prohíbe Épicos "from a template" y E1 instancia solo Evergreen.
→ Eliminar Epic seeds de §3/§10.1, o añadir a FR-11 la consecuencia que fija su superficie (seed = prefill del formulario manual, siempre vía Slicer). **Sin fix:** el implementador rompe E1 o conserva una ficción que el principio 6 prohíbe.

**ADR-3 · FR-7 vs FR-12 — bolsa de 5 min no admite Focus Chunk.** Rango 5–30, pero Focus Chunk (10–15) ≤ bolsa con bolsa <10: composición indefinida en un valor legal.
→ Regla del caso límite ("bolsa <10 → slot '1' vacío, sin deuda") o mínimo de bolsa = 10. **Sin fix:** SM-3 estructuralmente imposible sin aviso. *(solapa con EDGE-6)*

**ADR-4 · FR-10 vs FR-8/UJ-1 — checkpoint aritméticamente falso.** "Toda sesión alcanza checkpoint (10–15)" falla en bolsillos de 5–9 min; con defaults (bolsa 15 = bolsillo 15 = checkpoint 15) el "rest offer along the way, never an end" cae exactamente al final.
→ Checkpoint relativo al bolsillo (`min(bolsillo, valor)`) o eximir sesiones cortas. **Sin fix:** o nunca aparece, o es solo el cierre nativo. *(solapa con EDGE-11)*

**ADR-5 · FR-12 — frase del "26 min excede la bolsa" caducada.** La consecuencia 5 conserva la aritmética pre-2026-08-23 junto a la regla nueva (solo el Focus Chunk se carga): 15 contra 15 no "excede".
→ Reescribir en pasado explícito o eliminar la cláusula. **Sin fix:** dos lecturas del mismo FR producen escalados distintos.

**ADR-6 · FR-26 vs FR-5/FR-27 — origen de re-slices indefinido.** ¿Una tarea `manual` re-rebanada vía FR-5 mantiene `manual` o pasa a `cloud`? Nadie lo decidió.
→ Regla de herencia escrita en FR-26 ("la re-slice no cambia el origen de génesis"). **Sin fix:** SM-4 y el detector de §10.2 ("el hallazgo más importante de la ventana") dan veredictos opuestos según el etiquetado.

**ADR-7 · §7 accesibilidad vs FR-28/FR-32 — "no keyboard required" es falso.** La entrada de la API key BYOK exige teclear y FR-32 limita el dictado a la línea de captura ("nowhere else").
→ Acotar la afirmación (superficies de usuario; BYOK-settings es superficie del validador) y registrar la disponibilidad de reconocimiento on-device como supuesto activo. **Sin fix:** el piso se rompe en la primera configuración del build.

**ADR-8 · §8 SM-2 — mecanismo de entrega sin especificar.** "Preguntada los domingos": si es in-app y no hay apertura, hueco silencioso; si fuese notificación, viola FR-24/§5.2.
→ "Pregunta ambiental en el Dispenser, persistida hasta la primera apertura de esa semana, nunca notificada" + tratamiento de semanas sin respuesta. **Sin fix:** el baseline de la métrica primaria acumula huecos.

**ADR-9 · UJ-5 vs FR-27/FR-12/FR-5 — el ejemplo estrella es patológico.** "Regar el jueves": FR-27 prohíbe fecha, FR-12 la adelanta (lun–mié), y saltarla 3 días esperando el jueves dispara el rescue que la despedaza en pasos ≤60 s.
→ Semántica de capturas con día implícito (eximirlas del contador de FR-5, o incorporarla a OQ-11). **Sin fix:** la tarea sale el día equivocado o el heurístico la destroza. *(solapa con EDGE-5)*

**ADR-10 · FR-23 snowball — "día cómodo" indefinido y conflicto con principio 2.** Ninguna serie de FR-26 define "cómodo" (no existen contadores de skips), y §4.6 dice "streaks" que el principio 2 veta sin matiz.
→ Definirlo en términos auditables de la serie (a) y acotar el principio 2 (contadores internos jamás mostrados). **Sin fix:** disparador no verificable por test.

**ADR-11 · §3 "Evergreen always active" vs FR-31/FR-11 — tres ciclos de vida incompatibles.** Desactivar el cluster de la zona de la rotación deja el día sin zona activa (FR-11 exige exactamente una); "instantiate" no añade nada si el día 1-3-5 ya funciona por defecto.
→ Reconciliar: qué pasa con la rotación bajo curación (¿salta esa semana?, ¿el slot cae al Épico?). **Sin fix:** rotación indefinida y pool de Focus Chunks aún más estrecho. *(solapa con EDGE-7)*

**ADR-12 · §3/FR-21 Quarantine Box — condicional inobservable.** "If untouched after 6 months": la app no tiene señal de si la caja física fue tocada; lo implementable es el temporizador ciego.
→ Eliminar el condicional o especificar la señal ("tap: la caja se vació"), igualando glosario y FR. **Sin fix:** requisito implementable solo transgrediéndolo; contradicción auditable por SM-C2.

**ADR-13 · §7 mapa de egreso vs FR-11/E2 — tercer payload ausente.** El mapa enumera scan image y rescue text, pero la génesis por texto/formulario también viaja al Slicer: sin consentimiento especificado (FR-25 es per-scan/imagen) y sin serie en FR-26 (la serie (b) solo registra fotos).
→ Añadir el payload al mapa y a FR-25 ("texto de génesis: ¿consentimiento por llamada o cubierto por el gate?") e instrumentarlo. **Sin fix:** el mapa "load-bearing" es falso; texto personalísimo del hogar sale sin copys ni registro.

**ADR-14 · FR-12 reserva del slot vs precedencia manual.** Una captura manual de 10–15 min, ¿ocupa el hueco reservado al avance o añade un segundo ítem grande? "Focus Chunk" se usa a la vez como tamaño y como papel.
→ Fijar vocabulario (tamaño vs papel) y resolver el caso por escrito. **Sin fix:** dos implementadores producen días distintos y SM-3 varía según cuál.

**ADR-15 · §1.1 registro de excepciones — exhaustividad falsable.** "An exception exists only where this register names it", pero FR-20 (3 destinos), FR-27 (3 tamaños), FR-4 (3 energías) y SM-2 (5 puntos) son "elegir de una lista" en letra.
→ Acotar la letra del principio 1 ("nunca elegir entre tareas pendientes; las superficies de respuesta de opciones fijas no son listas") o registrar cada una. **Sin fix:** cualquier lector literal declara erróneas FR-20/27/4 y SM-2 con el propio mecanismo del documento.

**ADR-16 · §8 anexo — supuesto no registrado.** El "per-key cost attribution desde una sola cuenta" del proveedor no está en §10.2 ni en OQ-10.
→ Fila de supuesto o alternativa escrita (clave compartida, aceptada explícitamente). **Sin fix:** la configuración de las observadoras cambia en silencio sin registrar el desvío.

---

## Lente: Edge-Case Hunter — 21 hallazgos

- **EDGE-1 · FR-4** — 🟡 no define exclusión ninguna → rama explícita (excluye 10–15, o sin filtro); sin ella cada build decide distinto.
- **EDGE-2 · FR-4/FR-27** — captura 10–15 min + 🔴 sostenido ≥3 días → congelar el contador de 3 días en días incompatibles (como FR-5 congela el suyo); SLA incumplible.
- **EDGE-3 · FR-6** — captura seguida de ausencia ≥48 h que cruza el límite de 3 días → ¿se congela la latencia? A la vuelta, capturas "vencidas" sin regla.
- **EDGE-4 · FR-27/FR-12** — backlog manual crece más rápido que los slots → definir orden (FIFO) y techo/caducidad silenciosa; sin lista ni edición ni purga, el backlog es irremovible y desplaza Evergreen/Épico indefinidamente.
- **EDGE-5 · FR-27/UJ-5** — plazo en la línea ("el jueves") no modelado → ruling: texto plano y reparto ciego a fechas, o rechazo; tarea con vencimiento real repartida tras el plazo.
- **EDGE-6 · FR-7/FR-12** — bolsa 5 min → slot "1" vacío indefinido; el escalado solo borra upkeep/hábitos, nunca el Focus Chunk. *(solapa ADR-3)*
- **EDGE-7 · FR-31/FR-12** — desactivar el cluster de la zona activa sin Épico → fuente alternativa del slot "1" o bloqueo; el piso de cobertura queda anulado en runtime. *(solapa ADR-11)*
- **EDGE-8 · FR-31/FR-4** — día 🔴: solo anclas ~30 s elegibles y el piso de 45 excluye lo diario → todas las jornadas 🔴 reparten las mismas 5 tarjetas.
- **EDGE-9 · FR-1/FR-3/FR-8** — sesión que agota el pool elegible → FR-3 promete "una alternativa" inexistente; definir cierre anticipado con copia neutral.
- **EDGE-10 · FR-4/FR-10** — pulsar 🔴 con Focus Chunk en curso → ¿se puede terminar la tarjeta activa (como en el checkpoint) o se retira al instante?
- **EDGE-11 · FR-10/FR-8** — bolsillo <10 min con checkpoint 10–15 → "toda sesión alcanza un checkpoint" insatisfacible. *(solapa ADR-4)*
- **EDGE-12 · FR-8/FR-10** — bolsillo ≫15 (p. ej. 60) con checkpoint único → sesiones de horas con un solo descanso; acotar rango o checkpoint recurrente.
- **EDGE-13 · FR-9/FR-7** — pausa tras gastar el bolsillo en upkeep (no cargado al bag) → contabilidad de "minutos restantes que regresan al bag" indefinida.
- **EDGE-14 · FR-7/FR-8** — encadenar sesiones el mismo día → ¿el bag acota el avance diario total o solo la composición? SM-C1 pierde referencia.
- **EDGE-15 · FR-23/FR-7** — snowball con bolsa ya a 30 → suprimir la sugerencia en el tope del rango.
- **EDGE-16 · FR-16/FR-29** — escaneo asíncrono sin timeout, app a background o proveedor colgado → definir timeout, sondeo solo en primer plano y descarte.
- **EDGE-17 · §7/FR-30** — el export se declara "restore format" pero ningún FR especifica importar/restaurar → añadir FR de restauración o retirar la promesa.
- **EDGE-18 · FR-27/FR-32** — transcripción vacía/línea en blanco con tamaño elegible → validar línea no vacía antes de habilitar captura; tarea sin texto entra al pool irreversible.
- **EDGE-19 · FR-5/FR-29** — rescue falla por no-Slicer y el contador no se resetea → reintento de re-slice en cada reparto posterior; backoff/reset.
- **EDGE-20 · FR-5** — usuario rechaza los pasos de rescue repetidamente, profundidad ya en tope 1 → tarea zombi re-tejida para siempre; estado terminal (disolución silenciosa tras N rechazos).
- **EDGE-21 · FR-31/FR-11** — onboarding abandonado a mitad de curación → estado por defecto (todos los clusters activos) o el primer día 1-3-5 puede salir vacío.

---

## Lente: Editorial Structure — tabla de hallazgos (13: 9 cortes, 1 pregunta de andamiaje, 3 PRESERVE)

Modelo: Strategic/Context (Pyramid). Desajuste estructural principal: §0 abre con ~380 palabras de historia de revisiones antes que la conclusión.

| Pass | Original | Revisión propuesta | Motivo |
|---|---|---|---|
| structure | §0 — 4 bloques "Revision" (~380 palabras) | MOVE a "Changelog" final + CONDENSE a 1–2 líneas cada uno | Pyramid: lo crítico primero; ~380 palabras devueltas al frente |
| structure | §0 "§10 single record" vs valores restated en FR-5/6/7/10/21/23 | QUESTION — una sola convención: FRs citan "Valor: §10.1" (como §3) o §10.1 se declara índice | Dos fuentes por parámetro divergen a la primera edición |
| structure | §3 — entradas con política nivel-FR (Archetype Template ~110 palabras, Manual Capture, AI Access Path…) | CONDENSE a definición + puntero al FR propietario | ~300 palabras; una fuente menos por ruling |
| structure | Ruling `Tirar o soltar` argumentado en 3 sitios (§0, §3, FR-20/22) | MERGE en FR-20; §3 conserva solo el mapeo concepto→label | ~150 palabras; elimina copias paralelas divergentes |
| structure | Gemma 4/topología en 4 sitios (§4.4, OQ1, §10.1, §10.2) | CONDENSE §4.4 a intención (~60 palabras) + "estado: OQ1" | Un único dueño del estado de la pregunta empírica |
| structure | Rationale de FR-32 duplicada en bullets de §7 | MERGE en FR-32; §7 conserva constraint + puntero | §7 debe ser el mapa canónico para `bmad-architecture` |
| structure | §6 MVP — 13 bullets que re-listan la tabla de §4 | CONDENSE a cabecera + ítems sin FR propio | Dos índices paralelos divergen al añadir el próximo FR |
| structure | Procedencia datada inline ("Added 2026-08-xx", "Promoted…") en 9 FRs | MOVE al changelog; el FR enuncia la regla vigente | Las historias necesitan la regla, no su fecha (~100 palabras) |
| structure | §10.1 — filas-párrafo ("AI Access Path" ~45 palabras) y fila "Working title" | CONDENSE a parámetro+valor corto; MOVE "Working title" fuera | La tabla recupera su esquema consistente y escaneable |
| structure | §5.2 "task list" — invariante citada desde ~7 secciones como bullet anónimo | QUESTION — ¿registro nombrado con ID estable (tipo E1/E2)? | "§5.2's exclusion" es referencia posicional frágil |
| structure | §9 OQs cerradas con tachado (OQ-2/3/4/9) | **PRESERVE** | FRs y §7 citan esos rulings por número |
| structure | Tags "Realizes UJ-x" / "Validates FR-x" | **PRESERVE** | Andamio de trazabilidad para épicas/stories |
| structure | §5.1/§5.2 dividido "deliberately" | **PRESERVE** | MECE real; la decisión de alcance más citada |

Reducción estimada si se aceptan todos los cortes: ~1.400–1.500 palabras (≈9% de ~16.000).

---

## JSON (hallazgos canónicos; structure se rinde como tabla por su shape declarado)

```json
[
  {"lens":"adversarial","location":"FR-31 vs §3/§10.1/A12","trigger_condition":"Piso de cobertura cuenta entradas de 3 min y mensuales no elegibles para el slot Focus Chunk (10–15 min): solo 20 entradas semanales 10–15 en A12 y una zona con 3 no cubre 7 días","guard_snippet":"Reformular el piso en unidades elegibles (≥7 entradas 10–15 por zona) y decidir el rol del cluster fondo","potential_consequence":"Semanas enteras repiten Focus Chunk; la verificación 'checkable by counting' pasa mientras la garantía fracasa"},
  {"lens":"adversarial","location":"§3/§10.1 'Epic seeds' vs FR-11/E1","trigger_condition":"El glosario declara Epic seeds pero ninguna superficie las usa: FR-11 prohíbe Épicos from a template y E1 instancia solo Evergreen","guard_snippet":"Eliminar Epic seeds o fijar su superficie en FR-11 (prefill manual vía Slicer)","potential_consequence":"Vocabulario muerto que reabre la ficción de plantilla suplantando al Slicer"},
  {"lens":"adversarial","location":"FR-7 vs FR-12","trigger_condition":"Time Bag 5 min legal pero ningún Focus Chunk (10–15) cabe; composición indefinida","guard_snippet":"Regla del caso límite (slot '1' vacío sin deuda) o mínimo de bolsa 10","potential_consequence":"SM-3 estructuralmente imposible sin aviso"},
  {"lens":"adversarial","location":"FR-10 vs FR-8/UJ-1","trigger_condition":"Checkpoint 10–15 aritméticamente falso en bolsillos 5–9 min; con defaults coincide con el final de la sesión","guard_snippet":"Checkpoint = min(bolsillo, valor) o eximir sesiones cortas","potential_consequence":"O nunca aparece o es solo cierre nativo; el anti-maratón queda decorativo"},
  {"lens":"adversarial","location":"FR-12 consecuencia 5","trigger_condition":"Frase '26 min siempre excedía la bolsa' caducada tras 2026-08-23 (solo Focus Chunk se carga: 15 vs 15)","guard_snippet":"Reescribir en pasado explícito o eliminar","potential_consequence":"Dos lecturas del mismo FR producen escalados distintos"},
  {"lens":"adversarial","location":"FR-26 vs FR-5/FR-27","trigger_condition":"Origen de tareas re-rebanadas indefinido (¿manual→cloud?)","guard_snippet":"Regla de herencia en FR-26: la re-slice no cambia el origen de génesis","potential_consequence":"SM-4 y el detector de §10.2 dan veredictos opuestos según etiquetado"},
  {"lens":"adversarial","location":"§7 accesibilidad vs FR-28/FR-32","trigger_condition":"'No keyboard required' falso: la API key BYOK exige teclear y el dictado está limitado a la línea de captura","guard_snippet":"Acotar la afirmación y registrar disponibilidad on-device como supuesto activo","potential_consequence":"El piso de accesibilidad se rompe en la primera configuración del build"},
  {"lens":"adversarial","location":"§8 SM-2","trigger_condition":"Mecanismo de entrega de la pregunta dominical sin especificar (in-app con huecos vs notificación prohibida)","guard_snippet":"Pregunta ambiental persistida hasta la primera apertura, nunca notificada + semanas sin respuesta","potential_consequence":"El baseline de la métrica primaria acumula huecos silenciosos"},
  {"lens":"adversarial","location":"UJ-5 vs FR-27/FR-12/FR-5","trigger_condition":"Captura con día ('el jueves'): adelantada por FR-12 y/o despedazada por el rescue de FR-5","guard_snippet":"Semántica de capturas con día implícito (exención del contador o incorporar a OQ-11)","potential_consequence":"El ejemplo estrella se comporta patológicamente con su propio caso"},
  {"lens":"adversarial","location":"FR-23 snowball","trigger_condition":"'Día cómodo' indefinido; 'streak' interno vs principio 2 sin matiz","guard_snippet":"Definir en términos de serie (a) de FR-26; acotar principio 2 a contadores visibles","potential_consequence":"Disparador no verificable por ningún test"},
  {"lens":"adversarial","location":"§3 'Evergreen always active' vs FR-31/FR-11","trigger_condition":"Desactivar el cluster de la zona activa deja el día sin zona; 'instantiate' no añade nada al día 1 por defecto","guard_snippet":"Reconciliar ciclo de vida: rotación bajo curación y significado de instanciar","potential_consequence":"Rotación indefinida y tres secciones con ciclos de vida incompatibles"},
  {"lens":"adversarial","location":"§3/FR-21 Quarantine Box","trigger_condition":"'If untouched after 6 months' es inobservable para la app","guard_snippet":"Eliminar el condicional o añadir la señal ('la caja se vació')","potential_consequence":"Requisito implementable solo transgrediéndolo; contradicción auditable SM-C2"},
  {"lens":"adversarial","location":"§7 mapa de egreso vs FR-11/E2","trigger_condition":"Génesis por texto/formulario viaja al Slicer sin consentimiento especificado ni serie en FR-26","guard_snippet":"Añadir el tercer payload al mapa y a FR-25 e instrumentarlo","potential_consequence":"Texto personal del hogar sale sin copys ni registro; el mapa load-bearing es falso"},
  {"lens":"adversarial","location":"FR-12 reserva del slot vs precedencia manual","trigger_condition":"Captura manual 10–15: ¿ocupa el slot reservado o añade un segundo ítem? 'Focus Chunk' = tamaño y papel a la vez","guard_snippet":"Fijar vocabulario y resolver el caso por escrito","potential_consequence":"Días distintos según implementador; SM-3 varía"},
  {"lens":"adversarial","location":"§1.1 registro de excepciones","trigger_condition":"'Solo donde el registro nombra' pero FR-20/FR-27/FR-4/SM-2 son listas de opciones sin excepción","guard_snippet":"Acotar la letra del principio 1 o registrar cada superficie","potential_consequence":"Cualquier lector literal invalida cuatro FRs con el propio mecanismo del documento"},
  {"lens":"adversarial","location":"§8 anexo vs §10.2","trigger_condition":"'Per-key cost attribution' asumida sin fila de supuesto ni cobertura en OQ-10","guard_snippet":"Registrar el supuesto o la alternativa aceptada","potential_consequence":"La configuración del anexo cambia en silencio sin registrar el desvío"},
  {"lens":"edge-case-hunter","location":"FR-4","trigger_condition":"Energía 🟡 sin exclusión definida","guard_snippet":"Rama explícita: 🟡 excluye 10–15 o sin filtro","potential_consequence":"Pool indeterminado en días 🟡 según build"},
  {"lens":"edge-case-hunter","location":"FR-4/FR-27","trigger_condition":"Captura 10–15 con 🔴 sostenido ≥3 días","guard_snippet":"Congelar contador de 3 días en días incompatibles","potential_consequence":"SLA de 3 días incumplible; estado tras expirar indefinido"},
  {"lens":"edge-case-hunter","location":"FR-6","trigger_condition":"Captura seguida de ausencia ≥48 h que cruza el límite de 3 días","guard_snippet":"Especificar congelación de la latencia en ausencias","potential_consequence":"Capturas 'vencidas' sin regla a la vuelta"},
  {"lens":"edge-case-hunter","location":"FR-27/FR-12","trigger_condition":"Backlog manual crece más rápido que los slots","guard_snippet":"FIFO + techo o caducidad silenciosa","potential_consequence":"Backlog irremovible que desplaza Evergreen/Épico indefinidamente"},
  {"lens":"edge-case-hunter","location":"FR-27/UJ-5","trigger_condition":"Plazo en la línea no modelado por el motor","guard_snippet":"Ruling: texto plano y reparto ciego, o rechazo","potential_consequence":"Tarea con vencimiento real repartida tras el plazo"},
  {"lens":"edge-case-hunter","location":"FR-7/FR-12","trigger_condition":"Time Bag 5: slot '1' vacío indefinido","guard_snippet":"Composición sin '1' o piso de bolsa ≥10","potential_consequence":"Escalado sin regla para el slot principal"},
  {"lens":"edge-case-hunter","location":"FR-31/FR-12","trigger_condition":"Desactivar cluster de la zona activa sin Épico","guard_snippet":"Fuente alternativa del slot '1' o bloqueo","potential_consequence":"Piso de cobertura anulado en runtime por curación"},
  {"lens":"edge-case-hunter","location":"FR-31/FR-4","trigger_condition":"Día 🔴: solo anclas ~30 s elegibles; el piso de 45 excluye lo diario","guard_snippet":"Extender piso a ≤60 s no diarios o aceptar repetición documentada","potential_consequence":"Toda jornada 🔴 reparte las mismas 5 tarjetas"},
  {"lens":"edge-case-hunter","location":"FR-1/FR-3/FR-8","trigger_condition":"Sesión agota el pool elegible","guard_snippet":"Cierre anticipado con copia neutral","potential_consequence":"FR-3 promete una alternativa inexistente"},
  {"lens":"edge-case-hunter","location":"FR-4/FR-10","trigger_condition":"🔴 pulsado con Focus Chunk en curso","guard_snippet":"Especificar si la tarjeta activa puede terminarse","potential_consequence":"Progreso en curso 'desaparece sin comentario'"},
  {"lens":"edge-case-hunter","location":"FR-10/FR-8","trigger_condition":"Bolsillo <10 con checkpoint 10–15","guard_snippet":"Eximir sesiones cortas o checkpoint al cierre","potential_consequence":"'Toda sesión alcanza checkpoint' insatisfacible"},
  {"lens":"edge-case-hunter","location":"FR-8/FR-10","trigger_condition":"Bolsillo ≫15 con checkpoint único","guard_snippet":"Acotar rango del bolsillo o checkpoint recurrente","potential_consequence":"Sesiones de horas con un solo descanso"},
  {"lens":"edge-case-hunter","location":"FR-9/FR-7","trigger_condition":"Pausa tras gastar bolsillo en upkeep no cargado al bag","guard_snippet":"Definir contabilidad de retroceso de minutos","potential_consequence":"Bag y bolsillo se mezclan; el presupuesto pierde significado"},
  {"lens":"edge-case-hunter","location":"FR-7/FR-8","trigger_condition":"Encadenar sesiones el mismo día","guard_snippet":"Declarar si el bag acota el avance diario total","potential_consequence":"Avance sin cota; SM-C1 sin referencia"},
  {"lens":"edge-case-hunter","location":"FR-23/FR-7","trigger_condition":"Snowball con bolsa a 30 (tope)","guard_snippet":"Suprimir sugerencia en el máximo","potential_consequence":"Acción imposible o contradice FR-7"},
  {"lens":"edge-case-hunter","location":"FR-16/FR-29","trigger_condition":"Escaneo asíncrono sin timeout; app a background","guard_snippet":"Timeout, sondeo en primer plano, descarte","potential_consequence":"Espera infinita o background work prohibido"},
  {"lens":"edge-case-hunter","location":"§7/FR-30","trigger_condition":"Export 'restore format' sin FR de importación","guard_snippet":"FR de restauración o retirar la promesa","potential_consequence":"Reinstalación sin camino de vuelta"},
  {"lens":"edge-case-hunter","location":"FR-27/FR-32","trigger_condition":"Transcripción vacía con tamaño elegible","guard_snippet":"Validar línea no vacía antes de habilitar captura","potential_consequence":"Tarea sin texto irreversible en el pool"},
  {"lens":"edge-case-hunter","location":"FR-5/FR-29","trigger_condition":"Rescue falla por no-Slicer sin reset del contador","guard_snippet":"Backoff o reset tras intento fallido","potential_consequence":"Reintento de re-slice en cada reparto"},
  {"lens":"edge-case-hunter","location":"FR-5","trigger_condition":"Rechazo repetido de los pasos de rescue, profundidad 1","guard_snippet":"Estado terminal (disolución silenciosa tras N rechazos)","potential_consequence":"Tarea zombi re-tejida para siempre"},
  {"lens":"edge-case-hunter","location":"FR-31/FR-11","trigger_condition":"Onboarding abandonado a mitad de curación","guard_snippet":"Default: todos los clusters activos","potential_consequence":"Primer día 1-3-5 posiblemente vacío"}
]
```

---

## Solapes entre lentes (señal, no duplicado)

- **ADR-3 ↔ EDGE-6** — bolsa de 5 min sin Focus Chunk posible
- **ADR-4 ↔ EDGE-11** — checkpoint vs bolsillo corto
- **ADR-1 / ADR-11 ↔ EDGE-7 / EDGE-8** — pool del Focus Chunk (piso de cobertura, curación de zonas, día 🔴)
- **ADR-9 ↔ EDGE-5** — capturas con plazo implícito

Los cuatro focos confirmados por dos métodos independientes son los de mayor prioridad.

## Orden sugerido de corrección

1. Los 4 solapes + **ADR-13** (mapa de egreso) y **ADR-6** (herencia de origen) — decisiones de producto baratas de escribir ahora y caras de descubrir en arquitectura.
2. Resto de hallazgos adversariales y edge-case según impacto.
3. Cortes de estructura (opcional, ~9% de reducción) idealmente junto con los fixes para no tocar el documento dos veces.
