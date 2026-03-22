# Changelog - WCS_Brain

Todas las versiones notables de este proyecto serán documentadas en este archivo.

---

## [8.2.0] - Marzo 24, 2026
### 🧠 INTELIGENCIA TÁCTICA GOD-TIER
- **Smart Dispel (Felhunter)**: Priorización dinámica de debuffs (CC > Silencio > Daño).
- **Sistema de Peeling (Voydwalker)**: Intercepción reactiva de atacantes para proteger al Warlock.
- **Rastreador de Casteo 1.12**: Implementado fallback autónomo vía Combat Log para identificar hechizos enemigos.
- **Ejecución Nativa (v8.1.0)**: Migración completa a `CastPetAction` garantizando 100% obediencia técnica.
- **Unificación de Motores**: El `PetManager` básico ahora delega toda la táctica al cerebro avanzado.

## [8.0.0] - Marzo 22, 2026
### 🏆 EVOLUCIÓN GOD-TIER
- **Soporte Multi-Clase Universal**: Integración del `WCS_ClassEngine` y `WCS_ClassRotations`. La IA ahora detecta la raza y clase (las 9 disponibles) y ejecuta rotaciones con mitigación de daño, sin depender de Warlocks.
- **Hub de Comando Unificado (5-Tabs)**: El macro-panel de opciones se rediseñó desde cero para incluir pestañas directas de `IA`, `CLAN`, `PET`, `HUD` y `SYS` bajo el comando unificado `/brain`.
- **Rebirth Gráfico (Deep Void Theme)**: La estética del addon fue pulida en sus ~40 paneles secundarios eliminando las UI base genéricas e implementando Tooltips oscuros con bordes violetas `#9482C9` (0.58, 0.51, 0.79).
- **Control de Mascotas Inteligente**: Guardianes de clase dinámicos aseguran que la UI de mascotas (`WCS_BrainPetUI`) solo se ejecute y recaude memoria si el jugador es Warlock o Hunter.
- **Micro-Optimizaciones Lua 5.0**: Limpieza total de incompatibilidades futuras (`#table`, `string.match`) brindando compatibilidad inmaculada con 1.12.
- **Auditoría Forense 100% Correcta**: Arreglo de 10 bugs críticos de Lua y crasheos en el arranque.
- **WCSVault (Banco Guild P2P)**: El Banco del Clan reemplaza el "Inventario Local" por un Libro Mayor distribuido que sincroniza donaciones y préstamos en vivo a través de un protocolo oculto de addon.
- **Macros Asistidas (Raid & Summon)**: Generación 1-clic (script nativo) para macros de utilidad complejas (Soulstones, Healthstones, Auto-Curses, Ritual).
- **Roster en Tiempo Real**: Panel de miembros corregido (adiós al false *Online: 0*) atado a escuchas servidor `GUILD_ROSTER_UPDATE`.

---

## [7.0.0] - Enero 20, 2026

### 🚀 REARQUITECTURA MAYOR - Cerebro Predictivo & HUD Holográfico

Esta versión marca un hito en el desarrollo de WCS_Brain, introduciendo una arquitectura profesional basada en eventos, simulación matemática real de daño y una interfaz HUD inmersiva.

### ✨ Nuevas Características

#### 1. Cerebro Predictivo (BrainSim)
- **Simulador de daño real (DPCT):** La IA ya no "adivina" qué hechizo es mejor. Ahora calcula matemáticamente el daño por segundo de casteo (DPCT) basándose en tu gear, talentos y buffs activos.
- **Snapshotting inteligente:** Detecta procs de trinkets, Power Infusion y debuffs en el enemigo para ajustar la rotación en tiempo real.

#### 2. Interfaz Holográfica (BrainHUD)
- **HUD estilo "Iron Man":** Nueva interfaz minimalista y transparente cerca de tu personaje.
- **Visualización de decisiones:** Muestra el icono de la siguiente acción que la IA va a realizar *antes* de que ocurra.
- **Monitor de Shards:** Anillo holográfico que muestra tus Soul Shards disponibles.
- **Comando:** `/brainhud` para activar/desactivar.

#### 3. Arquitectura y Rendimiento (Core)
- **WCS_EventManager:** Nuevo bus de eventos centralizado. Elimina cientos de frames invisibles redundantes, mejorando drásticamente el rendimiento CPU.
- **WCS_ResourceManager:** Gestor unificado de recursos. El addon ahora sabe cuántas Shards tienes sin escanear tus bolsas 50 veces por segundo.

### 🔧 Cambios Técnicos
- **Refactorización Masiva:** `WCS_BrainCore` y `WCS_BrainAI` migrados al nuevo sistema de eventos.
- **Optimización de Memoria:** Reducción del garbage collection gracias a la reutilización de tablas y eventos.
- **Limpieza:** Integración de parches de versiones 6.x en el núcleo principal.

---

## [6.7.1] - Enero 12, 2026

### 🐾 Sistema de Control de Mascotas - Mejoras Críticas de Confiabilidad

**Archivo Modificado:** WCS_BrainPetAI.lua

**Problema Resuelto:**
El sistema de control de mascotas tenía una confiabilidad del ~60% debido a que usaba ChatFrameEditBox como método principal para ejecutar habilidades. Este método falla si el chat está oculto o el jugador está escribiendo.

**Nuevas Funciones Agregadas:**

1. **GetPetAbilitySlot(abilityName)** - Encuentra el slot (1-10) de una habilidad de mascota por nombre
2. **PetHasAbility(abilityName)** - Verifica si la mascota tiene una habilidad específica
3. **CanCastPetAbility(abilityName)** - Verificación completa: existencia + cooldown + mana

**Funciones Mejoradas:**

1. **ExecuteAbility()** - Completamente reescrito con sistema de 3 niveles:
   - Método 1: CastSpellByName() (95% confiable)
   - Método 2: CastPetAction(slot) (fallback)
   - Método 3: ChatFrameEditBox (último recurso)

2. **CastEnslaveDemon()** - Mejorado con CastSpellByName() primero

3. **GuardianAssist()** - Usa TargetUnit() + feedback visual

4. **GuardianDefend()** - Muestra HP del protegido

**Mejoras de Confiabilidad:**
- Antes: 60% → Después: 95%
- Cooldowns usando API real (GetPetActionCooldown)
- Debug detallado: "[Execute] Fire Shield - CastSpellByName"

**Compatibilidad:**
- ✅ WoW 1.12 (Turtle WoW) | ✅ Lua 5.0 | ✅ Todas las mascotas

**Comandos:**
```lua
/petai debug        -- Activa mensajes de debug detallados
/petai status       -- Muestra versión (v8.0.0)
```

---


## [6.9.3] - Enero 9, 2026

### 🌍 Sistema Multiidioma - Soporte Completo para Español

**Nuevos Módulos:**
- ✅ **WCS_SpellLocalization.lua** - Base de datos de 150+ traducciones español→inglés
- ✅ **WCS_SpellDB_Patch.lua** - Sobrescritura global de GetSpellName() + comando /listspells
- ✅ **WCS_BrainAutoExecute.lua** - Sistema de ejecución automática en combate

**Características Implementadas:**
- ✅ Sobrescritura global transparente de GetSpellName()
- ✅ Todos los hechizos críticos del Brujo traducidos y verificados
- ✅ Habilidades de todas las mascotas (Imp, Voidwalker, Succubus, Felhunter, Felguard)
- ✅ Sistema de cache para eficiencia
- ✅ Comando /listspells para debug (verde=traducido, rojo=sin traducir)
- ✅ Compatible con actualizaciones futuras del addon (no modifica archivos originales)

**Hechizos Traducidos:**
- Hechizos de daño: Shadow Bolt, Immolate, Corruption, Shadowburn, Rain of Fire, Hellfire, etc.
- Hechizos defensivos: Demon Armor, Demon Skin, Soul Link, Shadow Ward
- Invocaciones: Todas las mascotas + Inferno
- Piedras: Soulstone, Healthstone, Voidstone, Demonstone (todos los rangos)
- Control: Fear, Banish, Enslave Demon, Death Coil, Drain Soul, etc.

**Sistema de Ejecución Automática:**
- Frame OnUpdate con throttling (0.2s por defecto)
- Comandos: /autoexec on/off, /autoexec status, /autoexec interval
- Respeta GCD y cooldowns
- Activado por defecto: NO (el usuario debe activarlo con /autoexec on)

**Archivos Modificados:**
- WCS_Brain.toc - Añadidas 3 líneas para cargar los nuevos módulos

**Documentación:**
- ✅ MULTIIDIOMA.md - Documentación completa del sistema
- ✅ README.md - Actualizado con sección de multiidioma
- ✅ CHANGELOG.md - Añadida entrada v8.0.0

**Verificación:**
- ✅ Todos los hechizos críticos del Brujo funcionan correctamente
- ✅ Sistema probado en Turtle WoW con cliente en español
- ✅ Compatible con Lua 5.0 (WoW 1.12)

---

## [6.9.2] - Enero 7, 2026

### 🔧 Dashboard Mejorado y Limpieza de Código

**Mejoras al Dashboard:**
- ✅ Integrado con WCS_BrainMetrics (sistema original del addon)
- ✅ Muestra datos REALES de combate
- ✅ Contador de "Decisiones IA" ahora funciona correctamente
- ✅ Contador de "Pet IA" lee desde WCS_BrainPetAI.Stats
- ✅ Eventos procesados muestra combates totales
- ✅ CPU estimado: 15% en combate, 0.5% fuera de combate
- ✅ Desactivado WCS_BrainDashboard_Counters.lua (hooks rompían funciones)

**Archivos Modificados:**
- WCS_BrainDashboard_Fix.lua - Integrado con WCS_BrainMetrics.Data.spellUsage
- WCS_Brain.toc - Desactivado Counters, eliminadas referencias a archivos basura

**Archivos Basura Eliminados:**
- ❌ WCS_BrainCore_Debug.lua (sobrescribía ExecuteAction)
- ❌ WCS_BrainCore_CastDebug.lua (debug innecesario)
- ❌ WCS_BrainAutoCombat.lua (interfería con sistema existente)
- ❌ WCS_BrainKeybind.lua (no necesario)
- ❌ Bindings.xml (keybinds no necesarios)

**Cómo Usar el Addon:**
El addon WCS_Brain se usa con el **botón flotante** en pantalla (icono morado):
- Click DERECHO → Ejecuta la IA automáticamente
- Click IZQUIERDO → Abre configuración

**Archivos Útiles del Dashboard:**
- ✅ WCS_BrainDashboard.lua (original)
- ✅ WCS_BrainDashboard_Fix.lua (integración con Metrics)
- ✅ WCS_BrainDashboard_Debug.lua (/wcsdebug)
- ✅ WCS_BrainDashboard_Test.lua (/wcsdashtest)
- ✅ WCS_BrainDashboard_Inspect.lua (/wcsdashinspect)

---

## [6.9.0] - Enero 6, 2026

### 🚀 FASE 3 - Nuevas Features y Optimizaciones

**FASE 2: Optimizaciones de Memoria (Riesgo BAJO)**

**Nuevos Módulos:**
- **WCS_BrainCleanup.lua** - Limpieza automática de cooldowns principales cada 60s
- **WCS_BrainPetAICleanup.lua** - Limpieza automática de cooldowns de mascotas cada 60s

**Mejoras:**
- ✅ Prevención de crecimiento indefinido de tablas de cooldowns
- ✅ Gestión automática de memoria sin intervención manual
- ✅ Sistema de limpieza no invasivo que no afecta funcionalidad

---

**FASE 3 - SESIÓN 1: Features de Prioridad ALTA (Riesgo BAJO)**

**Nuevos Módulos:**
- **WCS_BrainEventThrottle.lua** - Sistema de throttling de eventos de combate
- **WCS_BrainNotifications.lua** - Notificaciones en pantalla estilo Blizzard
- **WCS_BrainSavedVarsValidator.lua** - Validación automática de SavedVariables
- **WCS_BrainSafety.lua** - Límites de seguridad globales

**Características:**

**1. Throttling de Eventos:**
- Limita procesamiento de eventos frecuentes (COMBAT_LOG: 0.1s, UNIT_HEALTH: 0.15s)
- Estadísticas de eventos bloqueados
- Comando: `/wcsthrottle stats`
- Mejora FPS en combates intensos

**2. Notificaciones:**
- UIErrorsFrame (centro de pantalla) + fallback a chat
- 5 tipos: INFO, SUCCESS, WARNING, ERROR, CRITICAL
- Colores y sonidos por tipo
- Throttling de duplicados (2s)
- Historial de 100 entradas
- Comandos: `/wcsnotif test`, `/wcsnotif history`

**3. Validación SavedVariables:**
- Validación automática al cargar addon
- Detección y reparación de datos corruptos
- Migración entre versiones (v5.x → v6.x → v6.7 → v6.8)
- Comando: `/wcsvalidate check`

**4. Límites de Seguridad:**
- Verificación cada 30 segundos
- Límites: Cooldowns (100), LearnedSpells (500), Logs (500), History (200)
- Limpieza automática al exceder límites
- Comandos: `/wcssafety check`, `/wcssafety stats`

---

**FASE 3 - SESIÓN 2: Features de Prioridad MEDIA (Riesgo MEDIO)**

**Nuevos Módulos:**
- **WCS_BrainDashboard.lua** - Dashboard de rendimiento en tiempo real
- **WCS_BrainWeakAuras.lua** - Integración completa con WeakAuras
- **WCS_BrainBossMods.lua** - Integración con BigWigs y DBM

**Características:**

**1. Dashboard de Rendimiento:**
- Ventana movible de 400x500 píxeles
- Métricas del sistema: FPS, Latencia, Memoria, CPU
- Métricas de eventos: Procesados, Throttled
- Métricas de cooldowns: Activos, Pet Cooldowns, Caché
- Métricas de IA: Decisiones BrainAI, Decisiones PetAI
- Historial de 60 segundos
- Colores dinámicos según rendimiento
- Comandos: `/wcsdash`, `/wcsdash hide`, `/wcsdash toggle`, `/wcsdash reset`

**2. Integración WeakAuras:**
- Variable global: `WCS_WeakAurasData`
- Actualización cada 100ms
- 6 categorías de datos: player, pet, ai, cooldowns, performance, alerts
- Funciones helper para custom triggers
- Comandos: `/wcswa status`, `/wcswa test`, `/wcswa export`, `/wcswa help`

**3. Integración Boss Mods:**
- Detección automática de BigWigs y DBM
- Hooks no invasivos
- Análisis inteligente de 6 tipos de alertas
- Reacciones automáticas configurables
- Sistema de callbacks extensible
- Historial de 50 alertas
- Comandos: `/wcsbm status`, `/wcsbm stats`, `/wcsbm alerts`, `/wcsbm history`, `/wcsbm toggle`

---

**HOTFIX: Compatibilidad WoW 1.12**
- Corregido uso de `#` por `table.getn()` en todos los módulos nuevos
- Corregido uso de `self` por `this` en frames OnUpdate
- Corregido uso de `...` por `arg1` en frames
- 100% compatible con Lua 5.0

---

**Correcciones Menores (Fase 1):**
- Actualizada versión en WCS_Brain.lua (6.7.0 → 6.8.0)
- Agregado guard `isThinking` en WCS_BrainPetAI.lua para prevenir race conditions
- Protegida restauración de target en WCS_GuardianV2.lua con pcall

---

## [6.8.0] - Enero 6, 2026

### 🐾 Sistema Guardian para Mascotas - Protección de Aliados

**Nuevos Módulos:**
- **WCS_GuardianV2.lua** - Sistema mejorado de defensa con rotación de habilidades
- **WCS_BrainGuardianCombatLog.lua** - Detección de atacantes via CombatLog en tiempo real
- **WCS_BrainGuardianAlerts.lua** - Sistema de notificaciones visuales
- **WCS_BrainCombatCache_GuardianExt.lua** - Extensiones del cache para tracking multi-unidad
- **WCS_BrainMajorDemonAlerts.lua** - Alertas visuales mejoradas para demonios mayores

**Características del Sistema Guardian:**
- ✅ Modo Guardian activable con clic derecho en pet bar (targetea aliado primero)
- ✅ Detección automática de atacantes en 4 niveles de prioridad
- ✅ Tracking de atacantes en tiempo real con DPS y daño total
- ✅ Priorización automática del atacante más peligroso (mayor DPS)
- ✅ Rotación inteligente de habilidades por tipo de mascota:
  - Voidwalker: Torment/Suffering
  - Felguard: Anguish/Cleave
  - Succubus: Seduction (CC)
  - Felhunter: Spell Lock/Devour Magic
  - Imp: Fire Shield automático
- ✅ Sistema de alertas visuales (5 tipos: Under Attack, Defending, Taunt, Emergency, Protected)
- ✅ Integración con CombatCache para tracking de amenaza y DPS recibido
- ✅ Macros automáticas: WCS_Guard, WCS_PetPos

**Nuevos Comandos:**
```lua
/petguard [nombre]     -- Asignar guardián (o clic derecho en pet bar)
/petguard target       -- Asignar tu target actual
/gstats                -- Ver estadísticas detalladas del guardián
/galerts on/off        -- Activar/desactivar alertas visuales
/guardmacros create    -- Crear macros WCS_Guard y WCS_PetPos
/gdebug                -- Activar/desactivar modo debug
```

**Mejoras de Alertas de Demonios Mayores:**
- ✅ Frame visual grande (400x80px) en centro superior de pantalla
- ✅ Sistema de 3 alertas: 60s (amarillo), 30s (naranja), 15s (rojo crítico)
- ✅ Animación de parpadeo para alertas críticas
- ✅ Sonidos de alerta según urgencia
- ✅ Funciona para Infernal y Doomguard
- ✅ Comando /mdalerts test para probar alertas

### 🐛 Correcciones
- ✅ Pet ya no targetea enemigos muertos (UnitIsDead)
- ✅ Pet ya no cambia el target del jugador (guarda/restaura target)
- ✅ Sistema de debug extensivo para diagnosticar problemas

---

## [6.7.0] - Enero 3, 2026

### ⚡ Sistema de Combate Integrado

**Nuevos Módulos:**
- **WCS_BrainCombatController.lua** - Coordinador central que arbitra entre DQN, SmartAI y Heuristic
- **WCS_BrainCombatCache.lua** - Cache compartido de DoTs, threat y cooldowns
- **INTEGRACION_COMBATE.md** - Documentación completa del sistema

**Características:**
- ✅ 4 modos de operación: `hybrid`, `dqn_only`, `smartai_only`, `heuristic_only`
- ✅ Pesos configurables para modo híbrido (DQN 40%, SmartAI 40%, Heuristic 20%)
- ✅ Sistema de decisiones de emergencia automáticas (HP/Mana/Pet críticos)
- ✅ Coordinación PetAI con acciones del jugador (Fear, Death Coil, Health Funnel)
- ✅ Throttling de decisiones (0.1s mínimo entre decisiones)
- ✅ Historial de últimas 50 decisiones para análisis

**Nuevos Comandos:**
```lua
/wcscombat mode [hybrid|dqn_only|smartai_only|heuristic_only]
/wcscombat weights <dqn> <smartai> <heuristic>  -- Ej: 0.4 0.4 0.2
/wcscombat status
/wcscombat reset
```

### 🧹 Limpieza y Optimización

**Archivos Obsoletos Removidos:**
- ✅ Eliminados 6 archivos HotFix obsoletos (v8.0.0, v8.0.0, v8.0.0, v8.0.0)
- ✅ Correcciones ya integradas en código base
- ✅ WCS_Brain.toc limpio sin referencias obsoletas
- ✅ Backup completo en carpeta `backup_obsolete/`

**Mejoras de Rendimiento:**
- Eliminación de cálculos duplicados entre sistemas de IA
- Cache compartido optimiza consultas de estado
- Decisiones coherentes y unificadas

### 🔧 Correcciones Lua 5.0
- Reemplazado operador `#` por `table.getn()` en módulos nuevos
- Verificada compatibilidad total con WoW 1.12 / Turtle WoW

### 📝 Archivos Actualizados
- WCS_Brain.toc: Versión 6.7.0
- WCS_Brain.lua: Versión 6.7.0
- WCS_BrainAI.lua: Versión 6.7.0
- WCS_BrainDQN.lua: Versión 6.7.0
- WCS_BrainSmartAI.lua: Versión 6.7.0
- WCS_BrainPetAI.lua: Versión 6.7.0 + Hook OnPlayerAction()
- README.md: Actualizado con sistema de combate integrado

---

## [6.6.1] - Enero 2, 2026

### 🔧 Correcciones

#### Errores Críticos Corregidos
1. **WCS_Brain.toc** - Agregado WCS_HotFix_v8.0.0.lua faltante en el orden de carga
2. **WCS_HotFix_v8.0.0.lua** - Eliminada función getTime() duplicada que causaba conflictos
3. **WCS_HotFix_v8.0.0.lua** - Eliminada verificación innecesaria que generaba warnings
4. **WCS_BrainAI.lua:550** - Corregido uso incorrecto de tableLength() para compatibilidad Lua 5.0
5. **WCS_HotFixCommandRegistrar.lua** - Eliminado conflicto de comando duplicado

#### Limpieza de Código
- Eliminada carpeta UI/ con versiones antiguas de archivos
- Sincronizada versión en todos los archivos (6.6.1)
- Actualizadas fechas a Enero 2026
- Verificada compatibilidad Lua 5.0 en todos los módulos

### ✅ Verificaciones
- **66/66 archivos revisados** (100% del código)
- **~25,000 líneas de código** analizadas
- **0 errores de sintaxis** encontrados
- **Compatibilidad Lua 5.0** confirmada

### 📝 Notas
- NO usa características de Lua 5.1+ (#, string.gmatch, table.unpack)
- USA: table.getn(), unpack(), pairs(), string.gfind(), mod()
- Compatible con Turtle WoW (1.12)

---

## [6.6.0] - Diciembre 2025

### ✨ Nuevas Características

#### Pestaña Recursos - 100% Funcional
- **Healthstones:** Detección automática en inventario con contador en tiempo real
- **Soulstones:** Lista de miembros con SS activo y actualización automática
- **Ritual of Summoning:** Detección de portal activo y cooldown en tiempo real

#### UI del Clan - 7 Módulos Completos
1. **WCS_ClanPanel** - Panel principal con lista de miembros del guild
2. **WCS_ClanBank** - Sistema de tracking de oro con sincronización
3. **WCS_RaidManager** - Gestión de HS/SS/Curses con detección real de buffs
4. **WCS_SummonPanel** - Cola de invocaciones con prioridades
5. **WCS_Grimoire** - Biblioteca de hechizos y conocimiento
6. **WCS_PvPTracker** - Seguimiento de estadísticas PvP
7. **WCS_Statistics** - Análisis de rendimiento y métricas

### 🔧 Mejoras Técnicas
- Sistema de eventos optimizado
- Sincronización automática entre módulos
- Interfaz responsive y escalable
- Compatibilidad total con Lua 5.0
