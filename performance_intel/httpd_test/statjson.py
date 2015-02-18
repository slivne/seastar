#!/usr/bin/env python

import json
import argparse
import sys
import collections
import traceback
import math
from __builtin__ import str

sum_values = {}
sq_values = {}
count_values = {}
total = 0
def inc_arr(arr, k, v):

    if k in arr:
        arr[k] = arr[k] + v
    else:
        arr[k] = v

def add_values(obj):
    global sum_values
    global sq_values
    global coiunt_values
    global total
    total = total + 1
    for k,v in obj.items():
        if isinstance(v,int) or isinstance(v,float) :
            inc_arr(sum_values, k, v)
            inc_arr(sq_values, k, v*v)
            inc_arr(count_values, k, 1)

def create_values():
    res = {}
    max = 0
    for k,v in count_values.items():
        if v > max:
            max = v
        if k in sum_values and v > 0:
            vf = float(v)
            res[k] = float(sum_values[k])/vf
            s = float(sq_values[k])/vf - (res[k] * res[k])
            if s < 0.000000000001:
                res[k + "_std"] = 0
            else:
                res[k + "_std"] = math.sqrt(s)
            if res[k] != 0:
                res[k + "_rsd"] = (res[k + "_std"] /  res[k]) * 100
            else:
                res[k + "_rsd"] = 0
    res["total"] = max
    print json.dumps(res, sort_keys=True, indent=4, separators=(',', ': '))

def print_values():
#    print json.dumps(count_values, indent=4)
    print ("{")
    for k,v in count_values.items():
        if k in sum_values and v > 0:
            print ('"' + k + '"'+ ": " + str(float(sum_values[k])/v) + ",")
    print ('"total": ' + str(total) + '\n}')

def json_from_file(name):
    try:
        json_data = open(name)
        data = json.load(json_data)
        json_data.close()
        return data
    except:
        t, value, tb = sys.exc_info()
        traceback.print_tb(tb)
        print("Bad formatted JSON file '" + name + "' error ", value.message)
        sys.exit(-1)

def parse_file(data):
    try:

        if isinstance(data, dict):
            add_values(data)
        else:
            for obj in data:
                add_values(obj)
    except:
        t, value, tb = sys.exc_info()
        traceback.print_tb(tb)
        print("Bad formatted JSON file '" + name + "' error ", value.message)
        sys.exit(-1)

def run_stat(files):
    if len(files) == 0:
        parse_file(json.load(sys.stdin))
    else:
        for f in files:
            parse_file(json_from_file(f))
#    print_values()
    create_values()

def xpath(obj, path, pos):
    if isinstance(obj, dict):
        if pos < len(path):
            if pos + 1 == len(path):
                    vals = path[pos].split(',')
                    first = True
                    for v in vals:
                        if v in obj:
                            if first:
                                first = False
                            else:
                                sys.stdout.write(",")
                            sys.stdout.write(json.dumps(obj[v]))
                        else:
                            print ("Path not found")
                            sys.exit(-1)
                    print('')
            else:
                if path[pos] in obj:
                    xpath(obj[path[pos]], path, pos +1)
                else:
                    print ("Path not found")
                    sys.exit(-1)
        else:
            print json.dumps(obj, indent=4)
    elif isinstance(obj, list):
        if pos < len(path):
            if path[pos] == "*":
                for v in obj:
                     xpath(v, path, pos +1)
            elif path[pos].isdigit() and int(path[pos]) < len(obj):
                xpath(obj[int(path[pos])], path, pos +1)
            else:
                print ("Path not found")
                sys.exit(-1)
        else:
            print json.dumps(obj, indent=4)

    else:
        print obj

def xpath_search(files, path):
    paths = path.split("/")
    if len(files) == 0:
        xpath(json.load(sys.stdin), paths, 0)
    else:
        for f in files:
            xpath(json_from_file(f), paths, 0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser('statjson')
    parser.add_argument('--path', default='', nargs='?',help='use xpath to search in json object')
    parser.add_argument('file',default='', nargs='*',help='file to run statistic on')
    args=parser.parse_args()
    if args.path != '':
        xpath_search(args.file, args.path)
    else:
        run_stat(args.file)
