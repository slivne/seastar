#!/bin/bash -xv

export vcpus_list="2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56"
export vcpus_list="2 4 8 12 16 20 24 28 32 6 10 14 18 22 26 30 34 36 38 40 42 44 46 48 50 52 54 56"
#export vcpus_list="2 4 6"
iterations=3
export tester_ip="192.168.20.185"
export seastar_ip="192.168.20.101"
export seastar_server_name="intel1"

export user="shlomi"

export seastar_cmd="sudo /home/$user/seastar/build/release/apps/httpd/httpd --network-stack native --dpdk-pmd --dhcp 0 --host-ipv4-addr $seastar_ip --netmask-ipv4-addr 255.255.255.0 --collectd 0 --smp "

export test_tool_wrk_cmd="~/tests/tools/wrk/wrk/wrk https://$seastar_ip:10000/ -c 2000 -d60s -t "
export test_tool_seawreck_cmd="sudo /home/$user/seastar/build/release/apps/seawreck/seawreck --server $seastar_ip:10000 --host-ipv4-addr $tester_ip --dhcp 0 --netmask-ipv4-addr 255.255.255.0 --network-stack native --dpdk-pmd  --collectd 0  --duration 60 --smp "
export test_tool_cmd="$test_tool_seawreck_cmd"

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

ssh $user@$seastar_server_name sudo $seastar_cmd $vcpu &

#sleep 10 

#sudo ifconfig $local_node_nic_id 192.168.10.185

sleep 20

tcpu=$(($vcpu+2))
$test_tool_cmd $tcpu --conn $(($tcpu*64)) > out.$iteration


# translate to json
echo "{" > out.$iteration.json
cat out.$iteration | tr '[:upper:]' '[:lower:]' | grep ^[rt][eo] | grep [0-9] | grep -v "cpu" | sed s/': '/':'/g | sed s/' '/'_'/g  | sed s/^/\"/g | sed s/:/\":/g | sed s/'\/'/'_'/g | sed s/$/,/g >>  out.$iteration.json
echo '"dummy":0' >> out.$iteration.json
echo "}" >> out.$iteration.json
#echo "---- test ----" >> out

ssh $user@$seastar_server_name sudo pkill -9 httpd

sleep 10

done

echo "[" > out.all.json
iteration=0
while [ $iteration -lt $(($iterations-1)) ]; do
  iteration=$(($iteration+1))
  cat out.$iteration.json >> out.all.json
  echo "," >> out.all.json
done
cat out.$iteration.json >> out.all.json
echo "]" >> out.all.json

cat out.all.json

#chmod +x *.py

./statjson.py out.all.json > out.all.ana.json

cat out.all.ana.json

cp out.all.json "$vcpu"_jenkins_perf.json
cp out.all.ana.json "$vcpu"_jenkins_perf.ana.json

sleep 10

done


