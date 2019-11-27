import argparse
import subprocess
import configparser
import os
import socket 
import time
import signal
import re
import sys
from FIO.IcingaOutput import IcingaOutput

class RHOSP:
    def __init__(self):
        self.services = []
        self.critical_alarms = []
        self.major_alarms = []
        self.minor_alarms = []
        self.ok_alarms = []

    def getOpenSDirectorData(self):
        allLines = []    
        process = subprocess.run(["systemctl list-units openstack*"], shell=True,stdout=subprocess.PIPE, universal_newlines=True)
#        process = subprocess.run(["cat demo.txt"], shell=True,stdout=subprocess.PIPE, universal_newlines=True)
        for line in process.stdout.splitlines():
            if re.search("^openstack", line):
                allLines.append(line)
        return allLines

    def parseOpenSLines(self, lines):
        for line in lines:
            service = dict()
            searchObj = re.search( r'(.*) loaded (.*)', line, re.M|re.I)
            if searchObj:
                service["UNIT"] = searchObj.group(1).strip()
                service["LOAD"] = "loaded"
            else:
                searchObj = re.search( r'(.*) disabled (.*)', line, re.M|re.I)
                if searchObj:
                    service["UNIT"] = searchObj.group(1).strip()
                    service["LOAD"] = "disabled"
                else:
                    print("No match")
                    service["UNIT"] = "No match"
                    service["LOAD"] = "No match"
                    break
            remaining = searchObj.group(2).strip()
            searchObj = re.search( r'^active (.*)', remaining, re.M|re.I)
            if searchObj:
                service["ACTIVE"] = "active"
            else:
                searchObj = re.search( r'^inactive (.*)', remaining, re.M|re.I)
                if searchObj:
                    service["ACTIVE"] = "inactive"
                else:
                    print("No match")
                    service["ACTIVE"] = "No match"
                    break
            remaining = searchObj.group(1).strip()
            searchObj = re.search( r'^running (.*)', remaining, re.M|re.I)
            if searchObj:
                service["SUB"] = "running"
            else:
                searchObj = re.search( r'^stop (.*)', remaining, re.M|re.I)
                if searchObj:
                    service["SUB"] = "stop"
                else:
                    print("No match")
                    service["ACTIVE"] = "No match"
                    break
            service["DESCRIPTION"] = searchObj.group(1).strip()
            self.services.append(service)

def run():
    signal.signal(signal.SIGALRM, alarm_handler)  # assign alarm_handler to SIGALARM
    signal.alarm(10)  # set alarm after 10 seconds
    iN = RHOSP()
    myL = iN.getOpenSDirectorData()
    iN.parseOpenSLines(myL)
    signal.alarm(0)
    prepare_data(iN)
    exit(display_data(iN))

def prepare_data(iN):
    for item in iN.services:
        if item["LOAD"] == "disabled":
            iN.critical_alarms.append({'Sev':'Critical', 'Summary':"{} {} {} {}".format(item["UNIT"], item["LOAD"], item["ACTIVE"], item["SUB"]),'key':item["UNIT"], 'AG':'RHOSP', 'MsgG':'OPS-IS-CLOUD'})
        else:
            if item["ACTIVE"] == "inactive":
                iN.major_alarms.append({'Sev':'Major', 'Summary':"{} {} {} {}".format(item["UNIT"], item["LOAD"], item["ACTIVE"], item["SUB"]),'key':item["UNIT"], 'AG':'RHOSP', 'MsgG':'OPS-IS-CLOUD'})
            else:
                if item["SUB"] == "stop":
                    iN.minor_alarms.append({'Sev':'Minor', 'Summary':"{} {} {} {}".format(item["UNIT"], item["LOAD"], item["ACTIVE"], item["SUB"]),'key':item["UNIT"], 'AG':'RHOSP', 'MsgG':'OPS-IS-CLOUD'})
                else:
                    iN.ok_alarms.append({'Sev':'OK', 'Summary':"{} {} {} {}".format(item["UNIT"], item["LOAD"], item["ACTIVE"], item["SUB"]),'key':item["UNIT"], 'AG':'RHOSP', 'MsgG':'OPS-IS-CLOUD'})

def display_data(iN):
    a = IcingaOutput()
    a.setDefaultMsgGroup("ENG-OSS")
    for alarm in iN.major_alarms:
        a.addAlarm(Sev=alarm['Sev'],msggroup="NOC-AN-Infra",Summary=alarm['Summary'],AlertGroup="IHSS_Hardware",AlertKey=alarm['key'])
    for alarm in iN.minor_alarms:
        a.addAlarm(Sev=alarm['Sev'],msggroup="NOC-AN-Infra",Summary=alarm['Summary'],AlertGroup="IHSS_Hardware",AlertKey=alarm['key'])
    for alarm in iN.ok_alarms:
        a.addAlarm(Sev=alarm['Sev'],msggroup="NOC-AN-Infra",Summary=alarm['Summary'],AlertGroup="IHSS_Hardware",AlertKey=alarm['key'])
    return a.print()

def alarm_handler(signum, stack):
    print('Plugin exit after 10 seconds')
    a = FNO.Alarms()
    a.add(Severity='Major',MsgGroup='OSS',Summary='Plugin exit after 10 seconds',AlertGroup='Icinga',AlertKey='Timeout')
    a.showall()
    a.printAll()
    exit(a.close())

def main():
    parser = argparse.ArgumentParser(description='Read command line arguments')
    args = parser.parse_args()
    if args:
        run ()
    else:
        parser.print_help()
main()
