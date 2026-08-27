set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

[private]
default:
    just kube -l

[doc('Force Flux to pull in changes from your Git repository')]
[group('kube')]
reconcile:
    flux --namespace flux-system reconcile kustomization flux-system --with-source

[doc('Render every Kustomization and HelmRelease offline, as CI does')]
[group('kube')]
test:
    flate test all --path '{{ source_directory() }}'

[doc('Render the working tree against main and write the diff as a browsable page')]
[group('kube')]
diff out='/tmp/flate-diff.html':
    flate diff all --path '{{ source_directory() }}' --base origin/main --output html > '{{ out }}'
    just log info "Diff written" path '{{ out }}'

# [script], not a plain recipe: the embedded manifest's own indentation is extra
# leading whitespace to just's line-by-line parser.
[doc('Copy one PVC onto another in the same namespace (both must be unmounted)')]
[group('kube')]
[script]
pvc-copy namespace src dst:
    # One-shot mover for the kopiur cutover: an app moving onto a component-owned
    # PVC gets a new name, and dataSourceRef cannot be added to a bound claim, so
    # the data has to be copied across once. Both claims are RWO - scale the
    # workload to 0 first or the pod will not schedule.
    just log info "Copying PVC" namespace '{{ namespace }}' from '{{ src }}' to '{{ dst }}'
    kubectl --namespace '{{ namespace }}' delete --ignore-not-found job/pvc-copy
    kubectl --namespace '{{ namespace }}' apply --filename - <<'EOF'
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: pvc-copy
    spec:
      backoffLimit: 0
      template:
        spec:
          restartPolicy: Never
          securityContext:
            runAsUser: 0
          containers:
            - name: copy
              image: mirror.gcr.io/library/busybox:latest
              # -a preserves ownership and modes, which the app's own uid needs;
              # /src/. copies the contents, not the directory itself.
              command: ["sh", "-c", "cp -a /src/. /dst/ && echo done"]
              volumeMounts:
                - {name: src, mountPath: /src, readOnly: true}
                - {name: dst, mountPath: /dst}
          volumes:
            - {name: src, persistentVolumeClaim: {claimName: '{{ src }}'}}
            - {name: dst, persistentVolumeClaim: {claimName: '{{ dst }}'}}
    EOF
    kubectl --namespace '{{ namespace }}' wait job/pvc-copy --for=condition=Complete --timeout=60m
    kubectl --namespace '{{ namespace }}' delete job/pvc-copy
    just log info "Copy complete"

# source_directory(), not justfile_directory(): inside a module the latter
# resolves to the root justfile's directory, which would drop the `kubernetes/`
# segment.
bench_rgw_dir := source_directory() / 'apps/rook-ceph/rgw-benchmark'

[doc('Benchmark RGW with a warp object-size sweep (64KiB/1MiB/16MiB, ~15 min)')]
[group('kube')]
bench-rgw:
    # The claim has to bind before the Job exists: the pod reads the bucket name
    # and credentials from the Secret and ConfigMap that binding creates, and
    # backoffLimit is 0, so a Job that starts too early just fails.
    just log info "Applying bucket claim"
    kubectl apply -f '{{ bench_rgw_dir }}/objectbucketclaim.yaml'
    kubectl --namespace rook-ceph wait objectbucketclaim/rgw-benchmark \
        --for=jsonpath='{.status.phase}'=Bound --timeout=2m
    kubectl apply -f '{{ bench_rgw_dir }}/job.yaml'
    # Hints go in the message, not in a key/value pair: the root `log` recipe
    # interpolates its trailing args unquoted, so a multi-word value
    # word-splits and gum renders it as a run of bogus keys.
    just log info "Benchmark started - follow with: just kube bench-rgw-logs"

[doc('Follow the running RGW warp benchmark')]
[group('kube')]
bench-rgw-logs:
    kubectl --namespace rook-ceph logs --follow job/rgw-benchmark

[doc('Delete the RGW warp benchmark Job and its bucket claim')]
[group('kube')]
bench-rgw-clean:
    kubectl --namespace rook-ceph delete --ignore-not-found job/rgw-benchmark
    kubectl --namespace rook-ceph delete --ignore-not-found objectbucketclaim/rgw-benchmark
    # ceph-bucket-delete is reclaimPolicy: Delete, so dropping the claim purges
    # the bucket in RGW too. Safe here and nowhere else: the claim is pinned to
    # bucketName rgw-benchmark, which holds nothing but warp's scratch data.
    just log info "Bucket rgw-benchmark purged with the claim"
