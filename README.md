Repository holding helm charts for running Hadoop Distributed File System (HDFS)
on Kubernetes for use with CI.  This is not intended to be run in production.

# Charts

Helm charts for launching HDFS daemons in a K8s cluster. The main entry-point
chart is `hdfs-k8s`, which is a uber-chart that specifies other charts as
dependency subcharts. This means you can launch all HDFS components using
`hdfs-k8s`.

Note that the HDFS charts is meant for CI and not for production.  This is why
it only runs with a single namenode for instance.

HDFS on K8s supports the following features and limitations:
  - single namenode only.  There is no high availability (HA).  This was
    intentional to keep the deployment simple as the intended use case is
    CI/CD.
  - K8s persistent volumes (PV) for metadata: Namenode crash will cause service
    outage. Losing namenode metadata can lead to loss of file system. HDFS on
    K8s can store the metadata in remote K8s persistent volumes so that metdata
    can remain intact even if both namenode daemons are lost or restarted.
  - K8s persistent volumes (PV) for file data: HDFS datanodes daemons store actual
    file data. File data should also survive datanode crash or restart. HDFS on
    K8s stores the file data on the local disks of the K8s cluster nodes using
    K8s HostPath volumes.
  - Kerberos: Vanilla HDFS is not secure. Intruders can easily write custom
    client code, put a fake user name in requests and steal data. Production
    HDFS often secure itself using Kerberos. HDFS on K8s supports Kerberos.

Here is the list of all charts.

  - hdfs-ci: main uber-chart. Launches other charts.
  - hdfs-ci-namenode: A setup of the namenode that launches only one namenode.
    i.e. This does not support HA.
  - hdfs-ci-datanode: a statefulset and other K8s components for launching HDFS
    datanode daemons, which are responsible for storing file data.
  - hdfs-ci-config: a configmap containing Hadoop config files for HDFS.
  - hdfs-ci-krb5: a size-1 statefulset and other K8s components for launching
    a Kerberos server, which can be used to secure HDFS. Disabled by default.

# Prerequisite

Requires Kubernetes 1.6+ as the `namenode` and `datanodes` are using
`ClusterFirstWithHostNet`, which was introduced in Kubernetes 1.6

# Usage

## Basic

The HDFS daemons can be launched using the main `hdfs-k8s` chart. First, build
the main chart using:

```
  $ helm dependency build charts/hdfs-k8s
```

Namenode needs persistent volumes for storing metadata. By default, the helm
charts do not set the storage class name for dynamically provisioned volumes,
nor does it use persistent volume selectors for static persistent volumes.

This means it will rely on a provisioner for default storage volume class for
dynamic volumes. Or if your cluster has statically provisioned volumes, the
chart will match existing volumes entirely based on the size requirements. To
override this default behavior, you can specify storage volume classes for
dynamic volumes, or volume selectors for static volumes. See below for how to
set these options.

  - namenodes: The namenode needs at least a 100 GB volume.  i.e.
    This can be overridden by the `hdfs-namenode-k8s.persistence.size` option.
    You can also override the storage class or the selector using
    `hdfs-namenode-k8s.persistence.storageClass`, or
    `hdfs-namenode-k8s.persistence.selector` respectively. For details, see the
    values.yaml file inside `hdfs-namenode-k8s` chart dir.
  - kerberos: The single Kerberos server will need at least 20 GB in the volume.
    The size can be overridden by the `hdfs-krb5-k8s.persistence.size` option.
    You can also override the storage class or the selector using
    `hdfs-krb5-k8s.persistence.storageClass`, or
    `hdfs-krb5-k8s.persistence.selector` respectively. For details, see the
    values.yaml file inside `hdfs-krb5-k8s` chart dir.

Then launch the main chart. Specify the chart release name say "my-hdfs",
which will be the prefix of the K8s resource names for the HDFS components.

```
  $ helm install my-hdfs charts/hdfs-k8s
```

Wait for all daemons to be ready. Note some daemons may restart themselves
a few times before they become ready.

```
  $ kubectl get pod -l release=my-hdfs

  NAME                             READY     STATUS    RESTARTS   AGE
  my-hdfs-datanode-0               1/1       Running   3          2m
  my-hdfs-namenode-0               1/1       Running   3          2m
```


## Kerberos

Kerberos can be enabled by setting a few related options:

```
  $ helm install -n my-hdfs charts/hdfs-k8s  \
    --set global.kerberosEnabled=true  \
    --set global.kerberosRealm=MYCOMPANY.COM  \
    --set tags.kerberos=true
```

This will launch all charts including the Kerberos server, which will become
ready pretty soon. However, HDFS daemon charts will be blocked as the deamons
require Kerberos service principals to be available. So we need to unblock
them by creating those principals.

First, create a configmap containing the common Kerberos config file:

```
  _MY_DIR=~/krb5
  mkdir -p $_MY_DIR
  _KDC=$(kubectl get pod -l app=hdfs-krb5,release=my-hdfs --no-headers  \
      -o name | cut -d/ -f2)
  _run kubectl cp $_KDC:/etc/krb5.conf $_MY_DIR/tmp/krb5.conf
  _run kubectl create configmap my-hdfs-krb5-config  \
    --from-file=$_MY_DIR/tmp/krb5.conf
```

Second, create the service principals and passwords. Kerberos requires service
principals to be host specific. Some HDFS daemons are associated with your K8s
cluster nodes' physical host names say kube-n1.mycompany.com, while others are
associated with Kubernetes virtual service names, for instance
my-hdfs-namenode-0.my-hdfs-namenode.default.svc.cluster.local. You can get
the list of these host names like:

```
  $ _HOSTS=$(kubectl get nodes  \
    -o=jsonpath='{.items[*].status.addresses[?(@.type == "Hostname")].address}')

  $ _HOSTS+=$(kubectl describe configmap my-hdfs-config |  \
      grep -A 1 -e dfs.namenode.rpc-address.hdfs-k8s  \
          -e dfs.namenode.shared.edits.dir |  
      grep "<value>" |
      sed -e "s/<value>//"  \
          -e "s/<\/value>//"  \
          -e "s/:8020//"  \
          -e "s/qjournal:\/\///"  \
          -e "s/:8485;/ /g"  \
          -e "s/:8485\/hdfs-k8s//")
```

Then generate per-host principal accounts and password keytab files.

```
  $ _SECRET_CMD="kubectl create secret generic my-hdfs-krb5-keytabs"
  $ for _HOST in $_HOSTS; do
      kubectl exec $_KDC -- kadmin.local -q  \
        "addprinc -randkey hdfs/$_HOST@MYCOMPANY.COM"
      kubectl exec $_KDC -- kadmin.local -q  \
        "addprinc -randkey HTTP/$_HOST@MYCOMPANY.COM"
      kubectl exec $_KDC -- kadmin.local -q  \
        "ktadd -norandkey -k /tmp/$_HOST.keytab hdfs/$_HOST@MYCOMPANY.COM HTTP/$_HOST@MYCOMPANY.COM"
      kubectl cp $_KDC:/tmp/$_HOST.keytab $_MY_DIR/tmp/$_HOST.keytab
      _SECRET_CMD+=" --from-file=$_MY_DIR/tmp/$_HOST.keytab"
    done
```

The above was building a command using a shell variable `SECRET_CMD` for
creating a K8s secret that contains all keytab files. Run the command to create
the secret.

```
  $ $_SECRET_CMD
```

This will unblock all HDFS daemon pods. Wait until they become ready.

Finally, test the setup using the following commands:

```
  $ _NN0=$(kubectl get pods -l app=hdfs-namenode,release=my-hdfs -o name |  \
      head -1 |  \
      cut -d/ -f2)
  $ kubectl exec $_NN0 -- sh -c "(apt install -y krb5-user > /dev/null)"  \
      || true
  $ kubectl exec $_NN0 --   \
      kinit -kt /etc/security/hdfs.keytab  \
      hdfs/my-hdfs-namenode-0.my-hdfs-namenode.default.svc.cluster.local@MYCOMPANY.COM
  $ kubectl exec $_NN0 -- hdfs dfsadmin -report
  $ kubectl exec $_NN0 -- hdfs haadmin -getServiceState nn0
  $ kubectl exec $_NN0 -- hdfs haadmin -getServiceState nn1
  $ kubectl exec $_NN0 -- hadoop fs -rm -r -f /tmp
  $ kubectl exec $_NN0 -- hadoop fs -mkdir /tmp
  $ kubectl exec $_NN0 -- hadoop fs -chmod 0777 /tmp
  $ kubectl exec $_KDC -- kadmin.local -q  \
      "addprinc -randkey user1@MYCOMPANY.COM"
  $ kubectl exec $_KDC -- kadmin.local -q  \
      "ktadd -norandkey -k /tmp/user1.keytab user1@MYCOMPANY.COM"
  $ kubectl cp $_KDC:/tmp/user1.keytab $_MY_DIR/tmp/user1.keytab
  $ kubectl cp $_MY_DIR/tmp/user1.keytab $_CLIENT:/tmp/user1.keytab

  $ kubectl exec $_CLIENT -- sh -c "(apt install -y krb5-user > /dev/null)"  \
      || true

  $ kubectl exec $_CLIENT -- kinit -kt /tmp/user1.keytab user1@MYCOMPANY.COM
  $ kubectl exec $_CLIENT -- sh -c  \
      "(head -c 100M < /dev/urandom > /tmp/random-100M)"
  $ kubectl exec $_CLIENT -- hadoop fs -ls /
  $ kubectl exec $_CLIENT -- hadoop fs -copyFromLocal /tmp/random-100M /tmp
```

## Advanced options

### Excluding datanodes from some K8s cluster nodes

You may want to exclude some K8s cluster nodes from datanodes launch target.
For instance, some K8s clusters may let the K8s cluster master node launch
a datanode. To prevent this, label the cluster nodes with
`hdfs-datanode-exclude`.

```
  $ kubectl label node YOUR-CLUSTER-NODE hdfs-datanode-exclude=yes
```

# Security

## K8s secret containing Kerberos keytab files

The Kerberos setup creates a K8s secret containing all the keytab files of HDFS
daemon service princialps. This will be mounted onto HDFS daemon pods. You may
want to restrict access to this secret using k8s
[RBAC](https://kubernetes.io/docs/admin/authorization/rbac/), to minimize
exposure of the keytab files.

## HostPath volumes
`Datanode` daemons run on every cluster node. They also mount k8s `hostPath`
local disk volumes.  You may want to restrict access of `hostPath`
using `pod security policy`.
See [reference](https://github.com/kubernetes/examples/blob/master/staging/podsecuritypolicy/rbac/README.md))

## Credits

Many charts are using public Hadoop docker images hosted by
[uhopper](https://hub.docker.com/u/uhopper/).
