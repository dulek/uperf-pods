#!/bin/bash -x

protocol=${1:-tcp}
size=${2:-16384}
duration=${3:-60}

server_name=uperf-server
client_name=uperf-client

oc create deploy --image quay.io/cloud-bulldozer/uperf $server_name -- uperf -s -v

until [[ `oc get pods -l app=$server_name` =~ "Running" ]] ; do
    sleep 3s
done

server_ip=`oc get pods -l app=$server_name -o jsonpath='{.items[0].status.podIP}'`

cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: uperf-profile
data:
  uperf-profile.xml: |
    <?xml version=1.0?>
    <profile name="uperf-profile">
          <group nthreads="1">
          <transaction iterations="1">
            <flowop type="connect" options="remotehost=$server_ip protocol=$protocol"/>
          </transaction>
          <transaction duration="$duration">
            <flowop type=write options="size=$size"/>
            <flowop type=read  options="size=$size"/>
          <transaction iterations="1">
            <flowop type=disconnect />
          </transaction>
      </group>
    </profile>
EOF

# Create client
cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: $client_name
  name: $client_name
spec:
  template:
    metadata:
      labels:
        app: $client_name
    spec:
      containers:
      - command:
        - uperf
        - -v
        - -a
        - -R
        - -i
        - "1"
        - -m
        - /tmp/uperf-profile.xml
        image: quay.io/cloud-bulldozer/uperf
        name: uperf
        volumeMounts:
        - mountPath: /tmp
          name: profile
      restartPolicy: OnFailure
      volumes:
      - name: profile
        configMap:
          defaultMode: 420
          name: uperf-profile
EOF

until [[ `oc get pods -l app=$client_name` =~ "Completed" ]] ; do
    sleep 3s
done

# Gather results
