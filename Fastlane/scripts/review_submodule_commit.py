# Author: Michael Ledger
# Date: 2023/08/16
# Usage:
# Inject environment variables via [Environment Injector] likes:
# key -> relative_path, value -> submodule_branch_name
# SUBMODULE_BRANCH_MAPPING={"XXX/SDK":"1.1.0"}
# Execute shell command likes:
# python3 ./XXX/scripts/review_submodule_commit.py

import sys
import subprocess
import os
import json

print(os.environ)
print(os.getcwd())

#record original path, restore cd to this path before exit.
entrance_path = os.getcwd()

#Show the absolute path of the top-level directory.
def get_git_top_level_path() -> str:
    return subprocess.check_output(['git', 'rev-parse', '--show-toplevel']).decode('ascii').strip()
    
def get_git_submodules_path() -> str:
    return subprocess.check_output(['git', 'config', '--file', '.gitmodules', '--get-regexp', 'path']).decode('ascii').strip()

def get_git_revision_hash() -> str:
    return subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode('ascii').strip()

def get_git_revision_short_hash() -> str:
    return subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode('ascii').strip()

#main_project_path = '/Users/michaelledger/Downloads/XXX'
#main_project_path = os.getcwd()
main_project_path = get_git_top_level_path()
print('main_project_path:', main_project_path)
os.chdir(main_project_path)
print(os.getcwd())

#submodule_branch_mapping_str = '{"XXX/SDK":"1.1.0"}'
submodule_branch_mapping_str = os.environ['SUBMODULE_BRANCH_MAPPING']
submodule_branch_mapping = json.loads(submodule_branch_mapping_str)
print('submodule_branch_mapping:', submodule_branch_mapping)

def get_git_submodules_commit() -> dict:
    submodule_commit_mapping={}
    submodules_info=subprocess.check_output(['git', 'submodule']).decode('ascii').strip()
    for line in submodules_info.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            commit_id=fields[0]
            relative_path=fields[1]
            submodule_commit_mapping[relative_path] = commit_id
    return submodule_commit_mapping

submodule_commit_mapping=get_git_submodules_commit()
print(submodule_commit_mapping)

submodules=get_git_submodules_path()

print(submodules)

#proc = subprocess.Popen(["submodules | awk -F\\' '{{print $2}}'".format(vm)], stdout=subprocess.PIPE, shell=True)
#stdout = proc.communicate()[0]
#print(stdout)

submodule_remote_urls_mapping = {}

def get_git_remote_url(submodule_relative_path) -> str:
    sumbmodule_absolute_path=main_project_path+'/'+submodule_relative_path
    print('sumbmodule_absolute_path:', sumbmodule_absolute_path)
    os.chdir(sumbmodule_absolute_path)
    print(os.getcwd())
    remote_info=subprocess.check_output(['git', 'remote', '-v']).decode('ascii').strip()
    for line in remote_info.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            remote_fetch_url=fields[1]
            print('remote_fetch_url:', remote_fetch_url)
            return remote_fetch_url

for line in submodules.splitlines():
    fields = line.split()
    if len(fields) >= 2:
        relative_path=fields[1]
        print(relative_path)
        submodule_remote_url=get_git_remote_url(relative_path)
        submodule_remote_urls_mapping[relative_path] = submodule_remote_url
        
print('submodule_remote_urls_mapping:', submodule_remote_urls_mapping)

# `git ls-remote $URL refs/heads/branch`
def get_head_commit_id(url, branch) -> str:
    remote_info=subprocess.check_output(['git', 'ls-remote', url, 'refs/heads/', branch]).decode('ascii').strip()
    for line in remote_info.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            return fields[0]

for key, value in submodule_remote_urls_mapping.items():
    relative_path=key
    remote_url=value
    branch_name=submodule_branch_mapping[relative_path]
    print('branch_name:', branch_name)
    remote_head_commit_id=get_head_commit_id(remote_url, branch_name)
    local_commit_id=submodule_commit_mapping[relative_path]
    print('remote_head_commit_id:', remote_head_commit_id)
    print('local_commit_id:', local_commit_id)
    if local_commit_id != remote_head_commit_id:
        print([relative_path], 'submodule audit failed! 😢')
        os.chdir(entrance_path)
        print(os.getcwd())
        sys.exit(1)
    else:
        print([relative_path], 'submodule audit passed! 😊')

print('[🎉] All submodules audit passed! 🍺')
os.chdir(entrance_path)
print(os.getcwd())
sys.exit(0)
