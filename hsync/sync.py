# This source code is a part of project violet-server.
# Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import sys
import os
import os.path
import time
import shutil
from subprocess import Popen, PIPE
from datetime import datetime

dbmetapath = './dbmeta.txt'

def sync():
  #
  #   Sync (Low Performance Starting)
  #
  shutil.rmtree('chunk', ignore_errors=True)
  process = Popen(['./hsync', '-ls', '--sync-only'])
  process.wait()

def upload_chunk():
  # donot use utcnow()
  timestamp = str(int(datetime.now().timestamp()))
  filename1 = os.listdir('chunk')[0]
  filename2 = os.listdir('chunk')[1]
  chunkfile1 = 'chunk/' + filename1
  chunkfile2 = 'chunk/' + filename2
  size1 = os.path.getsize(chunkfile1)
  size2 = os.path.getsize(chunkfile2)

  process = Popen([
    'gh', 'release', 'create', timestamp,
    '--repo', 'TaYaKi71751/chunk',
    '--title', 'chunk ' + timestamp,
    '--notes', '',
    chunkfile1,
    chunkfile2,
  ])
  process.wait()

  url = 'https://github.com/TaYaKi71751/chunk/releases/download/'+timestamp+'/'+filename1
  with open(dbmetapath, "a") as myfile:
    myfile.write('chunk ' + timestamp + ' ' + url + ' ' + str(size1) + '\n')

  url = 'https://github.com/TaYaKi71751/chunk/releases/download/'+timestamp+'/'+filename2
  with open(dbmetapath, "a") as myfile:
    myfile.write('chunkraw ' + timestamp + ' ' + url + ' ' + str(size2) + '\n')
  
def release():
  #
  #   Create database
  #

  #
  #   Compress
  #
  process = Popen(['7za', 'a', 'rawdata.7z', 'rawdata/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7za', 'a', 'rawdata-chinese.7z', 'rawdata-chinese/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7za', 'a', 'rawdata-english.7z', 'rawdata-english/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7za', 'a', 'rawdata-japanese.7z', 'rawdata-japanese/*'], stdout=open(os.devnull, 'wb'))
  process.wait()
  process = Popen(['7za', 'a', 'rawdata-korean.7z', 'rawdata-korean/*'], stdout=open(os.devnull, 'wb'))
  process.wait()

  #
  #   Upload
  #
  timestamp_str = str(timestamp)
  process = Popen([
    'gh', 'release', 'create', timestamp_str,
    '--repo', 'TaYaKi71751/db',
    '--title', 'db ' + timestamp_str,
    '--notes', '',
    'rawdata.7z',
    'rawdata-chinese.7z',
    'rawdata-english.7z',
    'rawdata-japanese.7z',
    'rawdata-korean.7z',
  ])
  process.wait()

  url = 'https://github.com/TaYaKi71751/db/releases/download/'+timestamp_str+'/rawdata'
  with open(dbmetapath, "a") as myfile:
    myfile.write('db ' + timestamp_str + ' ' + url + '\n')

def remove_exists(path):
  if os.path.exists(path):
    os.remove(path)

def clean():
  remove_exists('rawdata.7z')
  remove_exists('rawdata-chinese.7z')
  remove_exists('rawdata-english.7z')
  remove_exists('rawdata-japanese.7z')
  remove_exists('rawdata-korean.7z')

latest_sync_date = ''

sync()
upload_chunk()
cur_date = datetime.utcnow().strftime('%Y.%m.%d')
latest_sync_date = cur_date
clean()
release()
# 1 hour