# kube-slurm Deployment

## Requirements
You must have the previeous requirements in the top-level README.md complete, and have built your slurm-cluster image.

## Playbook Index
| Playbook                                                         | Description                                  |
| ---------------------------------------------------------------- | -------------------------------------------- |
| [deploy-slurm-control-plane.yml](deploy-slurm-control-plane.yml) | Manages the Slurm control plan in kubernetes |
| [deploy-slurm-nodes.yml](deploy-slurm-nodes.yml)                 | Manages the physical slurm nodes             |

## Installation
### 1. Run Setup
Run the setup.sh script in this directory to generate a new munge.key for your cluster. This will be distributed to all nodes.
```
./setup.sh
```

### 2. Create Ansible Inventory
Use the inventory.example in this directory to create your own inventory based on your cluster.
```
cp ./inventory.example ./inventory
```

### 3. Create group_vars all.yml file
Use the all.example.yml file to create your own all.yml with the requirements for your cluster
```
cp ./group_vars/all.example.yml ./group_vars/all.yml
```

### 4. Run Slurm deploy
Run the ansible playbook to configure the slurm worker nodes.
```
ansible-playbook -i ./inventory ./deploy-slurm-nodes.yml
```

Run the ansible playbook to configure the slurm control plane.
```
ansible-playbook -i ./inventory ./deploy-slurm-control-plane.yml
```
