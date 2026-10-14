set allow-duplicate-recipes := true
set ignore-comments := true

_default:
    #!/usr/bin/bash
    ujust --list --list-heading $'Available commands:\n' --list-prefix $' - '

# NECD OS overrides. Recipes defined in this root file win over the imported upstream ones.
# Keep the imports below in sync with upstream's 00-entry.just when the base image changes.

# Not available on NECD OS: it would move this machine off the NECD image
toggle-devmode:
    #!/usr/bin/bash
    echo "Developer mode is not available on NECD OS."

# Not available on NECD OS
devmode:
    #!/usr/bin/bash
    echo "Developer mode is not available on NECD OS."

# Not available on NECD OS: it can switch this machine to a different image
rebase-helper:
    #!/usr/bin/bash
    echo "Switching images is not available on NECD OS. Ask your administrator."

# Release notes are not published
changelogs:
    #!/usr/bin/bash
    echo "No changelog is published. Use: ujust changelogs-fedora"

[private]
aurora-cli:
    #!/usr/bin/bash
    echo "Not available."

[private]
aurora-fonts:
    #!/usr/bin/bash
    echo "Not available."

[private]
toggle-dinosaurs hemisphere="north":
    #!/usr/bin/bash
    echo "Not available."

# Imports
import "/usr/share/ublue-os/just/changelog.just"
import "/usr/share/ublue-os/just/system.just"
import "/usr/share/ublue-os/just/apps.just"
import "/usr/share/ublue-os/just/default.just"
import "/usr/share/ublue-os/just/shared.just"
import "/usr/share/ublue-os/just/update.just"
import? "/usr/share/ublue-os/just/60-custom.just"
