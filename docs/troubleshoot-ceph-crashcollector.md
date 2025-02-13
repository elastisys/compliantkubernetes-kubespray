# Troubleshoot rook-ceph crashcollector

If you enable the crash collector in your rook-ceph installation, you might see some error logs in the crashcollector pods :

```console
$ kubectl logs -f rook-ceph-crashcollector-dev-sc-storage-0-6695c6zx8rg
INFO:ceph-crash:monitoring path /var/lib/ceph/crash, delay 600s
WARNING:ceph-crash:post /var/lib/ceph/crash/2023-11-21T22:05:00.157537Z_cd3d06ca-bc60-4b24-9c05-998876d4f209 as client.crash.rook-ceph-crashcollector-dev-sc-storage-0-6695c6zx8rg failed: 2023-11-21T22:20:07.837+0000 7f8489b12700 -1 monclient(hunting): handle_auth_bad_method server allowed_methods [2] but i only support [2,1]
2023-11-21T22:20:07.837+0000 7f848a313700 -1 monclient(hunting): handle_auth_bad_method server allowed_methods [2] but i only support [2,1]
2023-11-21T22:20:07.837+0000 7f8489311700 -1 monclient(hunting): handle_auth_bad_method server allowed_methods [2] but i only support [2,1]
[errno 13] RADOS permission denied (error connecting to the cluster)
```

Note that in most cases, those error messages are expected due to the rook-ceph crash posting implementation.

Basically, what happens is that Ceph [scans](https://github.com/ceph/ceph/blob/main/src/ceph-crash.in#L66) the crash folder `/var/lib/ceph/crash` every _X_ minutes, by default the delay between scans is 10 minutes. Whenever it find crashes, it will try to [post](https://github.com/ceph/ceph/blob/main/src/ceph-crash.in#L44) them, once the post action succeeds, Ceph will [move those crashes](https://github.com/ceph/ceph/blob/main/src/ceph-crash.in#L84) to the **posted** folder.

The post action is running a ceph command :

```bash
ceph post -i /var/lib/ceph/crash/crash-2023-11-01-23-08-00 -n <auth-client>
```

The reason why sometimes we see those error messages on the crashcollector pods, is that rook-ceph try posting the crashes using different auth clients, until it succeeds. If you check the code [implementation](https://github.com/ceph/ceph/blob/main/src/ceph-crash.in#L46C25-L46C25)

```python
def post_crash(path):
    rc = 0
    for n in auth_names:
        pr = subprocess.Popen(
            args=['timeout', '30', 'ceph',
                  '-n', n,
                  'crash', 'post', '-i', '-'],
            stdin=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
```

and `auth_names` variable is set by default to :

```python
auth_names = ['client.crash.%s' % socket.gethostname(),
              'client.crash',
              'client.admin']
```

So, if you saw those error messages, you just need to double check that the crashes located at `/var/lib/ceph/crash` are posted, meaning moved to the `/var/lib/ceph/crash/posted` folder.

In some cases, you might want to generate a crash and see it under the crash folder, and verify that it was posted or not, to do that run the following command inside any `rook-ceph-mon` pod:

```bash
ceph --admin-daemon /var/run/ceph/ceph-mon.a.asok assert
```
