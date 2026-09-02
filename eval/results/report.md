# Model-evaluation report — story 4.1

Generated 2026-09-02T20:54:57.930976 by `make eval-report`. Machine-written: the builder reviews the  
selection proposal and the OQ-1 draft below before the PRD/spine edit lands.

## Shared inputs (byte-identical for every candidate)

- prompt: `eval/prompt.md` — sent as the text below its `---` marker, verbatim at the end of this report
- schema: `eval/schema.json` — verbatim at the end of this report
- bar: `eval/PASS-BAR.md` — confirmed on 2026-09-02
- corpus: `eval/corpus/manifest.json` — 10 photos, 10 space types (Dormitorio, Cocina, Salón, Baño, Despacho, Comedor, Habitación infantil, Recibidor, Lavadero, Vestidor)
- shared-input digests: not recorded (the runs predate the digest amendment); byte-identity rests on the run procedure

## Runs

- e2b_local: 1 run(s), model(s) gemma4-it-e2b-FLM
- e4b_local: 1 run(s), model(s) gemma4-it-e4b-FLM
- gemini: 1 run(s), model(s) google/gemini-3.5-flash-lite, via openrouter
- openai: 1 run(s), model(s) openai/gpt-5.6-luna, via openrouter
- anthropic: 1 run(s), model(s) anthropic/claude-haiku-4.5, via openrouter

## Scores

| candidate | photos | judged | machine-passed | passed | bar (≥8/10) |
|---|---|---|---|---|---|
| e2b_local | 10 | 10 | 10 | 3 | fail |
| e4b_local | 10 | 10 | 8 | 2 | fail |
| gemini | 10 | 10 | 10 | 9 | pass |
| openai | 10 | 10 | 10 | 9 | pass |
| anthropic | 10 | 10 | 10 | 6 | fail |

## Cost (whole 10-photo run per candidate)

Builder-supplied totals from the committed `results/costs.json` (OpenRouter dashboard); the evidence column sums `usage.cost_details.upstream_inference_cost` over the recorded raw responses (gitignored, reproducible from the provider). Small third-decimal differences are dashboard rounding.

| candidate | builder-supplied USD | evidence sum USD | per photo USD (evidence) |
|---|---|---|---|
| e2b_local | n/a | n/a | n/a |
| e4b_local | n/a | n/a | n/a |
| gemini | 0.00757 | 0.00757 | 0.000757 |
| openai | 0.00931 | 0.00941 | 0.000941 |
| anthropic | 0.02780 | 0.02807 | 0.002807 |

### e2b_local

- fence-stripped responses (2026-09-02 bar amendment): 10 of 10
| photo | transport | parse | durations | steps | real actions | workable order | passed |
|---|---|---|---|---|---|---|---|
| estancia-1 | ok | ok | ok | ok | ok | ok | yes |
| estancia-2 | ok | ok | ok | ok | ok | fail | no |
| estancia-3 | ok | ok | ok | ok | ok | fail | no |
| estancia-4 | ok | ok | ok | ok | ok | fail | no |
| estancia-5 | ok | ok | ok | ok | ok | ok | yes |
| estancia-6 | ok | ok | ok | ok | fail | ok | no |
| estancia-7 | ok | ok | ok | ok | fail | ok | no |
| estancia-8 | ok | ok | ok | ok | fail | ok | no |
| estancia-9 | ok | ok | ok | ok | ok | ok | yes |
| estancia-10 | ok | ok | ok | ok | ok | fail | no |

### e4b_local

- fence-stripped responses (2026-09-02 bar amendment): 6 of 10
| photo | transport | parse | durations | steps | real actions | workable order | passed |
|---|---|---|---|---|---|---|---|
| estancia-1 | ok | ok | ok | ok | ok | fail | no |
| estancia-2 | ok | ok | ok | ok | fail | ok | no |
| estancia-3 | ok | ok | ok | ok | fail | ok | no |
| estancia-4 | ok | ok | ok | ok | ok | ok | yes |
| estancia-5 | ok | ok | ok | ok | ok | ok | yes |
| estancia-6 | ok | fail — schema check failed: steps[1] is not an object; steps[2] is not an object; steps[3] is not an object; steps[4] is not an object | fail — not evaluated — an earlier limb failed | fail — not evaluated — an earlier limb failed | fail (auto) | fail (auto) | no |
| estancia-7 | ok | fail — schema check failed: steps[1] is not an object; steps[2] is not an object; steps[3] is not an object; steps[4] is not an object | fail — not evaluated — an earlier limb failed | fail — not evaluated — an earlier limb failed | fail (auto) | fail (auto) | no |
| estancia-8 | ok | ok | ok | ok | fail | ok | no |
| estancia-9 | ok | ok | ok | ok | fail | ok | no |
| estancia-10 | ok | ok | ok | ok | fail | ok | no |

### gemini

- fence-stripped responses (2026-09-02 bar amendment): 0 of 10
| photo | transport | parse | durations | steps | real actions | workable order | passed |
|---|---|---|---|---|---|---|---|
| estancia-1 | ok | ok | ok | ok | ok | ok | yes |
| estancia-2 | ok | ok | ok | ok | ok | ok | yes |
| estancia-3 | ok | ok | ok | ok | ok | ok | yes |
| estancia-4 | ok | ok | ok | ok | ok | ok | yes |
| estancia-5 | ok | ok | ok | ok | ok | ok | yes |
| estancia-6 | ok | ok | ok | ok | ok | ok | yes |
| estancia-7 | ok | ok | ok | ok | ok | ok | yes |
| estancia-8 | ok | ok | ok | ok | ok | ok | yes |
| estancia-9 | ok | ok | ok | ok | fail | ok | no |
| estancia-10 | ok | ok | ok | ok | ok | ok | yes |

### openai

- fence-stripped responses (2026-09-02 bar amendment): 0 of 10
| photo | transport | parse | durations | steps | real actions | workable order | passed |
|---|---|---|---|---|---|---|---|
| estancia-1 | ok | ok | ok | ok | ok | ok | yes |
| estancia-2 | ok | ok | ok | ok | fail | ok | no |
| estancia-3 | ok | ok | ok | ok | ok | ok | yes |
| estancia-4 | ok | ok | ok | ok | ok | ok | yes |
| estancia-5 | ok | ok | ok | ok | ok | ok | yes |
| estancia-6 | ok | ok | ok | ok | ok | ok | yes |
| estancia-7 | ok | ok | ok | ok | ok | ok | yes |
| estancia-8 | ok | ok | ok | ok | ok | ok | yes |
| estancia-9 | ok | ok | ok | ok | ok | ok | yes |
| estancia-10 | ok | ok | ok | ok | ok | ok | yes |

### anthropic

- fence-stripped responses (2026-09-02 bar amendment): 0 of 10
| photo | transport | parse | durations | steps | real actions | workable order | passed |
|---|---|---|---|---|---|---|---|
| estancia-1 | ok | ok | ok | ok | ok | ok | yes |
| estancia-2 | ok | ok | ok | ok | fail | ok | no |
| estancia-3 | ok | ok | ok | ok | ok | ok | yes |
| estancia-4 | ok | ok | ok | ok | ok | ok | yes |
| estancia-5 | ok | ok | ok | ok | ok | ok | yes |
| estancia-6 | ok | ok | ok | ok | fail | ok | no |
| estancia-7 | ok | ok | ok | ok | ok | ok | yes |
| estancia-8 | ok | ok | ok | ok | fail | fail | no |
| estancia-9 | ok | ok | ok | ok | fail | ok | no |
| estancia-10 | ok | ok | ok | ok | ok | ok | yes |

## Cascade decision

- kind: cloud-best
- selected: gemini
- gemini is the best cloud candidate at 9/10 (e2b_local 3/10, e4b_local 2/10, gemini 9/10, openai 9/10, anthropic 6/10; ties break in cascade order gemini → openai → anthropic) — proposed; the Local path stays a debug-only stub (FR-28).

## Selection proposal

gemini — proposed (best cloud candidate at ≥8/10 once the locals were killed).

## OQ-1 answer (DRAFT — builder reviews before the PRD/spine edit)

OQ-1 (draft — builder reviews before the PRD/spine edit): both local candidates were killed outright on the desktop (a desktop failure kills — the phone build cannot do better). gemini is the best cloud candidate over the identical corpus, prompt and schema, so the topology half points to cloud BYOK and the Local path ships as the debug-only canned stub (FR-28). Full scores: e2b_local 3/10, e4b_local 2/10, gemini 9/10, openai 9/10, anthropic 6/10.

## Prompt (verbatim, `eval/prompt.md`)

```text
# Prompt — foto → plan (the shared, immutable input of all five candidates)

This file is byte-identical for every candidate (`e2b_local`, `e4b_local`,
`gemini`, `openai`, `anthropic`) and is sent verbatim: the harness adds no
header, footer or wrapping of its own. Everything below the marker line is the
prompt text.

---

Eres el asistente de una app móvil de organización del hogar. Recibirás una foto real de un espacio doméstico desordenado. Tu tarea es convertirla en un plan corto que una persona pueda ejecutar hoy mismo, paso a paso.

Mira la foto con atención. Devuelve ÚNICAMENTE un objeto JSON válido con esta forma exacta:

{"steps": [{"text": "…", "duration_minutes": 4}]}

Reglas del plan:

- Escribe cada paso en español, como una acción concreta y directa: «Recoge la ropa del sillón», no «se debería recoger ropa».
- Devuelve al menos 4 pasos.
- Cada paso dura entre 3 y 5 minutos: `duration_minutes` es un número entero entre 3 y 5.
- Cada paso actúa sobre objetos que se ven en la foto. No inventes objetos ni espacios que no aparezcan.
- El orden debe ser ejecutable de principio a fin: no guardes nada en un sitio antes de despejar la superficie donde va, y despeja antes de limpiar.
- Un plan corto y realizable, no una lista exhaustiva: agrupa lo que se haga junto.

Reglas de formato:

- No escribas nada fuera del objeto JSON: ni explicaciones, ni disculpas, ni bloques de código, ni texto antes o después.
- El objeto JSON debe poder parsearse directamente.
```

## Schema (verbatim, `eval/schema.json`)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "steps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "text": { "type": "string" },
          "duration_minutes": { "type": "integer" }
        },
        "required": ["text", "duration_minutes"],
        "additionalProperties": false
      }
    }
  },
  "required": ["steps"],
  "additionalProperties": false
}
```

