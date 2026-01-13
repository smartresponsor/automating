Компонент: Automating / AutomateKit (Industrial Canon)

Куда кладём:
- В каждом бизнес‑репозитории экосистемы SmartResponsor кит живёт в .automating/
- В коде используем идентификатор automator (классы/модули/слои), но публичные переменные/заголовки — AUTOMATE_ / X-AUTOMATE-*

Цель:
- Защищённый запуск GitHub Actions через Cloudflare Worker (agent-trigger)
- Унифицированные PowerShell команды (Windows-first) для локального и CI использования
- Клиент‑потребительская модель: pull обновлений из релиза источника и применение патча в репо‑клиентах

Совместимость:
- Worker и клиенты принимают заголовки/секреты AUTOMATE_* и также legacy AUTOMATER_* / SR_* (переходный период).
