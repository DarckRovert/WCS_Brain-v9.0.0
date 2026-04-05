# FAQ — WCS_Brain ❓

> **Preguntas Frecuentes del ecosistema El Séquito del Terror.**

---

### Peligros y Seguridad 🛡️

**¿El uso de IA en WCS_Brain puede causar baneo?**
No. La "IA" de WCS_Brain es una red neuronal local que se ejecuta dentro del sandbox de Lua de World of Warcraft. No lee memoria externa ni automatiza clics de hardware. Todas las acciones se sugieren mediante el "Botón de Pensar" y deben ser validadas por el jugador.

---

### Rendimiento y Memoria 📊

**¿WCS_Brain consume mucha memoria?**
WCS_Brain es un framework robusto. Consume entre 15MB y 25MB de RAM dependiendo de la cantidad de datos en el banco del clan y el historial de aprendizaje. Sin embargo, utiliza un sistema de **Throttling** para asegurar que el impacto en los FPS sea nulo durante el combate.

**¿Cómo puedo reducir el consumo de memoria?**
Puedes usar el comando `/wb cleanup` para purgar el historial de aprendizaje antiguo o cache de combate.

---

### Funcionalidades de Clan 👥

**¿Cómo sincronizo los datos con mi hermandad?**
WCS_Brain utiliza un canal de addon oculto (`WCS_SYNC`). La sincronización es P2P (Peer-to-Peer). Cuando estás en un grupo o raid con otros miembros de **El Séquito del Terror**, el addon intercambiará automáticamente datos de honor, kills y estado del banco.

**¿El Banco del Clan es real?**
Es una simulación logística. Sirve para llevar un registro de quién tiene qué recursos, facilitando la organización de raids sin necesidad de usar el banco de hermandad estándar de versiones superiores de WoW.

---

### Solución de Problemas Comunes 🛠️

**El panel principal no aparece al escribir /wb.**
Asegúrate de que no haya conflictos con otros addons de interfaz. Prueba a usar `/wb hide` y luego `/wb show`. Si persiste, usa `/wb reset` (Cuidado: esto borrará tu configuración).

**La mascota no sigue las órdenes de la IA.**
Verifica en la pestaña **Mascotas** que el "Modo Inteligente" esté activo. Además, asegúrate de tener los hechizos de la mascota en su barra de acción original.

---
© 2026 **DarckRovert** — El Séquito del Terror.
