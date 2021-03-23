<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

## Terminology

 * Backend: a storage location like removable drive, Google Drive, etc
 * Tool: a command line backup tool like Duplicity, Restic, etc
 * Operation: a single logical operation like backup, restore, query, etc
 * InstallEnv: a release/installation environment like snap, flatpak, etc

## Tools

There is a small public interface to a tool, which supports only a few
operations. The tool is responsible for handling that operation, potentially
calling the tool command multiple times to handle a single logical operation.

The public interface is a single ToolPlugin which handles meta info about the
tool and a ToolJob which handles initiating and responding to a run of the
tool.

There is also some support code for tools in `libtool` which is not a public
interface, but just helper code to make writing a tool easier and share some
logic between them.

## Operations vs ToolJobs

Operations are a single toplevel operation, like a backup. But it may also hold
some "business logic". For example, the backup operation does a backup and a
verify.

Whereas a ToolJob is a little smaller in scope. There are "backup" jobs and
"verify" jobs.

And inside the ToolJob, a "backup" job may involve multiple calls to the
command line tool, like deleting old backups as we add new backups.
