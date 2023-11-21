#!/usr/bin/python
# -*- coding: UTF-8 -*-

import os
import json
import requests
import threading
import biplist

JSON_NAME = 'downloadList.json'
DOWNLOAD_DIR = 'download'
PLIST_NAME = 'sessionsmanifest_fp.plist'

def readDownloadList():
    lists = []
    urlList = []
    with open(JSON_NAME, 'r', encoding="utf-8", errors='ignore') as f:
        try:
            content = json.load(f)
            list = content['list']
            for line in list:
                url = line['url']
                if url not in urlList:
                    lists.append(line)
                    urlList.append(url)
        except:
            print('Load json fail')
    return lists

def downloadDir():
    os.makedirs('download', exist_ok=True)
    return os.getcwd() + '/download/'

def cleanDownloadDir(path):
    os.system('rm -rf ' + path + '*')
    print('Clean download dir success')

def downloadSingleFile(url,path):
    response = requests.get(url)
    with open(path, 'wb') as f:
        f.write(response.content)

def downloadFile():
    threads = []
    dirName = downloadDir()
    cleanDownloadDir(dirName)
    for line in downloadList:
        url = line['url']
        download = threading.Thread(target=downloadSingleFile, args=(url,dirName + url.split('/')[-1]))
        threads.append(download)
        download.start()
        print('Download: ' + url)

    for t in threads:
        t.join()
    
    print('Download finish' + '\n')

def getFileSize(url):
    dirName = downloadDir()
    file_path = dirName + url.split('/')[-1]
    return os.path.getsize(file_path)         

def getAllFileDetail():
    allFile = []
    index = 1

    essentialDownloadSize = 0
    nonEssentialDownloadSize = 0

    for line in downloadList:
        url = line['url']
        size = getFileSize(url)
        if size == 0:
            print('error: ' + url)
            continue
        # Size
        detail = {'URL': {"relative": url}, 'fileSize': size}
        
        # Title
        if 'title' in line:
            detail['title'] = line['title']
        else:
            detail['title'] = url.split('/')[-1]

        # Essential
        essential = True
        if 'essential' in line:
            essential = line['essential']
        detail['essential'] = essential
        
        # SessionId
        detail['sessionId'] = index
        index = index + 1

        allFile.append(detail)

        if essential:
             essentialDownloadSize = essentialDownloadSize + size
        else:
            nonEssentialDownloadSize = nonEssentialDownloadSize + size
    
    # TotalSize
    print('Essential download size: ' + str(essentialDownloadSize))
    print('Non-essential download size: ' + str(nonEssentialDownloadSize))
    print("Total size " + str(round(float(essentialDownloadSize + nonEssentialDownloadSize) / (1024 * 1024), 2)) + 'M' + '\n')

    return {'sessions': allFile}
    
def createPlist(list):
    try:
        plist = biplist.writePlistToString(list)
        with open(PLIST_NAME, 'wb') as f:
            f.write(plist)
        print('Create plist success: ' + os.getcwd() + '/' + PLIST_NAME)

    except:
        print('Create plist fail')

if __name__ == '__main__':
    downloadList = readDownloadList()
    print('Download list count: ' + str(len(downloadList)) + '\n')

    # start download list
    downloadFile()

    # get all file detail
    fileDetail = getAllFileDetail()

    # get plist
    createPlist(fileDetail)

