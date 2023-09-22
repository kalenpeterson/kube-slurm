Using LUA scripts to filter Interactive jobs

https://github.com/SchedMD/slurm/tree/master/contribs/lua

https://bugs.schedmd.com/show_bug.cgi?id=3094

https://slurm.schedmd.com/job_submit_plugins.html


1) Installation of lua

# Centos
yum install lua

# Ubuntu
sudo apt install lua5.3

2) Slurm should detect lua cf.
https://slurm.schedmd.com/quickstart_admin.html



2) Filtering Interactive jobs
https://groups.google.com/g/slurm-users/c/TuZatz7jJZU
https://serverfault.com/questions/1090689/how-can-i-set-up-interactive-job-only-or-batch-job-only-partition-on-a-slurm-clu

job_submit.lua