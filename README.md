# AVVMDiscover

A **PERL** script to automatically discover new Virtual Machines or vApps in vSphere and asign them to Avamar Policies. Virtual Machine discovery is performed based on the Virtual Machine's: Datacenter, Cluster or ESXi Host, Resoruce Group, Virtual Machine Folder and/or Name.

## Description

AVVMDiscover runs on an Avamar server and uses Avamar's `mccli` uitlity to query vSphere for new VMs and/or vApps. It then uses user sepcified options to place those VMs and/or vApps in the appropirate Avamar Policies. When run on a daily basis from cron AVVMDiscover will detect VMs that have been removed from a policy and add them back again. 

## Installation

1) Login to your Avamar single node, AVE or Utility Node as admin.

2) Create and change to a dirctory called /home/admin/scripts/AVVMDiscover.

```bash
mkdir -p /home/admin/scripts/AVVMDiscover
cd /home/admin/scripts/AVVMDiscover
```

3) Copy this respsitory from GITHub to your Avamar single node, AVE or Utility Node. This can be done directily with the command:

```bash
curl -L https://github.com/LGTOman/AVVMDiscover/tarball/master | tar xz --strip-components=1
```

4) Make the `AVVMDiscover.pl` script executable

```bash
chmod +x AVVMDiscover.pl
```

5) Edit the `VMsToExclude.txt` file and add any VMs, vApps or regex patterns to exclude.

6) Run `AVVMDisvover.pl` with the appropriate options and verify that VMs and/or vApps are added as expected. Example:

```bash

```

7) Schedule `AVVMDiscover.pl` to run in cron 

## Future

- Detect VMs that have moved between policy domains.
- Detect VMs based on their vSphere tag.
- Detect VMs that have been deleted from vSphere and retire them in Avamar.
