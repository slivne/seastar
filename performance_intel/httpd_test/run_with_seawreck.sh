#!/bin/bash -xvf

export vcpus_list="1 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56"
export vcpus_list=2
export iterations=1 
export tester_ip="192.168.20.185"
export seastar_ip="192.168.20.101"
export seastar_server_name="intel1"

export user="shlomi"

export seastar_cmd="sudo /home/$user/seastar/build/release/apps/httpd/httpd --network-stack native --dpdk-pmd --dhcp 0 --host-ipv4-addr $seastar_ip --netmask-ipv4-addr 255.255.255.0 --collectd 0 --smp "

export test_tool_wrk_cmd="~/tests/tools/wrk/wrk/wrk https://$seastar_ip:10000/ -c 2000 -d60s -t "
export test_tool_seawreck_cmd="sudo /home/$user/seastar/build/release/apps/seawreck/seawreck --server $seastar_ip:10000 --host-ipv4-addr $tester_ip --dhcp 0 --netmask-ipv4-addr 255.255.255.0 --network-stack native --dpdk-pmd  --collectd 0  --duration 60 --smp "
export test_tool_cmd="$test_tool_seawreck_cmd"

export test_tool_parser_wrk_cmd="cat"
export test_tool_parser_seawreck_cmd="tr '[:upper:]' '[:lower:]' | grep ^[rt][eo] | sed s/': '/':'/g | sed s/' '/'_'/g  | sed s/^/\"/g | sed s/:/\":\"/g | sed s/$/\"/g"
export test_tool_parser_cmd="$test_tool_parser_seawreck_cmd"


for vcpu in $vcpus_list; do

rm -Rf out.*
for iteration in $iterations; do

ssh $user@$seastar_server_name sudo $seastar_cmd $vcpu &

#sleep 10 

#sudo ifconfig $local_node_nic_id 192.168.10.185

sleep 20

$test_tool_cmd $vcpu --conn $(($vcpu*100)) > out.$iteration

echo "parser $test_tool_parser_cmd"
cat out.$iteration | tr '[:upper:]' '[:lower:]' | grep ^[rt][eo] | sed s/': '/':'/g | sed s/' '/'_'/g  | sed s/^/\"/g | sed s/:/\":\"/g | sed s/'\/'/'_'/g | sed s/$/\",/g >  out.$iteration.json
#echo "---- test ----" >> out

ssh $user@$seastar_server_name sudo pkill -9 httpd

sleep 10

done

if [1 != 0]; 
then

cat out.1
cat out.1.json
cat out.2
cat out.2.json
cat out.3
cat out.3.json
echo "[" > out.all.json
for iterations in 1 2; do
cat out.$iterations.json >> out.all.json
echo "," >> out.all.json
done
cat out.3.json >> out.all.json
echo "]" >> out.all.json

cat out.all.json

chmod +x tests/scripts/*.py

tests/scripts/statjson.py out.all.json > out.all.ana.json

cat out.all.ana.json

rm -f jenkins_perf.xml

tests/scripts/statjenkins.py out.all.ana.json  req_per_sec req_per_sec httpd req_per_sec req_per_sec > jenkins_perf.xml
cp jenkins_perf.xml "$config"_"$vcpus"_jenkins_perf.xml
cp out.all.json "$config"_"$vcpus"_jenkins_perf.json
cp out.all.ana.json "$config"_"$vcpus"_jenkins_perf.ana.json

ssh $remote sudo rm -Rf $WORKSPACE/$BUILD_NUMBER/jenkins_*

ls *_jenkins_perf.*
fi

sleep 10

done


