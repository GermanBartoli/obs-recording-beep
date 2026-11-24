# Guía de obs-recording-beep

El complemento que carga OBS es `src/obs-recording-beep.lua`. Al cambiar los eventos de grabación, revisá el registro y la baja del callback y que cada transición reproduzca un único aviso.

Desde la raíz, corré `luajit tests/recording_beep_spec.lua` o, en Windows, `python tools/test_windows.py --obs-bin "<carpeta bin/64bit de OBS>"`. Para validar el audio real, usá «Probar pitido» y recorré inicio, pausa, reanudación y detención en OBS.

Consultá los pasos de validación en [el flujo de GitHub Actions](.github/workflows/tests.yml).
