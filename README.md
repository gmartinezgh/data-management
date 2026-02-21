# Data Management Toolbox
Tools for managing personal data: files synchronization and backups across devices.

## `dsync`
Files synchronization with [rsync](https://linux.die.net/man/1/rsync)

### Prerequisites
A rsync daemon is pre-configured in the [synology diskstation](https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/file_rsync?version=6). See [Remote hosts](#remote-hosts).

### Installation
Checkout the repo and run the script `install.sh`.

### Configuration
#### Remote hosts
Multiple remote hosts to copy files to/from are supported. For each remote host specify:
- url. Fully qualified url of the host.
- auth. Authentication method. When connecting to a rsync daemon this is `RSYNC_PASSWORD`. This is provided at installation time and stored securely for each user.

> There are two different ways for rsync to contact a remote system: using a remote-shell program as the transport (such as ssh or rsh) or contacting an rsync daemon directly via TCP. The remote-shell transport is used whenever the source or destination path contains a single colon (:) separator after a host specification. Contacting an rsync daemon directly happens when the source or destination path contains a double colon (::) separator after a host specification, OR when an rsync:// URL is specified.

### Manual usage
```bash
dsync --help
dsync --dry-run
```

## Cloud provisioning
