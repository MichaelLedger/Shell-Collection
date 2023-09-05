#!/usr/bin/env python3
# importing the module
import sys
import os
import json
import rename_oc_class_name as rename

def main():
    # Opening JSON file
    with open('rename_classes.json') as json_file:
        data = json.load(json_file)
     
        # Print the type of data variable
        print("Type:", type(data))
     
        # Print the data of dictionary
        for k, v in data.items():
            print(k, v)
        
        # auto receive input arguments as class names
    try:
        root_path = sys.argv[1]
        print('root_path:', root_path)
    except:
        e = sys.exc_info()[0]
        # print('error:', e)
        root_path = None

    if root_path is None:
        root_path = input("Enter your project absolute path:\n")
        
    # Print the data of dictionary
    for k, v in data.items():
        if k == "" or v == "":
            print(f"skip with empty key and value: [{k}:{v}]")
            continue
        print(k, v)
        command = 'python3 rename_oc_class_name.py ' + k + ' ' + v + ' ' + root_path
        print(command)
        os.system(command)
        
if __name__ == "__main__":
    main()
