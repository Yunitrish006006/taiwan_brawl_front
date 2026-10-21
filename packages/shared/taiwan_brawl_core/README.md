# taiwan_brawl_core

Platform-neutral runtime configuration for Taiwan Brawl application entrypoints.

`AppConfiguration` contains deployment values and feature switches that a
composition root can inject into services. It does not store session tokens,
provider API keys, device secrets, or platform objects; those remain behind the
credential/key ports in `taiwan_brawl_messaging` or backend environment
injection.
