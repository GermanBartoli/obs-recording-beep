-- OBS Recording Beep: avisos de grabación con los controles habituales de OBS.
local obs = obslua
local audio
local enabled = true
local duration = 140
local frequency = 880
local diagnostics = false
local resume_pending = false
local internal_unpause = false
local suppress_pause = false
local resume_attempts = 0

local function initialize_audio()
    local ok, result = pcall(function()
        local ffi = require("ffi")
        if ffi.os ~= "Windows" then
            error("Este complemento requiere Windows.")
        end
        ffi.cdef[[
            int __stdcall Beep(unsigned long dwFreq, unsigned long dwDuration);
            void __stdcall Sleep(unsigned long dwMilliseconds);
        ]]
        return ffi.load("kernel32")
    end)
    if ok then
        audio = result
    else
        audio = nil
        obs.script_log(obs.LOG_WARNING, "Audio no disponible: " .. tostring(result))
    end
end

local function beep(reason)
    if not enabled or not audio then return end
    if diagnostics then
        obs.script_log(obs.LOG_INFO, string.format(
            "%s: antes del pitido; activa=%s; pausada=%s",
            reason, tostring(obs.obs_frontend_recording_active()),
            tostring(obs.obs_frontend_recording_paused())))
    end
    -- Es síncrono: OBS espera a que termine el pitido antes de seguir iniciando.
    -- La duración del sonido está limitada a 300 ms.
    local ok, result = pcall(function() return audio.Beep(frequency, duration) end)
    if not ok or result == 0 then
        obs.script_log(obs.LOG_WARNING, "No se pudo reproducir el pitido: " .. tostring(result))
    elseif diagnostics then
        obs.script_log(obs.LOG_INFO, reason .. ": pitido terminado")
    end
end

local function play_pause()
    obs.timer_remove(play_pause)
    if obs.obs_frontend_recording_active() and obs.obs_frontend_recording_paused() then
        beep("Pausa")
    end
end

local function finish_resume()
    obs.timer_remove(finish_resume)
    if resume_pending and obs.obs_frontend_recording_active()
        and obs.obs_frontend_recording_paused() then
        resume_pending = false
        internal_unpause = true
        obs.obs_frontend_recording_pause(false)
    else
        resume_pending = false
    end
end

local function play_resume()
    resume_attempts = resume_attempts + 1
    if not resume_pending or not obs.obs_frontend_recording_active() or resume_attempts > 40 then
        obs.timer_remove(play_resume)
        if resume_pending and resume_attempts > 40 then
            obs.script_log(obs.LOG_WARNING, "No se confirmó la pausa; se omite el pitido de reanudación.")
        end
        resume_pending = false
        suppress_pause = false
        return
    end
    if not obs.obs_frontend_recording_paused() then return end
    obs.timer_remove(play_resume)
    beep("Reanudación")
    -- Dejar un margen para el audio pendiente antes de continuar grabando.
    obs.timer_add(finish_resume, 350)
end

local function cancel_pending()
    obs.timer_remove(play_pause)
    obs.timer_remove(play_resume)
    obs.timer_remove(finish_resume)
    resume_pending, internal_unpause, suppress_pause = false, false, false
end

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTING then
        beep("Inicio")
        if enabled and audio then audio.Sleep(350) end
    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_PAUSED then
        if suppress_pause then
            suppress_pause = false
        else
            cancel_pending()
            obs.timer_add(play_pause, 200)
        end
    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_UNPAUSED then
        obs.timer_remove(play_pause)
        if internal_unpause then
            internal_unpause = false
        elseif enabled and audio then
            -- OBS no ofrece un evento previo a reanudar. Volver a pausar y
            -- esperar su confirmación antes de emitir el sonido.
            if not resume_pending then
                resume_pending, resume_attempts = true, 0
                obs.timer_add(play_resume, 200)
            end
            suppress_pause = true
            obs.obs_frontend_recording_pause(true)
        end
    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        cancel_pending()
        beep("Detención")
    end
end

function script_description()
    return [[<h2>OBS Recording Beep</h2>
<p>Un pitido <b>antes de iniciar</b>, <b>después de pausar</b> y
<b>después de detener</b> la grabación.</p>
<p>Usá los botones o atajos habituales de OBS. Solo Windows; no requiere Python.
Al reanudar, mantiene una pausa breve para reproducir el pitido antes de continuar.</p>
<p>El sonido sale por el dispositivo predeterminado de Windows.
El inicio espera el pitido y 350 ms adicionales. No garantiza aislar el sonido
de todas las fuentes de audio; usá auriculares y verificá tu captura.</p>]]
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_int(settings, "duration", 140)
    obs.obs_data_set_default_int(settings, "frequency", 880)
    obs.obs_data_set_default_bool(settings, "diagnostics", false)
end

function script_update(settings)
    enabled = obs.obs_data_get_bool(settings, "enabled")
    duration = math.max(50, math.min(300, obs.obs_data_get_int(settings, "duration")))
    frequency = math.max(200, math.min(2000, obs.obs_data_get_int(settings, "frequency")))
    diagnostics = obs.obs_data_get_bool(settings, "diagnostics")
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "enabled", "Activar pitidos")
    obs.obs_properties_add_int_slider(props, "duration", "Duración (ms)", 50, 300, 10)
    obs.obs_properties_add_int_slider(props, "frequency", "Frecuencia (Hz)", 200, 2000, 20)
    obs.obs_properties_add_bool(props, "diagnostics", "Registrar diagnóstico en el log")
    obs.obs_properties_add_button(props, "test", "Probar pitido", function()
        beep("Prueba")
        return false
    end)
    return props
end

function script_load(settings)
    script_update(settings)
    initialize_audio()
    obs.obs_frontend_add_event_callback(on_event)
end

function script_unload()
    cancel_pending()
    obs.obs_frontend_remove_event_callback(on_event)
    audio = nil
end
