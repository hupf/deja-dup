## Multiple monitor daemons

Profiles are a way to get parallel-installed deja-dups. They're used for testing containerized deployments like flatpak.
Although parallel-installed deja-dups means multiple monitor daemons, they shouldn't conflict with each other because
they each claim separate bus names and use separate gsettings schemas.

However, there is still the possiblity of a race between the stable-release monitors (from distro, flatpak, and snap).
The first monitor to start wins the race. It's possible to put our thumb on the scale by adjusing the installed
autostart desktop file's X-GNOME-Autostart-Delay value.

## Why do we need a monitor program?

This program is a bit of a hack.  I'm not terribly happy with it, but it's a comprimise of sorts.  I want a periodic scheduler that 'just works' in terms of user perceptions.  So, we ideally would:
1. Backup at regular intervals
   1. preferrably early in the morning (probably configurable by user)
   2. or roughly ASAP if computer isn't on when scheduled
2. If user isn't logged in, still backup
3. If user is logged in (or becomes logged in while backup is still going),
   show notification icon allowing reschedule/cancel

Given these desired traits, what can we do?

(3) suggests that we need a constantly-running program in the user's session that waits for the scheduled backup and displays an icon.  This is unavoidable.  It should have as small a footprint as possible.

(2) suggests we need to run a scheduler as root, most naturally as part of a cron job.  Since we can't drop a file in that says 'add this job to each user's crontab' (like we can do with /etc/xdg/autostart for autostart tasks), we'd need to drop in a /etc/cron.d file that runs at the minimum period we allow the user to set (probably a day), checks *all* users' settings to see if they are due for a backup, and kicks off a backup for/as them if needed.  But we're not guaranteed to satisfy (1.2) unless user is running anacron.

We could avoid the hackery of 'one root task that checks all users' by, when keys that control periodic settings are changed (watched by (3) daemon), doing "crontab -l | cronttab -" goofiness.  That would correctly install into the user's crontab and allow nice system cron permission control and such.  I'm not sure if that's a bonus or not (the silent refusal to run might confuse user, but surely that's a corner case).

The above points about (2) assumes that the user has a properly set up cron.  These days that's probably true, but none-the-less, it would be nice if we could avoid that.

If we went with a cron-based solution, we couldn't truly be sure the user's jobs were being run, and we couldn't be sure if they would be run 'asap' if the computer isn't running at job time.  This can be fixed by depending on anacron.

Another issue with (2) is that it requires us to have saved the user's passwords -- and more importantly -- be able to get them from gnome-keyring without a gnome session.  This is probably a deal breaker.  Without keyring support, we'd have to hardcode passwords...

Alternatively, we could have the already-required user-space (3) watcher program kick of backups by watching the clock itself.  Our scheduling is simple enough, it would suffice.  This sacrifices (2) altogether.  Which sucks.  But we could kick off the build the next time the user does log in.  Such a choice would put us squarely in the 'single-user laptop/desktop' use-case, foregoing the 'making backup for administrators easier' camp.  I'm mostly OK with this.

For now, we're going to do what the paragraph above suggests:  don't use cron, do it ourselves.  This issue should be revisited in the future.
