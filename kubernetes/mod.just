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
    # ceph-bucket is reclaimPolicy: Retain, so dropping the claim leaves the
    # bucket behind. warp empties it on a clean exit, so this is normally an
    # empty bucket - not purged automatically, because purging is exactly the
    # operation that must never fire at the wrong bucket by accident.
    just log warn "Bucket rgw-benchmark is retained in RGW - purge with: kubectl -n rook-ceph exec deploy/rook-ceph-tools -- radosgw-admin bucket rm --bucket=rgw-benchmark --purge-objects"
