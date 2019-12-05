# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

libdeja = shared_library('deja',
    ['Backend.vala',
     'BackendAuto.vala',
     'BackendDrive.vala',
     'BackendFile.vala',
     'BackendGCS.vala',
     'BackendGOA.vala',
     'BackendGoogle.vala',
     'BackendLocal.vala',
     'BackendOpenstack.vala',
     'BackendRackspace.vala',
     'BackendRemote.vala',
     'BackendS3.vala',
     'CommonUtils.vala',
     'DirHandling.vala',
     'FilteredSettings.vala',
     'Network.vala',
     'Operation.vala',
     'OperationBackup.vala',
     'OperationFiles.vala',
     'OperationRestore.vala',
     'OperationStatus.vala',
     'OperationVerify.vala',
     'RecursiveDelete.vala',
     'RecursiveMove.vala',
     'RecursiveOp.vala',
     'ToolPlugin.vala',
     'tools/duplicity/DuplicityInstance.vala',
     'tools/duplicity/DuplicityJob.vala',
     'tools/duplicity/DuplicityPlugin.vala',
    ],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [
        gio_dep,
        gio_unix_dep,
        goa_dep,
        gpgerror_dep,
        json_dep,
        packagekit_dep,
        secret_dep,
        soup_dep,
    ],
    install: true,
    install_dir: pkglibdir)

libdeja_inc = include_directories('.')

# This is used when running duplicity as root.
# See data/org.gnome.DejaDup.policy.in and DuplicityInstance.vala for more details.
install_data('tools/duplicity/duplicity',
    install_dir: pkglibexecdir,
    install_mode: 'rwxr-xr-x')

subdir('tests')
