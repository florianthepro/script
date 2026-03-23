https://login.tailscale.com/admin/acls/file

Default+funnel
```
{
	"grants": [
		{
			"src": ["*"],
			"dst": ["*"],
			"ip":  ["*"]
		}
	],

	"ssh": [
		{
			"action": "check",
			"src":    ["autogroup:member"],
			"dst":    ["autogroup:self"],
			"users":  ["autogroup:nonroot", "root"]
		}
	],

	"nodeAttrs": [
		{
			"target": ["autogroup:member"],
			"attr":   ["funnel"]
		}
	]
}
```

funnel:
```
	"nodeAttrs": [
		{
			"target": ["autogroup:member"],
			"attr":   ["funnel"]
		}
	]
```

on device:
tailscale device
```
tailscaled funnel up --bg
