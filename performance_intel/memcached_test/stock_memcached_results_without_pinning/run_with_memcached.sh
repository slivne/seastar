#!/bin/bash -xv

export vcpus_list="20 24 28 32 8 2 4 6 10 14 16 18 22 26 30 34 36 38 40 42 44 46 48 50 52 54 56"
#export vcpus_list="2 4 8 12 16 20 24 28 32 6 10 14 18 22 26 30 34 36 38 40 42 44 46 48 50 52 54 56"
#export vcpus_list="2 4 8 12 16 20 24 28 32 6 10 14 18 22 26 30 34 36 38 40 42 44 46 48 50 52 54 56"
#export vcpus_list="2 4 6"
iterations=3
export tester_ip="192.168.20.185"
export seastar_ip="192.168.20.101"
export seastar_server_name="intel1"

export user="shlomi"

export seastar_cmd_dpdk="sudo /home/$user/seastar/build/release/apps/memcached/memcached --network-stack native --dpdk-pmd --dhcp 0 --host-ipv4-addr $seastar_ip --netmask-ipv4-addr 255.255.255.0 --collectd 0 --smp "
export seastar_cmd_posix="sudo /home/$user/seastar/build/release/apps/memcached/memcached --network-stack posix --dhcp 0 --host-ipv4-addr $seastar_ip --netmask-ipv4-addr 255.255.255.0 --collectd 0 --smp "
export seastar_cmd="$seastar_cmd_posix"

export test_tool_cmd="for ((i = 0; i < 40; ++i)); do memaslap -s 192.168.10.101:11211 -t 20s -T 1 -c 60 -X 64 > $out.$i & done"

export test_tool_parser_wrk_cmd="cat"
export test_tool_parser_seawreck_cmd="tr '[:upper:]' '[:lower:]' | grep ^[rt][eo] | grep [0-9] | sed s/': '/':'/g | sed s/' '/'_'/g  | sed s/^/\"/g | sed s/:/\":/g | sed s/$/$/g"
export test_tool_parser_cmd="$test_tool_parser_seawreck_cmd"


for vcpu in $vcpus_list; do

pwd
touch out
ls out*
rm out*
iteration=0
echo $iteration $iterations
while  [ $iteration -lt $iterations ]; do
iteration=$(($iteration+1))
echo $iteration $iterations

ssh $user@$seastar_server_name "for ((i = 0; i < $vcpu; ++i)); do port=\$((\$i+11000)) ; echo \$port ; memcached -t 1 -m 2048 -p \$port > /tmp/null &  done;"

#sleep 10 
sleep 10

#sudo ifconfig enp129s0 $tester_ip down
sudo ifconfig enp129s0 $tester_ip up
#sudo ifconfig $local_node_nic_id 192.168.10.185
ping -c 20 $seastar_ip


out="tmp_out"
rm -Rf $out*
clients=$vcpu

for ((i = 0; i < $clients; ++i)); do port=$(($i+11000)); taskset -c $(($i*2)),$(($i*2+1)) memaslap -s $seastar_ip:$port -t 60s -T 2 -c 60 -X 64 > $out.$i & done
wait `pgrep memaslap`

cat $out.* | grep "^servers" | head -1 >> $out.sum
echo "threads count: `cat $out.* | grep thread | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "concurrency: `cat $out.* | grep concurrency | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
cat $out.* | grep "run time" | head -1 >> $out.sum
cat $out.* | grep "window size" | head -1 >> $out.sum
cat $out.* | grep "set prop" | head -1 >> $out.sum
cat $out.* | grep "get prop" | head -1 >> $out.sum
echo "cmd_get: `cat $out.* | grep cmd_get | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "cmd_set: `cat $out.* | grep cmd_set | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "get_misses: `cat $out.* | grep get_misses | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "written_bytes: `cat $out.* | grep written_bytes | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "read_bytes: `cat $out.* | grep read_bytes | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo "object_bytes: `cat $out.* | grep object_bytes | cut -f2 -d':' | awk '{ sum+=$1} END {print sum}'`" >> $out.sum
echo >> $out.sum
echo "Run time: 20.0s Ops: `cat $out.* | grep Run | cut -f5 -d' ' | awk '{ sum+=$1} END {print sum}'` TPS: `cat $out.* | grep Run | cut -f7 -d' ' | awk '{ sum+=$1} END {print sum}'` Net_rate: `cat $out.* | grep Run | cut -f9 -d' ' | cut -f1 -d'M' | awk '{ sum+=$1} END {print sum}'`M/s" >> $out.sum
echo "---- test ----" >> $out.sum

cp $out.sum out.$iteration
cat out.$iteration >> out.all

ssh $user@$seastar_server_name sudo pkill -9 memcached

sleep 10

done

./memaslap2json.py --delimiter "---- test ----" out.all >> out.all.json
#echo "[" > out.all.json
#iteration=0
#while [ $iteration -lt $(($iterations-1)) ]; do
#  iteration=$(($iteration+1))
#  cat out.$iteration.json >> out.all.json
#  echo "," >> out.all.json
#done
#cat out.$iteration.json >> out.all.json
#echo "]" >> out.all.json

cat out.all.json

#chmod +x *.py

./statjson.py out.all.json > out.all.ana.json

cat out.all.ana.json

cp out.all.json "$vcpu"_jenkins_perf.json
cp out.all.ana.json "$vcpu"_jenkins_perf.ana.json

sleep 10

done


