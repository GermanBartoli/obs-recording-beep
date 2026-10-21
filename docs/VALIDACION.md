# Validación

## Entorno comprobado

- Fecha: 21 de octubre de 2026.
- Windows, OBS Studio **32.2.2**, distribución de Steam, 64 bits.
- Complemento cargado desde Herramientas → Scripts.
- Configuración: 880 Hz, 140 ms y diagnóstico habilitado durante la prueba.

## Pruebas automatizadas

La suite `tests/recording_beep_spec.lua` pasó usando `lua51.dll`, el runtime LuaJIT incluido en la instalación de OBS, mediante `tools/test_windows.py`.

Se verificaron el ciclo de inicio/pausa/reanudación/detención, ausencia de avisos duplicados al recibir STARTED, silencio en eventos ajenos, desactivación, valores predeterminados, límites de configuración, fallos de reproducción, plataforma incompatible y descarga/recarga del callback.

Estas pruebas simulan el estado de OBS: no sustituyen la validación real siguiente.

## Prueba real de la versión inicial en OBS

Se probó el botón **Probar pitido** y luego se utilizó la interfaz habitual para iniciar, pausar, reanudar y detener una grabación. Windows devolvió éxito en todas las llamadas de reproducción. OBS produjo **673 fotogramas** y finalizó la grabación.

Extracto del registro, limitado a los eventos relevantes:

```text
13:46:08.997 Inicio: antes del pitido; activa=false; pausada=false
13:46:09.139 Inicio: pitido terminado
13:46:09.218 Recording Start
13:46:14.832 Pausa: antes del pitido; activa=true; pausada=true
13:46:14.973 Pausa: pitido terminado
13:46:25.819 Recording Stop
13:46:25.820 Detención: antes del pitido; activa=false; pausada=false
13:46:25.961 Detención: pitido terminado
```

El aviso de inicio terminó **79 ms antes** del inicio registrado por OBS. El aviso de pausa se ejecutó con `pausada=true`, y el de detención con `activa=false`. Reanudar no generó un aviso adicional.

La comprobación acredita los eventos y la respuesta de la API de audio. No mide el sonido físico de los parlantes ni garantiza que los búferes de captura excluyan totalmente el sonido del archivo grabado. La grabación de prueba no se publica.

## Ajuste posterior de reanudación

Después de esta prueba se agregó el aviso al reanudar, la pausa de protección y los márgenes de 200/350 ms. La suite automatizada actual pasó con estos cambios, incluyendo cancelación al detener, descarga con trabajo pendiente y pausa no confirmada. Este ajuste todavía requiere recargar el script y repetir la prueba real en OBS; el extracto anterior corresponde al comportamiento inicial.

Se pudo decodificar el audio AAC de la grabación inicial (537600 muestras), pero no se completó una comprobación de ausencia de pitidos en el archivo. No se afirma que el sonido quede excluido de la captura.

## Cómo repetir la prueba

1. Cargá el script una sola vez y habilitá el diagnóstico.
2. Usá **Probar pitido** y comprobá que se escucha en tu salida de Windows.
3. Iniciá una grabación corta con el botón habitual.
4. Pausá, reanudá y detené.
5. En el registro, verificá el orden de inicio/pausa/detención y que el nuevo aviso de reanudación muestre `pausada=true` antes de continuar.
6. Confirmá que OBS volvió a **Iniciar Grabación** y desactivá el diagnóstico.
7. Si necesitás asegurar que el sonido no se captura, revisá el audio del archivo y tu configuración de captura/monitorización.
