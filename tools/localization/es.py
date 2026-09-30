"""Spanish (es) strings for EarlyOtter's String Catalogs.

Neutral Latin American Spanish, informal "tú" like iOS itself. Applied with
`python3 tools/localization/apply.py es`, which also fills in the English plural
forms. Keys are the catalog keys; values use positional specifiers (%1$@) when
there is more than one argument.

Glossary: alarm = alarma, rule = regla (feminine), prep = preparación,
commute = trayecto, snooze = posponer, wake up = despertar,
Auto Alarms = Alarmas automáticas, sleeping in = dormir de más.
"""

# Never translated: format-only keys and single letters.
DO_NOT_TRANSLATE = {"", "%@", "%@ %@", "%@%@", "%@ · %@", "G"}

STRINGS = {
    # Composite and format strings
    "%@ may need to refresh your alarms": "Es posible que %@ tenga que actualizar tus alarmas",
    "%@ needs calendar access to find your first event tomorrow and calculate your wake-up time.":
        "%@ necesita acceso a tu calendario para encontrar tu primer evento de mañana y calcular a qué hora despertarte.",
    "%@, %@": "%1$@, %2$@",
    "%@, alarm %@ and first event %@ at %@.": "%1$@, alarma a las %2$@ y primer evento, %3$@, a las %4$@.",
    "%@, alarm %@ linked to %@ at %@.": "%1$@, alarma a las %2$@ para %3$@ a las %4$@.",
    "%@, alarm at %@.": "%1$@, alarma a las %2$@.",
    "%@, alarm turned off for this day.": "%@, alarma desactivada para este día.",
    "%@, Auto Alarms are paused for this day.": "%@, las Alarmas automáticas están en pausa este día.",
    "%@, automatic alarms are turned off.": "%@, las alarmas automáticas están desactivadas.",
    "%@, EarlyOtter is disabled.": "%@, EarlyOtter está desactivado.",
    "%@, first event %@ at %@.": "%1$@, primer evento, %2$@, a las %3$@.",
    "%@, no event or alarm is scheduled.": "%@, no hay eventos ni alarmas programados.",
    "%lld min": "%lld min",
    "%lldm": "%lld min",
    "%lldm prep · %lldm commute": "%1$lld min de preparación · %2$lld min de trayecto",
    "%@ Sleeping in": "%@ A dormir de más",

    # A
    "A rule with the same calendars and conditions already exists. Adjust the config so rules don't overlap 1-to-1.":
        "Ya existe una regla con los mismos calendarios y condiciones. Ajústala para que las reglas no sean idénticas.",
    "About calendar alarms": "Sobre las alarmas del calendario",
    "Access": "Acceso",
    "Accounts": "Cuentas",
    "Action Required": "Acción necesaria",
    "Add": "Agregar",
    "Add a backup alarm": "Agregar una alarma de respaldo",
    "Add a Calendar to Continue": "Agrega un calendario para continuar",
    "Add a place or address": "Agrega un lugar o dirección",
    "Add a word": "Agrega una palabra",
    "Add alarm": "Agregar alarma",
    "Add Alarm": "Agregar alarma",
    "Add keyword": "Agregar palabra clave",
    "Add Rule": "Agregar regla",
    "Add Your Calendar": "Agrega tu calendario",
    "Alarm": "Alarma",
    "Alarm Access": "Acceso a alarmas",
    "Alarm access is off, so this won't ring": "El acceso a alarmas está desactivado, así que no sonará",
    "Alarm access is still needed to schedule wake-up alarms.": "Aún se necesita acceso a alarmas para programar las alarmas.",
    "Alarm access is still pending.": "El acceso a alarmas sigue pendiente.",
    "Alarm access lets %@ schedule real wake-up alarms for your calendar events. You can enable it later in Settings.":
        "El acceso a alarmas permite que %@ programe alarmas reales para tus eventos del calendario. Puedes activarlo más tarde en Configuración.",
    "Alarm access needed": "Se necesita acceso a alarmas",
    "Alarm access was previously denied. Enable it in Settings to schedule wake-up alarms.":
        "Denegaste el acceso a alarmas. Actívalo en Configuración para programar alarmas.",
    "Alarm moved to %@": "Alarma movida a las %@",
    "Alarm scheduled for the next valid event.": "Alarma programada para el próximo evento válido.",
    "Alarm set by %@": "Alarma definida por %@",
    "Alarm set by this event": "Alarma definida por este evento",
    "Alarm status unavailable.": "Estado de la alarma no disponible.",
    "Alarm turned off for this day": "Alarma desactivada para este día",
    "Alarms": "Alarmas",
    "All": "Todos",
    "All calendars": "Todos los calendarios",
    "All calendars are currently selected.": "Todos los calendarios están seleccionados.",
    "All set": "Todo listo",
    "All-day": "Todo el día",
    "All-Day Events": "Eventos de todo el día",
    "Allow": "Permitir",
    "Allow Alarms to Continue": "Permite las alarmas para continuar",
    "Allow Calendar Access": "Permitir acceso al calendario",
    "Allowed": "Permitido",
    "Allowed Only Keywords": "Solo estas palabras clave",
    "Any": "Cualquiera",
    "Apple Calendar": "Calendario de Apple",
    "Auto Alarms are paused for that day based on your active schedule.":
        "Las Alarmas automáticas están en pausa ese día según tus días activos.",
    "Auto Alarms are paused for this day": "Las Alarmas automáticas están en pausa este día",
    "Auto Alarms are paused for this day.": "Las Alarmas automáticas están en pausa este día.",
    "Automatic alarms are turned off": "Las alarmas automáticas están desactivadas",
    "Automatic alarms are turned off.": "Las alarmas automáticas están desactivadas.",

    # B–C
    "Before alarm": "Antes de la alarma",
    "Blocked Keywords": "Palabras clave bloqueadas",
    "Calendar": "Calendario",
    "Calendar access is still needed to use Apple Calendar.": "Aún se necesita acceso al calendario para usar el Calendario de Apple.",
    "Calendar access needed": "Se necesita acceso al calendario",
    "Calendar access was previously denied. Enable it in Settings to connect Apple Calendar.":
        "Denegaste el acceso al calendario. Actívalo en Configuración para conectar el Calendario de Apple.",
    "Calendar Alarms": "Alarmas del calendario",
    "Calendars": "Calendarios",
    "Cancel": "Cancelar",
    "Canceled": "Cancelados",
    "Canceled Events": "Eventos cancelados",
    "Choose which calendars can contribute events to EarlyOtter's alarm rules.":
        "Elige qué calendarios aportan eventos a las reglas de alarma de EarlyOtter.",
    "Choose which calendars count toward tomorrow's first alarm-worthy event.":
        "Elige qué calendarios cuentan para el primer evento de mañana que merece alarma.",
    "Choose which calendars EarlyOtter should scan.": "Elige qué calendarios debe revisar EarlyOtter.",
    "Classic": "Clásico",
    "Close day": "Cerrar día",
    "Commute": "Trayecto",
    "Commute · %lldm": "Trayecto · %lld min",
    "Connect a calendar source, enable an account, or make sure EarlyOtter still has access to one of your calendars.":
        "Conecta un calendario, activa una cuenta o asegúrate de que EarlyOtter aún tenga acceso a alguno de tus calendarios.",
    "Connect at least one calendar source to get started.": "Conecta al menos un calendario para empezar.",
    "Connected": "Conectadas",
    "Couldn't clear stale alarm record. %@": "No se pudo borrar el registro de una alarma antigua. %@",
    "Couldn't replace previous alarms. %@": "No se pudieron reemplazar las alarmas anteriores. %@",
    "Couldn't schedule alarm: %@": "No se pudo programar la alarma: %@",
    "Couldn't send. Try again.": "No se pudo enviar. Inténtalo de nuevo.",
    "Counts only. Never your calendar details.": "Solo conteos. Nunca los detalles de tu calendario.",
    "Creates a one-time test alarm without changing tomorrow's managed wake-up alarm.":
        "Crea una alarma de prueba única sin cambiar la alarma de mañana.",

    # D–E
    "Date": "Fecha",
    "Days": "Días",
    "Default Rule": "Regla predeterminada",
    "Delete": "Eliminar",
    "Delete Alarm": "Eliminar alarma",
    "Design Review": "Revisión de diseño",
    "Dismiss": "Descartar",
    "Done": "Listo",
    "Duplicate Rule": "Regla duplicada",
    "Duration": "Duración",
    "Earlier events": "Eventos anteriores",
    "EarlyOtter Alarms": "Alarmas de EarlyOtter",
    "EarlyOtter is disabled": "EarlyOtter está desactivado",
    "EarlyOtter is disabled.": "EarlyOtter está desactivado.",
    "EarlyOtter needs alarm access before it can schedule a real alarm.":
        "EarlyOtter necesita acceso a alarmas para poder programar una alarma real.",
    "Edit Alarm": "Editar alarma",
    "Edits this day's alarm. Hold and drag to move it.": "Edita la alarma de este día. Mantén presionado y arrastra para moverla.",
    "Enabled": "Activada",
    "Enjoy sleeping in": "Disfruta dormir de más",
    "Enjoy sleeping in!": "¡Disfruta dormir de más!",
    "Events whose location contains all of these use this rule.": "Los eventos cuya ubicación contiene todas estas usan esta regla.",
    "Events whose title contains all of these words use this rule.": "Los eventos cuyo título contiene todas estas palabras usan esta regla.",
    "Events whose title contains any of these words are ignored.": "Se ignoran los eventos cuyo título contiene alguna de estas palabras.",
    "Every %@": "Cada %@",
    "Every day": "Todos los días",
    "Experience": "Experiencia",

    # F–I
    "Feedback": "Comentarios",
    "Feedback sent.": "Comentarios enviados.",
    "Finish & Go to Dashboard": "Terminar e ir al inicio",
    "Fix Permissions": "Corregir permisos",
    "For %@ only": "Solo el %@",
    "For days without early events": "Para días sin eventos temprano",
    "Free": "Libres",
    "Free Events": "Eventos libres",
    "Generating alarms...": "Generando alarmas...",
    "Get Started": "Empezar",
    "Google Account": "Cuenta de Google",
    "Google Calendar": "Google Calendar",
    "Google Calendar access expired or was never granted. Reconnect your Google account.":
        "El acceso a Google Calendar venció o nunca se otorgó. Vuelve a conectar tu cuenta de Google.",
    "Google Calendar could not find a signed-in user.": "Google Calendar no encontró una sesión iniciada.",
    "Google Calendar request failed with status %lld.": "La solicitud a Google Calendar falló con el estado %lld.",
    "Google Sign-In could not find a screen to present from.": "El inicio de sesión de Google no encontró una pantalla para mostrarse.",
    "Google Sign-In did not return an email or account identifier.": "El inicio de sesión de Google no devolvió un correo ni un identificador de cuenta.",
    "Grant Permissions": "Otorgar permisos",
    "Home": "Inicio",
    "How has EarlyOtter been for you?": "¿Qué tal te ha ido con EarlyOtter?",
    "hr": "h",
    "Ignore Calendar Status": "Ignorar según estado",
    "Ignored Events": "Eventos ignorados",
    "Ignored Events & Filters": "Eventos ignorados y filtros",
    "in %@": "en %@",
    "Internal device": "Dispositivo interno",
    "Issue": "Problema",

    # K–N
    "Keep your next wake-up alarm visible on Home, Lock Screen, and StandBy.":
        "Mantén tu próxima alarma a la vista en la pantalla de inicio, la pantalla bloqueada y StandBy.",
    "Label": "Etiqueta",
    "Late Alarm Warning": "Alarma tardía",
    "Later events": "Eventos posteriores",
    "Location contains": "La ubicación contiene",
    "Location Contains": "La ubicación contiene",
    "Long-press a Google account to remove it.": "Mantén presionada una cuenta de Google para eliminarla.",
    "Match": "Coincidencia",
    "Matching events will never trigger an alarm.": "Los eventos que coincidan nunca activarán una alarma.",
    "min": "min",
    "Never": "Nunca",
    "New Rule": "Nueva regla",
    "Next": "Siguiente",
    "Next Alarm": "Próxima alarma",
    "Next event": "Próximo evento",
    "No alarm is currently scheduled.": "No hay ninguna alarma programada.",
    "No alarm scheduled": "Sin alarma programada",
    "No Alarm": "Sin alarma",
    "No alarms": "Sin alarmas",
    "No Alarms": "Sin alarmas",
    "No alarms will ring": "No sonará ninguna alarma",
    "No calendar events or alarms are coming up.": "No hay eventos ni alarmas próximos.",
    "No Calendars Found": "No se encontraron calendarios",
    "No early events": "Sin eventos temprano",
    "No events on %@": "No hay eventos el %@",
    "No events today": "No hay eventos hoy",
    "No events tomorrow": "No hay eventos mañana",
    "No Events Tomorrow!": "¡Sin eventos mañana!",
    "No scheduled events or alarms.": "No hay eventos ni alarmas programados.",
    "None": "Ninguno",
    "Notification access is still needed.": "Aún se necesita acceso a notificaciones.",
    "Notification access is still pending.": "El acceso a notificaciones sigue pendiente.",
    "Notification access was previously denied. Enable it in Settings.": "Denegaste el acceso a notificaciones. Actívalo en Configuración.",
    "Notifications": "Notificaciones",

    # O–R
    "OK": "OK",
    "Open EarlyOtter": "Abre EarlyOtter",
    "Open Settings": "Abrir Configuración",
    "Open the app to keep tomorrow's alarm up to date.": "Abre la app para mantener al día la alarma de mañana.",
    "Otter": "Nutria",
    "Overrides %@ for %@ only": "Reemplaza «%1$@» solo el %2$@",
    "Perfectly synced with your morning schedule.": "En perfecta sincronía con tus mañanas.",
    "Permissions": "Permisos",
    "Pick a date": "Elige una fecha",
    "Pick the days EarlyOtter wakes you for your first event.": "Elige los días en que EarlyOtter te despierta para tu primer evento.",
    "Played by iOS when the alarm fires": "Lo reproduce iOS cuando suena la alarma",
    "Please complete setup in settings.": "Termina la configuración en Configuración.",
    "Prep": "Preparación",
    "Prep · %lldm": "Preparación · %lld min",
    "Prep time": "Tiempo de preparación",
    "Preparing EarlyOtter...": "Preparando EarlyOtter...",
    "Privacy": "Privacidad",
    "Privacy Policy": "Política de privacidad",
    "Rate EarlyOtter": "Califica EarlyOtter",
    "Reactivate": "Reactivar",
    "Refresh Alarms": "Actualizar alarmas",
    "Refresh App": "Actualiza la app",
    "Refresh EarlyOtter's rolling wake-up alarms using your latest calendar events.":
        "Actualiza las alarmas de EarlyOtter con los eventos más recientes de tu calendario.",
    "Remove": "Eliminar",
    "Remove Account": "Eliminar cuenta",
    "Remove this account?": "¿Eliminar esta cuenta?",
    "Repeat": "Repetir",
    "Reset": "Restablecer",
    "Rule": "Regla",
    "Rule icon": "Ícono de la regla",
    "Rule name": "Nombre de la regla",
    "rule.default": "Predeterminada",
    "Rules": "Reglas",

    # S
    "Save": "Guardar",
    "Save Anyway": "Guardar de todos modos",
    "Schedule": "Horario",
    "Scheduled": "Programada",
    "Send feedback": "Enviar comentarios",
    "Send Feedback": "Enviar comentarios",
    "Sending…": "Enviando…",
    "Settings": "Configuración",
    "Setup Required": "Falta configurar",
    "Share Usage Data": "Compartir datos de uso",
    "Skip": "Omitir",
    "Skip after calendar alarm": "Omitir tras alarma del calendario",
    "Skip after calendar alarms?": "¿Omitir tras las alarmas del calendario?",
    "Skip alarm": "Omitir alarma",
    "Skip window": "Margen para omitir",
    "Sleeping in": "Dormir de más",
    "Snooze": "Posponer",
    "Snooze Duration": "Duración de posponer",
    "Sound": "Sonido",
    "sound.default": "Predeterminado",
    "Stale": "Desactualizado",
    "Starlight": "Luz de estrellas",
    "Starts before your alarm": "Empieza antes de tu alarma",
    "Stop": "Detener",
    "Submit Feedback": "Enviar comentarios",
    "Suggestion": "Sugerencia",
    "Sunrise": "Amanecer",
    "Support": "Soporte",
    "Sync events from a Google account": "Sincroniza eventos de una cuenta de Google",
    "System disabled": "Sistema desactivado",

    # T–Z
    "Tentative": "Tentativos",
    "Tentative Events": "Eventos tentativos",
    "Test Alarm in 1 Minute": "Alarma de prueba en 1 minuto",
    "Test alarm scheduled for %@.": "Alarma de prueba programada para las %@.",
    "These are optional during setup. Enable them now to let %@ schedule alarms and notify you on updates automatically.":
        "Son opcionales durante la configuración. Actívalos ahora para que %@ programe alarmas y te avise de los cambios automáticamente.",
    "Tide": "Marea",
    "Time": "Hora",
    "Timing": "Tiempos",
    "Tip: add “Refresh Alarms” to a Shortcut automation to keep alarms synced.":
        "Consejo: agrega «Actualizar alarmas» a una automatización de Atajos para mantener tus alarmas sincronizadas.",
    "Title contains": "El título contiene",
    "Title Contains": "El título contiene",
    "Today": "Hoy",
    "Tomorrow": "Mañana",
    "Turn alarm on": "Activar alarma",
    "Unavailable": "No disponible",
    "Undo": "Deshacer",
    "Unknown Google Account": "Cuenta de Google desconocida",
    "Untitled Event": "Evento sin título",
    "Use All": "Usar todos",
    "Use your on-device calendars and subscriptions": "Usa los calendarios y suscripciones de tu dispositivo",
    "Wake Time": "Hora de despertar",
    "Wake up": "Despertar",
    "Wakes you in time for your first event on these days.": "Te despierta a tiempo para tu primer evento en estos días.",
    "We couldn't check tomorrow yet, but you can finish and adjust things from the dashboard.":
        "Aún no pudimos revisar mañana, pero puedes terminar y ajustar todo desde el inicio.",
    "We'll subtract this prep and commute time from your first event.":
        "Restaremos este tiempo de preparación y trayecto a la hora de tu primer evento.",
    "Weekdays": "Entre semana",
    "Weekends": "Fines de semana",
    "Welcome to": "Te damos la bienvenida a",
    "What went wrong?": "¿Qué salió mal?",
    "What would make EarlyOtter better?": "¿Qué mejorarías de EarlyOtter?",
    "When non-empty, only events matching these words are considered.":
        "Si agregas palabras, solo se tienen en cuenta los eventos que las contengan.",
    "Within": "Dentro de",
    "You are setting an alarm for the afternoon or after your first event starts. Are you sure?":
        "Estás poniendo una alarma por la tarde o después de que empiece tu primer evento. ¿Seguro?",
    "You turned off the alarm for this day.": "Desactivaste la alarma de este día.",
    "You're All Set!": "¡Todo listo!",
    "Your Default Routine": "Tu rutina predeterminada",
    "Your First Auto Alarm": "Tu primera alarma automática",
}

# Keys whose number decides the wording. (one, other) per language.
PLURALS = {
    "%lld calendars": {"en": ("%lld calendar", "%lld calendars"), "es": ("%lld calendario", "%lld calendarios")},
    "%lld connected": {"en": ("%lld connected", "%lld connected"), "es": ("%lld conectada", "%lld conectadas")},
    "%lld Google accounts connected": {
        "en": ("%lld Google account connected", "%lld Google accounts connected"),
        "es": ("%lld cuenta de Google conectada", "%lld cuentas de Google conectadas"),
    },
    "%lld hours": {"en": ("%lld hour", "%lld hours"), "es": ("%lld hora", "%lld horas")},
    "%lld needed": {"en": ("%lld needed", "%lld needed"), "es": ("Falta %lld", "Faltan %lld")},
}

# Keys with two counted arguments: sentence plus per-argument (one, other) forms.
MULTI_PLURALS = {
    "Updated %lld alarms across %lld upcoming wake plans.": {
        "en": ("Updated %#@alarms@ across %#@plans@.",
               {"alarms": (1, "%arg alarm", "%arg alarms"), "plans": (2, "%arg upcoming wake plan", "%arg upcoming wake plans")}),
        "es": ("Se actualizaron %#@alarms@ en %#@plans@.",
               {"alarms": (1, "%arg alarma", "%arg alarmas"), "plans": (2, "%arg día próximo", "%arg días próximos")}),
    },
}

INFO_PLIST = {
    "EarlyOtter/InfoPlist.xcstrings": {
        "NSCalendarsFullAccessUsageDescription":
            "EarlyOtter lee tu calendario para calcular la hora ideal para despertarte antes de tu primer evento.",
        "NSAlarmKitUsageDescription":
            "EarlyOtter programa alarmas para despertarte según los eventos de tu calendario.",
    },
    "NextAlarmWidget/InfoPlist.xcstrings": {
        "CFBundleDisplayName": "Próxima alarma",
    },
}

# English source for Info.plist keys the extractor doesn't pick up.
INFO_PLIST_SOURCE = {
    "EarlyOtter/InfoPlist.xcstrings": {
        "NSAlarmKitUsageDescription": "EarlyOtter schedules wake-up alarms based on your calendar events.",
    },
}

SHORTCUT_PHRASES = {
    "Refresh alarms in ${applicationName}": [
        "Actualiza las alarmas en ${applicationName}",
        "Actualizar mis alarmas en ${applicationName}",
    ],
}
