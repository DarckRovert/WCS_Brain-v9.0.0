# Guía de Usuario — WCS_Brain v9.3.1

## Inicio Rápido

### Primer Uso
1. Entra al juego con un personaje Warlock.
2. Escribe /wb para abrir el panel principal.
3. El panel muestra 14 pestañas en la parte superior.
4. Haz clic en **"Clan"** para comenzar a registrar a tus compañeros.

### Configuración Inicial Recomendada
- **Pestaña Perfiles** → Crea un perfil con el nombre de tu personaje.
- **Pestaña IA** → Activa el modo de aprendizaje con /wb ai start.
- **Pestaña HUD** → Posiciona el HUD de recursos en la pantalla.

---

## Las 14 Pestañas Explicadas

| # | Pestaña | Función |
|---|---|---|
| 1 | **Clan** | Lista de miembros, rangos y estado online |
| 2 | **IA DQN** | Motor de aprendizaje táctico |
| 3 | **HUD** | Recursos de Warlock (mana, soul shards, mascota) |
| 4 | **Mascotas** | Control avanzado de la IA de mascotas |
| 5 | **Grimorio** | Rotaciones y hechizos optimizados |
| 6 | **Estadísticas** | Rendimiento histórico de combate |
| 7 | **PvP** | Tracker de honor y kills del clan |
| 8 | **Raid** | Organización de grupos y asignación de roles |
| 9 | **Banco** | Seguimiento de recursos del clan |
| 10 | **Macros** | Gestor de macros predefinidas |
| 11 | **Alertas** | Notificaciones de demonios y eventos |
| 12 | **Perfiles** | Configuraciones guardadas por personaje |
| 13 | **Invocación** | Panel de convocatoria grupal |
| 14 | **Dashboard** | Diagnóstico y rendimiento del addon |

---

## Preguntas Frecuentes

**¿El addon afecta al rendimiento del juego?**
El sistema de throttling de eventos limita el procesamiento a lo esencial. En combate, el uso de CPU es mínimo.

**¿Puedo usarlo con un personaje que no sea Warlock?**
Sí, pero algunas funciones (HUD de Warlock, IA de mascotas) estarán deshabilitadas automáticamente.

**¿Cómo reseteo solo una pestaña?**
Cada pestaña tiene un botón de "Reset" en su configuración. Para un reset total usa /wb reset.

**¿Los datos del Banco del Clan se sincronizan automáticamente?**
Los datos son locales. Cada miembro debe actualizar manualmente vía la pestaña Banco cuando tenga los items.

---

## Solución de Problemas

| Problema | Solución |
|---|---|
| Panel no abre | Escribe /reload y vuelve a intentar |
| IA no aprende | Verifica que tienes /wb ai start activo |
| Mascota no usa habilidades | Revisa que Auto IA Mascota esté ON en pestaña Mascotas |
| Error de 
il en consola | Actualiza a la última versión y usa /wb reset |