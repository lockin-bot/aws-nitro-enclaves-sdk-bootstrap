## Bootstrap for AWS Nitro Enclaves

This project builds the kernel, nsm driver and bootstrap process for AWS Nitro Enclaves.

The binaries being built from the sources in this package are distributed as part of [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli) and can be used to build enclave image files for AWS Nitro Enclaves.

### Overview of the included binaries

The binaries being built from this repository are used at different stages of building enclave image files (EIFs). The [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli) uses docker images as the base to build EIFs from. An EIF contains a minimal operating system and a user application to run inside the enclave, as well as some additional metadata. A detailed specification of the EIF format can be found in [aws-nitro-enclaves-image-format](https://github.com/aws/aws-nitro-enclaves-image-format) This repository provides a way to build the following components: 

* **[`linuxkit`](https://github.com/linuxkit/linuxkit)**: is a toolkit for building operating systems for containers. For building enclave image files we use a slightly modified version to extract docker images and create initrd files containing the application to be run inside the enclave.

* **`kernel`**: is a linux kernel to be used inside the enclave. Depending on the architecture, this will be a `bzImage` (`x86_64`) or an `Image` (`aarch64`) file. Alongside the kernel we also create the respective `bzImage.config` or `Image.config` containing the kernel config the kernel was built with. That file does not get included into the EIF, but helps in reasoning about which features and configurations were set for the kernel.

* **`nsm.ko`**: is a loadable linux kernel modules built for the particular kernel being built. It provides the driver for the Nitro Secure Module, which the enclave can use to request an attestation document from the hypervisor. That attestation document can be used to prove the identity of the enclave.

* **`init`**: is the bootstrap process for the enclave. This provides the initial userspace process that will setup the file system and drivers and launch the user application.

## Changes from Upstream

This is a fork of [aws/aws-nitro-enclaves-sdk-bootstrap](https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap) with the following modifications:

### Kernel Version

Upgraded from the upstream kernel to **Linux 6.19.10**. This version was chosen because it includes stable support for the kernel features required by our enclave architecture (NBD, dm-crypt/LUKS, virtio-vsock improvements).

### Kernel Configuration Changes

The following kernel options were enabled beyond the upstream defaults:

- **`CONFIG_BLK_DEV_NBD=y`** — Network Block Device support, used to provide persistent storage to enclaves over VSOCK
- **`CONFIG_DM_CRYPT=y`** — Device-mapper crypto target, required for LUKS disk encryption inside the enclave
- **`CONFIG_CRYPTO_AES=y`**, **`CONFIG_CRYPTO_XTS=y`**, **`CONFIG_CRYPTO_AES_NI_INTEL=y`** — AES and XTS cipher support for LUKS encryption

### Kernel Patches

Two patches are applied on top of the upstream kernel:

1. **`0001-vsock-virtio-Remove-queued_replies-pushback-logic-6.19.10.patch`** — Fixes a virtio-vsock deadlock between parent and enclave. Can be removed once the fix lands in upstream stable.
2. **`nbd-vsock-support.patch`** — Adds VSOCK transport support to the in-kernel NBD client, enabling block device access over VSOCK without requiring TCP.

### Other Changes

- Nix build configurations updated for the new kernel version
- No modifications to the `init` process, `linuxkit`, or `nsm.ko` driver beyond what was required for the kernel upgrade

### PCR Reproducibility

All builds use Nix for deterministic, reproducible output. To verify PCR values:

1. Build using Nix: `nix-build -A all`
2. The resulting kernel, init, and nsm.ko are bit-for-bit reproducible
3. These components are inputs to the EIF (Enclave Image File), which determines PCR0/PCR1/PCR2 values
4. PCR values registered on-chain (Sui blockchain) can be independently verified by rebuilding from source

Deterministic build settings include fixed `SOURCE_DATE_EPOCH`, `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_USER`, and `KBUILD_BUILD_HOST` to ensure reproducibility.

## Build

### Prerequisites

The binaries can be build through one of two ways:
1) Build through [Nix](https://nixos.org/download.html), which requires a local nix environment installed.
2) Build through [Docker](https://www.docker.com/), which requires a local docker environment installed.

### Building natively with Nix

If you have a working nix environment installed on your machine you can build the whole set of binaries through:

```
nix-build -A all
```

which creates the following directory structure (Example built on x86_64):

```
result/
└── x86_64
    ├── bzImage
    ├── bzImage.config
    ├── init
    ├── linuxkit
    └── nsm.ko
```

Similarly you can build individual sub-packages as follows:

```
nix-build -A kernel     # For `[bz]Image`, `[bz]Image.config`, `nsm.ko` (`Image` on aarch64, `bzImage` on x86_64)
nix-build -A init       # For the bootstrap `init` binary
nix-build -A linuxkit   # For the `linuxkit` binary
```

### Building with Docker

The project can be built inside a Docker container to avoid installing Nix on your local device.

Build the full set of binaries through:

```
docker build -t blobs_all .
```

You can extract the binaries from the docker image through the following commands:

```
docker create --name extract_blobs blobs_all
docker cp extract_blobs:/blobs ./blobs
docker rm extract_blobs
```

Similarly you can build individual sub-packages through docker as follows:

```
docker build --build-arg TARGET=kernel .   # For `[bz]Image`, `[bz]Image.config`, `nsm.ko` (`Image` on aarch64, `bzImage` on x86_64)
docker build --build-arg TARGET=init .     # For the boostrap `init` binary
docker build --build-arg TARGET=linuxkit . # For the `linuxkit` binary
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.

