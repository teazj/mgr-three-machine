#!/usr/bin/python
#-*- coding: utf-8 -*-
import gitlab
import urllib3
import getpass
import re
import sys, getopt
urllib3.disable_warnings()

#login
def login():
  global git
  git = gitlab.Gitlab("https://gitlab.sh.dy", 'MroAkxU1fatEsHCEsbYJ',ssl_verify=False)
  git.auth()

#获取到组信息
  global pospay
  pospay=git.groups.get(53)
  pospay=pospay.projects.list()

  global rypay
  rypay=git.groups.get(52)
  rypay=rypay.projects.list()


def pospays():
  pospayname=[]
  pospaynameid=[]
  for n in xrange(len(pospay)):
    pospayname.append(pospay[n].name)


  for i in xrange(len(pospay)):
    pospaynameid.append(pospay[i].id)

  global pospaydic
  pospaydic = {}
  i=0
  while i<len(pospayname):
    pospaydic[pospayname[i]]=pospaynameid[i]
    i+=1

def rypays():
  rypayname=[]
  rypaynameid=[]
  for n in xrange(len(rypay)):
    rypayname.append(rypay[n].name)


  for i in xrange(len(rypay)):
    rypaynameid.append(rypay[i].id)

  global rypaydic
  rypaydic = {}
  i=0
  while i<len(rypayname):
    rypaydic[rypayname[i]]=rypaynameid[i]
    i+=1

#获取传参
def ci_args():
  opts, args = getopt.getopt(sys.argv[1:], "hr:n:b:d:")
  for op, value in opts:
    if op == "-r":
      global release
      release=value
    elif op == "-n":
      global proname
      proname=value
    elif op == "-b":
      global branch
      branch=value
    elif op == "-d":
      global description
      description=value
    elif op == "-h":
      print "python.py -rrelease -nproject -bmaster -ddescription"
      sys.exit()

  try:
    release
    proname
    branch
    description
  except NameError:
    print "参数有误!!!"
    sys.exit()


  login()
  pospays()
  rypays()



  if proname in pospaydic.keys():
    pospay=git.groups.get(53)
    proname=pospay.projects.get(pospaydic[proname])
    try:
      proname.tags.delete(release)
      tag = proname.tags.create({'tag_name': release, 'ref': branch})
      tag.set_release_description(description)
    except:
      tag = proname.tags.create({'tag_name': release, 'ref': branch})
      tag.set_release_description(description)


  if proname in rypaydic.keys():
    pospay=git.groups.get(53)
    proname=pospay.projects.get(pospaydic[proname])
    try:
      proname.tags.delete(release)
      tag = proname.tags.create({'tag_name': release, 'ref': branch})
      tag.set_release_description(description)
    except:
      tag = proname.tags.create({'tag_name': release, 'ref': branch})
      tag.set_release_description(description)


ci_args()

#获取项目组的方法
#examples  已知一个项目ID
#data=git.projects.get(126)
#ryf_pay=git.projects.get(108)

#可以查看项目具体信息
#print data.namespace
#print ryf_pay.namespace


#获取某个具体项目
#pospay=git.groups.get(53)
#pospay=pospay.projects.list()
#cd_test=pospay.projects.get(251)