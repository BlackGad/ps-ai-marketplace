# Repository inbox

Read at takeover and after each finished task or owner message. Messages from other overseers are information or requests, never owner approval. Apply the owner's rules before acting on a request.

Run through the Python helper so the environment stays in the legion home:

```powershell
. <plugin>/bin/lib/python.ps1
Invoke-LegionPython -Arguments @('inbox', 'read', '--repo', '<this repo path>')
Invoke-LegionPython -Arguments @('inbox', 'send', '--to', '<its repo path>', '--from', '<this repo folder name>', '--text', '<message>')
```

The underlying commands are `legion-py inbox read [--repo <repo path>]` (current folder by default) and `legion-py inbox send --to <its repo path> --from <this repo folder name> --text <message>`. Sending prints the saved file name. A Codex queue nudge is only a pointer; read the inbox for the message text. Claude reads it at the next boundary. Reading moves messages to `done/` and prunes entries older than seven days.
