"""Prunes what Immich's machine-learning will never read again from its model cache.

Immich only replaces an artifact when it loads that artifact again, so anything
the running versions no longer ask for stays on the volume for good:

- the flat OpenVINO blobs Immich before 3.3 wrote straight into
  <model>/openvino/, one set per OpenVINO release and GPU driver. 3.3 reads
  only <model>/openvino/<gpu>/<shape>/;
- prepared graphs (a directory holding a manifest.json) built under an
  onnxruntime or OpenVINO release other than this image's. Immich rebuilds
  these in place when it loads them, but one for a GPU or shape it no longer
  uses is never loaded;
- prepared graphs that never got their manifest, from a replica stopped
  mid-compile;
- huggingface's xet cache, which only a download reads.

Runs in the machine-learning image so the versions it compares against are
the ones Immich records, read the same way.
"""

import ctypes
import fcntl
import json
import os
import shutil
import time
from pathlib import Path

import onnxruntime as ort

CACHE = Path(os.environ.get("MACHINE_LEARNING_CACHE_FOLDER", "/cache"))
DRY_RUN = os.environ.get("DRY_RUN", "").lower() in ("1", "true")
# Older than this, files without a manifest are a compile that was cut short,
# not one still running.
GRACE = 24 * 3600
# The directories an execution provider caches into, beside each model.onnx:
# the provider's name without "ExecutionProvider", lowercased.
PROVIDERS = ("openvino", "cpu", "cuda", "migraphx", "coreml", "nv_tensorrt_rtx")

freed = 0


def openvino_build() -> str | None:
    """The release half of the device version Immich records for an Intel GPU (immich_ml.sessions.ort._intel_gpu)."""
    library = Path(ort.__file__).parent / "capi" / "libopenvino_c.so"
    if not library.exists():
        return None
    ov = ctypes.CDLL(str(library))
    release = (ctypes.c_char_p * 2)()  # ov_version_t: build number, description
    ov.ov_get_openvino_version(release)
    build = (release[0] or b"").decode()
    ov.ov_version_free(release)
    return build


ONNXRUNTIME = ort.__version__
OPENVINO = openvino_build()


def files(path: Path) -> list[Path]:
    return [Path(root) / name for root, _, names in os.walk(path) for name in names]


def size(path: Path) -> int:
    if not path.is_dir() or path.is_symlink():
        return path.lstat().st_size
    return sum(file.lstat().st_size for file in files(path))


def idle(path: Path) -> bool:
    """Nothing in it was written within the grace period."""
    newest = max((file.lstat().st_mtime for file in files(path)), default=path.lstat().st_mtime)
    return time.time() - newest > GRACE


def remove(path: Path, why: str) -> None:
    global freed
    amount = size(path)
    freed += amount
    print(f"{'would remove' if DRY_RUN else 'removing'} {path} ({amount / 2**20:.0f} MiB): {why}", flush=True)
    if DRY_RUN:
        return
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def stale(manifest: Path, provider: str) -> str | None:
    try:
        facts = json.loads(manifest.read_bytes())["facts"]
    except (OSError, ValueError, KeyError, TypeError):
        return "its manifest does not parse"
    if facts.get("onnxruntime") != ONNXRUNTIME:
        return f"prepared under onnxruntime {facts.get('onnxruntime')}, not {ONNXRUNTIME}"
    device = facts.get("device")
    # "<driver> <openvino>"; a CPU fallback records no device.
    if provider == "openvino" and OPENVINO and device and not device.endswith(f" {OPENVINO}"):
        return f"compiled for {device}, not OpenVINO {OPENVINO}"
    return None


def prune(provider: Path) -> None:
    for root, dirs, names in os.walk(provider):
        here = Path(root)
        if "manifest.json" in names:
            if why := stale(here / "manifest.json", provider.name):
                remove(here, why)
            dirs.clear()  # an artifact holds no other artifacts
        elif here == provider:
            for name in names:
                remove(here / name, "flat execution provider cache from Immich before 3.3")
        elif names and idle(here):
            remove(here, "no manifest, so its preparation never finished")
            dirs.clear()
    if not DRY_RUN:
        for root, _, _ in os.walk(provider, topdown=False):
            if not any(Path(root).iterdir()):
                Path(root).rmdir()


def main() -> None:
    print(f"onnxruntime {ONNXRUNTIME}, OpenVINO {OPENVINO}{', dry run' if DRY_RUN else ''}", flush=True)
    before = size(CACHE)

    for model in sorted(CACHE.rglob("model.onnx")):
        directory = model.parent
        if any(part in PROVIDERS for part in directory.relative_to(CACHE).parts):
            continue  # a prepared graph, not a download
        # The lock Immich holds while it prepares a graph for this model.
        with (directory / "model.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print(f"skipping {directory}: Immich is preparing it", flush=True)
                continue
            for provider in PROVIDERS:
                if (directory / provider).is_dir():
                    prune(directory / provider)

    for xet in (CACHE / "xet", CACHE / "hf-cache" / "xet"):
        if xet.is_dir() and idle(xet):
            remove(xet, "huggingface download cache, read only while downloading")

    for entry in sorted(CACHE.iterdir()):
        print(f"{size(entry) / 2**20:8.0f} MiB  {entry.name}", flush=True)
    print(f"{freed / 2**20:.0f} MiB of {before / 2**20:.0f} MiB {'reclaimable' if DRY_RUN else 'freed'}", flush=True)


if __name__ == "__main__":
    main()
