#!/usr/local/bin/python3 -u

from argparse import ArgumentParser
from ast import arg
from http import server
import json
from operator import contains
import os
from posixpath import dirname
from datetime import datetime
import time
import traceback
import requests

def doDeleteTasks(token, serverIP, workDir):

    r = requests.get("http://del_jenkins:{}@{}:8080/api/json?tree=jobs[name,color]".format(token, serverIP))
    # r = requests.get("http://maintain_jenkins:{}@{}:8080/api/json?tree=jobs[name,color]".format(token, serverIP), headers={'Authorization': 'TOK:<MY_TOKEN>'})

    # print("http://del_jenkins:{}@{}:8080/api/json?tree=jobs[name,color]".format(token, serverIP))

    try:

        respText = str(r.text)
        # print(r.text)

        jsonResponse = json.loads(respText)
        jobs = list(jsonResponse["jobs"])
        jobNames = list()
        for j in jobs:
            jobNames.append(j["name"])
        # print(jobNames)

        # targetPath = workDir.format(os.getenv('HOME'))
        # we use absolute path here for security to avoid deleting something mistakenly
        targetPath = workDir.format("")
        if "ExDisk" not in workDir:
            targetPath = workDir.format("/Users/administrator")
        print("targetPath= {}".format(targetPath))

        for name in os.listdir(targetPath):
            if os.path.isdir(os.path.join(targetPath, name)):
                dirName = os.path.join(targetPath, name)
                jobName = name
                if not contains(dirName, "/Users/administrator") and not contains(dirName, "ExDisk"):
                    print("error dirname, please confirm dirname")
                    quit(-1)
                if contains(name, "@tmp"):
                    jobName = name.replace("@tmp", "")
                if not contains(jobNames, jobName):
                    print("deleting jobName = {}  dirName = {}".format(
                        jobName, dirName))
                    deleteCmd = "rm -rf '{}'".format(dirName)
                    # print("deleteCmd = '{}'".format(deleteCmd))
                    os.system(deleteCmd)
    except Exception:
        # print(r.text)
        traceback.print_exc()

def doDeleteArchives(workDir):
    try:
        archivesPath = workDir.format("")
        if "ExDisk" not in workDir:
            archivesPath = workDir.format("/Users/administrator")
        print("archivesPath= {}".format(archivesPath))
    
        for name in os.listdir(archivesPath):
            if os.path.isdir(os.path.join(archivesPath, name)):
                dirName = os.path.join(archivesPath, name)
                y = datetime.strptime(name, '%Y-%m-%d')
                z = datetime.now()
                diff = z - y
                if diff.days > 7:
                    print("deleting archive file = {}".format(dirName))
                    deleteCmd = "rm -rf '{}'".format(dirName)
                    os.system(deleteCmd)
    except Exception:
        # print(r.text)
        traceback.print_exc()


parser = ArgumentParser()
parser.add_argument('-s', '--server', default='master')
# parser.add_argument('-t1', '--token1', default='')
# parser.add_argument('-t2', '--token2', default='')

args = parser.parse_args()
server = str(args.server)
# token1 = str(args.token1)
# token2 = str(args.token2)
token1 = os.getenv('CLEAN_JENKINS_TOKEN1')
token2 = os.getenv('CLEAN_JENKINS_TOKEN2')
token3 = os.getenv('CLEAN_JENKINS_TOKEN3')

# print("token = {}".format(token1))

# os.system("echo 'before cleaning, disk info:' ")
# os.system("df -h")
# print("\n")


if server == "FP":
    print("cleaning 10.4.2.4")
    
    doDeleteTasks(token1, "10.4.2.4", "{}/.jenkins/workspace")
    doDeleteArchives("{}/Library/Developer/Xcode/Archives")

elif server == "SA":
    print("cleaning 10.4.3.2")
    
    doDeleteTasks(token3, "10.4.3.2", "{}/Jenkins/projects")
    doDeleteArchives("{}/Library/Developer/Xcode/Archives")

elif server == "FP_SA":
    print("cleaning 10.4.2.2")

    doDeleteTasks(token2, "10.4.2.2", "{}/Volumes/ExDisk/Jenkins-workspace")
    doDeleteArchives("{}/Volumes/ExDisk/Xcode/Archives")


print("cleaning finish!")

# os.system("echo 'after cleaning, disk info:' ")
# os.system("df -h")
