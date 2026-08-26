# DDLC-LOVE 1.2.3 — PS3 PORT (AIO + FIX)

Port no oficial de **Doki Doki Literature Club** a **PlayStation 3**, construido sobre
[DDLC-LOVE](https://github.com/LukeZGD/DDLC-LOVE) de LukeZGD y ejecutado mediante
**LuaPlayerPS3 5.2.1**.

Version de este port: `v1.2.3 AIO + FIX` (basado en DDLC-LOVE v1.2.3, con traduccion al español)

---

## ✅ INSTALACION SIMPLE — NO REQUIERE LUA PLAYER

**Este port ya NO necesita instalar "Lua Player PS3" ni ningun otro homebrew previo.**
Todo va integrado dentro del PKG: **solo instala el PKG y listo**, aparece en el XMB
como un juego mas y corre directo desde ahi.

---

## ⚠️ AVISO IMPORTANTE — ESTABILIDAD

**A este port se le aplicaron numerosas correcciones de estabilidad** (audio, memoria,
carga de assets, transiciones -- ver lista completa abajo), y el juego ya es terminable
de principio a fin. **PERO**: al no contar con el codigo fuente del interprete
LuaPlayerPS3 5.2.1 (solo existe como binario compilado), existen fugas de memoria y
limitaciones a nivel del motor que NO pueden eliminarse desde los scripts del juego.
Por lo tanto **el juego sigue pudiendo ser inestable en ocasiones**, especialmente en
partidas muy largas o con uso intensivo del avance rapido (R1).
Si el juego llegara a congelarse, simplemente reinicialo: las partidas guardadas
(autoload) te devuelven practicamente al mismo punto.

---

> This port is unofficial and is not affiliated with Team Salvato.
> Please support the official game.
>
> You can download Doki Doki Literature Club at: https://ddlc.moe
>
> For the full experience of the game on the PC, Switch, and other consoles,
> please support Team Salvato and buy Doki Doki Literature Club Plus!
> Get the official console versions at: https://ddlc.plus

---

## Que es esto

Este repositorio contiene el trabajo de adaptar DDLC-LOVE (que ya corre en PSP, PS Vita,
3DS, Switch y PC) a la PlayStation 3 real, corrigiendo los problemas graves que tenia la
version base sobre el hardware de la consola: congelamientos durante el minijuego de
poesia, al cargar partidas, al cambiar de cancion y en transiciones pesadas del Acto 2.

El motor es LuaPlayerPS3 (interprete Lua homebrew) + LOVE-WrapLua (capa que traduce las
llamadas estilo LÖVE 2D a funciones nativas de la PS3). Sobre ese conjunto se aplico una
serie de correcciones profundas documentadas abajo.

**Nota:** este repo NO incluye los assets originales del juego (imagenes, audio, textos
de DDLC). Por respeto a Team Salvato y sus guias de propiedad intelectual, cada quien
debe proveer sus propios assets desde su copia legitima del juego colocandolos dentro de
`USRDIR/DDLC-LOVE/game/assets/`.

## Instalacion

1. Instalar el PKG en una PS3 con CFW/HAN (o construirlo usted mismo con los assets).
2. Los guardados se crean automaticamente en `USRDIR/DDLC-LOVE/savedata/`.
3. Controles principales:
   - **X / Cruz**: avanzar dialogo
   - **Triangulo**: menu de pausa
   - **R1**: auto-skip (avance rapido)
   - **Start**: modo auto
   - **Circulo**: ocultar cuadro de texto / borrar letra en el teclado

## Correcciones y cambios respecto a la version original

### Audio (la causa principal de los congelamientos)
- **Migracion completa a la ruta BGM nativa del binario** (`SetBGMusic` / `PlayBGMusic(handle, loop)` /
  `StopBGMusic` / `FreeBGMusic`): la ruta anterior (`SetVoice`) filtraba memoria en CADA cambio
  de cancion porque nunca liberaba el buffer, y era el origen directo de los congelamientos
  tras ~30 cambios acumulados. Con la ruta BGM el leak desaparece por completo.
- **Eliminado el reset `snd.Init()` por cambio de cancion**: quitaba 1-2 segundos de lag
  por transicion y solo contenia el leak sin curarlo.
- **Sistema auto-validante con memoria persistente**: al primer arranque se prueba la ruta
  BGM midiendo si el tiempo de reproduccion realmente avanza; el veredicto se guarda en
  savedata y los arranques siguientes entren directo por la ruta correcta.
- **Anti re-disparo de PlayVoice**: antes `snd.PlayVoice()` se llamaba ~60 veces por
  segundo mientras sonaba una cancion (corrupcion de estado del motor de audio). Ahora se
  dispara una sola vez por reproduccion.
- **Lista NO_LOOP**: `end-voice`, `credits` y `6r` suenan una sola vez (antes se repetian
  en bucle por error).
- Volumen de la musica conectado al slider de opciones del juego.
- Sistema de precarga de audio desactivado (no cacheaba nada y generaba rafagas de
  asignaciones de memoria justo donde mas daniaba).

### Estabilidad / memoria
- **FrameSpread**: las transiciones mas pesadas (volver del minijuego de poesia, cargar
  partida, entrada al minijuego) reparten sus decodificaciones de imagen en varios frames
  en lugar de cargar hasta 15 PNG en uno solo. La pantalla queda en negro un instante y
  revela la escena completa al terminar.
- **Fugas de memoria corregidas en eventos**: imagenes de `sayori_gs`, `n_eye`,
  `s_killzoom`, familia `s_kill`, `vignette`/`eventvar2` en beforecredits, y la tabla
  global `animframe` ya no quedan retenidas para siempre ni se sobrescriben sin liberar.
- **Freno de autoskip** en todas las transiciones pesadas (cambios de cancion, cambios de
  escena, eventos): el avance rapido se detiene antes de dispararlas en medio de una rafaga.

### Rendimiento
- Auto-skip (R1) mas pausado en PS3 (una linea cada 8 frames en vez de cada 4) y
  `collectgarbage()` espaciado a 1 de cada 4 lineas en vez de una por linea.
- La secuencia de muerte de Yuri conserva el ritmo original de texto (la velocidad es
  parte de la escena).
- Acto 3: eliminada la compilacion dinamica (`loadstring`) por linea de dialogo en el
  bucle de topicos de Monika (~845 compilaciones innecesarias por tema).

### Textos / presentacion
- **Poemas con ajuste de linea real**: los poemas (en espanol y ingles) ahora se parten
  por oraciones y palabras para no salirse de la hoja, con interlineado dinamico para que
  los poemas largos entren completos en pantalla.
- **"JUST MONIKA"** en la pantalla de titulo durante el Acto 3 o posterior, como en el
  juego original.
- Teclado en pantalla traducido al espanol (nombre del jugador, mayusculas, espacio, entrar).
- Incluye traduccion completa al espanol (ademas del ingles original).

### Diagnostico
- Logger opcional a `savedata/logfile.txt`: registra cada textura cargada, transicion de
  estado, cambio de musica y evento. Util para diagnosticar problemas; se reinicia en cada
  arranque.

## Creditos

- **LukeZGD** — creador de [DDLC-LOVE](https://github.com/LukeZGD/DDLC-LOVE), la base de
  todo este port.
- **GlowTranslations** — traduccion al espanol de DDLC.
- **Team Salvato** — creadores de Doki Doki Literature Club.
- **Hermes / Estwald** — spu_soundlib y las librerias homebrew de PS3 que mueven el audio
  por SPU.
- **Comunidad Lua Player PS3** — interprete LuaPlayerPS3 5.2.1.
- **KiZeo** — port PS3, fixes de estabilidad, AIO y traduccion.

## Licencias

- El codigo de DDLC-LOVE de LukeZGD se distribuye bajo licencia MIT (ver archivo `LICENSE`).
- Este port mantiene la misma licencia para sus modificaciones.
- Doki Doki Literature Club es propiedad de Team Salvato. Este proyecto no distribuye
  ningun asset del juego y no esta afiliado a Team Salvato.
