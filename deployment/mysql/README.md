# Deploying a MySQL Slumrm AcctDB on Kubernetes

## Refrences

  * https://github.com/bitnami/charts/tree/master/bitnami/mariadb

## Backup Existing Slurm AcctDB
From the MySQL Node as root

Create Dump
```
mysqldump --all-databases --single-transaction --quick --lock-tables=false > full-backup-$(date +%F).sql -u root -p

sudo mysqldump -u root slurm_acct_db > slurm_acct_db.$(date +"%Y%m%d").sql
```
## Stage Images in Container repo
This is required if you want to use the local repo for the images. Probobly a good idea.

### MariaDb Chart v11.0.13
```
docker.io/bitnami/bitnami-shell:11-debian-11-r3
docker.io/bitnami/bitnami/mysqld-exporter:0.14.0-debian-11-r3
docker.io/bitnami/bitnami/bitnami/mariadb:10.6.8-debian-11-r3
```

## Deploy MySQL With Bitnami Helm Chart
Install Helm
```
wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz
tar -xzf ./helm*.tar.gz
sudo cp ./linux-amd64/helm /usr/local/bin
sudo chmod +x /usr/local/bin/helm
```

Deploy Chart
```
helm repo add bitnami https://charts.bitnami.com/bitnami

kubectl create namespace slurm-db
helm install slurm-mysql-db bitnami/mariadb \
    --namespace slurm-db \
    --values ./values.yaml \
    --version 11.0.13
```

## Prepare MySQL DB
Connect to MySQL as root
```
mysql -h <HOSTNAME> -u root -p
```

Create grant for slurm user and validate it
```
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'%';
flush privileges;
use slurm_acct_db;
show grants for 'slurm'@'%';
```

## Restore MySQL Dump Into new DB
```
mysql -h hostname -u root -p slurm_acct_db < <DB_DUMP>
```

## Stop Old MySQL on each node
```
systemctl disable --now mariadb
```

## Repoint Slurm to new DB
Update /etc/slurm/slurmdbd.conf
```
# Database info
StorageType=accounting_storage/mysql
StorageHost=
StoragePort=3306
StorageUser=slurm
StoragePass=
StorageLoc=slurm_acct_db
```

Restart slurmdbd
```
sudo systemctl restart slurmdbd
sudo systemctl status slurmdbd
```


