# Reconciliación de credenciales: Architecture Spine → PRD

**Fecha:** 2026-08-27  
**Input:** `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md`  
**Fuentes contrastadas:** `prd.md`, `addendum.md`  
**Alcance:** exclusivamente la corrección de credenciales en reposo fijada por AD-11 y AD-22.

## Veredicto

**PASS — sin brechas ni contradicciones materiales.**

La formulación actual de FR-28 conserva el requisito de producto y coincide con el contrato arquitectónico:

- AndroidKeyStore retiene una clave de envoltura no exportable; no afirma que almacene directamente la cadena arbitraria de la API key.
- La credencial del proveedor reside como sobre cifrado y acotado al proveedor en almacenamiento privado de la aplicación, nunca en preferencias ni en el export.
- La selección del proveedor puede restaurarse, mientras que la disponibilidad de la credencial es una capacidad local de la instalación comprobada en vivo.
- El texto plano solo existe al guardarlo o durante una petición a su propio proveedor. El addendum completa el detalle técnico de AD-22: ámbito `withCredential`, ausencia de caché y exclusión del core funcional.

## Evidencia de cobertura

1. **FR-28 (`prd.md`, §4.10).** Expresa la separación wrapping key / encrypted envelope, excluye preferencias y export, y distingue selección restaurable de disponibilidad local.
2. **OQ-9 cerrado (`prd.md`, §9).** Repite el mecanismo corregido y remite a FR-29 para material ausente, inválido o agotado.
3. **Historial (`prd.md`, 2026-08-27).** Registra explícitamente la sustitución de la formulación imposible anterior.
4. **Addendum A14.** Conserva la justificación técnica, incluye Files, descifrado vivo, `withCredential`, no caché, no paso por el core y referencia AD-22 como contrato autoritativo.

## Barrido de contradicciones

No queda en `prd.md` ni `addendum.md` ninguna afirmación vigente de que la API key arbitraria se almacene directamente en AndroidKeyStore, ninguna persistencia de `keyExists` o de disponibilidad de credencial, ni ninguna inclusión del secreto en log, preferencias, restauración o export.

La frase de FR-28 “protegida en reposo por el OS keystore” no constituye contradicción: la oración la define inmediatamente como protección mediante una wrapping key en AndroidKeyStore y un sobre cifrado en almacenamiento privado. A14 elimina la posible ambigüedad histórica.

## Resultado

No se requieren cambios adicionales para reconciliar el PRD con AD-11/AD-22 en este alcance.
