#!/usr/bin/env python
import argparse
import re

def num(line, key, val):
    print '"' + key + '": ' + val + ","

def find_float(line, key, val):
    p = re.compile('[^\d]*([\d\.]+).*')
    m = p.match(val)
    if m:
        num(line, key, m.group(1))

def k_num(line, key, val):
    p = re.compile('(\d+)([^\d]*)\s*')
    m = p.match(val)
    if m:
        v = m.group(1)
        if m.group(2) == "k":
            v = v + "000"
        elif m.group(2) == "m":
            v = v + "000000"
        num(line, key, v)

def tm(line, key, val):
   p = re.compile('([\d\.]+)s')
   m = p.match(val)
   if m:
       num(line, key, m.group(1))

def str(line, key, val):
    print '"' + key + '": "' + val + '",'

def footter(line):
    values = re.split('([^\s][^:]*:\s*[^\s]*)', line)
    for v in values:
        parse_line(v)

match = {"cmd_get" : num, "get_misses" : num, "servers" : str, "cmd_set" : num
         , "threads count" : num, "concurrency" : num, "set proportion" : find_float,
         "get proportion": find_float, "written_bytes" : num, "read_bytes" : num, "object_bytes" : num,
         "windows size" : k_num, "run time" : tm, "Run time" : tm, "Ops" : num, "TPS" : num, "Net_rate" : find_float}

def parse_line(line):
    patern = re.compile('([^:]+[^:\s])\s*:\s*(\S.*)')
    footer_patern = re.compile('.*Run time\s*:.*TPS\s*:.*')
    ft = footer_patern.match(line)
    if ft:
        footter(line)
    else:
        m = patern.match(line)
        if m:
            f = match.get(m.group(1))
            if f:
                f(line, m.group(1), m.group(2))
def non_empty(line):
    p = re.compile('^\s*$')
    return not p.match(line)

def parse_file(name, delim):
    p = re.compile('\s*' + delim + '\s*')
    f = open(name, 'r')
    if delim != '':
        print '['
    strt = False
    found = False
    for line in f:
        if delim != '' and p.match(line):
            print ('"file": "' + name + '"')
            print ("}")
            strt = False
        elif non_empty(line):
            if not strt:
                if found:
                    print ","
                found = True
                print ("{")
                strt = True
            parse_line(line)
    if delim == '':
        print ('"file": "' + name + '"')
        print ("}")
    else:
        print ']'

    f.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser('memaslap2json')
    parser.add_argument('file', nargs='+', help='file to convert')
    parser.add_argument('--delimiter', default='', nargs='?')
    args = parser.parse_args()
    for f in args.file:
        parse_file(f, args.delimiter)
