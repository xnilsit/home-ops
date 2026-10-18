# garage-offsite

A daily `rclone sync` of every Garage bucket into one Backblaze B2 bucket,
through an rclone `crypt` layer. Each Garage bucket becomes a top-level
directory. Contents are encrypted, while object names stay readable and carry
a `.bin` suffix.

The `offsite-backup` key reads every bucket through `allBuckets`. A bucket
outside the `garage` namespace also needs a GarageReferenceGrant from
`GarageKey` in `garage`, or its controller revokes that read. Buckets from
`kubernetes/components/postgres` bring their own.

## B2 setup

The B2 side lives outside git:

- **Bucket**: private, and **Lifecycle Settings → custom**:

  ```json
  [{"fileNamePrefix": "", "daysFromHidingToDeleting": 90, "daysFromUploadingToHiding": null, "daysFromStartingToCancelingUnfinishedLargeFiles": 1}]
  ```

  With the native `b2` backend, `rclone sync` hides objects that are gone from
  Garage, as well as overwritten versions, instead of deleting them. This rule
  is what removes them 90 days later.
- **Application key**: restricted to that bucket, with capabilities
  `listBuckets, listFiles, readFiles, writeFiles` and **no `deleteFiles`**.
  Nothing the cluster holds can destroy data in B2.

The bucket name and key go into `app/secret.sops.yaml` as `B2_BUCKET`,
`B2_ACCOUNT` (key ID) and `B2_KEY`.

## Restore

Take the remote config from the decrypted `app/secret.sops.yaml`:

```ini
[b2]
type = b2
account = <B2_ACCOUNT>
key = <B2_KEY>

[offsite]
type = crypt
remote = b2:<B2_BUCKET>
filename_encryption = off
directory_name_encryption = false
password = <CRYPT_PASSWORD>
password2 = <CRYPT_PASSWORD2>
```

```sh
rclone lsf offsite:                                   # one directory per Garage bucket
rclone copy offsite:cnpg-backup garage:cnpg-backup    # restore a single bucket
```

To get back objects that were deleted or overwritten in the last 90 days, add
`--b2-version-at <timestamp>`. rclone then reads the bucket as it was at that
moment.
