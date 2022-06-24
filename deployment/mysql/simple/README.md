# Deploying MySQL with simple method

## Stage Images in Container repo
This is required if you want to use the local repo for the images. Probobly a good idea.

### MariaDb Chart v11.0.13
```
docker.io/mariadb:10.6.8
```

## Deploy MySQL
Edit mysql-deploy.yaml and add secrets as needed

Deploy
```
kubectl create -n slurm-db -f ./mysql-deploy.yaml
```

To Delete
```
kubectl delete -n slurm-db -f ./mysql-deploy.yaml
```

