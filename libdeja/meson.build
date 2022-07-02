# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

libdeja = shared_library(
  'deja',
  'Backend.vala',
  'BackendAuto.vala',
  'BackendDrive.vala',
  'BackendFile.vala',
  'BackendGoogle.vala',
  'BackendLocal.vala',
  'BackendMicrosoft.vala',
  'BackendOAuth.vala',
  'BackendRemote.vala',
  'BackendUnsupported.vala',
  'BackendWatcher.vala',
  'CommonUtils.vala',
  'DirHandling.vala',
  'FileTree.vala',
  'FilteredSettings.vala',
  'InstallEnv.vala',
  'InstallEnvFlatpak.vala',
  'InstallEnvSnap.vala',
  'LogObscurer.vala',
  'Network.vala',
  'Operation.vala',
  'OperationBackup.vala',
  'OperationFiles.vala',
  'OperationRestore.vala',
  'OperationStatus.vala',
  'OperationVerify.vala',
  'Rclone.vala',
  'RecursiveDelete.vala',
  'RecursiveMove.vala',
  'RecursiveOp.vala',
  'ToolJob.vala',
  'ToolPlugin.vala',
  'borg/BorgInstance.vala',
  'borg/BorgJob.vala',
  'borg/BorgPlugin.vala',
  'duplicity/DuplicityInstance.vala',
  'duplicity/DuplicityJob.vala',
  'duplicity/DuplicityLogger.vala',
  'duplicity/DuplicityPlugin.vala',
  'libtool/ToolInstance.vala',
  'libtool/ToolJobChain.vala',
  'libtool/ToolJoblet.vala',
  'restic/ResticInstance.vala',
  'restic/ResticJob.vala',
  'restic/ResticPlugin.vala',
  dependencies: [
    gio_dep,
    gio_unix_dep,
    gpg_error_dep,
    json_dep,
    packagekit_dep,
    secret_dep,
    soup_dep,
  ],
  install: true,
  install_dir: pkglibdir,
)

libdeja_inc = include_directories('.')

install_data(
  'restic/restic-dump-to',
  install_dir: pkglibexecdir,
  install_mode: 'rwxr-xr-x',
)

subdir('tests')
