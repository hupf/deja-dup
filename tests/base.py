#!/usr/bin/env python
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 2; coding: utf-8 -*-

from os import environ, path, remove
import tempfile
import sys
import os
import ldtp
import subprocess

latest_duplicity = '0.5.17'

temp_dir = None
gconf_dir = None
cleanup_dirs = []
cleanup_mounts = []

# The current directory is always the 'distdir'.  But 'srcdir' may be different
# if we're running inside a distcheck for example.  So note that we check for
# srcdir and use it if available.  Else, default to current directory.

def setup(backend = None, encrypt = True, start = True, dest = '/', sources = []):
  global gconf_dir, cleanup_dirs, latest_duplicity
  
  if 'srcdir' in environ:
    srcdir = environ['srcdir']
  else:
    srcdir = '.'
  
  environ['LANG'] = 'C'
  
  extra_paths = '../deja-dup:../preferences:../applet:../monitor:'
  extra_pythonpaths = ''
  
  version = None
  if 'DEJA_DUP_TEST_VERSION' in environ:
    version = environ['DEJA_DUP_TEST_VERSION']
  if version is None:
    version = latest_duplicity
  if version != 'system':
    os.system('%s/build-duplicity %s' % (srcdir, version))
    duproot = './duplicity/duplicity-%s' % (version)
    if not os.path.exists(duproot):
      print 'Could not find duplicity %s' % version
      sys.exit(1)
    
    extra_paths += duproot + '/usr/local/bin:'
    
    # Also add the module path, but we have to find it
    libdir = duproot + '/usr/local/lib/'
    libdir += os.listdir(libdir)[0] # python2.5 or python2.6, etc
    libdir += '/site-packages:'
    extra_pythonpaths += libdir
  
  environ['PYTHONPATH'] = extra_pythonpaths + (environ['PYTHONPATH'] if 'PYTHONPATH' in environ else '')
  environ['PATH'] = extra_paths + environ['PATH']
  
  gconf_dir = get_temp_name('gconf')
  os.system('mkdir -p %s' % gconf_dir)
  environ['GCONF_CONFIG_SOURCE'] = 'xml:readwrite:' + gconf_dir
  
  # Now install default rules into our temporary config dir
  os.system('gconftool-2 --makefile-install-rule %s > /dev/null' % ('%s/../data/deja-dup.schemas.in' % srcdir))
  
  if backend == 'file':
    create_local_config(dest, sources)
  elif backend == 'ssh':
    create_ssh_config(dest, sources);
  
  set_gconf_value("encrypt", 'true' if encrypt else 'false', 'bool')
  
  if start:
    start_deja_dup()

def cleanup(success):
  global cleanup_dirs, cleanup_mounts
  for d in cleanup_mounts:
    os.system('gksudo "umount %s"' % d)
  for d in cleanup_dirs:
    os.system("rm -rf %s" % d)
  if not success:
    sys.exit(1)

def set_gconf_value(key, value, key_type = "string", list_type = None):
  cmd = ['gconftool-2', '--config-source=xml:readwrite:%s' % gconf_dir, '-t',
         key_type, '-s', '/apps/deja-dup/%s' % key, value]
  if key_type == "list" and list_type:
    cmd += ["--list-type=%s" % list_type]
  sp = subprocess.Popen(cmd, stdout=subprocess.PIPE)
  sp.communicate()

def get_gconf_value(key):
  cmd = ['gconftool-2', '--config-source=xml:readwrite:%s' % gconf_dir,
         '-g', '/apps/deja-dup/%s' % key]
  sp = subprocess.Popen(cmd, stdout=subprocess.PIPE)
  pout = sp.communicate()[0]
  return pout.strip()

def start_deja_dup():
  ldtp.launchapp('deja-dup', delay=0)
  ldtp.appundertest('deja-dup')
  ldtp.waittillguiexist('frmDéjàDup')

def start_deja_dup_prefs():
  ldtp.launchapp('deja-dup-preferences', delay=0)
  ldtp.appundertest('deja-dup-preferences')
  ldtp.waittillguiexist('frmDéjàDupPreferences')

def start_deja_dup_applet():
  ldtp.launchapp('deja-dup-applet')
  ldtp.appundertest('deja-dup-applet')

def create_local_config(dest='/', includes=None, excludes=None):
  if dest is None:
    dest = get_temp_name('local')
    os.system('mkdir -p %s' % dest)
  set_gconf_value("backend", "file")
  set_gconf_value("file/path", dest)
  if includes is not None:
    includes = '[' + ','.join(includes) + ']'
    set_gconf_value("include-list", includes, "list", "string")
  if excludes is not None:
    excludes = '[' + ','.join(excludes) + ']'
    set_gconf_value("exclude-list", excludes, "list", "string")

def create_ssh_config(dest='/', includes=None, excludes=None):
  if dest is None:
    dest = get_temp_name('local')
    os.system('mkdir -p %s' % dest)
  set_gconf_value("backend", "file")
  set_gconf_value("file/path", "ssh://localhost" + dest)
  if includes is not None:
    includes = '[' + ','.join(includes) + ']'
    set_gconf_value("include-list", includes, "list", "string")
  if excludes is not None:
    excludes = '[' + ','.join(excludes) + ']'
    set_gconf_value("exclude-list", excludes, "list", "string")

def create_temp_dir():
  global temp_dir, cleanup_dirs
  if temp_dir is not None:
    return
  if 'DEJA_DUP_TEST_TMP' in environ:
    temp_dir = environ['DEJA_DUP_TEST_TMP']
    os.system('mkdir -p %s' % temp_dir)
    # Don't automatically clean it
  else:
    temp_dir = tempfile.mkdtemp()
    cleanup_dirs += [temp_dir]

def get_temp_name(extra):
  global temp_dir
  create_temp_dir()
  return temp_dir + '/' + extra

def create_mount(path=None, mtype='ext3', size=20):
  global cleanup_mounts
  if mtype is None: mtype = 'ext3'
  if size is None: size = 20
  if path is None:
    path = get_temp_name('blob')
    if not os.path.exists(path):
      os.system('dd if=/dev/zero of=%s bs=1 count=0 seek=%dM' % (path, size))
      if mtype == 'ext3':
        args = '-F'
      else:
        args = ''
      os.system('mkfs -t %s %s %s' % (mtype, args, path))
  mount_dir = get_temp_name('mount')
  os.system('mkdir -p %s' % mount_dir)
  if mtype == 'vfat':
    args = ',umask=0000'
  else:
    args = ''
  if os.system('gksudo "mount -t %s -o loop,sizelimit=%d%s %s %s"' % (mtype, size*1024*1024, args, path, mount_dir)):
    raise Exception("Couldn't mount")
  cleanup_mounts += [mount_dir]
  return mount_dir

def quit():
  return ldtp.selectmenuitem('frmDéjàDup', 'mnuFile;mnuQuit')

def run(method):
	success = False
	try:
		success = method()
	except Exception, e:
	  print e
	  quit()
	finally:
	  cleanup(success)
