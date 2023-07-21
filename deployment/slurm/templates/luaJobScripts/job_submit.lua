--[[
 Example lua script demonstrating the Slurm job_submit/lua interface.
 This is only an example, not meant for use in its current form.
 For use, this script should be copied into a file name "job_submit.lua"
 in the same directory as the Slurm configuration file, slurm.conf.

20230408 - filter interactive jobs to land on bwh_comppath-Interactive
--]]

function slurm_job_submit(job_desc, part_list, submit_uid)
       local log_prefix = "slurm_job_submit"
       local interactive_partition = "bwh_comppath-Interactive"
-- check for interactive jobs (empty jobscripts)
       if (job_desc.script == nil or job_desc.script == '') then
           job_desc.partition = interactive_partition
           slurm.log_info("%s: normal job seems to be interactive, moved to %s partition.", log_prefix, job_desc.partition)
       end

       slurm.log_info("%s: for user %u, setting partition(s): %s.", log_prefix, submit_uid, job_desc.partition)
       slurm.log_user("Job \"%s\" queued to partition(s): %s.", job_desc.name, job_desc.partition)

	   return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
	return slurm.SUCCESS
end

slurm.log_info("initialized")
return slurm.SUCCESS