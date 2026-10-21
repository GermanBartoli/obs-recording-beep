-- Pruebas de comportamiento sin grabar ni reproducir audio real.
local calls, logs = {}, {}
local callback
local active, paused = false, false
local fail_audio, fail_beep = false, false
local timers = {}
local ignore_pause = false
local ffi = { os = "Windows", cdef = function() end }
ffi.load = function()
    if fail_audio then error("Audio no disponible") end
    return { Sleep = function(ms) assert(ms == 350) end, Beep = function(frequency, duration)
        table.insert(calls, { frequency = frequency, duration = duration,
            active = active, paused = paused })
        return fail_beep and 0 or 1
    end }
end
package.loaded.ffi = ffi
obslua = {
    LOG_WARNING = 2, LOG_INFO = 1,
    OBS_FRONTEND_EVENT_RECORDING_STARTING = 10,
    OBS_FRONTEND_EVENT_RECORDING_STARTED = 11,
    OBS_FRONTEND_EVENT_RECORDING_PAUSED = 12,
    OBS_FRONTEND_EVENT_RECORDING_STOPPED = 13,
    OBS_FRONTEND_EVENT_RECORDING_UNPAUSED = 14,
    script_log = function(_, message) table.insert(logs, message) end,
    obs_frontend_recording_active = function() return active end,
    obs_frontend_recording_paused = function() return paused end,
    timer_add = function(fn, ms) timers[fn] = ms end,
    timer_remove = function(fn) timers[fn] = nil end,
    obs_frontend_recording_pause = function(value)
        if ignore_pause then return end
        paused = value
        callback(value and 12 or 14)
    end,
    obs_frontend_add_event_callback = function(fn) assert(not callback); callback = fn end,
    obs_frontend_remove_event_callback = function(fn) assert(callback == fn); callback = nil end,
    obs_data_get_bool = function(s, k) return s[k] end,
    obs_data_get_int = function(s, k) return s[k] end,
    obs_data_set_default_bool = function(s, k, v) if s[k] == nil then s[k] = v end end,
    obs_data_set_default_int = function(s, k, v) if s[k] == nil then s[k] = v end end,
}
local function tick()
    local pending = {}
    for fn in pairs(timers) do table.insert(pending, fn) end
    for _, fn in ipairs(pending) do if timers[fn] then fn() end end
end
dofile("src/obs-recording-beep.lua")
local settings = {}
script_defaults(settings)
script_load(settings)
callback(10)
assert(#calls == 1 and not calls[1].active, "El inicio debe avisar antes de grabar")
active = true
callback(11)
assert(#calls == 1, "No debe duplicar el aviso al confirmar el inicio")
paused = true
callback(12)
assert(#calls == 1, "Debe dar margen a la pausa antes del sonido")
tick()
assert(#calls == 2 and calls[2].paused, "La pausa debe avisar después de pausar")
paused = false
callback(14)
assert(paused and #calls == 2, "Reanudar debe volver a pausar antes del pitido")
tick()
assert(#calls == 3 and calls[3].paused, "El pitido de reanudación debe sonar en pausa")
tick()
assert(not paused and #calls == 3, "Debe continuar sin repetir el pitido")
callback(999)
assert(#calls == 3, "Otros eventos deben ser silenciosos")
active = false
callback(13)
assert(#calls == 4 and not calls[4].active, "Detener debe avisar después de finalizar")
assert(calls[1].frequency == 880 and calls[1].duration == 140)
settings.enabled = false
script_update(settings)
callback(10)
assert(#calls == 4, "Desactivar debe silenciar los avisos")
settings.enabled, settings.duration, settings.frequency = true, 999999, -1
script_update(settings)
callback(10)
assert(calls[5].duration == 300 and calls[5].frequency == 200)
settings.duration, settings.frequency = -1, 999999
script_update(settings)
callback(10)
assert(calls[6].duration == 50 and calls[6].frequency == 2000)
fail_beep = true
callback(10)
assert(#logs == 1, "Debe registrar el error de reproducción sin interrumpir OBS")
fail_beep = false
script_unload()
assert(next(timers) == nil, "Descargar debe cancelar todos los temporizadores")
assert(callback == nil, "Descargar debe retirar el callback")
fail_audio = true
script_load(settings)
local count = #calls
callback(10)
assert(#calls == count and #logs == 2, "Sin audio debe continuar sin lanzar errores")
script_unload()
fail_audio = false
ffi.os = "Linux"
script_load(settings)
callback(10)
assert(#calls == count and #logs == 3, "Debe manejar plataformas no compatibles")
script_unload()
ffi.os = "Windows"
settings.diagnostics = true
script_load(settings)
callback(10)
assert(#calls == count + 1 and #logs == 5, "Debe poder recargarse y registrar el diagnóstico")
script_unload()
settings.diagnostics = false
script_load(settings)
active, paused = true, false
callback(14)
assert(paused)
active, paused = false, false
callback(13)
count = #calls
tick()
assert(#calls == count and next(timers) == nil, "Detener debe cancelar la reanudación pendiente")
active, ignore_pause = true, true
callback(14)
for _ = 1, 41 do tick() end
assert(#calls == count and next(timers) == nil, "Sin pausa confirmada no debe sonar ni insistir indefinidamente")
ignore_pause = false
callback(14)
assert(paused)
script_unload()
assert(next(timers) == nil, "Descargar durante reanudación debe cancelar el trabajo pendiente")
print("OK: ciclo de grabación, configuración, límites, fallos y recarga")
