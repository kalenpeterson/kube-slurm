# Redeploying slurm

## Set Variables
Edit ./deepeops/config/group_vars/slurm-cluster.yml
  - Need to update version to a valid one
  - Need to disable everything we don't need like extra packages and NFS
```
```

## Edit slurm role
Need to edit the build taks in the slurm role to stage the slurm install on the master

## Run the slurm playbook directly
```
ansible-playbook -i ./config/inventory ./playbooks/slurm.yml