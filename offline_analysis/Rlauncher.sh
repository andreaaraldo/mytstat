mv -f /home/araldo/temp/r_out/r.log /home/araldo/temp/r_out/r.log.01.old
mv -f /home/araldo/temp/r_out/r.build_influence_point.log /home/araldo/temp/r_out/r.build_influence_point.log.01.old
R < ~/tstat/offline_analysis/R_scripts/get_affected_flows.r --no-save
