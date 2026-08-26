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

migrate_dir := source_directory() / 'apps/garage/rgw-to-garage'

[doc('Copy the CNPG backup buckets from Ceph RGW to Garage on the NAS')]
[group('kube')]
migrate-cnpg-backups:
    # A Job is immutable, so a rerun has to replace it. Rerunning is safe: both
    # Jobs run `rclone copy`, which never deletes at the destination.
    just log info "Replacing any previous copy Jobs"
    kubectl --namespace database delete --ignore-not-found \
        job/rgw-to-garage-cnpg-backup job/rgw-to-garage-timescale-backup
    kubectl apply -f '{{ migrate_dir }}/job.yaml'
    just log info "Copy started - follow with: just kube migrate-cnpg-backups-logs"

[doc('Follow the running RGW-to-Garage copy Jobs')]
[group('kube')]
migrate-cnpg-backups-logs:
    # --max-log-requests must clear the pod count or kubectl refuses to stream
    kubectl --namespace database logs --follow --prefix --max-log-requests 4 \
        --selector app.kubernetes.io/name=rgw-to-garage

[doc('Wait for the RGW-to-Garage copy Jobs to finish')]
[group('kube')]
migrate-cnpg-backups-wait:
    kubectl --namespace database wait job/rgw-to-garage-cnpg-backup \
        job/rgw-to-garage-timescale-backup --for=condition=Complete --timeout=6h
    just log info "Both buckets copied"

[doc('Delete the RGW warp benchmark Job and its bucket claim')]
[group('kube')]
bench-rgw-clean:
    kubectl --namespace rook-ceph delete --ignore-not-found job/rgw-benchmark
    kubectl --namespace rook-ceph delete --ignore-not-found objectbucketclaim/rgw-benchmark
    # ceph-bucket-delete is reclaimPolicy: Delete, so dropping the claim purges
    # the bucket in RGW too. Safe here and nowhere else: the claim is pinned to
    # bucketName rgw-benchmark, which holds nothing but warp's scratch data.
    just log info "Bucket rgw-benchmark purged with the claim"
