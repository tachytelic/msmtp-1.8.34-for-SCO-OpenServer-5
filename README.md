# msmtp 1.8.34 for SCO OpenServer 5

A build of [msmtp 1.8.34](https://marlam.de/msmtp/) for **SCO OpenServer 5**.
msmtp takes a mail message and hands it to a mail service over an encrypted
connection, logging in with a username and password. It is one binary and one
short settings file, with no daemon to run.

```
$ echo "The backup finished." | mail -s "Nightly backup" it@example.com
$ tail -1 /usr/adm/msmtp.log
Nov 25 18:11:00 host=smtp.example.com tls=on auth=on ... smtpstatus=250 ... exitcode=EX_OK
```

## Why?

Mail services now expect two things from anything that sends through them: an
encrypted connection (TLS) and a login (SMTP AUTH). The MMDF and sendmail that
OpenServer 5 shipped with can do neither, so reports, alerts and invoices that
a SCO system used to email stop arriving when the mail service is changed.

msmtp fills that gap. OpenServer's own `mail` and `mailx` commands pass each
message to a helper program, and msmtp accepts exactly what they pass. Scripts
and applications that already call `mail` carry on unchanged.

## Requirements

| System | Needs |
|---|---|
| OpenServer 5.0.7 | PRNGD running, and a CA certificate bundle. |
| OpenServer 5.0.5 | The same, plus OSS646C. Tested on a system set up as in our [OpenSSH guide](https://scoexpert.com/guides/openssh-sco-openserver-5-0-5/). |
| OpenServer 5.0.6 | Not run there, but it sits between the two tested releases and should work with OSS646C. |

**PRNGD.** OpenServer has no `/dev/urandom`, so the OpenSSL inside this build
takes its random numbers from the PRNGD socket at `/etc/egd-pool`. If
`ps -ef | grep prngd` shows it running, as it does on a system with SSH set
up, there is nothing to do.

**CA bundle.** msmtp checks the mail server's certificate against
`/usr/local/etc/ssl/cert.pem` and will not send without that file. Our
[curl build](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
installs it, so install curl first and you have both the bundle and the means
to fetch this binary. Check with `ls -l /usr/local/etc/ssl/cert.pem`. If it is
missing, download [cacert.pem](https://curl.se/ca/cacert.pem) on another
computer, copy it across and save it under that name.

## Install

```sh
# On the SCO box:
curl -Lo /usr/local/bin/msmtp https://github.com/tachytelic/msmtp-1.8.34-for-SCO-OpenServer-5/releases/download/v1.0.0/msmtp
chmod 755 /usr/local/bin/msmtp
msmtp --version
```

## Configure

Fetch the example settings file and edit the five lines that name your mail
service:

```sh
curl -Lo /usr/local/etc/msmtprc https://github.com/tachytelic/msmtp-1.8.34-for-SCO-OpenServer-5/releases/download/v1.0.0/msmtprc.example
vi /usr/local/etc/msmtprc
```

Put the password in a file of its own that only root can read. Type the
`cat` line, then the password, then Ctrl-D on a new line:

```sh
umask 077
cat > /usr/local/etc/msmtp.pass
chmod 600 /usr/local/etc/msmtp.pass /usr/local/etc/msmtprc
```

As set up here, only root can send. If the application sends mail as another
user, give that user's group read access to both files instead
(`chgrp` the files to the group and `chmod 640`), and point `logfile` at a
file the group can write.

Some services, Gmail among them, will not accept your normal password here and
ask you to create an app password instead.

Check the connection before sending anything. This logs nothing in and sends
nothing; it shows the certificate and what the server offers:

```sh
msmtp --serverinfo --host=smtp.example.com --port=587 --tls=on \
      --tls-starttls=on --tls-trust-file=/usr/local/etc/ssl/cert.pem
```

Then send a test message:

```sh
( echo "To: you@example.com"; echo "Subject: msmtp test"; echo; echo "It works." ) | msmtp -t
```

## Make `mail` and `mailx` use it

`mail` and `mailx` are the same program on OpenServer 5. It runs the helper
named in the `EXECMAIL` environment variable, with the recipients as arguments
and the message on standard input:

```sh
EXECMAIL=/usr/local/bin/msmtp; export EXECMAIL
echo "The backup finished." | mail -s "Nightly backup" it@example.com
```

Set it in `/etc/profile` for logins, and at the top of any script that cron
runs. Mail sent this way leaves the system through your mail service. Mail
sent without the variable is delivered locally as before, so messages between
users on the SCO system are not affected.

## Tested

| Test | 5.0.5 | 5.0.7 |
|---|---|---|
| TLS handshake with the certificate verified, Gmail and Microsoft 365 | Yes | Yes |
| Login and send through Gmail, direct and through `mail` | Yes, with the 1.0.2 build below | Yes, with the 1.0.2 build below |
| Login and send through Gmail with the published binary, PDF and text attachments built by Python | Not run | Yes |

The first login and send tests were run with an earlier build of the same
source linked to OpenSSL 1.0.2. The published binary differs only in being
linked to OpenSSL 3.5.0. It has passed the handshake test on both releases and
has sent through Gmail on 5.0.7.

Microsoft 365 is turning off password logins for SMTP, so a password in
msmtp is not a lasting answer there. Use a mail relay service, or a
Microsoft 365 connector that accepts mail from your fixed IP address.

## Build from source

`build.sh` builds natively on OpenServer 5.0.7 with GCC 3.4.6 and a static
OpenSSL 3.5.0 (see our
[OpenSSL build](https://github.com/tachytelic/OpenSSL-3.5.0-for-SCO-OpenServer-5)).
Unpack [msmtp-1.8.34.tar.xz](https://marlam.de/msmtp/releases/msmtp-1.8.34.tar.xz)
next to it and run it. The patch is small:

- `msgid.c`: a stand-in for `clock_gettime()`, which OpenServer lacks.
- `tools.c`: `select()` in place of `nanosleep()`.
- `getopt.h`: a declaration of `getopt_long()`, taken from GCC's libiberty at
  link time.
- `net.c`, `sco-net.h`: `socklen_t`, and the IPv6 code compiled out.

Not built in: GNU SASL, IDN host names, NLS and the `msmtpd` daemon. msmtp's
own PLAIN, LOGIN and CRAM-MD5 logins are included.

## Files

```
build.sh                       Build script for OpenServer 5.0.7
patches/msmtp-1.8.34-sco.patch The source changes
msmtprc.example                Example settings file
LICENSE                        MIT (covers patch + build script)
README.md                      This file
```

The binary ships via the **[Releases](../../releases)** page.

## License

msmtp is © Martin Lambers and others, distributed under
[GPLv3+](https://www.gnu.org/licenses/gpl-3.0.html). The prebuilt binary is
upstream msmtp 1.8.34 with the patch in this repo applied, linked statically
to OpenSSL 3.5.0 (Apache License 2.0) and to `getopt_long` from GCC's
libiberty (LGPL). The patch and build script are released under MIT.

## See also

- [curl-7.88.1 for SCO](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5):
  the natural first install on a fresh SCO box, and the source of the CA bundle.
- [More SCO OpenServer 5 binaries](https://scoexpert.com/guides/sco-openserver-5-binaries/):
  the full list of builds, on scoexpert.com.
- [SCO Expert](https://scoexpert.com/): support for SCO OpenServer
  systems, with guides, a knowledge base and a mirror of SCO's own
  downloads.
