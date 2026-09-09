src/
├── main.lua              ← Entry point, love callbacks
├── rules.lua             ← COLD PATH: Smell definitions (ugly is fine)
├── scanner.lua           ← HOT PATH: Hardened pool-based scanner
├── renderer.lua          ← HOT PATH: Zero-alloc virtual-scroll renderer
├── sentinel.lua          ← TOOLING: Drop-in profiler
└── ui_chrome.lua         ← COLD PATH: Buttons, menus, file browser
                            (Keep this in Hack state forever)