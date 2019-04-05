# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# This file is part of Déjà Dup.
# For copyright information, see AUTHORS.
#
# Déjà Dup is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Déjà Dup is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.

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
