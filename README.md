# Bloodborne Sound Repack Guide
This script Extracts and Repacks Bloodborne sound files so that ShadPS4 is able play them. (for now, AT9 encoded sound files cannot be played)

Just unpack it and run the AutoRepack.ps1 Powershell Script. (Right-Click then "Run with Powershell")

If a "Security Warning" pop up, __UNCHECK__ "Always ask before opening this file", and click "Open".

If it's failing, try AutoRepack_Admin.ps1 which will resolve system permission problems.

You can just follow the script prompts and enjoy. The script will extract and repack everything into a new subfolder named "repacked". No files should be overwritten in the process.

This script can be "resumed" if it crashes or you stop it you can just rerun the script and it will ask you to SKIP existing repacked files, effectively resuming the repacking, or if you want to OVERWRITE them, effectively rebuilding all existing FSBs.

If you want more detail, there is this [Google Docs Guide](https://docs.google.com/document/d/e/2PACX-1vRyZW18yDhWC3VmTGkfXCronfiEJxJ31zbsitic7QoBq7hIYB5pfF40N-QH7qToF47sTu1UHcFhBEhH/pub) 

It has more details and some images to help if needed.

If you are looking for a **Linux** version, follow this link to Az’s [GitHub repack Linux script](https://github.com/ItsAzM8/bloodborne-sound-repack-linux).
