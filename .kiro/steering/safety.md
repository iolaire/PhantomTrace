# Safety

- Subprocesses are launched with argument arrays and without a shell. Never build command strings.
- The Safety_Policy is the single approval path for every action. No action bypasses it.
- Protected processes are never sent a signal, at any stage.
- No network access and no telemetry are permitted.
- The root volume and system volumes are never mutated.
- Each resolution stage is opt-in, previewed, and re-verified against fresh process discovery before escalating.
