# config/

`backend.json` (NO versionado) lo genera CI desde los GitHub Secrets `SUPABASE_URL` y `SUPABASE_ANON_KEY`:

```json
{"url": "https://<proyecto>.supabase.co", "anon_key": "<clave publica anon/publishable>"}
```

Solo la clave PÚBLICA. La service key nunca va aquí: el cliente la rechaza (`BackendConfig.is_configured`).
Sin este archivo el juego usa `LocalBackend` (cuenta local de prueba, sin online real).
